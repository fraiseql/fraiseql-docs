---
title: PostgreSQL Guide for FraiseQL
description: Complete PostgreSQL implementation guide for FraiseQL's CQRS architecture with Trinity pattern, JSONB projections, materialized views, and mutation responses
---

## Introduction

PostgreSQL is the **optimal database for FraiseQL** because it perfectly supports the core CQRS + JSON in/out architecture:

- **60+ WHERE Operators**: Full-featured GraphQL input types when compiled to PostgreSQL
- **JSONB Type**: Native, indexed, queryable JSON with operators (`::`, `->`, `->>`, `@>`)
- **GIN Indexes**: Efficient indexing of JSONB columns for fast queries
- **View Composition**: Seamless aggregation of nested JSONB objects via `jsonb_build_object()`, `jsonb_agg()`
- **Stored Procedures**: PL/pgSQL for complex mutation logic with transaction support
- **Composite Types**: Strong typing for input validation and return shapes
- **Materialized Views**: Optional denormalized projections for read-heavy workloads
- **Advanced Features**: CTEs, window functions, arrays, full-text search, hierarchies (LTREE)

FraiseQL applications on PostgreSQL typically follow a **numbered directory structure** for schema organization (see [Schema Organization](#schema-organization) below).

## Core Architecture

### Single JSONB Data Column Pattern

FraiseQL views expose entities as **single JSONB columns** named `data`:

```sql
-- Every v_* view returns:
-- 1. Metadata columns (id, tenant_id, organization_id, etc.)
-- 2. Single JSONB column named 'data' containing complete entity

SELECT
  id,                    -- Metadata
  tenant_id,             -- Metadata
  organization_id,       -- Metadata
  is_current,            -- Metadata
  data                   -- Complete JSONB entity
FROM v_user
WHERE id = $1;

-- Result row:
-- id: "550e8400-e29b-41d4-a716-446655440000"
-- tenant_id: "550e8400-..."
-- organization_id: "550e8400-..."
-- is_current: true
-- data: {"id": "550e8400-...", "name": "John", "email": "john@example.com", ...}
```

**Why?** Rust GraphQL server receives complete entity as single JSONB payload, no assembly needed.

### Trinity Pattern: UUID + INTEGER PKs

FraiseQL uses a dual-identifier system:

```sql
CREATE TABLE tb_user (
  pk_user BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,  -- Internal, fast FKs
  id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),        -- Public, exposed in GraphQL
  email VARCHAR(255) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  deleted_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE tb_post (
  pk_post BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  fk_user BIGINT NOT NULL REFERENCES tb_user(pk_user) ON DELETE CASCADE,  -- Uses pk_user
  title VARCHAR(255) NOT NULL,
  deleted_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

**Why?**
- `id` (UUID): Exposed in GraphQL, immutable across systems, stateless
- `pk_*` (INTEGER): Fast joins, small FK storage, internal only
- Resolver functions bridge them in mutations

### Resolver Functions

Every table has UUID ↔ INTEGER resolver functions:

```sql
-- Resolve UUID to internal pk (used in mutations)
CREATE OR REPLACE FUNCTION core.get_pk_user(p_user_id UUID)
RETURNS BIGINT
LANGUAGE SQL STABLE PARALLEL SAFE
AS $$
  SELECT pk_user FROM tb_user WHERE id = p_user_id;
$$;

-- Resolve pk to UUID (used in responses)
CREATE OR REPLACE FUNCTION core.get_user_id(p_pk_user BIGINT)
RETURNS UUID
LANGUAGE SQL STABLE PARALLEL SAFE
AS $$
  SELECT id FROM tb_user WHERE pk_user = p_pk_user;
$$;
```

Created in the same file as the table definition for maintainability.

## Mutation Response Type

All mutations return a **composite type** with 8 fields:

```sql
-- File: 00402_type_mutation_response.sql
CREATE TYPE app.mutation_response AS (
  status          TEXT,              -- "success:created", "failed:validation", "not_found:user"
  message         TEXT,              -- Human-readable error/success message
  entity_id       TEXT,              -- UUID of created/updated entity
  entity_type     TEXT,              -- GraphQL type name: "User", "Post", "Allocation"
  entity          JSONB,             -- Complete entity from v_* view (null if error)
  updated_fields  TEXT[],            -- Array of field names that changed: ['name', 'email']
  cascade         JSONB,             -- Side-effects: {updated: [...], deleted: [...]}
  metadata        JSONB              -- Audit: {operation: "INSERT", tenant_id: "...", user_id: "..."}
);
```

**Example mutation result:**
```json
{
  "status": "success:created",
  "message": "User created successfully",
  "entity_id": "550e8400-e29b-41d4-a716-446655440000",
  "entity_type": "User",
  "entity": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "john@example.com",
    "name": "John Doe"
  },
  "updated_fields": ["email", "name"],
  "cascade": {
    "updated": [
      {"__typename": "Organization", "id": "...", "member_count": 5}
    ]
  },
  "metadata": {
    "operation": "INSERT",
    "tenant_id": "...",
    "user_id": "...",
    "timestamp": "2024-02-08T10:30:00Z"
  }
}
```

## Input Types

Mutations accept strongly-typed input via composite types:

```sql
-- File: 00445_type_user_input.sql
CREATE TYPE app.type_user_input AS (
  email         VARCHAR(255),
  name          VARCHAR(255),
  status        VARCHAR(50),
  metadata      JSONB
);

-- File: 00446_type_post_input.sql
CREATE TYPE app.type_post_input AS (
  title         VARCHAR(255),
  content       TEXT,
  author_id     UUID,
  status        VARCHAR(50)
);
```

**Security: Input Validation & SQL Injection Prevention**

All input examples use **parameterized queries** (`$1`, `$2` placeholders) to prevent SQL injection:

```sql
-- ✅ SAFE: Parameterized query
SELECT * FROM tb_user WHERE id = $1 AND email = $2;
-- Caller: EXECUTE query_text USING user_id, email;

-- ❌ UNSAFE: String concatenation (NEVER DO THIS)
-- SELECT * FROM tb_user WHERE id = '" || user_id || "';
-- This allows injection: user_id = "'; DROP TABLE tb_user; --"
```

Best practices applied in all examples:
- ✅ JSON values extracted before SQL composition (`JSON_VALUE()` patterns)
- ✅ Enums validated against whitelist before use (status IN ('active', 'suspended'))
- ✅ String lengths enforced at database level (VARCHAR(255))
- ✅ All external input treated as untrusted

Used in mutation functions for validation:

```sql
CREATE OR REPLACE FUNCTION app.create_user(
  input_tenant_id UUID,
  input_user_id UUID,
  input_payload JSONB                                   -- Raw API payload
) RETURNS app.mutation_response
LANGUAGE plpgsql AS $$
DECLARE
  v_input app.type_user_input;
BEGIN
  -- Deserialize JSON to typed composite
  v_input := jsonb_populate_record(
    NULL::app.type_user_input,
    input_payload
  );

  -- Delegate to core function with validated input
  RETURN core.create_user(
    input_tenant_id,
    input_user_id,
    v_input,
    input_payload
  );
END;
$$;
```

## View Structure: v_* (Regular Views)

Views are the **source truth** for read operations:

```sql
-- File: 02411_v_user.sql
CREATE OR REPLACE VIEW v_user AS
SELECT
  u.id,
  u.organization_id,                             -- Tenant context for RLS
  u.tenant_id,                                   -- Tenant context for RLS
  u.deleted_at IS NULL AS is_current,            -- Soft-delete filter
  jsonb_build_object(
    'id', u.id::TEXT,
    'email', u.email,
    'name', u.name,
    'status', u.status,
    'role', u.role,
    'created_at', u.created_at,
    'updated_at', u.updated_at
  ) AS data
FROM tb_user u
WHERE u.deleted_at IS NULL;  -- Always filter soft-deletes
```

**View Query Pattern:**
```sql
-- Client requests: query { user(id: "uuid") { id name email } }
-- Server executes:
SELECT id, data FROM v_user WHERE id = $1;
```

### Nested Views (One-to-Many Relationships)

```sql
-- File: 02412_v_user_with_posts.sql
CREATE OR REPLACE VIEW v_user_with_posts AS
SELECT
  u.id,
  u.organization_id,
  u.tenant_id,
  u.is_current,
  jsonb_build_object(
    'id', u.id::TEXT,
    'email', u.email,
    'name', u.name,
    'posts', COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', p.id::TEXT,
          'title', p.title,
          'status', p.status
        ) ORDER BY p.created_at DESC
      ) FILTER (WHERE p.id IS NOT NULL),
      '[]'::jsonb
    )
  ) AS data
