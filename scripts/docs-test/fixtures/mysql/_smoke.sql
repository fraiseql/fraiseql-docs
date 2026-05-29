-- _smoke.sql — MySQL fixture for `pages/_smoke.docs-test.sh`.
--
-- Reproduces the SQL schema documented in
--   src/content/docs/getting-started/quickstart.mdx
-- Step 2 ("Write Your SQL Views"), MySQL tab (lines 104–131 in mdx).
--
-- source: src/content/docs/getting-started/quickstart.mdx:L17 "assumes you have a … database with tables already set up"
-- source: src/content/docs/getting-started/quickstart.mdx:L104-L131 (MySQL view definitions, JSON_OBJECT)
--
-- IMPORTANT — page-vs-framework gap:
--   The fraiseql-server binary at the frozen SHA is hardcoded to PostgresAdapter
--   (`~/code/fraiseql/crates/fraiseql-server/src/main.rs:L240-L260`). The
--   quickstart's MySQL tab is therefore not exercisable through the framework
--   server binary today; this fixture proves the page's per-DB SQL is correct
--   against a real MySQL server, but the smoke does NOT route MySQL through
--   FraiseQL. See `_internal/.plan/handoff.md` Cycle 5 close entry for the
--   filed framework issue.

CREATE TABLE IF NOT EXISTS tb_user (
    pk_user    INT          AUTO_INCREMENT PRIMARY KEY,
    id         VARCHAR(64)  NOT NULL UNIQUE,
    name       VARCHAR(255) NOT NULL,
    email      VARCHAR(255) NOT NULL UNIQUE,
    created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tb_post (
    pk_post    INT          AUTO_INCREMENT PRIMARY KEY,
    id         VARCHAR(64)  NOT NULL UNIQUE,
    fk_user    INT          NOT NULL,
    title      VARCHAR(255) NOT NULL,
    content    TEXT         NOT NULL,
    published  BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_tb_post_user FOREIGN KEY (fk_user) REFERENCES tb_user (pk_user)
);

-- source: src/content/docs/getting-started/quickstart.mdx:L106-L115
CREATE OR REPLACE VIEW v_user AS
SELECT
    u.id,
    JSON_OBJECT(
        'id',         u.id,
        'name',       u.name,
        'email',      u.email,
        'created_at', u.created_at
    ) AS data
FROM tb_user u;

-- source: src/content/docs/getting-started/quickstart.mdx:L118-L131
CREATE OR REPLACE VIEW v_post AS
SELECT
    p.id,
    JSON_OBJECT(
        'id',      p.id,
        'title',   p.title,
        'content', p.content,
        'author',  vu.data
    ) AS data
FROM tb_post p
JOIN tb_user u  ON u.pk_user = p.fk_user
JOIN v_user vu  ON vu.id     = u.id;

-- Seed (idempotent — INSERT IGNORE on duplicate unique key).
INSERT IGNORE INTO tb_user (id, name, email) VALUES
    ('00000000-0000-0000-0000-000000000001', 'Alice Smith', 'alice@example.com');

INSERT IGNORE INTO tb_post (id, fk_user, title, content, published)
SELECT '11111111-1111-1111-1111-111111111111',
       u.pk_user,
       'Hello FraiseQL',
       'Compiled API server FTW.',
       TRUE
FROM tb_user u
WHERE u.id = '00000000-0000-0000-0000-000000000001';
