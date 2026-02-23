---
title: SQLite Guide for FraiseQL
description: SQLite implementation guide for FraiseQL with Trinity pattern, JSON projections, and pragmatic patterns for development and embedded use
---

## Introduction

SQLite is the **best choice for FraiseQL development** because it requires zero setup and perfectly mirrors production behavior:

- **Instant Setup**: Single file, zero configuration, works everywhere
- **Perfect for Development**: Identical schema and queries to PostgreSQL/MySQL
- **In-Memory Testing**: Create isolated test databases instantly
- **Embedded Deployments**: Ship database with your application
- **~15 WHERE Operators**: Fewer operators, but sufficient for most GraphQL queries
- **JSON Support**: Native `json_object()`, `json_array()` functions (SQLite 3.9+)
- **ACID Transactions**: Despite simplicity, maintains consistency
- **Pragmatic Limits**: Not for high-concurrency production, but excellent for single-server apps

FraiseQL works perfectly on SQLite; schema and patterns are identical to PostgreSQL/MySQL, just with simpler syntax and fewer concurrent writers.

## Core Architecture

### Single JSON Data Column Pattern

Like PostgreSQL and MySQL, FraiseQL views expose entities as **single JSON columns** named `data`:

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
WHERE id = ?;

-- Result row:
-- id: "550e8400-e29b-41d4-a716-446655440000"
-- tenant_id: "550e8400-..."
-- organization_id: "550e8400-..."
-- is_current: 1
-- data: {"id": "550e8400-...", "name": "John", "email": "john@example.com", ...}
```

**Why?** Rust GraphQL server receives complete entity as single JSON payload, no assembly needed.

### Trinity Pattern: TEXT UUID + INTEGER PKs

FraiseQL uses a dual-identifier system (adapted for SQLite):

```sql
CREATE TABLE tb_user (
  pk_user INTEGER PRIMARY KEY AUTOINCREMENT,  -- Internal, fast FKs
  id TEXT NOT NULL UNIQUE,                    -- Public, exposed in GraphQL (UUID)
  email TEXT NOT NULL UNIQUE COLLATE NOCASE,
  name TEXT NOT NULL,
  deleted_at TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE tb_post (
  pk_post INTEGER PRIMARY KEY AUTOINCREMENT,
  id TEXT NOT NULL UNIQUE,
  fk_user INTEGER NOT NULL REFERENCES tb_user(pk_user) ON DELETE CASCADE,  -- Uses pk_user
  title TEXT NOT NULL,
  deleted_at TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Foreign key enforcement (CRITICAL - default is OFF in SQLite)
PRAGMA foreign_keys = ON;
```

**Why?**
- `id` (TEXT): UUID exposed in GraphQL, immutable across systems
- `pk_*` (INTEGER): Fast joins, small FK storage, internal only
- Resolver functions bridge them in mutations

### Resolver Functions

Every table has UUID ↔ INTEGER resolver functions:

```sql
-- Resolve UUID to internal pk (used in mutations)
CREATE FUNCTION core_get_pk_user(p_user_id TEXT)
RETURNS INTEGER AS
SELECT pk_user FROM tb_user WHERE id = p_user_id LIMIT 1;

-- Resolve pk to UUID (used in responses)
CREATE FUNCTION core_get_user_id(p_pk_user INTEGER)
RETURNS TEXT AS
SELECT id FROM tb_user WHERE pk_user = p_pk_user LIMIT 1;
```

Created in the same file as the table definition for maintainability.

## Mutation Response Type

All mutations return a structure with 8 fields (expressed as JSON):

```sql
-- File: 00402_type_mutation_response.sql
-- JSON structure documentation:
-- {
--   "status": "success:created|failed:validation|not_found:user",
--   "message": "Human-readable message",
--   "entity_id": "UUID",
--   "entity_type": "User|Post|...",
--   "entity": {...complete JSON...},
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
  "cascade": {},
  "metadata": {
    "operation": "INSERT",
    "timestamp": "2024-02-08T10:30:00Z"
  }
}
```

## Input Types

Input validation via JSON and trigger/function parameter documentation:

```sql
-- File: 00445_type_user_input.sql
-- Expected input JSON:
-- {
--   "email": "user@example.com",
--   "name": "User Name",
--   "status": "active"
-- }
```

Used in mutation triggers for validation:

```sql
CREATE TRIGGER trg_user_before_insert
BEFORE INSERT ON tb_user
FOR EACH ROW
BEGIN
  -- Validate email format (basic)
  SELECT CASE
    WHEN NEW.email NOT LIKE '%@%.%' THEN
      RAISE(ABORT, 'Invalid email format')
  END;

  -- Set defaults
  SET NEW.created_at = CURRENT_TIMESTAMP;
  SET NEW.updated_at = CURRENT_TIMESTAMP;
END;
```

**Security: Input Validation & SQL Injection Prevention**

All input examples use **parameterized queries** (`?` placeholders) to prevent SQL injection:

```sql
-- ✅ SAFE: Parameterized query
SELECT * FROM tb_user WHERE id = ? AND email = ?;
-- Caller: db.execute(query, [user_id, email])

-- ❌ UNSAFE: String concatenation (NEVER DO THIS)
-- query = f"SELECT * FROM tb_user WHERE id = '{user_id}'"
-- This allows injection: user_id = "'; DELETE FROM tb_user; --"
```

Best practices applied in all examples:
- ✅ JSON values extracted before SQL composition (`json_extract()` patterns)
- ✅ Enums validated against whitelist before use (status IN ('active', 'suspended'))
- ✅ String lengths validated in application layer
- ✅ All external input treated as untrusted
- ✅ Application-level binds parameters (no user input in SQL strings)

## View Structure: v_* (Regular Views)

Views are the **source truth** for read operations:

```sql
-- File: 02411_v_user.sql
CREATE VIEW v_user AS
SELECT
  u.id,
  u.organization_id,                          -- Tenant context for RLS
  u.tenant_id,                                -- Tenant context for RLS
  u.deleted_at IS NULL AS is_current,         -- Soft-delete filter
  json_object(
    'id', u.id,
    'email', u.email,
    'name', u.name,
    'status', COALESCE(u.status, 'active'),
    'role', u.role,
    'created_at', u.created_at,
    'updated_at', u.updated_at
  ) AS data
FROM tb_user u
WHERE u.deleted_at IS NULL;
```

**View Query Pattern:**
```sql
-- Client requests: query { user(id: "uuid") { id name email } }
-- Server executes:
SELECT id, data FROM v_user WHERE id = ?;
```

### Nested Views (One-to-Many Relationships)

```sql
-- File: 02412_v_user_with_posts.sql
CREATE VIEW v_user_with_posts AS
SELECT
  u.id,
  u.organization_id,
  u.tenant_id,
  u.is_current,
  json_object(
    'id', u.id,
    'email', u.email,
    'name', u.name,
    'posts', COALESCE(
      (
        SELECT json_group_array(
          json_object(
            'id', p.id,
            'title', p.title,
            'status', p.status
          )
        )
        FROM tb_post p
        WHERE p.fk_user = u.pk_user AND p.deleted_at IS NULL
      ),
      json_array()
    )
  ) AS data
FROM v_user u;
```

**Key Patterns:**
- Views embed other views' JSON data (no duplication)
- `COALESCE(..., json_array())` provides default empty array
- Subqueries for aggregation (SQLite doesn't support LEFT JOIN with GROUP BY as elegantly)
- Always ensure WHERE clause for soft-delete filtering

### Deep Nesting (3+ Levels)

```sql
-- File: 02413_v_user_with_posts_and_comments.sql
CREATE VIEW v_user_with_posts_and_comments AS
SELECT
  u.id,
  u.organization_id,
  u.tenant_id,
  u.is_current,
  json_object(
    'id', u.id,
    'email', u.email,
    'name', u.name,
    'posts', COALESCE(
      (
        SELECT json_group_array(
          json_object(
            'id', p.id,
            'title', p.title,
            'comments', COALESCE(
              (
                SELECT json_group_array(
                  json_object(
                    'id', c.id,
                    'content', c.content
                  )
                )
                FROM tb_comment c
                WHERE c.fk_post = p.pk_post AND c.deleted_at IS NULL
              ),
              json_array()
            )
          )
        )
        FROM tb_post p
        WHERE p.fk_user = u.pk_user AND p.deleted_at IS NULL
      ),
      json_array()
    )
  ) AS data
FROM v_user u;
```

**Note**: Deep nesting is possible but can become complex. For development, this is fine; consider caching/materialization for production use.

## Materialized Views: tv_* (Optional for Heavy Reads)

SQLite is single-writer, so materialized views are mainly useful for caching query results:

```sql
-- File: 02414_tv_user.sql
-- Materialized cache of v_user results
CREATE TABLE IF NOT EXISTS tv_user (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  tenant_id TEXT NOT NULL,
  is_current BOOLEAN DEFAULT 1,
  data TEXT NOT NULL,  -- JSON stored as TEXT (SQLite has no JSONB type)

  -- Materialization metadata
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_synced_at TIMESTAMP NULL,
  sync_count INTEGER DEFAULT 0,
  is_stale BOOLEAN DEFAULT 0
);

-- Indexes for access patterns
CREATE INDEX IF NOT EXISTS idx_tv_user_organization ON tv_user(organization_id);
CREATE INDEX IF NOT EXISTS idx_tv_user_is_current ON tv_user(is_current);
CREATE INDEX IF NOT EXISTS idx_tv_user_updated_at ON tv_user(updated_at DESC);
```

**Refresh Triggers** (called after INSERT/UPDATE):

```sql
-- File: 03101_refresh_user.sql
-- Trigger to keep materialized view fresh
CREATE TRIGGER trg_user_after_insert
AFTER INSERT ON tb_user
FOR EACH ROW
BEGIN
  INSERT OR REPLACE INTO tv_user (id, organization_id, tenant_id, is_current, data)
  SELECT id, organization_id, tenant_id, is_current, data
  FROM v_user
  WHERE id = NEW.id;
END;

CREATE TRIGGER trg_user_after_update
AFTER UPDATE ON tb_user
FOR EACH ROW
BEGIN
  INSERT OR REPLACE INTO tv_user (id, organization_id, tenant_id, is_current, data)
  SELECT id, organization_id, tenant_id, is_current, data
  FROM v_user
  WHERE id = NEW.id;
END;
```

## Mutation Triggers: Handling INSERT/UPDATE/DELETE

SQLite uses **INSTEAD OF triggers** for mutation logic (no stored procedures in SQLite):

```sql
-- File: 03311_create_user.sql
-- Create new user via triggered mutation
CREATE TRIGGER trg_user_create
INSTEAD OF INSERT ON v_user
WHEN NEW.id IS NOT NULL AND NEW.email IS NOT NULL
BEGIN
  -- Validate email uniqueness
  SELECT CASE
    WHEN EXISTS(SELECT 1 FROM tb_user WHERE email = NEW.email AND deleted_at IS NULL)
    THEN RAISE(ABORT, 'conflict:email')
  END;

  -- INSERT into write table
  INSERT INTO tb_user (id, email, name, status)
  VALUES (NEW.id, NEW.email, NEW.name, COALESCE(NEW.status, 'active'));
END;

-- Update existing user via triggered mutation
CREATE TRIGGER trg_user_update
INSTEAD OF UPDATE ON v_user
WHEN OLD.id IS NOT NULL
BEGIN
  UPDATE tb_user
  SET
    email = COALESCE(NEW.email, OLD.email),
    name = COALESCE(NEW.name, OLD.name),
    status = COALESCE(NEW.status, OLD.status),
    updated_at = CURRENT_TIMESTAMP
  WHERE id = OLD.id;
END;

-- Soft delete user via triggered mutation
CREATE TRIGGER trg_user_delete
INSTEAD OF DELETE ON v_user
WHEN OLD.id IS NOT NULL
BEGIN
  UPDATE tb_user
  SET deleted_at = CURRENT_TIMESTAMP
  WHERE id = OLD.id;
END;
```

**Alternative: Application-Level Mutations**

For more complex mutations, handle them in application code (Python/Rust) rather than triggers:

```python
# Pseudo-Python application logic
def create_user(db, tenant_id: str, user_id: str, payload: dict) -> dict:
    # Validate input
    if not payload.get('email') or '@' not in payload['email']:
        return {
            'status': 'invalid_input',
            'message': 'Valid email required',
            'entity': None
        }

    # Check for duplicate
    existing = db.execute(
        'SELECT id FROM tb_user WHERE email = ? AND deleted_at IS NULL',
        (payload['email'],)
    ).fetchone()

    if existing:
        return {
            'status': 'conflict:email',
            'message': 'Email already in use',
            'entity': None
        }

    # INSERT
    db.execute(
        '''INSERT INTO tb_user (id, email, name, status)
           VALUES (?, ?, ?, ?)''',
        (str(uuid.uuid4()), payload['email'], payload.get('name'), 'active')
    )
    db.commit()

    # AFTER snapshot: read from view
    result = db.execute(
        'SELECT data FROM v_user WHERE id = ?',
        (new_id,)
    ).fetchone()

    return {
        'status': 'success:created',
        'message': 'User created',
        'entity': json.loads(result[0])
    }
```

## Configuration: Essential Pragmas

SQLite configuration via pragmas (critical for FraiseQL reliability):

```sql
-- File: 00001_pragmas.sql
-- Enable foreign key enforcement (OFF by default!)
PRAGMA foreign_keys = ON;

-- Set journal mode to WAL (better for concurrent reads)
PRAGMA journal_mode = WAL;

-- Cache size (in pages, negative = MB)
PRAGMA cache_size = -64000;  -- 64MB cache

-- Temporary table storage (use memory for speed)
PRAGMA temp_store = MEMORY;

-- Synchronous writes (balance safety vs speed)
PRAGMA synchronous = NORMAL;  -- 1=NORMAL, 2=FULL, 0=OFF

-- Query optimization
PRAGMA optimize;

-- Enable query planner statistics
ANALYZE;
```

## Schema Organization: Numbered Prefix System

SQLite projects follow the same directory structure as PostgreSQL/MySQL:

```sql


│
│   │
│   │
│   │
│   │
│   ↓
│
│   │
│   │
│   │
│   ↓
│
│   │
│   │   │
│   │   │
│   │   │
│   │   ↓
│   │
│   ↓
│
│
│       │
│       │
│       ↓
│
│
│
│
↓
```

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

### SQLite-Specific Implementation

**Calendar Dimension Table:**

```sql
-- File: 01001_tb_calendar.sql
-- Pre-computed temporal dimensions (in-memory or from file)
CREATE TABLE tb_calendar (
    id TEXT UNIQUE,
    reference_date TEXT PRIMARY KEY,

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

    date_info TEXT,         -- JSON
    week_info TEXT,         -- JSON
    half_month_info TEXT,   -- JSON
    month_info TEXT,        -- JSON
    quarter_info TEXT,      -- JSON
    semester_info TEXT,     -- JSON
    year_info TEXT,         -- JSON

    week_reference_date TEXT,
    half_month_reference_date TEXT,
    month_reference_date TEXT,
    quarter_reference_date TEXT,
    semester_reference_date TEXT,
    year_reference_date TEXT,

    is_week_reference_date BOOLEAN,
    is_half_month_reference_date BOOLEAN,
    is_month_reference_date BOOLEAN,
    is_quarter_reference_date BOOLEAN,
    is_semester_reference_date BOOLEAN,
    is_year_reference_date BOOLEAN
);

CREATE INDEX idx_tb_calendar_date ON tb_calendar(reference_date);
CREATE INDEX idx_tb_calendar_year_month ON tb_calendar(year, month);

-- Seed calendar (populate from JSON file or Python script for efficiency)
-- SQLite doesn't have generator function, so prefer:
-- 1. Load calendar.json from fixtures
-- 2. Or use Python datetime to generate and INSERT via parameterized queries
```

**Fact Table with Measures and Dimensions:**

```sql
-- File: 01002_tf_user_events.sql
-- Fact table: user events with measures as direct columns
CREATE TABLE tf_user_events (
    pk_event INTEGER PRIMARY KEY AUTOINCREMENT,

    -- MEASURES (direct columns for fast aggregation)
    event_count INT DEFAULT 1,
    engagement_score REAL NOT NULL,
    duration_seconds INT,

    -- DIMENSIONS (JSON for flexibility)
    data TEXT NOT NULL,     -- JSON object

    -- TEMPORAL (foreign key to calendar)
    occurred_at TEXT NOT NULL,

    -- DENORMALIZED KEYS (indexed for filtering)
    user_id TEXT NOT NULL,
    organization_id TEXT NOT NULL,
    event_type TEXT NOT NULL,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_tf_user_events_occurred ON tf_user_events(occurred_at);
CREATE INDEX idx_tf_user_events_user ON tf_user_events(user_id);
CREATE INDEX idx_tf_user_events_organization ON tf_user_events(organization_id);
CREATE INDEX idx_tf_user_events_type ON tf_user_events(event_type);
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
CREATE VIEW va_user_events_daily AS
SELECT
    e.user_id,
    e.organization_id,
    json_object(
        'dimensions', json(e.data) || json_object(
            'date_info', json(cal.date_info),
            'event_type', e.event_type
        ),
        'measures', json_object(
            'event_count', SUM(e.event_count),
            'total_engagement', CAST(SUM(e.engagement_score) AS REAL),
            'total_duration', SUM(e.duration_seconds),
            'avg_engagement', CAST(AVG(e.engagement_score) AS REAL)
        ),
        'temporal', json_object(
            'date', cal.reference_date,
            'week', cal.week,
            'month', cal.month,
            'quarter', cal.quarter,
            'year', cal.year
        )
    ) AS data
FROM tf_user_events e
LEFT JOIN tb_calendar cal ON cal.reference_date = e.occurred_at
WHERE e.occurred_at >= date('now', '-90 days')
GROUP BY e.user_id, e.organization_id, cal.reference_date, e.event_type;
```

**Analytics Table for Arrow/Parquet Export:**

```sql
-- File: 01003_ta_user_events_daily.sql
-- Pre-aggregated, flattened structure for Arrow Flight export
CREATE TABLE ta_user_events_daily (
    day TEXT NOT NULL,
    user_id TEXT NOT NULL,
    organization_id TEXT NOT NULL,
    event_type TEXT NOT NULL,

    event_count INTEGER NOT NULL,
    total_engagement REAL NOT NULL,
    total_duration INTEGER NOT NULL,
    avg_engagement REAL NOT NULL,

    year INT NOT NULL,
    month INT NOT NULL,
    week INT NOT NULL,
    quarter INT NOT NULL,

    computed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sync_count INTEGER DEFAULT 1,
    is_stale BOOLEAN DEFAULT FALSE,

    PRIMARY KEY (day, user_id, event_type)
);

CREATE INDEX idx_ta_user_events_daily_org ON ta_user_events_daily(organization_id, day);

-- Refresh procedure (run hourly from application or via cron)
-- SQLite lacks stored procedures; use Python/application-level scheduling
-- Pseudo-code pattern:

CREATE TRIGGER IF NOT EXISTS tr_sync_ta_user_events_daily
AFTER INSERT ON tf_user_events
WHEN NEW.occurred_at >= date('now', '-7 days')
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
    WHERE e.occurred_at = NEW.occurred_at AND e.user_id = NEW.user_id AND e.event_type = NEW.event_type
    GROUP BY e.occurred_at, e.user_id, e.organization_id, e.event_type
    ON CONFLICT(day, user_id, event_type) DO UPDATE SET
        event_count = excluded.event_count,
        total_engagement = excluded.total_engagement,
        total_duration = excluded.total_duration,
        avg_engagement = excluded.avg_engagement,
        computed_at = CURRENT_TIMESTAMP,
        sync_count = sync_count + 1,
        is_stale = FALSE;
END;

-- Read view for Arrow Flight
CREATE VIEW va_user_events_daily_arrow AS
SELECT * FROM ta_user_events_daily WHERE is_stale = FALSE ORDER BY day DESC;
```

**Year-over-Year Analysis Query:**

```sql
-- Compare monthly engagement across years
SELECT
    cal.month,
    cal.year,
    COUNT(*) AS event_count,
    CAST(SUM(e.engagement_score) AS REAL) AS total_engagement,
    CAST(AVG(e.engagement_score) AS REAL) AS avg_engagement
FROM tf_user_events e
LEFT JOIN tb_calendar cal ON cal.reference_date = e.occurred_at
WHERE e.organization_id = ?
GROUP BY cal.year, cal.month
ORDER BY cal.year DESC, cal.month;
```

**Application-Level Analytics Sync (Python example):**

```python
# Preferred pattern for SQLite: sync from application
from datetime import datetime, timedelta
import sqlite3
import json

def sync_ta_user_events_daily(db_path: str):
    """Refresh analytics table daily (run from scheduled task/cron)"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Get last 7 days of events
    start_date = (datetime.now() - timedelta(days=7)).strftime('%Y-%m-%d')

    # Aggregate from fact table
    query = """
    INSERT OR REPLACE INTO ta_user_events_daily
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
        datetime('now'),
        1,
        0
    FROM tf_user_events e
    LEFT JOIN tb_calendar cal ON cal.reference_date = e.occurred_at
    WHERE e.occurred_at >= ?
    GROUP BY e.occurred_at, e.user_id, e.organization_id, e.event_type
    """

    cursor.execute(query, (start_date,))
    conn.commit()
    conn.close()
    print(f"Analytics sync completed for {start_date} onwards")
```

## Testing with In-Memory Databases

Perfect isolation for tests:

```python
import sqlite3
import pytest

@pytest.fixture
def test_db():
    """Create fresh in-memory SQLite database for each test"""
    conn = sqlite3.connect(':memory:')
    conn.row_factory = sqlite3.Row  # Enable column access by name
    conn.execute('PRAGMA foreign_keys = ON')

    # Load schema
    with open('db/0_schema/init.sql', 'r') as f:
        conn.executescript(f.read())

    yield conn
    conn.close()

def test_create_user(test_db):
    """Test user creation"""
    test_db.execute(
        'INSERT INTO tb_user (id, email, name) VALUES (?, ?, ?)',
        ('550e8400-e29b-41d4-a716-446655440000', 'test@example.com', 'Test User')
    )
    test_db.commit()

    result = test_db.execute(
        'SELECT data FROM v_user WHERE email = ?',
        ('test@example.com',)
    ).fetchone()

    assert result is not None
```

## Performance Optimization

### Index Strategy

```sql
-- Create indexes on write tables (tb_*)
CREATE INDEX IF NOT EXISTS idx_user_email ON tb_user(email);
CREATE INDEX IF NOT EXISTS idx_user_organization ON tb_user(organization_id);
CREATE INDEX IF NOT EXISTS idx_user_deleted_created ON tb_user(deleted_at, created_at DESC);

-- Create indexes on materialized tables (tv_*)
CREATE INDEX IF NOT EXISTS idx_tv_user_organization ON tv_user(organization_id);

-- Analyze to generate statistics
ANALYZE;
```

### Query Optimization

```sql
-- Check query plan
EXPLAIN QUERY PLAN
SELECT data FROM v_user WHERE organization_id = ? AND is_current = 1;

-- View table statistics (after ANALYZE)
SELECT * FROM sqlite_stat1 WHERE tbl = 'tb_user';
```

## Deployment: Single-File Distribution

Easiest deployment model:

```bash
# Package database with application
cp fraiseql_dev.db /path/to/app/data/

# Or create on first run
if [ ! -f $APP_DATA_DIR/fraiseql.db ]; then
  sqlite3 $APP_DATA_DIR/fraiseql.db < db/0_schema/init.sql
fi

# Application connects with:
# connection_string = "sqlite:///./data/fraiseql.db"
```

## Troubleshooting

### "database is locked" Error

```sql
-- Problem: Another process has exclusive lock
-- Solution: SQLite locks release automatically; usually means:
-- 1. Long-running transaction
-- 2. Another concurrent writer (SQLite allows only 1)

-- Check open connections
PRAGMA database_list;

-- Increase busy timeout
PRAGMA busy_timeout = 5000;  -- Wait 5 seconds before failing
```

### Foreign Key Constraint Fails

```sql
-- Problem: FK constraint violated
-- Solution: Ensure pragmas are loaded

PRAGMA foreign_keys = ON;  -- MUST be first statement after opening connection!
```

### View Returns NULL Instead of Empty Array

```sql
-- Problem: json_group_array returns NULL when no rows
SELECT json_group_array(id) FROM tb_post WHERE user_id = 999;
-- Result: NULL (not [])

-- Solution: Use COALESCE
SELECT COALESCE(
  json_group_array(id),
  json_array()
) FROM tb_post WHERE user_id = 999;
```

### JSON Functions Not Available

```sql
-- Problem: json_object() not found
-- Solution: Ensure SQLite 3.9+ (August 2015+)

SELECT sqlite_version();  -- Should be 3.9.0 or higher
```

## Bulk Operations: Initial Data Load

For seeding calendar data and bulk inserts with SQLite, use batching and transactions:

### CSV Import (Application-level)

```python
# Preferred for SQLite: load from application (no server-side file requirements)
import csv
import json
import sqlite3
from datetime import datetime, timedelta

def seed_calendar(db_path: str):
    """Seed calendar dimension table"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Generate dates and insert in batches
    batch_size = 1000
    start_date = datetime(2015, 1, 1)
    end_date = datetime(2035, 12, 31)

    current = start_date
    batch = []

    while current <= end_date:
        week = current.isocalendar()[1]
        month = current.month
        quarter = (month - 1) // 3 + 1
        semester = 1 if month <= 6 else 2

        date_info = json.dumps({
            'date': current.isoformat(),
            'week': week,
            'month': month,
            'quarter': quarter,
            'semester': semester,
            'year': current.year
        })

        batch.append((
            current.isoformat(),  # reference_date
            week, month, quarter, semester, current.year,
            date_info
        ))

        if len(batch) >= batch_size:
            cursor.executemany(
                '''INSERT INTO tb_calendar(reference_date, week, month, quarter,
                   semester, year, date_info) VALUES (?, ?, ?, ?, ?, ?, ?)''',
                batch
            )
            conn.commit()
            batch = []

        current += timedelta(days=1)

    # Insert remainder
    if batch:
        cursor.executemany(
            '''INSERT INTO tb_calendar(reference_date, week, month, quarter,
               semester, year, date_info) VALUES (?, ?, ?, ?, ?, ?, ?)''',
            batch
        )
        conn.commit()

    conn.close()
    print(f"Calendar seeded: {(end_date - start_date).days} days")
```

### Batched SQL Inserts

```sql
-- Batch insert with transactions
BEGIN TRANSACTION;
INSERT INTO tf_sales(day, customer_id, quantity, revenue) VALUES
  ('2024-01-01', 'cust-1', 100, 1000.00),
  ('2024-01-01', 'cust-2', 50, 500.00),
  ...
  ('2024-01-01', 'cust-1000', 75, 750.00);
COMMIT;

-- Repeat for next batch of 1000 rows
```python

**Performance Tips:**
- Use batch sizes of 1000-5000 rows per transaction
- `BEGIN TRANSACTION` blocks are critical - 100-500x faster
- `PRAGMA synchronous = OFF;` during bulk load (trade durability for speed)
- `PRAGMA journal_mode = OFF;` during import (disable journal)
- Re-enable after: `PRAGMA synchronous = FULL;` and `PRAGMA journal_mode = WAL;`
- Use parameter binding (`?` placeholders) to prevent SQL injection
- Monitor: `PRAGMA page_count;` and `PRAGMA freelist_count;` for disk usage

### Import from CSV File

```sql
-- Using readcsv extension (if available)
.mode csv
.import calendar_2015_2035.csv tb_calendar

-- Or use command-line SQLite
sqlite3 fraiseql.db ".mode csv" ".import calendar.csv tb_calendar"
```

                          ─

When scaling beyond SQLite's single-writer limitation:

```sql
-- Export from SQLite
.mode insert tb_user
SELECT * FROM tb_user;


        ─
                         ─
                 ─
                      ─
```

FraiseQL schemas are database-agnostic, so migration is primarily changing:
1. Column types
2. JSON functions
3. Trigger syntax

The schema structure (tb_*, v_*, fn_*, ta_*, va_*) remains identical.

## Performance Benchmarks

Typical FraiseQL SQLite workloads:

| Query Type | Latency | Notes |
|-----------|---------|-------|
| Single entity (v_*) | 0.3-0.8ms | Index lookup on id |
| List query (100 rows) | 2-5ms | With is_current filter |
| Nested JSON (3 levels) | 5-20ms | Depends on aggregation |
| Materialized view (tv_*) | 0.5-1ms | Pre-computed cache |
| Analytics view (va_*) | 10-100ms | GROUP BY aggregation |

**Optimization Tips:**
- Always enable WAL mode for concurrent read performance
- Use materialized views (tv_*) for frequently-accessed data
- Create indexes on frequently-filtered columns
- In-memory `:memory:` databases are fastest for testing
- Cache large materialized views in memory with `PRAGMA cache_size`

## Limitations & Workarounds

| Limitation | Workaround |
|-----------|-----------|
| Single concurrent writer | Use application-level locking; reads are concurrent |
| No JSONB type | JSON works fine; slightly slower but same patterns |
| No composite types | Use JSON structures in documentation |
| No stored procedures | Use INSTEAD OF triggers or application logic |
| Max ~15 WHERE operators | Use simpler queries; application-level filtering for complex logic |

## See Also

- [Database Comparison](/databases/)
- [PostgreSQL Guide](/databases/postgresql/)
- [MySQL Guide](/databases/mysql/)
- [SQL Server Guide](/databases/sqlserver/)