FROM v_user u
LEFT JOIN tb_post p ON p.fk_user = u.pk_user AND p.deleted_at IS NULL
WHERE u.is_current
GROUP BY u.pk_user, u.id, u.organization_id, u.tenant_id, u.is_current;
```

**Key Patterns:**
- Views embed other views' JSONB data (no duplication)
- `FILTER (WHERE ...)` ensures empty arrays instead of NULL
- `COALESCE(..., '[]'::jsonb)` provides default empty array
- `ORDER BY` within aggregation for consistent ordering
- Always group by PK and all selected columns

### Deep Nesting (3+ Levels)

```sql
-- File: 02413_v_user_with_posts_and_comments.sql
CREATE OR REPLACE VIEW v_user_with_posts_and_comments AS
SELECT
  u.id,
  u.organization_id,
  u.tenant_id,
  u.is_current,
  jsonb_build_object(
    'id', u.id::TEXT,
    'email', u.email,
    'name', u.name,
    'posts', COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', p.id::TEXT,
          'title', p.title,
          'comments', (
            SELECT COALESCE(
              jsonb_agg(
                jsonb_build_object(
                  'id', c.id::TEXT,
                  'content', c.content
                ) ORDER BY c.created_at
              ),
              '[]'::jsonb
            )
            FROM tb_comment c
            WHERE c.fk_post = p.pk_post AND c.deleted_at IS NULL
          )
        ) ORDER BY p.created_at DESC
      ) FILTER (WHERE p.id IS NOT NULL),
      '[]'::jsonb
    )
  ) AS data
