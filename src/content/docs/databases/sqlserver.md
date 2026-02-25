---
title: SQL Server Guide for FraiseQL
description: SQL Server implementation guide for FraiseQL with Trinity pattern, FOR JSON projections, indexed views, and enterprise HA features
---

## Introduction

SQL Server is an **excellent choice for FraiseQL** in enterprise Windows/Azure environments:

- **~18 WHERE Operators**: Suitable for complex GraphQL input types
- **FOR JSON PATH**: Native JSON generation matching GraphQL schema
- **Indexed Views**: Materialized views with automatic maintenance (unique to SQL Server)
- **Always On Availability Groups**: Built-in HA/DR without additional tools
- **Transparent Data Encryption**: Enterprise security at database level
- **Row-Level Security**: Column and row filtering for multi-tenancy
- **Azure SQL**: Seamless cloud deployment with managed backup/HA
- **Strong Windows Integration**: Active Directory, Azure AD authentication

FraiseQL works perfectly on SQL Server; schema and patterns mirror PostgreSQL/MySQL, with enterprise-specific optimizations.

## Core Architecture

### Single JSON Data Column Pattern

Like all FraiseQL databases, views expose entities as **single JSON columns** named `data`:

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
WHERE id = @user_id;

-- Result row:
-- id: "550e8400-e29b-41d4-a716-446655440000"
-- data: {"id": "550e8400-...", "name": "John", "email": "john@example.com", ...}
```

### Trinity Pattern: UNIQUEIDENTIFIER + BIGINT PKs

FraiseQL uses dual identifiers:

```sql
CREATE TABLE dbo.tb_user (
  pk_user BIGINT PRIMARY KEY IDENTITY(1,1),           -- Internal, fast FKs
  id UNIQUEIDENTIFIER NOT NULL UNIQUE DEFAULT NEWSEQUENTIALID(),  -- Public UUID
  email NVARCHAR(255) NOT NULL UNIQUE,
  name NVARCHAR(255) NOT NULL,
  deleted_at DATETIMEOFFSET NULL,
  created_at DATETIMEOFFSET DEFAULT GETUTCDATE(),
  updated_at DATETIMEOFFSET DEFAULT GETUTCDATE()
);

CREATE TABLE dbo.tb_post (
  pk_post BIGINT PRIMARY KEY IDENTITY(1,1),
  id UNIQUEIDENTIFIER NOT NULL UNIQUE DEFAULT NEWSEQUENTIALID(),
  fk_user BIGINT NOT NULL REFERENCES dbo.tb_user(pk_user) ON DELETE CASCADE,
  title NVARCHAR(255) NOT NULL,
  deleted_at DATETIMEOFFSET NULL,
  created_at DATETIMEOFFSET DEFAULT GETUTCDATE()
);
```

### Resolver Functions and Helper Functions

UUID ↔ INTEGER resolution bridges the Trinity pattern (external UUID, internal BIGINT PK):

```sql
-- File: 02001_resolver_functions.sql
-- Single UUID → PK resolver
CREATE FUNCTION dbo.core_get_pk_user(@user_id UNIQUEIDENTIFIER)
RETURNS BIGINT
AS BEGIN
  RETURN (SELECT pk_user FROM dbo.tb_user WHERE id = @user_id);
END;

-- Single PK → UUID resolver
CREATE FUNCTION dbo.core_get_user_id(@pk_user BIGINT)
RETURNS UNIQUEIDENTIFIER
AS BEGIN
  RETURN (SELECT id FROM dbo.tb_user WHERE pk_user = @pk_user);
END;

-- Batch UUID → PK resolver (returns table)
-- File: 02002_batch_resolver_functions.sql
CREATE FUNCTION dbo.core_resolve_user_pks(@user_ids NVARCHAR(MAX))
RETURNS @result TABLE (user_id UNIQUEIDENTIFIER, pk_user BIGINT)
AS BEGIN
  INSERT INTO @result
  SELECT
    JSON_VALUE(value, '$') AS user_id,
    u.pk_user
  FROM OPENJSON(@user_ids) AS data
  LEFT JOIN dbo.tb_user u ON u.id = JSON_VALUE(data.value, '$')
  WHERE JSON_VALUE(data.value, '$') IS NOT NULL;
  RETURN;
END;

-- Usage example: resolve multiple user IDs in a single call
-- DECLARE @ids NVARCHAR(MAX) = N'["uuid-1", "uuid-2", "uuid-3"]';
-- SELECT * FROM dbo.core_resolve_user_pks(@ids);
```

**Performance Considerations:**
- Ensure `tb_user(id)` has unique index for fast O(log n) lookup
- Batch resolvers use `OPENJSON()` to parse JSON arrays efficiently
- Consider caching resolved PKs in application layer for frequently-accessed users
- Monitor with: `SELECT * FROM sys.dm_db_index_usage_stats WHERE object_id = OBJECT_ID('dbo.tb_user')`

## Mutation Response Type

All mutations return JSON with 8 fields:

```sql
-- File: 00402_type_mutation_response.sql
-- Return structure (as JSON):
-- {
--   "status": "success:created|failed:validation|not_found",
--   "message": "Human-readable message",
--   "entity_id": "UUID",
--   "entity_type": "User|Post|...",
--   "entity": {...complete JSON...},
--   "updated_fields": ["name", "email"],
--   "cascade": {...side effects...},
--   "metadata": {...audit info...}
-- }
```

## View Structure: v_* (Regular Views)

Views are the **source truth** for read operations:

```sql
-- File: 02411_v_user.sql
CREATE VIEW dbo.v_user
WITH SCHEMABINDING AS
SELECT
  u.id,
  u.id AS organization_id,
  u.id AS tenant_id,
  CAST(CASE WHEN u.deleted_at IS NULL THEN 1 ELSE 0 END AS BIT) AS is_current,
  (
    SELECT u.id,
           u.email,
           u.name,
           u.status,
           u.created_at,
           u.updated_at
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  ) AS data
FROM dbo.tb_user u
WHERE u.deleted_at IS NULL;
```

### Nested Views with FOR JSON

```sql
-- File: 02412_v_user_with_posts.sql
CREATE VIEW dbo.v_user_with_posts
WITH SCHEMABINDING AS
SELECT
  u.id,
  u.organization_id,
  u.tenant_id,
  u.is_current,
  (
    SELECT
      u.id,
      u.email,
      u.name,
      (
        SELECT p.id, p.title
        FROM dbo.tb_post p
        WHERE p.fk_user = u.pk_user AND p.deleted_at IS NULL
        FOR JSON PATH
      ) AS posts
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  ) AS data
FROM dbo.v_user u;
```

### Deep Nesting: 3+ Levels with FOR JSON PATH

SQL Server excels at multi-level JSON nesting. Here's a 4-level example:

```sql
-- File: 02413_v_user_with_nested_content.sql
CREATE VIEW dbo.v_user_with_nested_content
WITH SCHEMABINDING AS
SELECT
  u.id,
  u.organization_id,
  u.tenant_id,
  CAST(CASE WHEN u.deleted_at IS NULL THEN 1 ELSE 0 END AS BIT) AS is_current,
  (
    SELECT
      u.id,
      u.email,
      u.name,
      (
        SELECT
          p.id,
          p.title,
          p.created_at,
          (
            SELECT
              c.id,
              c.text,
              c.created_at,
              (
                SELECT r.id, r.reaction_type, r.count
                FROM dbo.tb_reaction r
                WHERE r.fk_comment = c.pk_comment
                  AND r.deleted_at IS NULL
                FOR JSON PATH
              ) AS reactions
            FROM dbo.tb_comment c
            WHERE c.fk_post = p.pk_post
              AND c.deleted_at IS NULL
            FOR JSON PATH
          ) AS comments
        FROM dbo.tb_post p
        WHERE p.fk_user = u.pk_user
          AND p.deleted_at IS NULL
        FOR JSON PATH
      ) AS posts
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  ) AS data
FROM dbo.tb_user u
WHERE u.deleted_at IS NULL;
```

**Performance Notes:**
- Use indexed columns in WHERE clauses (id, pk_*, deleted_at)
- Limit nesting depth; 4 levels acceptable, 5+ may cause performance issues
- For very large nested arrays, consider lazy-loading with separate queries
- Monitor plan with `SET STATISTICS IO ON` to detect excessive scans

## Indexed Views (Materialized Projections)

Unique to SQL Server—views with persistent indexes. SQL Server automatically maintains indexed views whenever base tables change:

```sql
-- File: 02414_v_post_summary.sql
-- SCHEMABINDING required for indexed views
CREATE VIEW dbo.v_post_summary
WITH SCHEMABINDING AS
SELECT
  p.fk_user,
  COUNT_BIG(*) as post_count,
  MAX(p.created_at) as latest_post
