-- _smoke.sql — PostgreSQL fixture for `pages/_smoke.docs-test.sh`.
--
-- Reproduces the SQL schema documented in
--   src/content/docs/getting-started/quickstart.mdx
-- Step 2 ("Write Your SQL Views"), PostgreSQL tab (lines 73–102 in mdx).
--
-- The page documents tb_user / tb_post tables and v_user / v_post views.
-- The page does NOT include a CREATE TABLE block (it says "assumes you have
-- a PostgreSQL database with tables already set up"). The tables below are
-- the minimal shape that lets the documented views compile and return data.
--
-- Seed (1 user, 1 post) is the minimum to assert a non-empty shape.
--
-- source: src/content/docs/getting-started/quickstart.mdx:L17 "assumes you have a PostgreSQL database with tables already set up"
-- source: src/content/docs/getting-started/quickstart.mdx:L73-L102 (PostgreSQL view definitions)

BEGIN;

-- Tables (page implies their existence; not documented inline — minimal shape).
CREATE TABLE IF NOT EXISTS tb_user (
    pk_user    SERIAL PRIMARY KEY,
    id         TEXT   NOT NULL UNIQUE,
    name       TEXT   NOT NULL,
    email      TEXT   NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tb_post (
    pk_post    SERIAL PRIMARY KEY,
    id         TEXT   NOT NULL UNIQUE,
    fk_user    INTEGER NOT NULL REFERENCES tb_user(pk_user),
    title      TEXT   NOT NULL,
    content    TEXT   NOT NULL,
    published  BOOLEAN NOT NULL DEFAULT TRUE
);

-- Views (verbatim shape from the page; jsonb_build_object as documented).
-- source: src/content/docs/getting-started/quickstart.mdx:L75-L86
CREATE OR REPLACE VIEW v_user AS
SELECT
    u.id,
    jsonb_build_object(
        'id',         u.id::text,
        'name',       u.name,
        'email',      u.email,
        'created_at', u.created_at
    ) AS data
FROM tb_user u;

-- source: src/content/docs/getting-started/quickstart.mdx:L88-L101
CREATE OR REPLACE VIEW v_post AS
SELECT
    p.id,
    jsonb_build_object(
        'id',      p.id::text,
        'title',   p.title,
        'content', p.content,
        'author',  vu.data
    ) AS data
FROM tb_post p
JOIN tb_user u  ON u.pk_user = p.fk_user
JOIN v_user vu  ON vu.id     = u.id;

-- Seed (idempotent — ON CONFLICT).
INSERT INTO tb_user (id, name, email) VALUES
    ('00000000-0000-0000-0000-000000000001', 'Alice Smith', 'alice@example.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO tb_post (id, fk_user, title, content, published) VALUES
    ('11111111-1111-1111-1111-111111111111',
     (SELECT pk_user FROM tb_user WHERE id = '00000000-0000-0000-0000-000000000001'),
     'Hello FraiseQL',
     'Compiled API server FTW.',
     TRUE)
ON CONFLICT (id) DO NOTHING;

COMMIT;
