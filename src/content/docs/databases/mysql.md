---
title: MySQL Guide for FraiseQL
description: MySQL implementation guide for FraiseQL with Trinity pattern, JSON projections, materialized views, and considerations for JSON vs JSONB
---

## Introduction

MySQL is a **solid choice for FraiseQL** when PostgreSQL isn't available or when you have existing MySQL infrastructure:

- **~20 WHERE Operators**: Fewer than PostgreSQL but suitable for most GraphQL input types
- **JSON Type Support**: Native JSON type (since 5.7) with functions for composition
- **JSON_OBJECT & JSON_ARRAYAGG**: Enables JSONB-like view composition (MySQL 5.7.22+)
- **InnoDB ACID**: Full transaction support with row-level locking
- **View Composition**: Can aggregate nested JSON objects, though less elegant than JSONB
- **Stored Procedures**: MySQL stored procedures for mutation logic
- **Composite Types**: User-defined types via JSON structures
- **Wide Availability**: Common on shared hosting and cloud platforms

**Key Limitation**: JSON is text-based, not JSONB. This means:
- Slightly slower queries (string parsing vs. optimized binary format)
- No native JSONB operators like `@>` (containment)
- GIN indexes not available; JSON path indexes more limited
- Slightly more verbose query syntax

FraiseQL works perfectly on MySQL; it just requires slightly different optimization strategies.

## Core Architecture

### Single JSON Data Column Pattern

Like PostgreSQL, FraiseQL views expose entities as **single JSON columns** named `data`:

```sql
-- Every v_* view returns:
-- 1. Metadata columns (id, tenant_id, organization_id, etc.)
-- 2. Single JSON column named 'data' containing complete entity

SELECT
  id,                    -- Metadata
  tenant_id,             -- Metadata
  organization_id,       -- Metadata
  is_current,            -- Metadata
  data                   -- Complete JSON entity
FROM v_user
WHERE id = UNHEX($1);

-- Result row:
-- id: "550e8400-e29b-41d4-a716-446655440000"
-- tenant_id: "550e8400-..."
-- organization_id: "550e8400-..."
-- is_current: true
-- data: {"id": "550e8400-...", "name": "John", "email": "john@example.com", ...}
```

**Why?** Rust GraphQL server receives complete entity as single JSON payload, no assembly needed.

### Trinity Pattern: CHAR(36) UUID + INTEGER PKs

FraiseQL uses a dual-identifier system (adapted for MySQL):

```sql
CREATE TABLE tb_user (
  pk_user BIGINT PRIMARY KEY AUTO_INCREMENT,                    -- Internal, fast FKs
  id CHAR(36) NOT NULL UNIQUE DEFAULT (UUID()),                 -- Public, exposed in GraphQL
  email VARCHAR(255) NOT NULL UNIQUE COLLATE utf8mb4_unicode_ci,
  name VARCHAR(255) NOT NULL,
  deleted_at TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_user_id (id),
  KEY idx_user_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE tb_post (
  pk_post BIGINT PRIMARY KEY AUTO_INCREMENT,
  id CHAR(36) NOT NULL UNIQUE DEFAULT (UUID()),
  fk_user BIGINT NOT NULL REFERENCES tb_user(pk_user) ON DELETE CASCADE,  -- Uses pk_user
  title VARCHAR(255) NOT NULL,
  deleted_at TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_post_user (fk_user)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

**Why?**
- `id` (CHAR(36)): UUID exposed in GraphQL, immutable across systems
- `pk_*` (BIGINT): Fast joins, small FK storage, internal only
- Resolver functions bridge them in mutations

### Resolver Functions

Every table has UUID ↔ INTEGER resolver functions:

```sql
-- Resolve UUID to internal pk (used in mutations)
DELIMITER $$
CREATE FUNCTION core_get_pk_user(p_user_id CHAR(36))
RETURNS BIGINT
READS SQL DATA
DETERMINISTIC
BEGIN
  DECLARE v_pk BIGINT;
  SELECT pk_user INTO v_pk FROM tb_user WHERE id = p_user_id LIMIT 1;
  RETURN v_pk;
END$$
DELIMITER ;

-- Resolve pk to UUID (used in responses)
DELIMITER $$
CREATE FUNCTION core_get_user_id(p_pk_user BIGINT)
RETURNS CHAR(36)
READS SQL DATA
DETERMINISTIC
BEGIN
  DECLARE v_id CHAR(36);
  SELECT id INTO v_id FROM tb_user WHERE pk_user = p_pk_user LIMIT 1;
  RETURN v_id;