FROM dbo.tb_post p
WHERE p.deleted_at IS NULL
GROUP BY p.fk_user;

-- Create UNIQUE CLUSTERED INDEX (materializes the view!)
CREATE UNIQUE CLUSTERED INDEX idx_post_summary
ON dbo.v_post_summary (fk_user);

-- Now v_post_summary is physically stored and auto-maintained!
```

**SCHEMABINDING Requirements:**
- All referenced tables/columns must exist and use two-part names (dbo.table)
- Cannot drop referenced tables without first dropping view
- Cannot modify referenced columns (ALTER COLUMN)
- Ensures consistency for SQL Server's auto-refresh

**Refresh Strategies:**

Option 1: **Automatic (SQL Server Standard Edition+)**
- Indexed views auto-refresh when base tables change
- No action required; works transparently
- Best for small-to-medium indexed views

Option 2: **Explicit Refresh (control update timing)**
```sql
-- File: 04001_refresh_indexed_views_job.sql
-- Refreshes all indexed views (equivalent to REBUILD)
CREATE PROCEDURE dbo.sp_refresh_indexed_views
AS BEGIN
  SET NOCOUNT ON;

  -- Refresh v_post_summary
  ALTER INDEX idx_post_summary
  ON dbo.v_post_summary
  REBUILD;

  -- Refresh other indexed views...

  -- Log refresh completion
  INSERT INTO dbo.ta_audit (event_type, event_data, created_at)
  VALUES ('indexed_view_refresh',
    JSON_OBJECT('view_name', 'v_post_summary', 'refreshed_at', GETUTCDATE()),
    GETUTCDATE());
END;

-- Schedule as SQL Server Agent Job
-- Job: "Daily Index View Refresh"
-- Frequency: Daily at 2:00 AM (off-peak)
-- Command: EXEC dbo.sp_refresh_indexed_views;
```

Option 3: **Event-Driven Refresh (after bulk operations)**
```sql
-- Refresh after batch import of posts
INSERT INTO dbo.tb_post (id, fk_user, title, deleted_at, created_at)
SELECT ... FROM staging_posts;

-- Immediately refresh affected indexed view
ALTER INDEX idx_post_summary ON dbo.v_post_summary REBUILD;
```

**When to Use:**
- Frequently-accessed aggregations (>10 reads/sec)
- Complex JOINs with GROUP BY
- Analytics queries
- Read-heavy, stable data
- Aggregations that would be expensive to compute live

**When NOT to Use:**
- High-frequency mutations (<1 sec between changes)
- Views with complex multi-table JOINs
- Views with 100+ columns (wide rows)

## Stored Procedures: app/ vs core/

### app/ Schema: API Layer

Handles JSON deserialization:

```sql
-- File: 03311_create_user.sql
CREATE PROCEDURE dbo.app_create_user
  @tenant_id UNIQUEIDENTIFIER,
  @user_id UNIQUEIDENTIFIER,
  @payload NVARCHAR(MAX)
AS BEGIN
  DECLARE @email NVARCHAR(255);
  DECLARE @name NVARCHAR(255);

  -- Extract JSON fields
  SET @email = JSON_VALUE(@payload, '$.email');
  SET @name = JSON_VALUE(@payload, '$.name');

  -- Delegate to core
  EXEC dbo.core_create_user @tenant_id, @user_id, @email, @name, @payload;
END;
```

### core/ Schema: Business Logic

Contains implementation with transactions:

```sql
-- File: 03311_create_user.sql
CREATE PROCEDURE dbo.core_create_user
  @tenant_id UNIQUEIDENTIFIER,
  @user_id UNIQUEIDENTIFIER,
  @email NVARCHAR(255),
  @name NVARCHAR(255),
  @payload NVARCHAR(MAX)
AS BEGIN
  DECLARE @new_user_id UNIQUEIDENTIFIER = NEWID();
  DECLARE @new_user_pk BIGINT;
  DECLARE @entity_data NVARCHAR(MAX);

  SET NOCOUNT ON;
  BEGIN TRANSACTION;

  BEGIN TRY
    -- Check for duplicate email
    IF EXISTS(SELECT 1 FROM dbo.tb_user WHERE email = @email AND deleted_at IS NULL)
    BEGIN
      ROLLBACK;
      SELECT JSON_OBJECT(
        'status', 'conflict:email',
        'message', 'Email already in use',
        'entity', NULL
      ) AS result;
      RETURN;
    END;

    -- INSERT
    INSERT INTO dbo.tb_user (id, email, name, status)
    VALUES (@new_user_id, @email, @name, 'active');

    SET @new_user_pk = SCOPE_IDENTITY();

    -- AFTER snapshot from view
    SELECT @entity_data = (
      SELECT *
      FROM dbo.v_user u
      WHERE u.id = @new_user_id
      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );

    -- Log mutation
    INSERT INTO dbo.ta_audit (entity_type, entity_id, operation)
    VALUES ('User', @new_user_id, 'INSERT');

    -- Build response
    SELECT JSON_OBJECT(
      'status', 'success:created',
      'message', 'User created',
      'entity_id', CAST(@new_user_id AS NVARCHAR(MAX)),
      'entity_type', 'User',
      'entity', JSON_QUERY(@entity_data),
      'updated_fields', JSON_ARRAY('id', 'email', 'name'),
      'cascade', NULL,
      'metadata', JSON_OBJECT('operation', 'INSERT', 'entity_pk', @new_user_pk)
    ) AS result;

    COMMIT;
  END TRY
  BEGIN CATCH
    ROLLBACK;
    SELECT JSON_OBJECT(
      'status', 'database_error',
      'message', ERROR_MESSAGE(),
      'entity', NULL
    ) AS result;
  END CATCH;
END;
```

## Input Types and Validation

FraiseQL handles input validation at the app layer. Input types are documented as JSON structures (SQL Server lacks native composite input types like PostgreSQL):

```sql
-- File: 00401_input_types.sql
-- Input type documentation (in code comments, not schema objects)

