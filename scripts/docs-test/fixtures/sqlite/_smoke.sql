-- _smoke.sql — SQLite fixture for `pages/_smoke.docs-test.sh`.
--
-- Reproduces the SQL schema documented in
--   src/content/docs/getting-started/quickstart.mdx
-- Step 2 ("Write Your SQL Views"), SQLite tab (lines 134–162 in mdx).
--
-- source: src/content/docs/getting-started/quickstart.mdx:L17 "assumes you have a … database with tables already set up"
-- source: src/content/docs/getting-started/quickstart.mdx:L134-L162 (SQLite view definitions, json_object)
--
-- IMPORTANT — page-vs-framework gap:
--   The fraiseql-server binary at the frozen SHA is hardcoded to PostgresAdapter
--   (`~/code/fraiseql/crates/fraiseql-server/src/main.rs:L240-L260`). The
--   quickstart's SQLite tab is therefore not exercisable through the framework
--   server binary today; this fixture proves the page's per-DB SQL is correct
--   against a real SQLite database, but the smoke does NOT route SQLite
--   through FraiseQL. See handoff.md.

CREATE TABLE IF NOT EXISTS tb_user (
    pk_user    INTEGER  PRIMARY KEY AUTOINCREMENT,
    id         TEXT     NOT NULL UNIQUE,
    name       TEXT     NOT NULL,
    email      TEXT     NOT NULL UNIQUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tb_post (
    pk_post    INTEGER  PRIMARY KEY AUTOINCREMENT,
    id         TEXT     NOT NULL UNIQUE,
    fk_user    INTEGER  NOT NULL REFERENCES tb_user(pk_user),
    title      TEXT     NOT NULL,
    content    TEXT     NOT NULL,
    published  INTEGER  NOT NULL DEFAULT 1
);

-- SQLite does NOT support CREATE OR REPLACE VIEW; drop-then-create is the idiom.
DROP VIEW IF EXISTS v_post;
DROP VIEW IF EXISTS v_user;

-- source: src/content/docs/getting-started/quickstart.mdx:L136-L145
CREATE VIEW v_user AS
SELECT
    u.id,
    json_object(
        'id',         u.id,
        'name',       u.name,
        'email',      u.email,
        'created_at', u.created_at
    ) AS data
FROM tb_user u;

-- source: src/content/docs/getting-started/quickstart.mdx:L148-L161
-- DEVIATION (page bug): the page writes `'author', vu.data`, but `vu.data`
-- in SQLite is the TEXT result of an inner `json_object` call; without
-- wrapping in `json(...)` the outer `json_object` embeds it as a JSON
-- string (with escaped quotes), not as a nested object. Smoke wraps the
-- column in `json(...)` to produce the shape the page's "What Just Happened"
-- section claims. Page-vs-framework finding logged in handoff.md.
CREATE VIEW v_post AS
SELECT
    p.id,
    json_object(
        'id',      p.id,
        'title',   p.title,
        'content', p.content,
        'author',  json(vu.data)
    ) AS data
FROM tb_post p
JOIN tb_user u  ON u.pk_user = p.fk_user
JOIN v_user vu  ON vu.id     = u.id;

-- Seed (idempotent — INSERT OR IGNORE).
INSERT OR IGNORE INTO tb_user (id, name, email) VALUES
    ('00000000-0000-0000-0000-000000000001', 'Alice Smith', 'alice@example.com');

INSERT OR IGNORE INTO tb_post (id, fk_user, title, content, published)
SELECT '11111111-1111-1111-1111-111111111111',
       u.pk_user,
       'Hello FraiseQL',
       'Compiled API server FTW.',
       1
FROM tb_user u
WHERE u.id = '00000000-0000-0000-0000-000000000001';