END$$
DELIMITER ;
```

Created in the same file as the table definition for maintainability.

## Mutation Response Type

All mutations return a structure with 8 fields (using JSON for compatibility):

```sql
-- File: 00402_type_mutation_response.sql
-- Note: MySQL doesn't have composite types, so wrap in JSON
-- Helper stored procedures return JSON matching this structure:
-- {
--   "status": "success:created|failed:validation|not_found:user",
--   "message": "Human-readable message",
--   "entity_id": "UUID",
--   "entity_type": "User|Post|...",
--   "entity": {...complete JSONB...},
--   "updated_fields": ["name", "email"],
--   "cascade": {...side effects...},
--   "metadata": {...audit info...}
-- }
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

Input validation via JSON structures and stored procedure parameter validation:

```sql
-- No formal composite types in MySQL, but document expected JSON structures
-- File: 00445_type_user_input.sql
-- Expected input JSON:
-- {
--   "email": "user@example.com",
--   "name": "User Name",
--   "status": "active",
--   "metadata": {...}
-- }
```

Used in mutation procedures for validation:

```sql
DELIMITER $$
CREATE PROCEDURE app_create_user(
  IN input_tenant_id CHAR(36),
  IN input_user_id CHAR(36),
  IN input_payload JSON
)
BEGIN
  DECLARE v_email VARCHAR(255);
  DECLARE v_name VARCHAR(255);
  DECLARE v_status VARCHAR(50);

  -- Extract and validate input
  SET v_email = JSON_UNQUOTE(JSON_EXTRACT(input_payload, '$.email'));
  SET v_name = JSON_UNQUOTE(JSON_EXTRACT(input_payload, '$.name'));
  SET v_status = COALESCE(
    JSON_UNQUOTE(JSON_EXTRACT(input_payload, '$.status')),
    'active'
  );

  -- Delegate to core procedure with validated inputs
  CALL core_create_user(
    input_tenant_id,
    input_user_id,
    v_email,
    v_name,
    v_status,
    input_payload
  );
END$$
DELIMITER ;
```

**Security: Input Validation & SQL Injection Prevention**

All input examples use **parameterized queries** (prepared statements with `?` placeholders) to prevent SQL injection:

```sql
-- ✅ SAFE: Parameterized query
PREPARE stmt FROM 'SELECT * FROM tb_user WHERE id = UNHEX(?) AND email = ?';
EXECUTE stmt USING user_id, email;

-- ❌ UNSAFE: String concatenation (NEVER DO THIS)
-- SET @sql = CONCAT('SELECT * FROM tb_user WHERE id = UNHEX("', user_id, '")');
-- This allows injection: user_id = "'); DROP TABLE tb_user; --"
```

Best practices applied in all examples:
- ✅ JSON values extracted before SQL composition (`JSON_EXTRACT()` + `JSON_UNQUOTE()`)
- ✅ Enums validated against whitelist before use (status IN ('active', 'suspended'))
- ✅ String lengths enforced at database level (VARCHAR(255))
- ✅ All external input treated as untrusted
- ✅ Caller binds parameters; SQL never concatenates user input

## View Structure: v_* (Regular Views)

Views are the **source truth** for read operations:

```sql
-- File: 02411_v_user.sql
CREATE OR REPLACE VIEW v_user AS
SELECT
  u.id,
  u.organization_id,                              -- Tenant context for RLS
  u.tenant_id,                                    -- Tenant context for RLS
  u.deleted_at IS NULL AS is_current,             -- Soft-delete filter
  JSON_OBJECT(
    'id', u.id,
    'email', u.email,
    'name', u.name,
    'status', u.status,
    'role', u.role,
    'created_at', DATE_FORMAT(u.created_at, '%Y-%m-%dT%H:%i:%sZ'),
    'updated_at', DATE_FORMAT(u.updated_at, '%Y-%m-%dT%H:%i:%sZ')
  ) AS data
FROM tb_user u
WHERE u.deleted_at IS NULL;
```

**View Query Pattern:**
```sql
-- Client requests: query { user(id: "uuid") { id name email } }
-- Server executes:
SELECT id, data FROM v_user WHERE id = UNHEX($1);
```

### Nested Views (One-to-Many Relationships)

```sql
-- File: 02412_v_user_with_posts.sql
-- Note: MySQL's JSON_ARRAYAGG requires GROUP BY
CREATE OR REPLACE VIEW v_user_with_posts AS
SELECT
  u.id,
  u.organization_id,
  u.tenant_id,
  u.is_current,
  JSON_OBJECT(
    'id', u.id,
    'email', u.email,
    'name', u.name,
    'posts', COALESCE(
      JSON_ARRAYAGG(
        JSON_OBJECT(
          'id', p.id,
          'title', p.title,
          'status', p.status
        )
      ),
      JSON_ARRAY()
    )
  ) AS data
FROM v_user u
LEFT JOIN tb_post p ON p.fk_user = u.pk_user AND p.deleted_at IS NULL
WHERE u.is_current
GROUP BY u.pk_user, u.id, u.organization_id, u.tenant_id, u.is_current;
```