-- Input: create_user_input
-- {
--   "email": "string (required, 255 chars max, must be valid email)",
--   "name": "string (required, 255 chars max)",
--   "status": "enum: 'active' | 'suspended' | 'inactive' (optional, default 'active')"
-- }

-- Input: update_user_input
-- {
--   "name": "string (optional)",
--   "status": "enum: 'active' | 'suspended' | 'inactive' (optional)",
--   "email": "string (optional, unique constraint enforced)"
-- }

CREATE PROCEDURE dbo.app_create_user
  @tenant_id UNIQUEIDENTIFIER,
  @user_id UNIQUEIDENTIFIER,
  @payload NVARCHAR(MAX)
AS BEGIN
  DECLARE @email NVARCHAR(255);
  DECLARE @name NVARCHAR(255);
  DECLARE @status NVARCHAR(50);

  -- Extract and validate JSON fields
  SET @email = JSON_VALUE(@payload, '$.email');
  SET @name = JSON_VALUE(@payload, '$.name');
  SET @status = COALESCE(JSON_VALUE(@payload, '$.status'), 'active');

  -- Validation: email required
  IF @email IS NULL OR @email = ''
  BEGIN
    SELECT JSON_OBJECT(
      'status', 'failed:validation',
      'message', 'Email is required',
      'entity_id', NULL,
      'entity_type', 'User',
      'entity', NULL,
      'updated_fields', JSON_ARRAY(),
      'cascade', NULL,
      'metadata', JSON_OBJECT('error_code', 'EMAIL_REQUIRED')
    ) AS result;
    RETURN;
  END;

  -- Validation: name required
  IF @name IS NULL OR @name = ''
  BEGIN
    SELECT JSON_OBJECT(
      'status', 'failed:validation',
      'message', 'Name is required',
      'entity_id', NULL,
      'entity_type', 'User',
      'entity', NULL,
      'updated_fields', JSON_ARRAY(),
      'cascade', NULL,
      'metadata', JSON_OBJECT('error_code', 'NAME_REQUIRED')
    ) AS result;
    RETURN;
  END;

  -- Validation: status enum
  IF @status NOT IN ('active', 'suspended', 'inactive')
  BEGIN
    SELECT JSON_OBJECT(
      'status', 'failed:validation',
      'message', 'Status must be active, suspended, or inactive',
      'entity_id', NULL,
      'entity_type', 'User',
      'entity', NULL,
      'updated_fields', JSON_ARRAY(),
      'cascade', NULL,
      'metadata', JSON_OBJECT('error_code', 'INVALID_STATUS')
    ) AS result;
    RETURN;
  END;

  -- All validations passed; delegate to core
  EXEC dbo.core_create_user @tenant_id, @user_id, @email, @name, @status, @payload;
END;
```

**Validation Strategy:**
- Extract all JSON fields in app_ layer
- Validate before calling core_ layer
- Return early with failed:validation status on validation errors
- Keep validation messages user-friendly
- Log validation failures for debugging

**Security: Input Validation & SQL Injection Prevention**

All input examples use **parameterized queries** (`@parameter` placeholders) to prevent SQL injection:

```sql
-- ✅ SAFE: Parameterized query with sp_executesql
DECLARE @sql NVARCHAR(MAX) = N'SELECT * FROM dbo.tb_user WHERE id = @user_id AND email = @email';
EXEC sp_executesql @sql,
  N'@user_id UNIQUEIDENTIFIER, @email NVARCHAR(255)',
  @user_id = @user_id_param,
  @email = @email_param;

