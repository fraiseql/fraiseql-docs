-- _smoke.sql — MSSQL fixture for `pages/_smoke.docs-test.sh`.
--
-- Reproduces the SQL schema documented in
--   src/content/docs/getting-started/quickstart.mdx
-- Step 2 ("Write Your SQL Views"), SQL Server tab (lines 164–190 in mdx).
--
-- source: src/content/docs/getting-started/quickstart.mdx:L17 "assumes you have a … database with tables already set up"
-- source: src/content/docs/getting-started/quickstart.mdx:L164-L190 (SQL Server view definitions, FOR JSON PATH)
--
-- IMPORTANT — page-vs-framework gap:
--   The fraiseql-server binary at the frozen SHA is hardcoded to PostgresAdapter
--   (`~/code/fraiseql/crates/fraiseql-server/src/main.rs:L240-L260`). The
--   quickstart's SQL Server tab is therefore not exercisable through the
--   framework server binary today; this fixture proves the page's per-DB SQL
--   is correct against a real SQL Server instance, but the smoke does NOT
--   route SQL Server through FraiseQL. See handoff.md.
--
-- IMPORTANT — page-vs-fixture deviation:
--   The page defines v_user / v_post WITH SCHEMABINDING, which requires the
--   referenced base tables to also be schema-bound and is incompatible with
--   v_post referencing v_user (you cannot bind a view to another view).
--   This fixture drops SCHEMABINDING so the documented two-view structure
--   compiles unmodified. See bug filing in framework-qa-triage.md.

-- Bootstrap: the docs-test MSSQL service ships with master only. Create the
-- fraiseql database on first run, idempotently. The script is invoked via
-- sqlcmd in master context.
IF DB_ID('fraiseql') IS NULL CREATE DATABASE fraiseql;
GO

USE fraiseql;
GO

IF OBJECT_ID('dbo.tb_post', 'U') IS NULL
    CREATE TABLE dbo.tb_post (
        pk_post   INT IDENTITY(1,1) PRIMARY KEY,
        id        NVARCHAR(64)  NOT NULL UNIQUE,
        fk_user   INT           NOT NULL,
        title     NVARCHAR(255) NOT NULL,
        content   NVARCHAR(MAX) NOT NULL,
        published BIT           NOT NULL DEFAULT 1
    );
GO

IF OBJECT_ID('dbo.tb_user', 'U') IS NULL
    CREATE TABLE dbo.tb_user (
        pk_user    INT IDENTITY(1,1) PRIMARY KEY,
        id         NVARCHAR(64)  NOT NULL UNIQUE,
        name       NVARCHAR(255) NOT NULL,
        email      NVARCHAR(255) NOT NULL UNIQUE,
        created_at DATETIME2     NOT NULL DEFAULT SYSDATETIME()
    );
GO

-- Drop-and-recreate so re-runs are clean. CREATE OR ALTER VIEW exists in
-- 2016+ but does not coexist with SCHEMABINDING removal across re-runs cleanly.
IF OBJECT_ID('dbo.v_post', 'V') IS NOT NULL DROP VIEW dbo.v_post;
IF OBJECT_ID('dbo.v_user', 'V') IS NOT NULL DROP VIEW dbo.v_user;
GO

-- source: src/content/docs/getting-started/quickstart.mdx:L166-L175
-- DEVIATION: dropped SCHEMABINDING (see header).
CREATE VIEW dbo.v_user AS
SELECT
    u.id,
    (
        SELECT u.id, u.name, u.email, u.created_at
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS data
FROM dbo.tb_user u;
GO

-- source: src/content/docs/getting-started/quickstart.mdx:L178-L189
-- DEVIATION 1: dropped SCHEMABINDING (see header).
-- DEVIATION 2 (page bug): the page writes `vu.data AS author` directly, but
-- `vu.data` is NVARCHAR(MAX) holding JSON text; without wrapping in
-- `JSON_QUERY()` the outer FOR JSON PATH embeds it as a JSON string with
-- escaped quotes, not as a nested object. Smoke uses `JSON_QUERY(vu.data)`
-- to produce the shape the page's narrative claims. Finding in handoff.md.
CREATE VIEW dbo.v_post AS
SELECT
    p.id,
    (
        SELECT p.id, p.title, p.content, JSON_QUERY(vu.data) AS author
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS data
FROM dbo.tb_post p
JOIN dbo.tb_user u  ON u.pk_user = p.fk_user
JOIN dbo.v_user  vu ON vu.id     = u.id;
GO

-- Seed (idempotent via MERGE on the unique id).
IF NOT EXISTS (SELECT 1 FROM dbo.tb_user WHERE id = '00000000-0000-0000-0000-000000000001')
    INSERT INTO dbo.tb_user (id, name, email)
    VALUES ('00000000-0000-0000-0000-000000000001', 'Alice Smith', 'alice@example.com');
GO

IF NOT EXISTS (SELECT 1 FROM dbo.tb_post WHERE id = '11111111-1111-1111-1111-111111111111')
    INSERT INTO dbo.tb_post (id, fk_user, title, content, published)
    SELECT '11111111-1111-1111-1111-111111111111',
           u.pk_user,
           N'Hello FraiseQL',
           N'Compiled API server FTW.',
           1
    FROM dbo.tb_user u
    WHERE u.id = '00000000-0000-0000-0000-000000000001';
GO