**Key Patterns:**
- Views embed other views' JSON data (no duplication)
- `COALESCE(..., JSON_ARRAY())` provides default empty array
- `GROUP BY` required for JSON_ARRAYAGG (list aggregation)
- Always group by PK and all selected columns
- Order determinism: use `ORDER BY` in JSON_ARRAYAGG (MySQL 5.7.31+)

### Deep Nesting (3+ Levels)

```sql
-- File: 02413_v_user_with_posts_and_comments.sql
-- More complex: requires subqueries for 3+ levels
CREATE OR REPLACE VIEW v_user_with_posts_and_comments AS
SELECT
  u.id,
  u.organization_id,
  u.tenant_id,
  u.is_current,
  JSON_OBJECT(
    'id', u.id,
    'email', u.email,
    'name', u.name,
    'posts', COALESCE(
      JSON_ARRAYAGG(
        JSON_OBJECT(
          'id', p.id,
          'title', p.title,
          'comments', (
            SELECT COALESCE(
              JSON_ARRAYAGG(
                JSON_OBJECT(
                  'id', c.id,
                  'content', c.content
                )
              ),
              JSON_ARRAY()
            )
            FROM tb_comment c
            WHERE c.fk_post = p.pk_post AND c.deleted_at IS NULL
          )
        )
      ),
      JSON_ARRAY()
    )
  ) AS data
FROM v_user u
LEFT JOIN tb_post p ON p.fk_user = u.pk_user AND p.deleted_at IS NULL
WHERE u.is_current
GROUP BY u.pk_user, u.id, u.organization_id, u.tenant_id, u.is_current;
```

**Note**: Deep nesting becomes complex in MySQL. Consider:
1. Separate, simpler views that frontends compose
2. Application-level composition (fetch separate queries)
3. Materialized snapshots for read-heavy patterns

## Materialized Views: tv_* (Denormalized Projections)

For **read-heavy workloads** with complex object graphs, use table-backed materialized views:

```sql
-- File: 02414_tv_user.sql
-- Table-backed denormalized projection
CREATE TABLE IF NOT EXISTS tv_user (
  id CHAR(36) PRIMARY KEY,
  organization_id CHAR(36) NOT NULL,
  tenant_id CHAR(36) NOT NULL,
  is_current BOOLEAN DEFAULT TRUE,
  data JSON NOT NULL DEFAULT '{}',

  -- Materialization metadata
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  last_synced_at TIMESTAMP NULL,
  sync_count INT DEFAULT 0,

  -- Data quality tracking
  is_stale BOOLEAN DEFAULT FALSE,

  -- Indexes
  KEY idx_tv_user_organization (organization_id),
  KEY idx_tv_user_tenant (tenant_id),
  KEY idx_tv_user_is_current (is_current),
  KEY idx_tv_user_updated_at (updated_at DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Refresh Strategy:**

```sql
-- File: 03101_refresh_user.sql
-- Full refresh: recompute from v_user
DELIMITER $$
CREATE PROCEDURE core_fast_refresh_user(
  IN p_organization_id CHAR(36)
)
MODIFIES SQL DATA
BEGIN
  -- Clear existing records for organization
  DELETE FROM tv_user
  WHERE p_organization_id IS NULL OR organization_id = p_organization_id;

  -- Insert refreshed data
  INSERT INTO tv_user (id, organization_id, tenant_id, is_current, data)
  SELECT
    id, organization_id, tenant_id, is_current, data
  FROM v_user_with_posts
  WHERE p_organization_id IS NULL OR organization_id = p_organization_id;
END$$
DELIMITER ;

-- Partial refresh: update specific row
DELIMITER $$
CREATE PROCEDURE core_refresh_user(
  IN p_user_id CHAR(36)
)
MODIFIES SQL DATA
BEGIN
  DECLARE v_new_data JSON;

  SELECT data INTO v_new_data
  FROM v_user_with_posts
  WHERE id = p_user_id;

  IF v_new_data IS NOT NULL THEN
    INSERT INTO tv_user (id, organization_id, tenant_id, is_current, data)
    SELECT id, organization_id, tenant_id, is_current, v_new_data
    FROM v_user
    WHERE id = p_user_id
    ON DUPLICATE KEY UPDATE
      data = VALUES(data),
      updated_at = CURRENT_TIMESTAMP,
      last_synced_at = CURRENT_TIMESTAMP,
      sync_count = sync_count + 1,
      is_stale = FALSE;
  END IF;