-- ❌ UNSAFE: String concatenation (NEVER DO THIS)
-- DECLARE @sql = 'SELECT * FROM dbo.tb_user WHERE id = ''' + CAST(@user_id AS NVARCHAR(MAX)) + '''';
-- This allows injection: @user_id = "'; DROP TABLE dbo.tb_user; --"
```

Best practices applied in all examples:
- ✅ JSON values extracted before SQL composition (`JSON_VALUE()` patterns)
- ✅ Enums validated against whitelist before use (status IN ('active', 'suspended', 'inactive'))
- ✅ String lengths enforced at database level (NVARCHAR(255))
- ✅ All external input treated as untrusted
- ✅ Stored procedures receive extracted/validated values, not raw user input

## Analytics Architecture

FraiseQL analytics uses a canonical **Star Schema pattern** with:
- **Calendar dimension table** (tb_calendar) for pre-computed temporal dimensions
- **Fact tables** (tf_*) with measures as direct columns and dimensions as JSONB or denormalized columns
- **Analytics views** (va_*) that compose dimensions + measures with calendar JOIN
- **Analytics tables** (ta_*) for Arrow/Parquet export with flattened structure

See [FraiseQL Analytics Architecture](/analytics-architecture/) for the complete canonical pattern, including:
- Calendar dimension design and benefits (10-16x faster temporal queries than DATE_TRUNC)
- Fact table structure (measures vs dimensions decision matrix)
- Dimension composition patterns with explicit separation
- Analytics table population and refresh strategies
- Year-over-year and cohort analysis examples

### SQL Server-Specific Implementation

**Calendar Dimension Table:**

```sql
-- File: 01001_tb_calendar.sql
-- Pre-computed temporal dimensions (seeded 2015-2035, one-time operation)
CREATE TABLE dbo.tb_calendar (
    id UNIQUEIDENTIFIER DEFAULT NEWSEQUENTIALID() UNIQUE,
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

    date_info NVARCHAR(MAX),         -- JSON
    week_info NVARCHAR(MAX),         -- JSON
    half_month_info NVARCHAR(MAX),   -- JSON
    month_info NVARCHAR(MAX),        -- JSON
    quarter_info NVARCHAR(MAX),      -- JSON
    semester_info NVARCHAR(MAX),     -- JSON
    year_info NVARCHAR(MAX),         -- JSON

    week_reference_date DATE,
    half_month_reference_date DATE,
    month_reference_date DATE,
    quarter_reference_date DATE,
    semester_reference_date DATE,
    year_reference_date DATE,

    is_week_reference_date BIT,
    is_half_month_reference_date BIT,
    is_month_reference_date BIT,
    is_quarter_reference_date BIT,
    is_semester_reference_date BIT,
    is_year_reference_date BIT,

    PRIMARY KEY (reference_date),
    INDEX idx_tb_calendar_year_month (year, month)
);

-- Seed calendar (covers 2015-2035)
INSERT INTO dbo.tb_calendar (reference_date, week, month, quarter, semester, year, date_info, month_reference_date, is_month_reference_date)
SELECT
    CAST(d AS DATE) AS reference_date,
    DATEPART(WEEK, d) AS week,
    DATEPART(MONTH, d) AS month,
    DATEPART(QUARTER, d) AS quarter,
    CASE WHEN DATEPART(MONTH, d) <= 6 THEN 1 ELSE 2 END AS semester,
    DATEPART(YEAR, d) AS year,
    JSON_OBJECT(
        'date', FORMAT(d, 'yyyy-MM-dd'),
        'week', DATEPART(WEEK, d),
        'month', DATEPART(MONTH, d),
        'quarter', DATEPART(QUARTER, d),
        'semester', CASE WHEN DATEPART(MONTH, d) <= 6 THEN 1 ELSE 2 END,
        'year', DATEPART(YEAR, d)
    ) AS date_info,
    DATEADD(MONTH, DATEDIFF(MONTH, 0, d), 0) AS month_reference_date,
    CAST(CASE WHEN DAY(d) = 1 THEN 1 ELSE 0 END AS BIT) AS is_month_reference_date
FROM (
    SELECT DATEADD(DAY, ROW_NUMBER() OVER (ORDER BY (SELECT 1)) - 1, '2015-01-01') AS d
    FROM master..spt_values
    WHERE DATEADD(DAY, ROW_NUMBER() OVER (ORDER BY (SELECT 1)) - 1, '2015-01-01') <= '2035-12-31'
) dates;
```

**Fact Table with Measures and Dimensions:**

```sql
-- File: 01002_tf_user_events.sql
-- Fact table: user events with measures as direct columns
CREATE TABLE dbo.tf_user_events (
    pk_event BIGINT PRIMARY KEY IDENTITY(1,1),

    -- MEASURES (direct columns for fast aggregation)
    event_count INT DEFAULT 1,
    engagement_score DECIMAL(5,2) NOT NULL,
    duration_seconds INT,

    -- DIMENSIONS (JSONB for flexibility)
    data NVARCHAR(MAX) NOT NULL,

    -- TEMPORAL (foreign key to calendar)
    occurred_at DATE NOT NULL,

    -- DENORMALIZED KEYS (indexed for filtering)
    user_id UNIQUEIDENTIFIER NOT NULL,
    organization_id UNIQUEIDENTIFIER NOT NULL,
    event_type NVARCHAR(50) NOT NULL,

    created_at DATETIMEOFFSET DEFAULT GETUTCDATE(),

    INDEX idx_tf_user_events_occurred (occurred_at),
    INDEX idx_tf_user_events_user (user_id),
    INDEX idx_tf_user_events_organization (organization_id),
    INDEX idx_tf_user_events_type (event_type)
);
```

**Analytics View with Calendar JOIN:**

```sql
-- File: 02701_va_user_events_daily.sql
-- Composition view: dimensions + measures + temporal context
CREATE VIEW dbo.va_user_events_daily
WITH SCHEMABINDING AS
SELECT
    e.user_id,
    e.organization_id,
    JSON_OBJECT(
        'dimensions', JSON_MODIFY(
            JSON_MODIFY(e.data, '$.date_info', JSON_QUERY(cal.date_info)),
            '$.event_type', e.event_type
        ),
        'measures', JSON_OBJECT(
            'event_count', CAST(COUNT(*) AS INT),
            'total_engagement', CAST(SUM(e.engagement_score) AS DECIMAL(12,2)),
            'total_duration', CAST(SUM(e.duration_seconds) AS BIGINT),
            'avg_engagement', CAST(AVG(e.engagement_score) AS DECIMAL(5,2))
        ),
        'temporal', JSON_OBJECT(
            'date', cal.reference_date,
            'week', cal.week,
            'month', cal.month,
            'quarter', cal.quarter,
            'year', cal.year
        )
    ) AS data
FROM dbo.tf_user_events e
LEFT JOIN dbo.tb_calendar cal ON cal.reference_date = e.occurred_at
WHERE e.occurred_at >= DATEADD(DAY, -90, GETUTCDATE())
GROUP BY e.user_id, e.organization_id, cal.reference_date, e.event_type, cal.week, cal.month, cal.quarter, cal.year;
```

**Analytics Tables (ta_*) and Views (va_*) for Arrow/Parquet Export

Analytics tables are denormalized, pre-aggregated tables optimized for data warehouse queries and Arrow/Parquet export. Unlike indexed views (which maintain exact row-level data), analytics tables store computed aggregates with time dimensions:

```sql
-- File: 01003_ta_user_analytics.sql
-- Analytics table: pre-aggregated metrics for data warehouse
CREATE TABLE dbo.ta_user_analytics (
  -- Denormalized keys
  user_id UNIQUEIDENTIFIER NOT NULL,
  organization_id UNIQUEIDENTIFIER NOT NULL,

  -- Aggregated metrics (flattened, not JSON)
  total_posts BIGINT NOT NULL DEFAULT 0,
  total_comments BIGINT NOT NULL DEFAULT 0,
  total_reactions BIGINT NOT NULL DEFAULT 0,
  avg_post_length FLOAT NOT NULL DEFAULT 0.0,
  avg_comment_sentiment DECIMAL(3,2) NULL,

  -- Time dimensions (for Arrow/Parquet grouping)
  year INT NOT NULL,
  month INT NOT NULL,
  day INT NOT NULL,
  week INT NOT NULL,

  -- Refresh metadata
  last_synced_at DATETIMEOFFSET NOT NULL DEFAULT GETUTCDATE(),
  sync_count BIGINT NOT NULL DEFAULT 1,
  is_stale BIT NOT NULL DEFAULT 0,

  PRIMARY KEY (user_id, organization_id, year, month, day),
  INDEX idx_org_date ON dbo.ta_user_analytics(organization_id, year, month, day)
);

-- File: 01004_va_user_analytics.sql
-- Read view over analytics table (for Arrow/Parquet export)
CREATE VIEW dbo.va_user_analytics AS
SELECT
  user_id,
  organization_id,
  total_posts,
  total_comments,
  total_reactions,
  CAST(avg_post_length AS DECIMAL(10,2)) AS avg_post_length,
  CAST(avg_comment_sentiment AS DECIMAL(3,2)) AS avg_comment_sentiment,
  DATEFROMPARTS(year, month, day) AS date,
  week,
  last_synced_at,
  sync_count,
  is_stale
FROM dbo.ta_user_analytics;

-- File: 04002_sync_analytics_tables_job.sql
-- Job that populates ta_user_analytics (runs hourly)
CREATE PROCEDURE dbo.sp_sync_analytics_tables
AS BEGIN
  SET NOCOUNT ON;

  MERGE INTO dbo.ta_user_analytics target
  USING (
    SELECT
      u.id AS user_id,
      u.organization_id,
      COUNT(DISTINCT p.pk_post) AS total_posts,
      COUNT(DISTINCT c.pk_comment) AS total_comments,
      COALESCE(SUM(r.count), 0) AS total_reactions,
      COALESCE(AVG(LEN(p.title)), 0.0) AS avg_post_length,
      NULL AS avg_comment_sentiment,
      YEAR(GETUTCDATE()) AS year,
      MONTH(GETUTCDATE()) AS month,
      DAY(GETUTCDATE()) AS day,
      DATEPART(WEEK, GETUTCDATE()) AS week
    FROM dbo.tb_user u
    LEFT JOIN dbo.tb_post p ON u.pk_user = p.fk_user AND p.deleted_at IS NULL
    LEFT JOIN dbo.tb_comment c ON u.pk_user = c.fk_user AND c.deleted_at IS NULL
    LEFT JOIN dbo.tb_reaction r ON c.pk_comment = r.fk_comment
    WHERE u.deleted_at IS NULL
    GROUP BY u.id, u.organization_id
  ) source
  ON target.user_id = source.user_id
    AND target.year = source.year
    AND target.month = source.month
    AND target.day = source.day
  WHEN MATCHED THEN
    UPDATE SET
      total_posts = source.total_posts,
      total_comments = source.total_comments,
      total_reactions = source.total_reactions,
      avg_post_length = source.avg_post_length,
      last_synced_at = GETUTCDATE(),
      sync_count = sync_count + 1,
      is_stale = 0
  WHEN NOT MATCHED THEN
    INSERT (user_id, organization_id, total_posts, total_comments, total_reactions,
            avg_post_length, avg_comment_sentiment, year, month, day, week,
            last_synced_at, sync_count, is_stale)
    VALUES (source.user_id, source.organization_id, source.total_posts,
            source.total_comments, source.total_reactions, source.avg_post_length,
            source.avg_comment_sentiment, source.year, source.month, source.day,
            source.week, GETUTCDATE(), 1, 0);

  -- Clean up old data (older than 90 days)
  DELETE FROM dbo.ta_user_analytics
  WHERE DATEFROMPARTS(year, month, day) < DATEADD(DAY, -90, GETUTCDATE());
END;

-- Schedule: EXEC dbo.sp_sync_analytics_tables;
-- Frequency: Hourly (during off-peak hours)
```

**Analytics vs Indexed Views:**

| Aspect | Indexed Views (tv_*) | Analytics (ta_*) |
|--------|---------------------|------------------|
| **Data** | Live row data + JSON | Pre-aggregated metrics |
| **Update** | Automatic (SQL Server) | Scheduled (job-based) |
| **Latency** | Immediate | 1+ hours (configurable) |
| **Use Case** | Real-time queries | Data warehouse, reporting |
| **Export** | Less suitable | Ideal for Arrow/Parquet |
| **Dimensions** | Row-level | Time-based (year/month/day) |
| **Flattened** | No (JSON columns) | Yes (numeric columns) |

**When to Use Analytics Tables:**
- Data warehouse exports (flattened structure for Arrow/Parquet)
- Historical trend analysis (time dimensions)
- Heavy aggregations (COUNT, SUM, AVG)
- Read-only dashboards (no mutation support needed)
- Compliance/audit archival (immutable snapshots)

## Schema Organization with Numbered Prefixes

FraiseQL uses a deterministic file organization system enabling reliable seeding and execution ordering. Each directory has a specific responsibility:

```


│
│
│
↓

│
│
↓

│
↓

│
↓

│
↓
```


                  ─ ─ ─
                 ─ ─
                     ─
                      ─
                ─
                ─ ─ ─ ─

**Benefits:**
- Deterministic execution (no race conditions)
- Easy to understand load order
- Can seed incrementally
- Supports partial deployments
- Numbered approach scales to 100+ files

## Configuration & Performance

### FraiseQL-Optimized SQL Server Config

**Instance-level Configuration** (applies to entire SQL Server):

```sql
-- Memory configuration (critical for large JSON aggregations)
-- For 8GB server: min=2GB, max=6GB (leave 2GB for OS)
EXEC sp_configure 'max server memory (MB)', 6144;
EXEC sp_configure 'min server memory (MB)', 2048;

-- Query execution for FOR JSON PATH parallelism
EXEC sp_configure 'max degree of parallelism', 8;  -- Match CPU cores
EXEC sp_configure 'cost threshold for parallelism', 50;  -- Lower = more parallelism

-- Enable indexed view automatic refresh
EXEC sp_configure 'option (recompile)', 1;

-- Transaction log behavior
EXEC sp_configure 'recovery interval (minutes)', 5;

-- Reconfigure changes
RECONFIGURE;
```

**Database-level Configuration**:

```sql
-- Recovery model (FULL for production, SIMPLE for dev)
ALTER DATABASE fraiseql_dev SET RECOVERY FULL;
ALTER DATABASE fraiseql_dev SET RECOVERY SIMPLE;  -- Dev only

-- Enable compression (reduces I/O, increases CPU)
ALTER DATABASE fraiseql_dev SET PAGE_COMPRESSION ON;

-- Enable snapshot isolation (reduces blocking on reads)
ALTER DATABASE fraiseql_dev SET ALLOW_SNAPSHOT_ISOLATION ON;
ALTER DATABASE fraiseql_dev SET READ_COMMITTED_SNAPSHOT ON;

-- Statistics update
ALTER DATABASE fraiseql_dev SET AUTO_UPDATE_STATISTICS ON;
ALTER DATABASE fraiseql_dev SET AUTO_UPDATE_STATISTICS_ASYNC ON;

-- Query Store (tracks query performance over time)
ALTER DATABASE fraiseql_dev SET QUERY_STORE = ON;
ALTER DATABASE fraiseql_dev SET QUERY_STORE (OPERATION_MODE = READ_WRITE);
```

**Workload-Specific Tuning:**

```sql
-- For heavy JSON aggregation (large FOR JSON PATH queries)
ALTER DATABASE fraiseql_dev SET QUERY_GOVERNOR_COST_LIMIT 0;  -- No query timeout
EXEC sp_configure 'max degree of parallelism', 16;  -- More parallelism

-- For high-mutation workloads (many INSERTs)
ALTER DATABASE fraiseql_dev SET RECOVERY FULL;  -- Enable full transaction log
EXEC sp_configure 'cost threshold for parallelism', 100;  -- Less parallelism (faster)

-- For read-heavy workloads (many SELECTs)
ALTER DATABASE fraiseql_dev SET RECOVERY SIMPLE;  -- Reduce log overhead
EXEC sp_configure 'max degree of parallelism', 8;  -- Full parallelism
ALTER INDEX ALL ON dbo.tb_user REBUILD;  -- Refresh statistics
```

### Index Strategy

```sql
-- Indexes on write tables (tb_*)
CREATE INDEX idx_user_email ON dbo.tb_user(email);
CREATE INDEX idx_user_organization ON dbo.tb_user(organization_id);
CREATE INDEX idx_user_deleted_created ON dbo.tb_user(deleted_at, created_at DESC);

-- Indexes on materialized tables (tv_*)
CREATE INDEX idx_tv_user_organization ON dbo.tv_user(organization_id);

-- Monitor index usage
SELECT TOP 10
  OBJECT_NAME(ius.object_id) AS table_name,
  i.name AS index_name,
  ius.user_seeks + ius.user_scans + ius.user_lookups AS total_reads,
  ius.user_updates AS writes
FROM sys.dm_db_index_usage_stats ius
INNER JOIN sys.indexes i ON ius.object_id = i.object_id
WHERE database_id = DB_ID()
ORDER BY total_reads DESC;
```

### Generated Columns for JSON Field Filtering

When frequently filtering on JSON fields (e.g., `WHERE JSON_VALUE(data, '$.status') = 'active'`), use computed columns indexed for performance:

```sql
-- Problem: Filtering directly on JSON is slow
SELECT * FROM dbo.tb_user
WHERE JSON_VALUE(data, '$.status') = 'active';
-- Result: Full table scan (JSON_VALUE() not index-able)

-- Solution: Create computed column
ALTER TABLE dbo.tb_user
ADD status_computed AS JSON_VALUE(data, '$.status') PERSISTED;

-- Create index on computed column
CREATE INDEX idx_user_status_computed ON dbo.tb_user(status_computed);

-- Now filtering is fast (index seek)
SELECT * FROM dbo.tb_user
WHERE status_computed = 'active';
-- Result: Index seek (O(log n))

-- Example: Filter active users by organization
CREATE INDEX idx_user_org_status
ON dbo.tb_user(organization_id, status_computed)
INCLUDE (email, name);

SELECT id, email, name
FROM dbo.tb_user
WHERE organization_id = @org_id
  AND status_computed = 'active';
-- Result: Single index seek using covering index
```

**When to Create Computed Columns:**
- Filtering on same JSON field in 10+ queries
- High-volume tables (>100K rows)
- JSON field is non-nullable
- Field value is stable (not constantly changing)

**Performance Impact:**
- Write: +1-2% overhead (computed on INSERT/UPDATE)
- Read: -50-90% faster for filtered queries (index seek vs scan)
- Storage: +1-2% increase for index

## Always On Availability Groups

Enterprise HA/DR:

```sql
-- Create availability group
CREATE AVAILABILITY GROUP fraiseql_ag
WITH (AUTOMATED_BACKUP_PREFERENCE = SECONDARY)
FOR DATABASE fraiseql_dev
REPLICA ON N'server1' WITH (
  ENDPOINT_URL = N'TCP://server1.domain.com:5022',
  AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
  FAILOVER_MODE = AUTOMATIC,
  SECONDARY_ROLE (ALLOW_CONNECTIONS = READ_ONLY)
),
N'server2' WITH (
  ENDPOINT_URL = N'TCP://server2.domain.com:5022',
  AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
  FAILOVER_MODE = AUTOMATIC
);

-- Application connection string with read routing
-- Server=ag-listener.domain.com,1433;Database=fraiseql_dev;
-- ApplicationIntent=ReadWrite;
```

## Security Features

### Transparent Data Encryption (TDE)

```sql
-- Create master key
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'StrongPassword@123!';

-- Create certificate
CREATE CERTIFICATE fraiseql_cert
WITH SUBJECT = 'FraiseQL TDE Certificate';

-- Create encryption key
CREATE DATABASE ENCRYPTION KEY
WITH ALGORITHM = AES_256
ENCRYPTION BY SERVER CERTIFICATE fraiseql_cert;

-- Enable TDE
ALTER DATABASE fraiseql_dev SET ENCRYPTION ON;
```

### Row-Level Security (RLS)

```sql
-- Predicate function
CREATE FUNCTION dbo.fn_security_check(@tenant_id UNIQUEIDENTIFIER)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN SELECT 1 AS check_result
WHERE CAST(SESSION_CONTEXT(N'tenant_id') AS UNIQUEIDENTIFIER) = @tenant_id;

-- Apply to table
CREATE SECURITY POLICY fraiseql_security
ADD FILTER PREDICATE dbo.fn_security_check(tenant_id) ON dbo.tb_user
WITH (STATE = ON);

-- Set context
EXEC sp_set_session_context @key = N'tenant_id', @value = 'uuid-value';
```

## Backup & Recovery

### Backup Strategy

```sql
-- Full backup
BACKUP DATABASE fraiseql_dev
TO DISK = 'D:\Backups\fraiseql_dev.bak'
WITH NAME = 'Full backup';

-- Differential backup
BACKUP DATABASE fraiseql_dev
TO DISK = 'D:\Backups\fraiseql_dev_diff.bak'
WITH DIFFERENTIAL,
     NAME = 'Differential backup';

-- Log backup
BACKUP LOG fraiseql_dev
TO DISK = 'D:\Backups\fraiseql_dev_log.trn'
WITH NAME = 'Log backup';

-- Verify backup
RESTORE VERIFYONLY FROM DISK = 'D:\Backups\fraiseql_dev.bak';
```

## Troubleshooting

### JSON Functions Return Unexpected Results

```sql
-- Problem: FOR JSON PATH adds array wrapper
SELECT p.id, p.title FOR JSON PATH;
-- Returns: [{"id": "...", "title": "..."}]

-- Solution: Use WITHOUT_ARRAY_WRAPPER
SELECT p.id, p.title FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
-- Returns: {"id": "...", "title": "..."}

-- Problem: NULL values in FOR JSON PATH
SELECT p.id, p.description FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
-- Returns: {"id": "...", "description": null}  (includes NULL)

-- Solution: Use JSON_QUERY() to exclude NULLs
SELECT JSON_QUERY((
  SELECT p.id, p.description
  WHERE p.description IS NOT NULL
  FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
)) AS data;
```

### Indexed View Not Being Materialized

```sql
-- Problem: Indexed view exists but queries still scan base tables
-- Cause 1: Missing SCHEMABINDING
-- Solution: Recreate view WITH SCHEMABINDING

-- Cause 2: SCHEMABINDING but indexes were dropped
-- Solution: Verify index exists
SELECT i.name, i.type_desc
FROM sys.indexes i
WHERE OBJECT_NAME(i.object_id) = 'v_post_summary';
-- If empty, create clustered index

-- Cause 3: Query optimizer chooses not to use indexed view
-- Solution: Use WITH (NOEXPAND) hint
SELECT * FROM dbo.v_post_summary WITH (NOEXPAND)
WHERE fk_user = @user_id;

-- Check index usage stats
SELECT
  OBJECT_NAME(ius.object_id) AS view_name,
  i.name AS index_name,
  ius.user_seeks + ius.user_scans AS read_count,
  CASE WHEN ius.user_seeks + ius.user_scans > 0 THEN 'IN USE' ELSE 'UNUSED' END AS status
FROM sys.dm_db_index_usage_stats ius
INNER JOIN sys.indexes i ON ius.object_id = i.object_id
WHERE OBJECT_NAME(ius.object_id) = 'v_post_summary';
```

### FOR JSON PATH Performance on Large Result Sets

```sql
-- Problem: FOR JSON PATH becomes slow with >10,000 rows
SELECT u.id, u.email,
  (SELECT p.id, p.title FROM dbo.tb_post p WHERE p.fk_user = u.pk_user
   FOR JSON PATH) AS posts
FROM dbo.tb_user u
FOR JSON PATH;
-- Result: Slow (aggregating 10K+ rows into JSON)

-- Solution 1: Use OFFSET/FETCH pagination
SELECT u.id, u.email,
  (SELECT p.id, p.title FROM dbo.tb_post p WHERE p.fk_user = u.pk_user
   ORDER BY p.created_at DESC
   OFFSET 0 ROWS FETCH NEXT 100 ROWS ONLY
   FOR JSON PATH) AS posts
FROM dbo.tb_user u
OFFSET 0 ROWS FETCH NEXT 100 ROWS ONLY
FOR JSON PATH;

-- Solution 2: Materialize large nested arrays
CREATE INDEXED VIEW dbo.v_post_list AS
SELECT
  p.fk_user,
  (SELECT p2.id, p2.title FROM dbo.tb_post p2 WHERE p2.fk_user = p.fk_user
   FOR JSON PATH) AS posts_json
FROM dbo.tb_post p
WHERE p.deleted_at IS NULL
GROUP BY p.fk_user;

-- Solution 3: Lazy-load: return posts separately
-- GET /users/{id}
SELECT u.id, u.email FROM dbo.v_user WHERE id = @user_id;
-- GET /users/{id}/posts
SELECT * FROM dbo.v_post WHERE fk_user = @user_pk;
```

### Blocking on Mutations

```sql
-- Problem: INSERT/UPDATE transactions are blocked by SELECTs
SELECT
  er.session_id,
  er.blocking_session_id,
  SUBSTRING(st.text, 1, 100) AS query,
  er.status,
  er.wait_type
FROM sys.dm_exec_requests er
CROSS APPLY sys.dm_exec_sql_text(er.sql_handle) st
WHERE er.blocking_session_id > 0;

-- Solution 1: Kill blocking session
KILL <session_id>;

-- Solution 2: Use snapshot isolation (reduces blocking)
ALTER DATABASE fraiseql_dev SET ALLOW_SNAPSHOT_ISOLATION ON;
ALTER DATABASE fraiseql_dev SET READ_COMMITTED_SNAPSHOT ON;

-- Solution 3: Optimize query timeout
-- In your app connection string add: Command Timeout=30
-- Don't run unbounded queries on production
```

### RLS (Row-Level Security) Performance Degradation

```sql
-- Problem: RLS filter on tb_user is slow when joining through views
-- Cause: Predicate applied AFTER table scan

-- Solution: Apply RLS early in nested FOR JSON subqueries
CREATE VIEW dbo.v_user_filtered AS
SELECT
  u.id,
  u.email,
  (
    SELECT p.id, p.title
    FROM dbo.tb_post p
    WHERE p.fk_user = u.pk_user
      AND p.deleted_at IS NULL
      AND dbo.fn_security_check(p.organization_id) = 1
    FOR JSON PATH
  ) AS posts
FROM dbo.tb_user u
WHERE dbo.fn_security_check(u.organization_id) = 1;

-- Alternative: Use indexed column instead of function call
-- Avoid: WHERE dbo.fn_rls_check(org_id) = 1 (function called per row)
-- Better: WHERE organization_id = CAST(SESSION_CONTEXT(N'org_id') AS UNIQUEIDENTIFIER)
```

### Index Fragmentation on Indexed Views

```sql
-- Problem: Indexed view queries become slow after many updates
-- Cause: Index fragmentation

-- Check fragmentation level
SELECT
  OBJECT_NAME(ips.object_id) AS object_name,
  i.name AS index_name,
  ips.avg_fragmentation_in_percent,
  ips.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
INNER JOIN sys.indexes i ON ips.object_id = i.object_id
WHERE ips.avg_fragmentation_in_percent > 10
  AND OBJECT_NAME(ips.object_id) = 'v_post_summary';

-- Solution: Rebuild index
ALTER INDEX idx_post_summary ON dbo.v_post_summary REBUILD;

-- Or reorganize (less disruptive)
ALTER INDEX idx_post_summary ON dbo.v_post_summary REORGANIZE;
```

### Transaction Log Growth with High Mutations

```sql
-- Problem: Transaction log grows rapidly during bulk inserts
-- Cause: RECOVERY FULL + high INSERT rate

-- Check log usage
SELECT
  DB_NAME(database_id) AS database_name,
  type_desc,
  CAST(((size*8)/1024)/1024.0 AS DECIMAL(10,2)) AS size_gb
FROM sys.master_files
WHERE database_id = DB_ID();

-- Solution 1: Backup transaction log more frequently
BACKUP LOG fraiseql_dev TO DISK = 'D:\Backups\fraiseql_dev_log.trn';

-- Solution 2: Use SIMPLE recovery during bulk operations
ALTER DATABASE fraiseql_dev SET RECOVERY SIMPLE;
-- Perform bulk insert
ALTER DATABASE fraiseql_dev SET RECOVERY FULL;

-- Solution 3: Batch large operations
-- Instead of 1M row insert, do 100 inserts of 10K rows
-- Allows log truncation between batches
```sql

## Bulk Operations: Initial Data Load

For seeding calendar data and bulk inserts, use SQL Server's optimized bulk loading methods:

### BULK INSERT (Fastest - ~80K rows/sec)

```sql
-- Calendar seed data from CSV (server-side file)
BULK INSERT dbo.tb_calendar
FROM 'D:\Data\calendar_2015_2035.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2,  -- Skip header row
    TABLOCK,       -- Table-level lock for better parallelism
    CHECK_CONSTRAINTS,
    FIRE_TRIGGERS
);

-- Fact table bulk insert
BULK INSERT dbo.tf_sales
FROM 'D:\Data\sales_data.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2,
    TABLOCK
);
```

### SqlBulkCopy (.NET / C# Application-level)

```csharp
// Preferred for real-time data ingestion from application
using System;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Text.Json;

public class BulkDataLoader
{
    private readonly string _connectionString = "Server=localhost;Database=fraiseql_dev;...";

    public void BulkInsertCalendar(string csvPath)
    {
        using (var conn = new SqlConnection(_connectionString))
        {
            conn.Open();

            // Disable triggers/constraints temporarily for speed
            using (var cmd = conn.CreateCommand())
            {
                cmd.CommandText = "ALTER TABLE dbo.tb_calendar DISABLE TRIGGER ALL;";
                cmd.ExecuteNonQuery();
            }

            using (var bulk = new SqlBulkCopy(conn))
            {
                bulk.DestinationTableName = "dbo.tb_calendar";
                bulk.BatchSize = 5000;
                bulk.BulkCopyTimeout = 300;  // 5 minutes
                bulk.WriteToServer(LoadDataTable(csvPath));
            }

            // Re-enable triggers
            using (var cmd = conn.CreateCommand())
            {
                cmd.CommandText = "ALTER TABLE dbo.tb_calendar ENABLE TRIGGER ALL;";
                cmd.ExecuteNonQuery();
            }
        }
    }

    public void BulkInsertWithJsonSerializaton(string csvPath)
    {
        var dt = new DataTable();
        dt.Columns.Add("reference_date", typeof(DateTime));
        dt.Columns.Add("week", typeof(int));
        dt.Columns.Add("month", typeof(int));
        dt.Columns.Add("quarter", typeof(int));
        dt.Columns.Add("semester", typeof(int));
        dt.Columns.Add("year", typeof(int));
        dt.Columns.Add("data", typeof(string));  // JSON column

        using (var reader = new StreamReader(csvPath))
        {
            string line;
            int batchCount = 0;

            while ((line = reader.ReadLine()) != null)
            {
                var parts = line.Split(',');
                var date = DateTime.Parse(parts[0]);

                // Build JSON data object
                var dateInfo = new
                {
                    date = date.ToString("yyyy-MM-dd"),
                    week = int.Parse(parts[1]),
                    month = int.Parse(parts[2]),
                    quarter = int.Parse(parts[3]),
                    year = int.Parse(parts[5])
                };

                dt.Rows.Add(
                    date,
                    int.Parse(parts[1]),  // week
                    int.Parse(parts[2]),  // month
                    int.Parse(parts[3]),  // quarter
                    int.Parse(parts[4]),  // semester
                    int.Parse(parts[5]),  // year
                    JsonSerializer.Serialize(dateInfo)  // data
                );

                if (++batchCount >= 5000)
                {
                    BulkInsertTable(dt);
                    dt.Rows.Clear();
                    batchCount = 0;
                }
            }

            // Insert remainder
            if (dt.Rows.Count > 0)
                BulkInsertTable(dt);
        }
    }

    private void BulkInsertTable(DataTable dt)
    {
        using (var conn = new SqlConnection(_connectionString))
        {
            conn.Open();
            using (var bulk = new SqlBulkCopy(conn))
            {
                bulk.DestinationTableName = "dbo.tb_calendar";
                bulk.BatchSize = 5000;
                bulk.WriteToServer(dt);
            }
        }
    }

    private DataTable LoadDataTable(string csvPath)
    {
        var dt = new DataTable();
        // Load CSV with proper schema mapping
        return dt;
    }
}
```

### Batched Inserts (When bulk loading not available)

```sql
-- Batch insert in transactions (prevents log explosion)
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN TRANSACTION;

INSERT INTO dbo.tf_sales(day, customer_id, quantity, revenue) VALUES
  (@day1, @cust_id1, @qty1, @rev1),
  (@day2, @cust_id2, @qty2, @rev2),
  ...
  (@day10000, @cust_id10000, @qty10000, @rev10000);

COMMIT;

-- Using sp_executesql for parameterized execution
DECLARE @sql NVARCHAR(MAX) =
    'INSERT INTO dbo.tf_sales(day, customer_id, quantity, revenue) VALUES ' +
    '(@day1, @cust_id1, @qty1, @rev1),' +
    '(@day2, @cust_id2, @qty2, @rev2)';

EXEC sp_executesql @sql,
    N'@day1 DATE, @cust_id1 INT, @qty1 INT, @rev1 DECIMAL(10,2)',
    @day1='2024-01-01', @cust_id1=1, @qty1=100, @rev1=1000.00;
```

**Performance Tips:**

- `BULK INSERT` is 10-20x faster than INSERT for bulk data
- Use `TABLOCK` hint to enable parallel inserts and reduce locking overhead
- Disable triggers/constraints during bulk load: `ALTER TABLE tb_calendar DISABLE TRIGGER ALL`
- Re-enable after: `ALTER TABLE tb_calendar ENABLE TRIGGER ALL`
- Switch to `RECOVERY SIMPLE` before bulk operations for faster log growth:
  ```sql
  ALTER DATABASE fraiseql_dev SET RECOVERY SIMPLE;
  -- Perform bulk insert
  ALTER DATABASE fraiseql_dev SET RECOVERY FULL;
  BACKUP LOG fraiseql_dev TO DISK = 'D:\Backups\fraiseql_dev_log.trn';
  ```python
- For CSV import, ensure file path is on server (use UNC paths for network shares)
- Monitor transaction log growth: `DBCC SQLPERF(logspace);`
- Batch size 5000-10000 rows per transaction is optimal (balance memory vs log growth)
- Use `SqlBulkCopy.BatchSize` property to control memory usage
- Consider `SqlBulkCopy.SqlRowsCopied` event to track progress on large loads

## Migration from PostgreSQL/MySQL

Key conversions:

```sql
-- PostgreSQL uuid → SQL Server UNIQUEIDENTIFIER
-- PostgreSQL: id UUID
-- SQL Server: id UNIQUEIDENTIFIER DEFAULT NEWSEQUENTIALID()

-- PostgreSQL jsonb_build_object() → SQL Server JSON_OBJECT
-- PostgreSQL: jsonb_build_object('id', id, 'name', name)
-- SQL Server: JSON_OBJECT('id', id, 'name', name)

-- PostgreSQL jsonb_agg() → SQL Server (SELECT...FOR JSON PATH)
-- PostgreSQL: jsonb_agg(jsonb_build_object(...))
-- SQL Server: (SELECT...FOR JSON PATH)

-- PostgreSQL SERIAL → SQL Server IDENTITY
-- PostgreSQL: id BIGSERIAL PRIMARY KEY
-- SQL Server: id BIGINT PRIMARY KEY IDENTITY(1,1)

-- PostgreSQL PL/pgSQL → SQL Server T-SQL
-- Different syntax; same patterns
```python

## Performance Benchmarks

Typical FraiseQL SQL Server workloads (measured on 8-core, 32GB RAM server):

| Query Type | Dataset | Latency | Index | Notes |
|-----------|---------|---------|-------|-------|
| Single entity (v_*) | 1M rows | 0.5-1ms | PK seek | Direct ID lookup |
| Nested JSON (2 levels) | 1M users, 5M posts | 10-30ms | ix_post_user | User + posts aggregation |
| Nested JSON (3 levels) | +1M comments | 50-150ms | multiple | User + posts + comments |
| Nested JSON (4 levels) | +100K reactions | 200-500ms | multiple | Comments + reactions |
| Indexed view (v_post_summary) | 1M rows | 1-2ms | clustered | Pre-computed aggregation |
| List with pagination (1000 rows) | 10M rows | 5-15ms | covering | Indexed seek + sort |
| List with RLS (100 rows) | 1M rows | 10-30ms | ix_org | Row-level filtering |
| Analytics query (ta_*) | aggregated | 2-5ms | time index | Pre-aggregated metrics |
| Always On read replica | any | <1ms | primary | Read from secondary |
| INSERT mutation | - | 5-20ms | FK check | Transaction + logging |
| UPDATE mutation | - | 10-30ms | index seek | Lock + update + logging |
| DELETE mutation (soft) | - | 5-15ms | ix_deleted | SET deleted_at |

**Performance by Feature:**

**JSON Encoding Overhead:**
```
1K rows WITHOUT JSON: 2ms
1K rows WITH FOR JSON PATH: 5ms (2.5x slower)
10K rows WITHOUT JSON: 20ms
10K rows WITH FOR JSON PATH: 80ms (4x slower)
```

**Compression Impact:**
```
Page Compression enabled:
  - Write: 5-10% slower
  - Read: 10-30% faster
  - Storage: 30-50% reduction
  - Network: 30-50% reduction (fewer pages sent)

Recommendation: Enable on tables >100MB
```

**Index Impact on Lookups:**
```
Single column seek (index exists): 0.5ms
Column scan (no index): 50-100ms
100x speedup with proper indexing
```sql

**Optimization Tips:**

1. **Use indexed views for aggregations** (SQL Server-unique feature)
   - Reduces query complexity
   - Auto-maintained by SQL Server
   - 10-100x faster than computing live

2. **Enable page compression on large tables**
   - Tables >100MB (decisions): Enable
   - Tables <100MB: Skip (overhead > benefit)
   - Monitor `sys.dm_db_index_usage_stats` to verify

3. **Use Always On secondaries for read-heavy queries**
   - Configure read-only routing
   - 0 latency (local reads)
   - Scales read throughput linearly with replicas

4. **Limit JSON nesting depth**
   - 2 levels: <30ms (acceptable)
   - 3 levels: 50-150ms (monitor)
   - 4+ levels: >200ms (consider redesign)

5. **Create computed columns for frequently-filtered JSON fields**
   - Field filtering 10+ times/minute: Add computed column
   - Reduces FROM JSON_VALUE() overhead
   - Index on computed column for fast filtering

6. **Monitor wait statistics**
   ```sql
   SELECT TOP 10
     wait_type,
     SUM(wait_time_ms) AS total_wait_ms,
     SUM(wait_time_ms) / SUM(signal_wait_time_ms) AS ratio
   FROM sys.dm_os_waiting_tasks
   GROUP BY wait_type
   ORDER BY total_wait_ms DESC;
   ```
   - PAGEIOLATCH_SH: Add more RAM or faster disk
   - CXPACKET: Reduce max degree of parallelism
   - WRITELOG: Reduce transaction log I/O (enable async commit)

## See Also

- [Database Comparison](/databases/)
- [PostgreSQL Guide](/databases/postgresql/)
- [MySQL Guide](/databases/mysql/)
- [SQLite Guide](/databases/sqlite/)