FROM v_user u
LEFT JOIN tb_post p ON p.fk_user = u.pk_user AND p.deleted_at IS NULL
WHERE u.is_current
GROUP BY u.pk_user, u.id, u.organization_id, u.tenant_id, u.is_current;
```

## Materialized Views: tv_* (Denormalized Projections)

For **read-heavy workloads** with complex object graphs, use table-backed materialized views:

```sql
-- File: 02414_tv_user.sql
-- Table-backed denormalized projection
CREATE TABLE IF NOT EXISTS tv_user (
  id UUID PRIMARY KEY,
  organization_id UUID NOT NULL,
  tenant_id UUID NOT NULL,
  is_current BOOLEAN DEFAULT TRUE,
  data JSONB NOT NULL DEFAULT '{}'::jsonb,

  -- Materialization metadata
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  last_synced_at TIMESTAMP WITH TIME ZONE,
  sync_count INTEGER DEFAULT 0,

  -- Data quality tracking
  is_stale BOOLEAN DEFAULT FALSE
);

-- Indexes for query access patterns
CREATE INDEX idx_tv_user_organization ON tv_user(organization_id);
CREATE INDEX idx_tv_user_tenant ON tv_user(tenant_id);
CREATE INDEX idx_tv_user_is_current ON tv_user(is_current) WHERE is_current = TRUE;
CREATE INDEX idx_tv_user_updated_at ON tv_user(updated_at DESC);