END$$
DELIMITER ;
```

## Mutation Procedures: app_ vs core_

FraiseQL separates concerns into two procedure sets (MySQL doesn't have schemas as easily):

### app_ Procedures: API Layer

Handles JSON deserialization from GraphQL payloads:

```sql
-- File: 03311_create_user.sql
-- app_ procedures: JSON → Validation
DELIMITER $$
CREATE PROCEDURE app_create_user(
  IN input_tenant_id CHAR(36),
  IN input_user_id CHAR(36),
  IN input_payload JSON
)
BEGIN
  DECLARE v_email VARCHAR(255);
  DECLARE v_name VARCHAR(255);
  DECLARE v_status VARCHAR(50);

  -- Extract JSON fields
  SET v_email = JSON_UNQUOTE(JSON_EXTRACT(input_payload, '$.email'));
  SET v_name = JSON_UNQUOTE(JSON_EXTRACT(input_payload, '$.name'));
  SET v_status = COALESCE(
    JSON_UNQUOTE(JSON_EXTRACT(input_payload, '$.status')),
    'active'
  );

  -- Validate required fields
  IF v_email IS NULL OR v_email = '' THEN
    SELECT JSON_OBJECT(
      'status', 'invalid_input',
      'message', 'email is required',
      'entity_id', NULL,
      'entity_type', 'User',
      'entity', NULL,
      'updated_fields', JSON_ARRAY(),
      'cascade', NULL,
      'metadata', JSON_OBJECT('error', 'validation')
    ) AS result;
    LEAVE app_create_user;
  END IF;

  -- Delegate to core procedure
  CALL core_create_user(
    input_tenant_id,
    input_user_id,
    v_email,
    v_name,
    v_status,
    input_payload
  );
END$$
DELIMITER ;
```

### core_ Procedures: Business Logic Layer

Contains actual implementation with Trinity pattern handling:

```sql
-- File: 03311_create_user.sql
-- core_ procedures: Business logic + transactions
DELIMITER $$
CREATE PROCEDURE core_create_user(
  IN input_tenant_id CHAR(36),
  IN input_user_id CHAR(36),
  IN input_email VARCHAR(255),
  IN input_name VARCHAR(255),
  IN input_status VARCHAR(50),
  IN input_payload JSON
)
MODIFIES SQL DATA
BEGIN
  DECLARE v_user_id CHAR(36) DEFAULT UUID();
  DECLARE v_user_pk BIGINT;
  DECLARE v_existing_id CHAR(36);
  DECLARE v_entity_data JSON;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    SELECT JSON_OBJECT(
      'status', 'database_error',
      'message', 'Create user failed',
      'entity_id', NULL,
      'entity_type', 'User',
      'entity', NULL,
      'updated_fields', JSON_ARRAY(),
      'cascade', NULL,
      'metadata', NULL
    ) AS result;
  END;

  -- Start transaction
  START TRANSACTION;

  -- Check for duplicate email
  SELECT id INTO v_existing_id
  FROM tb_user
  WHERE email = input_email AND deleted_at IS NULL
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    SELECT JSON_OBJECT(
      'status', 'conflict:email',
      'message', 'Email already in use',
      'entity_id', v_existing_id,
      'entity_type', 'User',
      'entity', NULL,
      'updated_fields', JSON_ARRAY(),
      'cascade', NULL,
      'metadata', JSON_OBJECT('operation', 'CONFLICT')
    ) AS result;
    ROLLBACK;
    LEAVE core_create_user;
  END IF;

  -- INSERT with TRINITY pattern: both id and pk_user
  INSERT INTO tb_user (
    id, email, name, status, created_by
  ) VALUES (
    v_user_id,
    input_email,
    input_name,
    input_status,
    input_user_id
  );

  SET v_user_pk = LAST_INSERT_ID();

  -- AFTER snapshot: read from view
  SELECT data INTO v_entity_data
  FROM v_user
  WHERE id = v_user_id
  LIMIT 1;

  -- Log mutation (audit trail)
  INSERT INTO ta_audit (
    entity_type, entity_id, operation, changes,
    tenant_id, user_id
  ) VALUES (
    'User', v_user_id, 'INSERT', JSON_OBJECT(
      'id', v_user_id,
      'email', input_email,
      'name', input_name
    ),
    input_tenant_id, input_user_id
  );

  -- OPTIONAL: Refresh materialized view
  CALL core_refresh_user(v_user_id);

  -- Build response
  SELECT JSON_OBJECT(
    'status', 'success:created',
    'message', 'User created successfully',
    'entity_id', v_user_id,
    'entity_type', 'User',
    'entity', v_entity_data,
    'updated_fields', JSON_ARRAY('id', 'email', 'name'),
    'cascade', NULL,
    'metadata', JSON_OBJECT(
      'operation', 'INSERT',
      'entity_pk', v_user_pk,
      'timestamp', NOW()
    )
  ) AS result;

  COMMIT;
END$$
DELIMITER ;
```

## Schema Organization: Numbered Prefix System

MySQL projects follow a similar directory structure to PostgreSQL (see PostgreSQL guide for full structure overview):

**Key differences for MySQL:**
- Use `DELIMITER $$` for procedures/functions
- Schema files can use `00_common/`, `01_write_side/`, `02_query_side/`, `03_functions/` directories
- Numbering: `024111_v_user.sql`, `034511_create_user.sql`, etc.
- Composite types expressed as JSON instead of PostgreSQL composite types

## Analytics Architecture

FraiseQL analytics uses a canonical **Star Schema pattern** with:
- **Calendar dimension table** (tb_calendar) for pre-computed temporal dimensions
- **Fact tables** (tf_*) with measures as direct columns and dimensions as JSON
- **Analytics views** (va_*) that compose dimensions + measures with calendar JOIN
- **Analytics tables** (ta_*) for Arrow/Parquet export with flattened structure

See [FraiseQL Analytics Architecture](/analytics-architecture/) for the complete canonical pattern, including:
- Calendar dimension design and benefits (10-16x faster temporal queries)
- Fact table structure (measures vs dimensions decision matrix)
- Dimension composition patterns with explicit separation
- Analytics table population and refresh strategies
- Year-over-year and cohort analysis examples

### MySQL-Specific Implementation

**Calendar Dimension Table:**

```sql
-- File: 01001_tb_calendar.sql
-- Pre-computed temporal dimensions (seeded 2015-2035, one-time operation)
CREATE TABLE tb_calendar (
    id CHAR(36) NOT NULL DEFAULT UUID(),
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

    date_info JSON,
    week_info JSON,
    half_month_info JSON,
    month_info JSON,
    quarter_info JSON,
    semester_info JSON,
    year_info JSON,

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

    UNIQUE KEY uk_calendar_id (id),
    INDEX idx_calendar_year_month (year, month)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed calendar data
-- Use application script or INSERT INTO ... SELECT with calendar generation function
INSERT INTO tb_calendar (reference_date, week, month, quarter, semester, year, date_info, month_reference_date, is_month_reference_date)
SELECT
    DATE_ADD('2015-01-01', INTERVAL (d-1) DAY) as reference_date,
    WEEK(DATE_ADD('2015-01-01', INTERVAL (d-1) DAY)) as week,
    MONTH(DATE_ADD('2015-01-01', INTERVAL (d-1) DAY)) as month,
    QUARTER(DATE_ADD('2015-01-01', INTERVAL (d-1) DAY)) as quarter,
    (IF(MONTH(DATE_ADD('2015-01-01', INTERVAL (d-1) DAY)) <= 6, 1, 2)) as semester,
    YEAR(DATE_ADD('2015-01-01', INTERVAL (d-1) DAY)) as year,
    JSON_OBJECT(
        'date', DATE_FORMAT(DATE_ADD('2015-01-01', INTERVAL (d-1) DAY), '%Y-%m-%d'),
        'week', WEEK(DATE_ADD('2015-01-01', INTERVAL (d-1) DAY)),
        'month', MONTH(DATE_ADD('2015-01-01', INTERVAL (d-1) DAY)),
        'quarter', QUARTER(DATE_ADD('2015-01-01', INTERVAL (d-1) DAY)),
        'semester', IF(MONTH(DATE_ADD('2015-01-01', INTERVAL (d-1) DAY)) <= 6, 1, 2),
        'year', YEAR(DATE_ADD('2015-01-01', INTERVAL (d-1) DAY))
    ) as date_info,
    DATE_FORMAT(DATE_ADD('2015-01-01', INTERVAL (d-1) DAY), '%Y-%m-01') as month_reference_date,
    (DAY(DATE_ADD('2015-01-01', INTERVAL (d-1) DAY)) = 1) as is_month_reference_date
FROM (SELECT @row:=@row+1 as d FROM (SELECT @row:=0) r, (SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5) t1) calendar
WHERE d <= 7665;  -- Days from 2015-01-01 to 2035-12-31
```

**Fact Table with Measures and Dimensions:**

```sql
-- File: 01002_tf_user_events.sql
-- Fact table: user events with measures as direct columns
CREATE TABLE tf_user_events (
    pk_event BIGINT PRIMARY KEY AUTO_INCREMENT,

    -- MEASURES (direct columns for fast aggregation)
    event_count INT DEFAULT 1,
    engagement_score DECIMAL(5,2) NOT NULL,
    duration_seconds INT,

    -- DIMENSIONS (JSON for flexibility)
    data JSON NOT NULL,

    -- TEMPORAL (foreign key to calendar)
    occurred_at DATE NOT NULL,

    -- DENORMALIZED KEYS (indexed for filtering)
    user_id CHAR(36) NOT NULL,
    organization_id CHAR(36) NOT NULL,
    event_type VARCHAR(50) NOT NULL,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_tf_user_events_occurred (occurred_at),
    INDEX idx_tf_user_events_user (user_id),
    INDEX idx_tf_user_events_organization (organization_id),
    INDEX idx_tf_user_events_type (event_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
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
    JSON_OBJECT(
        'dimensions', JSON_MERGE_PATCH(e.data, JSON_OBJECT('date_info', cal.date_info, 'event_type', e.event_type)),
        'measures', JSON_OBJECT(
            'event_count', SUM(e.event_count),
            'total_engagement', SUM(e.engagement_score),
            'total_duration', SUM(e.duration_seconds),
            'avg_engagement', AVG(e.engagement_score)
        ),
        'temporal', JSON_OBJECT(
            'date', JSON_UNQUOTE(JSON_EXTRACT(cal.date_info, '$.date')),
            'week', cal.week,
            'month', cal.month,
            'quarter', cal.quarter,
            'year', cal.year
        )
    ) AS data
FROM tf_user_events e
LEFT JOIN tb_calendar cal ON cal.reference_date = e.occurred_at
WHERE e.occurred_at >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
GROUP BY e.user_id, e.organization_id, cal.reference_date, e.event_type;
```

**Analytics Table for Arrow/Parquet Export:**

```sql
-- File: 01003_ta_user_events_daily.sql
-- Pre-aggregated, flattened structure for Arrow Flight export
CREATE TABLE ta_user_events_daily (
    day DATE NOT NULL,
    user_id CHAR(36) NOT NULL,
    organization_id CHAR(36) NOT NULL,
    event_type VARCHAR(50) NOT NULL,

    event_count BIGINT NOT NULL,
    total_engagement DECIMAL(12,2) NOT NULL,
    total_duration BIGINT NOT NULL,
    avg_engagement DECIMAL(5,2) NOT NULL,

    year INT NOT NULL,
    month INT NOT NULL,
    week INT NOT NULL,
    quarter INT NOT NULL,

    computed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    sync_count BIGINT DEFAULT 1,
    is_stale BOOLEAN DEFAULT FALSE,

    PRIMARY KEY (day, user_id, event_type),
    INDEX idx_ta_user_events_daily_org (organization_id, day)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Refresh procedure (hourly execution via scheduled event)
DELIMITER $$
CREATE PROCEDURE sp_sync_ta_user_events_daily()
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
        NOW(),
        1,
        FALSE
    FROM tf_user_events e
    LEFT JOIN tb_calendar cal ON cal.reference_date = e.occurred_at
    WHERE e.occurred_at >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
    GROUP BY e.occurred_at, e.user_id, e.organization_id, e.event_type, cal.year, cal.month, cal.week, cal.quarter
    ON DUPLICATE KEY UPDATE
        event_count = VALUES(event_count),
        total_engagement = VALUES(total_engagement),
        total_duration = VALUES(total_duration),
        avg_engagement = VALUES(avg_engagement),
        computed_at = NOW(),
        sync_count = sync_count + 1,
        is_stale = FALSE;

    -- Clean old data
    DELETE FROM ta_user_events_daily WHERE day < DATE_SUB(CURDATE(), INTERVAL 2 YEAR);
END$$
DELIMITER ;

-- Schedule: CREATE EVENT ev_sync_ta_user_events_daily EVERY 1 HOUR DO CALL sp_sync_ta_user_events_daily();

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
WHERE e.organization_id = UNHEX(?)
GROUP BY cal.year, cal.month
ORDER BY cal.year DESC, cal.month;
```

## Configuration & Performance

### FraiseQL-Optimized MySQL Configuration

```ini
# my.cnf or /etc/mysql/mysql.conf.d/mysqld.cnf
[mysqld]

# === InnoDB Settings (critical for FraiseQL) ===
default_storage_engine = InnoDB

# Buffer pool: 50-75% of available RAM
innodb_buffer_pool_size = 4G
innodb_buffer_pool_instances = 8

# Log file: 25% of buffer pool
innodb_log_file_size = 1G

# Flush strategy (balance between performance and durability)
innodb_flush_log_at_trx_commit = 2  # 1 = safest, 2 = balanced, 0 = fastest

# Avoid double buffering
innodb_flush_method = O_DIRECT

# === JSON Performance ===
# No specific JSON optimization; ensure adequate memory above

# === Query Optimization ===
join_buffer_size = 4M
sort_buffer_size = 4M
tmp_table_size = 256M
max_heap_table_size = 256M

# === Connection Pooling ===
max_connections = 500
connect_timeout = 10
wait_timeout = 28800

# === Character Set ===
character_set_server = utf8mb4
collation_server = utf8mb4_unicode_ci
```

### Index Strategy for JSON Views

```sql
-- Indexes on write tables (tb_*) support view queries
CREATE TABLE tb_user (
  pk_user BIGINT PRIMARY KEY AUTO_INCREMENT,
  id CHAR(36) NOT NULL UNIQUE,                    -- For direct ID lookups
  email VARCHAR(255) NOT NULL UNIQUE,             -- For email-based queries
  organization_id CHAR(36),                       -- For tenant filtering
  deleted_at TIMESTAMP NULL,                      -- For soft-delete filtering
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  -- Indexes for view queries
  KEY idx_user_id (id),
  KEY idx_user_email (email),
  KEY idx_user_organization (organization_id),
  KEY idx_user_deleted_created (deleted_at, created_at DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Indexes on materialized tables (tv_*)
CREATE TABLE tv_user (
  id CHAR(36) PRIMARY KEY,
  organization_id CHAR(36) NOT NULL,
  data JSON NOT NULL,
  KEY idx_tv_user_organization (organization_id),
  KEY idx_tv_user_updated_at (updated_at DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Monitor index usage
SELECT
  OBJECT_SCHEMA,
  OBJECT_NAME,
  COUNT_READ,
  COUNT_WRITE
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE OBJECT_SCHEMA = 'fraiseql_dev'
ORDER BY COUNT_READ DESC;
```

### JSON Query Examples

```sql
-- Extract specific fields from data column
SELECT
  id,
  JSON_UNQUOTE(JSON_EXTRACT(data, '$.email')) as email,
  CAST(JSON_UNQUOTE(JSON_EXTRACT(data, '$.age')) AS UNSIGNED) as age,
  JSON_EXTRACT(data, '$.metadata') as metadata_object,
  JSON_EXTRACT(data, '$.tags[0]') as first_tag
FROM v_user
WHERE id = UNHEX($1);

-- Filter on JSON fields
SELECT * FROM v_user
WHERE JSON_UNQUOTE(JSON_EXTRACT(data, '$.status')) = 'active'
  AND JSON_EXTRACT(data, '$.tags') LIKE '%premium%';

-- JSON aggregation (more limited than PostgreSQL)
SELECT
  JSON_UNQUOTE(JSON_EXTRACT(data, '$.organization_id')) as org,
  JSON_ARRAYAGG(data) as all_users
FROM v_user
GROUP BY JSON_UNQUOTE(JSON_EXTRACT(data, '$.organization_id'));
```

## MySQL 5.7 vs 8.0 Differences

**MySQL 5.7** (still in use):
- Basic `JSON_OBJECT()`, `JSON_ARRAY()` support
- No `JSON_ARRAYAGG()` (use GROUP_CONCAT as workaround)
- No `JSON_TABLE()` for normalizing JSON data

**MySQL 8.0** (recommended):
- Full `JSON_ARRAYAGG()` support
- `JSON_TABLE()` for unnesting JSON
- Better query optimizer for JSON paths
- Window functions (RANK, ROW_NUMBER, etc.)

**Upgrade strongly recommended** for FraiseQL compatibility.

## Troubleshooting

### JSON_ARRAYAGG Returns NULL for Zero Matches

```sql
-- Problem: No posts for user
-- View shows NULL instead of []
SELECT JSON_ARRAYAGG(p.id) FROM tb_post p WHERE fk_user = ?;
-- Result: NULL (not [])

-- Solution: Use COALESCE
SELECT COALESCE(
  JSON_ARRAYAGG(JSON_OBJECT('id', p.id, 'title', p.title)),
  JSON_ARRAY()
) as posts FROM tb_post p WHERE fk_user = ?;
```

### JSON Fields in WHERE Cause Performance Issues

```sql
-- Problem: Slow query
SELECT * FROM tv_user
WHERE JSON_UNQUOTE(JSON_EXTRACT(data, '$.status')) = 'active';
-- This scans every row, extracting JSON

-- Solution: Store scalar columns separately or use generated columns
ALTER TABLE tv_user
ADD COLUMN status_extracted VARCHAR(50) GENERATED ALWAYS AS
  (JSON_UNQUOTE(JSON_EXTRACT(data, '$.status'))) STORED;

CREATE INDEX idx_tv_user_status ON tv_user(status_extracted);

-- Now faster
SELECT * FROM tv_user WHERE status_extracted = 'active';
```

### Procedure Returns Result Set (Not OUT Parameters)

```sql
-- MySQL stored procedures return result sets via SELECT statements
CALL app_create_user(tenant_id, user_id, payload);
-- Returns: JSON result set from procedure's SELECT statement

-- Inside procedure: Use SELECT to return data
SELECT JSON_OBJECT(
    'status', 'success:created',
    'message', 'User created',
    'entity_id', CAST(new_user_id AS CHAR(36)),
    'entity_type', 'User',
    'entity', JSON_QUERY(entity_data),
    'updated_fields', JSON_ARRAY('id', 'email', 'name'),
    'cascade', NULL,
    'metadata', JSON_OBJECT('operation', 'INSERT')
) AS result;
```

### Materialized View Not Updating

```sql
-- Problem: tv_user stale after insert
-- Solution: Call refresh in transaction after insert
START TRANSACTION;
INSERT INTO tb_user (...);
CALL core_refresh_user(v_user_id);
COMMIT;
```

## Bulk Operations: Initial Data Load

For seeding calendar data and bulk inserts, use MySQL's optimized bulk loading:

### LOAD DATA INFILE (Fastest - ~50K rows/sec)

```sql
-- Calendar seed data from CSV (server-side file)
LOAD DATA INFILE '/var/lib/mysql/calendar_2015_2035.csv'
INTO TABLE tb_calendar
COLUMNS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(reference_date, week, month, quarter, semester, year, date_info, ...);

-- Fact table bulk insert from CSV
LOAD DATA INFILE '/var/lib/mysql/sales_data.csv'
INTO TABLE tf_sales
COLUMNS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(day, customer_id, product_id, quantity, revenue);
```

### LOAD DATA LOCAL INFILE (Client-side file)

```sql
-- From application (requires 'local_infile' enabled on server)
SET GLOBAL local_infile = 1;
LOAD DATA LOCAL INFILE 'C:/data/calendar.csv'
INTO TABLE tb_calendar
COLUMNS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;
```

### Batched Inserts (When LOAD DATA not available)

```sql
-- Batch insert in transactions
START TRANSACTION;
INSERT INTO tf_sales(day, customer_id, quantity, revenue) VALUES
  (?, ?, ?, ?),
  (?, ?, ?, ?),
  ...
  (?, ?, ?, ?);
COMMIT;

-- Use prepared statements:
-- PREPARE stmt FROM 'INSERT INTO tf_sales VALUES (?, ?, ?, ?)';
-- EXECUTE stmt USING @day, @cid, @qty, @rev;
```

**Performance Tips:**
- `LOAD DATA INFILE` is 20-30x faster than INSERT for bulk data
- Disable keys during bulk load: `ALTER TABLE tb_calendar DISABLE KEYS`
- Re-enable after: `ALTER TABLE tb_calendar ENABLE KEYS` (rebuilds indexes)
- Increase `max_allowed_packet` if loading large files: `SET GLOBAL max_allowed_packet = 256M;`
- Use `SET autocommit=0;` for batches, then `COMMIT;` after batch
- Monitor: `SHOW VARIABLES LIKE 'bulk_insert_buffer_size';` - increase for better performance

## Migration from PostgreSQL to MySQL

Key differences to handle:

```sql
-- PostgreSQL JSONB → MySQL JSON
-- PostgreSQL: jsonb_build_object()
-- MySQL: JSON_OBJECT()

-- PostgreSQL jsonb_agg() → MySQL JSON_ARRAYAGG()
-- PostgreSQL: jsonb_agg(row_to_json(t))
-- MySQL: JSON_ARRAYAGG(JSON_OBJECT(...))

-- PostgreSQL composite types → MySQL JSON structures
-- PostgreSQL: CREATE TYPE
-- MySQL: Document expected JSON via comments

-- PostgreSQL UUID type → MySQL CHAR(36)
-- PostgreSQL: CREATE TABLE (...id UUID...)
-- MySQL: CREATE TABLE (...id CHAR(36) DEFAULT UUID()...)

-- PostgreSQL SERIAL → MySQL AUTO_INCREMENT
-- PostgreSQL: id BIGSERIAL PRIMARY KEY
-- MySQL: id BIGINT PRIMARY KEY AUTO_INCREMENT

-- PostgreSQL functions → MySQL stored procedures
-- Both use different syntax (PL/pgSQL vs MySQL procedure language)
```

## Performance Benchmarks

Typical FraiseQL MySQL workloads:

| Query Type | Latency | Notes |
|-----------|---------|-------|
| Single entity (v_*) | 0.5-1ms | Index lookup on id |
| List query (1000 rows) | 10-30ms | With is_current filter |
| Nested JSON (5 levels) | 50-200ms | Depends on aggregation size |
| Materialized view access (tv_*) | 1-3ms | Pre-computed JSON |
| Analytics view (va_*) | 100-1000ms | GROUP BY aggregation |
| Full-text search | 200-2000ms | On indexed text fields |

**Optimization Tips:**
- Use `tv_*` for frequently-accessed complex objects (>10 reads/sec)
- Use `v_*` for simple entities or when real-time accuracy required
- Add generated columns for frequently-filtered JSON fields
- InnoDB buffer pool size is critical; allocate 50-75% of RAM
- Partial indexes with `WHERE deleted_at IS NULL` avoid scanning soft-deleted rows

## See Also

- [Database Comparison](/databases/)
- [PostgreSQL Guide](/databases/postgresql/)
- [SQLite Guide](/databases/sqlite/)
- [SQL Server Guide](/databases/sqlserver/)
`3
`3