-- JSONB GIN index for nested queries on 'data' column
CREATE INDEX idx_tv_user_data_gin ON tv_user USING GIN(data);
```

**Refresh Strategy:**

```sql
-- File: 03101_refresh_user.sql
-- Full refresh: recompute from v_user
CREATE OR REPLACE FUNCTION core.fast_refresh_user(
  p_organization_id UUID DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO tv_user (id, organization_id, tenant_id, is_current, data)
  SELECT
    id, organization_id, tenant_id, is_current, data
  FROM v_user_with_posts
  WHERE p_organization_id IS NULL OR organization_id = p_organization_id
  ON CONFLICT (id) DO UPDATE SET
    data = EXCLUDED.data,
    updated_at = CURRENT_TIMESTAMP,
    last_synced_at = CURRENT_TIMESTAMP,
    sync_count = tv_user.sync_count + 1,
    is_stale = FALSE;
END;
$$;

-- Partial refresh: update specific scope fields
CREATE OR REPLACE FUNCTION core.refresh_user(
  p_user_id UUID,
  p_scope TEXT[] DEFAULT NULL  -- NULL = full, ['posts'] = update posts field only
) RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
  v_new_data JSONB;
BEGIN
  SELECT data INTO v_new_data FROM v_user_with_posts WHERE id = p_user_id;

  IF p_scope IS NULL THEN
    -- Full refresh
    UPDATE tv_user SET
      data = v_new_data,
      updated_at = CURRENT_TIMESTAMP,
      last_synced_at = CURRENT_TIMESTAMP,
      sync_count = sync_count + 1,
      is_stale = FALSE
    WHERE id = p_user_id;
  ELSE
    -- Partial refresh: update only specified top-level fields
    UPDATE tv_user SET
      data = (
        SELECT jsonb_object_agg(key, value)
        FROM jsonb_each(data)
        WHERE key = ANY(p_scope)
      ) || (
        SELECT jsonb_object_agg(key, value)
        FROM jsonb_each(v_new_data)
        WHERE key = ANY(p_scope)
      ),
      updated_at = CURRENT_TIMESTAMP,
      last_synced_at = CURRENT_TIMESTAMP,
      sync_count = sync_count + 1,
      is_stale = FALSE
    WHERE id = p_user_id;
  END IF;
END;
$$;
```

## Mutation Functions: app/ vs core/

FraiseQL separates concerns into two schemas:

### app/ Schema: API Layer

Handles JSON deserialization from GraphQL payloads:

```sql
-- File: 03311_create_user.sql
-- app/ schema: JSON → Typed validation
CREATE OR REPLACE FUNCTION app.create_user(
  input_tenant_id UUID,
  input_user_id UUID,
  input_payload JSONB
) RETURNS app.mutation_response
LANGUAGE plpgsql AS $$
DECLARE
  v_input app.type_user_input;
BEGIN
  -- Deserialize raw JSON to composite type
  v_input := jsonb_populate_record(
    NULL::app.type_user_input,
    input_payload
  );

  -- Delegate to core function with validated input
  RETURN core.create_user(
    input_tenant_id,
    input_user_id,
    v_input,
    input_payload
  );
EXCEPTION WHEN others THEN
  RETURN core.build_error_response(
    'invalid_input',
    'Input validation failed: ' || SQLERRM,
    NULL,
    NULL
  );
END;
$$;
```

### core/ Schema: Business Logic Layer

Contains actual implementation with Trinity pattern handling:

```sql
-- File: 03311_create_user.sql
-- core/ schema: Business logic + transactions
CREATE OR REPLACE FUNCTION core.create_user(
  input_tenant_id UUID,
  input_user_id UUID,
  input_data app.type_user_input,
  input_payload JSONB
) RETURNS app.mutation_response
LANGUAGE plpgsql AS $$
DECLARE
  v_entity TEXT := 'User';
  v_user_id UUID := gen_random_uuid();
  v_user_pk BIGINT;
  v_existing_email UUID;
  v_entity_data JSONB;
BEGIN
  -- Validate inputs
  IF input_data.email IS NULL OR input_data.email = '' THEN
    RETURN core.build_error_response(
      'invalid_input',
      'email is required',
      NULL,
      v_entity
    );
  END IF;

  -- Check for duplicate email
  SELECT id INTO v_existing_email
  FROM tb_user
  WHERE email = input_data.email AND deleted_at IS NULL;

  IF v_existing_email IS NOT NULL THEN
    RETURN core.build_error_response(
      'conflict:email',
      'Email already in use',
      v_existing_email,
      v_entity
    );
  END IF;

  -- INSERT with TRINITY pattern: both id and pk_user
  INSERT INTO tb_user (
    id,
    email,
    name,
    status,
    created_by
  ) VALUES (
    v_user_id,
    input_data.email,
    input_data.name,
    COALESCE(input_data.status, 'active'),
    input_user_id
  ) RETURNING pk_user INTO v_user_pk;

  -- AFTER snapshot: read from view
  SELECT data INTO v_entity_data
  FROM v_user
  WHERE id = v_user_id;

  -- Log mutation (audit trail)
  INSERT INTO ta_audit (
    entity_type, entity_id, operation, changes,
    tenant_id, user_id
  ) VALUES (
    v_entity, v_user_id, 'INSERT', jsonb_build_object(
      'id', v_user_id,
      'email', input_data.email,
      'name', input_data.name
    ),
    input_tenant_id, input_user_id
  );

  -- OPTIONAL: Refresh materialized view
  -- (called explicitly if tv_user exists; otherwise optional)
  PERFORM core.refresh_user(v_user_id);

  -- Build response
  RETURN (
    'success:created'::TEXT,
    'User created successfully'::TEXT,
    v_user_id::TEXT,
    v_entity,
    v_entity_data,
    ARRAY['id', 'email', 'name']::TEXT[],
    NULL::JSONB,
    jsonb_build_object(
      'operation', 'INSERT',
      'entity_pk', v_user_pk,
      'timestamp', CURRENT_TIMESTAMP
    )
  )::app.mutation_response;

EXCEPTION WHEN others THEN
  RETURN core.build_error_response(
    'database_error',
    'Create user failed: ' || SQLERRM,
    NULL,
    v_entity
  );
END;
$$;
```

## Schema Organization: Numbered Prefix System

FraiseQL projects typically use a hierarchical file structure:

```


│
│   │
│   │
│   │
│   │
│   │   │
│   │   │
│   │   ↓
│   │
│   │
│   ↓
│
│   │
│   │
│   │
│   │
│   │
│   │
│   │
│   ↓
│
│   │
│   │
│   │
│   │   │
│   │   │
│   │   │
│   │   │
│   │   ↓
│   │
│   ↓
│
│   │
│   │   │
│   │   │
│   │   │
│   │   │
│   │   ↓
│   │
│   │
│   │   │
│   │   │
│   │   │
│   │   ↓
│   │
│   │   │
│   │   │
│   │   │
│   │   │
│   │   │
│   │   ↓
│   │
│   │
│   ↓
│
↓





│
↓
```

**File Naming Convention:**
- Directory number: `0` = schema, `1` = seed, etc.
- Subdirectory number: `24` = query_side/dim, `31` = crm, etc.
- File sequence: `1` = first file, `2` = second, etc.
- Example: `024511_tb_user.sql` = schema/query_side/dim/user/first-file

**Benefits:**
- Deterministic execution order (numbered directories execute in order)
- Easy to insert new phases (`4_resolve_prep_seed` added mid-sequence)
- Clear responsibility separation
- Supports environment-specific deployments (`database_development.sql`, `database_production.sql`)
- Schema version management and rollbacks

## Analytics Architecture

FraiseQL analytics uses a canonical **Star Schema pattern** with:
- **Calendar dimension table** (tb_calendar) for pre-computed temporal dimensions
- **Fact tables** (tf_*) with measures as direct columns and dimensions as JSONB
- **Analytics views** (va_*) that compose dimensions + measures with calendar JOIN
- **Analytics tables** (ta_*) for Arrow/Parquet export with flattened structure

See [FraiseQL Analytics Architecture](/analytics-architecture/) for the complete canonical pattern, including:
- Calendar dimension design and benefits (10-16x faster temporal queries)
- Fact table structure (measures vs dimensions decision matrix)
- Dimension composition patterns with explicit separation
- Analytics table population and refresh strategies
- Year-over-year and cohort analysis examples

### PostgreSQL-Specific Implementation

**Calendar Dimension Table:**

```sql
-- File: 01001_tb_calendar.sql
-- Pre-computed temporal dimensions (seeded 2015-2035, one-time operation)
CREATE TABLE tb_calendar (
    id UUID DEFAULT gen_random_uuid() UNIQUE,
    reference_date DATE PRIMARY KEY,

    week INT,
    week_n_days INT,
    half_month INT,
    half_month_n_days INT,
    month INT,
    month_n_days INT,
    quarter INT,
    quarter_n_days INT,
    semester INT,
    semester_n_days INT,
    year INT,
    year_n_days INT,

    date_info JSONB,
    week_info JSONB,
    half_month_info JSONB,
    month_info JSONB,
    quarter_info JSONB,
    semester_info JSONB,
    year_info JSONB,

    week_reference_date DATE,
    half_month_reference_date DATE,
    month_reference_date DATE,
    quarter_reference_date DATE,
    semester_reference_date DATE,
    year_reference_date DATE,

    is_week_reference_date BOOLEAN,
    is_half_month_reference_date BOOLEAN,
    is_month_reference_date BOOLEAN,
    is_quarter_reference_date BOOLEAN,
    is_semester_reference_date BOOLEAN,
    is_year_reference_date BOOLEAN,

    array_interval_dates DATE[]
);

CREATE INDEX idx_tb_calendar_date ON tb_calendar(reference_date);
CREATE INDEX idx_tb_calendar_year_month ON tb_calendar(year, month);

-- Seed calendar data
INSERT INTO tb_calendar (reference_date, week, month, quarter, semester, year, date_info, month_reference_date, is_month_reference_date)
SELECT
    d::DATE,
    EXTRACT(WEEK FROM d)::INT,
    EXTRACT(MONTH FROM d)::INT,
    EXTRACT(QUARTER FROM d)::INT,
    CASE WHEN EXTRACT(MONTH FROM d) <= 6 THEN 1 ELSE 2 END,
    EXTRACT(YEAR FROM d)::INT,
    jsonb_build_object(
        'date', d::text,
        'week', EXTRACT(WEEK FROM d),
        'month', EXTRACT(MONTH FROM d),
        'quarter', EXTRACT(QUARTER FROM d),
        'semester', CASE WHEN EXTRACT(MONTH FROM d) <= 6 THEN 1 ELSE 2 END,
        'year', EXTRACT(YEAR FROM d)
    ),
    DATE_TRUNC('month', d)::DATE,
    (EXTRACT(DAY FROM d) = 1)
FROM generate_series('2015-01-01'::date, '2035-12-31'::date, '1 day') AS d;
```

**Fact Table with Measures and Dimensions:**

```sql
-- File: 01002_tf_user_events.sql
-- Fact table: user events with measures as direct columns
CREATE TABLE tf_user_events (
    pk_event BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,

    -- MEASURES (direct columns for fast aggregation)
    event_count INT DEFAULT 1,
    engagement_score NUMERIC(5,2) NOT NULL,
    duration_seconds INT,

    -- DIMENSIONS (JSONB for flexibility)
    data JSONB NOT NULL,

    -- TEMPORAL (foreign key to calendar)
    occurred_at DATE NOT NULL,

    -- DENORMALIZED KEYS (indexed for filtering)
    user_id UUID NOT NULL,
    organization_id UUID NOT NULL,
    event_type TEXT NOT NULL,

    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_tf_user_events_occurred ON tf_user_events(occurred_at);
CREATE INDEX idx_tf_user_events_user ON tf_user_events(user_id);
CREATE INDEX idx_tf_user_events_organization ON tf_user_events(organization_id);
CREATE INDEX idx_tf_user_events_type ON tf_user_events(event_type);
CREATE INDEX idx_tf_user_events_data ON tf_user_events USING GIN(data);
```

**Fact Table Example Data:**

```json
{
    "session_id": "sess-001",
    "device": "mobile",
    "location": "US/West",
    "user_agent": "Mozilla/5.0...",
    "properties": {
        "page_url": "/dashboard",
        "referrer": "/home"
    }
}
```

**Analytics View with Calendar JOIN:**

```sql
-- File: 02701_va_user_events_daily.sql
-- Composition view: dimensions + measures + temporal context
CREATE OR REPLACE VIEW va_user_events_daily AS
SELECT
    e.user_id,
    e.organization_id,
    jsonb_build_object(
        'dimensions', e.data || jsonb_build_object(
            'date_info', cal.date_info,
            'event_type', e.event_type
        ),
        'measures', jsonb_build_object(
            'event_count', SUM(e.event_count),
            'total_engagement', SUM(e.engagement_score),
            'total_duration', SUM(e.duration_seconds),
            'avg_engagement', AVG(e.engagement_score)
        ),
        'temporal', jsonb_build_object(
            'date', (cal.date_info ->> 'date')::DATE,
            'week', cal.week,
            'month', cal.month,
            'quarter', cal.quarter,
            'year', cal.year
        )
    ) AS data
FROM tf_user_events e
LEFT JOIN tb_calendar cal ON cal.reference_date = e.occurred_at
WHERE e.occurred_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY e.user_id, e.organization_id, cal.date_info, e.event_type, cal.week, cal.month, cal.quarter, cal.year;
```

**Analytics Table for Arrow/Parquet Export:**

```sql
-- File: 01003_ta_user_events_daily.sql
-- Pre-aggregated, flattened structure for Arrow Flight export
CREATE TABLE ta_user_events_daily (
    day DATE NOT NULL,
    user_id UUID NOT NULL,
    organization_id UUID NOT NULL,
    event_type TEXT NOT NULL,

    event_count BIGINT NOT NULL,
    total_engagement NUMERIC(12,2) NOT NULL,
    total_duration BIGINT NOT NULL,
    avg_engagement NUMERIC(5,2) NOT NULL,

    year INT NOT NULL,
    month INT NOT NULL,
    week INT NOT NULL,
    quarter INT NOT NULL,

    computed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    sync_count BIGINT DEFAULT 1,
    is_stale BOOLEAN DEFAULT FALSE,

    PRIMARY KEY (day, user_id, event_type),
    INDEX idx_ta_user_events_daily_org ON ta_user_events_daily(organization_id, day)
);

-- Refresh procedure (hourly execution)
CREATE OR REPLACE PROCEDURE sp_sync_ta_user_events_daily()
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO ta_user_events_daily (day, user_id, organization_id, event_type, event_count, total_engagement, total_duration, avg_engagement, year, month, week, quarter, computed_at, sync_count, is_stale)
    SELECT
        e.occurred_at,
        e.user_id,
        e.organization_id,
        e.event_type,
        COUNT(*),
        SUM(e.engagement_score),
        SUM(e.duration_seconds),
        AVG(e.engagement_score),
        cal.year,
        cal.month,
        cal.week,
        cal.quarter,
        CURRENT_TIMESTAMP,
        1,
        FALSE
    FROM tf_user_events e
    LEFT JOIN tb_calendar cal ON cal.reference_date = e.occurred_at
    WHERE e.occurred_at >= CURRENT_DATE - INTERVAL '7 days'
    GROUP BY e.occurred_at, e.user_id, e.organization_id, e.event_type, cal.year, cal.month, cal.week, cal.quarter
    ON CONFLICT (day, user_id, event_type) DO UPDATE SET
        event_count = EXCLUDED.event_count,
        total_engagement = EXCLUDED.total_engagement,
        total_duration = EXCLUDED.total_duration,
        avg_engagement = EXCLUDED.avg_engagement,
        computed_at = CURRENT_TIMESTAMP,
        sync_count = sync_count + 1,
        is_stale = FALSE;

    -- Clean old data
    DELETE FROM ta_user_events_daily WHERE day < CURRENT_DATE - INTERVAL '2 years';
END;
$$;

-- Read view for Arrow Flight
CREATE OR REPLACE VIEW va_user_events_daily_arrow AS
SELECT * FROM ta_user_events_daily WHERE is_stale = FALSE ORDER BY day DESC;
```

**Year-over-Year Analysis Query:**

```sql
-- Compare monthly engagement across years
SELECT
    cal.month,
    cal.year,
    COUNT(*) AS event_count,
    SUM(e.engagement_score) AS total_engagement,
    AVG(e.engagement_score) AS avg_engagement
FROM tf_user_events e
LEFT JOIN tb_calendar cal ON cal.reference_date = e.occurred_at
WHERE e.organization_id = $1
GROUP BY cal.year, cal.month
ORDER BY cal.year DESC, cal.month;
```

## Configuration & Performance

### FraiseQL-Optimized PostgreSQL Configuration

```ini
# postgresql.conf
[memory]
shared_buffers = 4GB                    # 25% of available RAM
effective_cache_size = 12GB             # 75% of available RAM
maintenance_work_mem = 1GB              # For CREATE INDEX, VACUUM
work_mem = 50MB                         # Per operation

[query_planning]
random_page_cost = 1.1                  # For SSDs
effective_io_concurrency = 200
join_collapse_limit = 12
from_collapse_limit = 12

[jsonb_and_indexes]
# GIN indexes significantly improve jsonb performance
# Ensure jsonb_ops or jsonb_path_ops indexes are used

[connection_pooling]
max_connections = 200
# Use pgBouncer for connection pooling in production:
# - pgBouncer config: pool_mode = transaction
# - min_pool_size = 5
# - max_client_conn = 1000
```

### Index Strategy for Views

```sql
-- Indexes on write tables (tb_*) support view queries
CREATE TABLE tb_user (
  pk_user BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  id UUID NOT NULL UNIQUE,                      -- For direct ID lookups
  email VARCHAR(255) NOT NULL UNIQUE,           -- For email-based queries
  organization_id UUID,                         -- For tenant filtering
  deleted_at TIMESTAMP WITH TIME ZONE,          -- For soft-delete filtering
  created_at TIMESTAMP WITH TIME ZONE,
  -- Indexes for view queries
  INDEX idx_user_email (email),
  INDEX idx_user_organization (organization_id),
  INDEX idx_user_deleted_created (deleted_at, created_at DESC),
  INDEX idx_user_id (id)
);

-- Indexes on materialized tables (tv_*)
CREATE TABLE tv_user (
  id UUID PRIMARY KEY,
  organization_id UUID NOT NULL,
  data JSONB NOT NULL,
  INDEX idx_tv_user_organization (organization_id),
  INDEX idx_tv_user_data_gin USING GIN(data)  -- JSONB GIN index
);

-- Monitor index usage
SELECT
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;
```

### JSONB Query Examples

```sql
-- Extract specific fields from data column
SELECT
  id,
  data->>'email' as email,              -- ->> for text
  (data->>'age')::INTEGER as age,
  data->'metadata' as metadata_object,  -- -> for JSONB
  data->'tags'->0 as first_tag
FROM v_user
WHERE id = $1;

-- Filter on JSONB fields
SELECT * FROM v_user
WHERE data->>'status' = 'active'
  AND (data->'tags')::TEXT LIKE '%premium%';

-- JSONB containment queries (requires GIN index)
SELECT * FROM tv_user
WHERE data @> jsonb_build_object('status', 'active', 'verified', true);

-- JSONB aggregation
SELECT
  data->>'organization_id' as org,
  jsonb_agg(data) as all_users
FROM v_user
GROUP BY data->>'organization_id';
```

## Troubleshooting

### View Returns NULL for JSONB Aggregations

```sql
-- Problem: jsonb_agg returns NULL for zero matches
CREATE VIEW v_broken AS
SELECT jsonb_agg(p.data) FROM tb_post p GROUP BY 1;
-- Result: NULL (not [])

-- Solution: Use COALESCE with FILTER
CREATE VIEW v_fixed AS
SELECT COALESCE(
  jsonb_agg(p.data ORDER BY p.created_at DESC)
  FILTER (WHERE p.deleted_at IS NULL),
  '[]'::jsonb
) as posts FROM tb_post p GROUP BY p.user_id;
```

### Mutation Not Refreshing Materialized View

```sql
-- Problem: tv_user not updated after insert
-- Solution: Call refresh in mutation
CREATE FUNCTION core.create_user(...) RETURNS mutation_response AS $$
BEGIN
  INSERT INTO tb_user (...);
  -- ← Add this:
  PERFORM core.refresh_user(v_user_id);
  -- Now tv_user is updated
END;
$$;
```

### JSONB GIN Index Not Being Used

```sql
-- Check if index exists and has stats
SELECT * FROM pg_stat_user_indexes
WHERE indexname = 'idx_tv_user_data_gin';

-- If not used, check query plan
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM tv_user
WHERE data @> jsonb_build_object('status', 'active');
-- Look for "Bitmap Index Scan" on GIN index

-- Recreate index if needed
DROP INDEX IF EXISTS idx_tv_user_data_gin;
CREATE INDEX idx_tv_user_data_gin ON tv_user USING GIN(data);
```

### High Memory Usage During View Computation

```sql
-- Problem: Complex nested aggregations consume excessive memory
-- Solution: Increase work_mem for the connection
SET work_mem = '256MB';

-- Or use LIMIT to compute in batches
SELECT data FROM v_user_with_posts
WHERE organization_id = $1
LIMIT 100;
```

## Bulk Operations: Initial Data Load

For seeding calendar data and bulk inserts, use PostgreSQL's optimized bulk loading:

### COPY (Fastest - ~100K rows/sec)

```sql
-- Calendar seed data from CSV
\COPY tb_calendar(reference_date, week, month, quarter, semester, year, date_info, ...)
FROM 'calendar_2015_2035.csv' WITH (FORMAT csv, DELIMITER ',', HEADER true);

-- Fact table bulk insert from CSV
\COPY tf_sales(day, customer_id, product_id, quantity, revenue)
FROM 'sales_data.csv' WITH (FORMAT csv, DELIMITER ',', HEADER true);
```

### COPY with JSON Serialization

```sql
-- From application: generate JSON and stream to COPY
-- Example: Python psycopg2
with open('calendar.csv', 'w') as f:
    for date in calendar_dates:
        date_info = json.dumps({
            'date': date.isoformat(),
            'week': date.isocalendar()[1],
            'month': date.month,
            'year': date.year
        })
        f.write(f"{date.isoformat()},{date.isocalendar()[1]},...,{date_info}\n")

cursor.copy_from(f, 'tb_calendar', columns=[...])
```

### Batched Inserts (When COPY not available)

```sql
-- Batch insert in transactions (prevents memory spike)
BEGIN TRANSACTION;
INSERT INTO tf_sales(day, customer_id, quantity, revenue) VALUES
  ($1, $2, $3, $4),
  ($5, $6, $7, $8),
  ...
  ($10001, $10002, $10003, $10004);
COMMIT;


         ─
                 ─
                   ─
                                ─
- Disable indexes during bulk load: `ALTER TABLE tb_calendar DISABLE TRIGGER ALL`
- Re-enable and rebuild after: `ALTER TABLE tb_calendar ENABLE TRIGGER ALL; REINDEX TABLE tb_calendar;`
- Use `UNLOGGED TABLE` for temporary bulk loading (40% faster, not crash-safe)
- Monitor: `SHOW work_mem;` - increase for large sorts during COPY

## Migration from Other Databases

PostgreSQL is optimal, but if migrating from MySQL/SQLite/SQL Server:

```sql
         ─
                 ─
                   ─
                                ─

          ─
                 ─
          ─

              ─
                 ─
                ─
                ─
```

## Performance Benchmarks

Typical FraiseQL PostgreSQL workloads:

| Query Type | Latency | Notes |
|-----------|---------|-------|
| Single entity (v_*) | 0.2-0.5ms | Direct index lookup on id |
| List query (1000 rows) | 5-15ms | With is_current filter |
| Nested JSON (5 levels) | 20-100ms | Depends on aggregation size |
| Materialized view access (tv_*) | 0.5-2ms | Pre-computed JSONB |
| Analytics view (va_*) | 50-500ms | GROUP BY aggregation |
| Full-text search | 100-1000ms | On indexed text fields |

**Optimization Tips:**
- Use `tv_*` for frequently-accessed complex objects (>10 reads/sec)
- Use `v_*` for simple entities or when real-time accuracy required
- GIN indexes on JSONB data significantly improve performance
- BRIN indexes for time-series data (created_at, updated_at)
- Partial indexes on soft-delete filters: `WHERE deleted_at IS NULL`

## See Also

- [Database Comparison](/databases/)
- [MySQL Guide](/databases/mysql/)
- [SQLite Guide](/databases/sqlite/)
- [SQL Server Guide](/databases/sqlserver/)
