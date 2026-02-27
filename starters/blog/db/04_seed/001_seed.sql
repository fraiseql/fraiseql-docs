-- =============================================================================
-- Blog seed data
-- All inserts use DO $$ blocks to resolve foreign keys cleanly via CTEs.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Users (5): 1 admin, 2 authors, 2 readers
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    INSERT INTO tb_user (id, name, email, role) VALUES
        (gen_random_uuid(), 'Alice Martin',  'alice@example.com',  'admin'),
        (gen_random_uuid(), 'Bob Chen',      'bob@example.com',    'author'),
        (gen_random_uuid(), 'Carol Davis',   'carol@example.com',  'author'),
        (gen_random_uuid(), 'Dave Wilson',   'dave@example.com',   'reader'),
        (gen_random_uuid(), 'Eve Thompson',  'eve@example.com',    'reader')
    ON CONFLICT (email) DO NOTHING;
END $$;

-- -----------------------------------------------------------------------------
-- Tags (8)
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    INSERT INTO tb_tag (name, slug) VALUES
        ('GraphQL',      'graphql'),
        ('PostgreSQL',   'postgresql'),
        ('FraiseQL',     'fraiseql'),
        ('Performance',  'performance'),
        ('Tutorial',     'tutorial'),
        ('Architecture', 'architecture'),
        ('Security',     'security'),
        ('Open Source',  'open-source')
    ON CONFLICT (slug) DO NOTHING;
END $$;

-- -----------------------------------------------------------------------------
-- Posts (10 published), authored by Bob and Carol
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_pk_bob   BIGINT;
    v_pk_carol BIGINT;
BEGIN
    SELECT pk_user INTO v_pk_bob   FROM tb_user WHERE email = 'bob@example.com';
    SELECT pk_user INTO v_pk_carol FROM tb_user WHERE email = 'carol@example.com';

    INSERT INTO tb_post (fk_user, title, content, published) VALUES
        (
            v_pk_bob,
            'Getting Started with FraiseQL',
            'FraiseQL turns your PostgreSQL schema into a fully-featured GraphQL API with almost no configuration. In this post we walk through installing FraiseQL, writing your first view, and running your first query.',
            true
        ),
        (
            v_pk_bob,
            'Understanding the tb_/v_ Convention',
            'The naming convention at the heart of FraiseQL separates storage concerns from API concerns. Tables hold data with integer primary keys; views expose exactly the JSONB shape GraphQL needs.',
            true
        ),
        (
            v_pk_bob,
            'Writing Your First Mutation Function',
            'FraiseQL mutations are plain PostgreSQL functions. They receive UUID arguments, resolve to integer PKs internally, and return the new row UUID. No ORM, no magic — just SQL.',
            true
        ),
        (
            v_pk_bob,
            'Pagination Without Headaches',
            'Cursor-based pagination in FraiseQL requires nothing more than an ORDER BY and a WHERE clause in your view. This post shows a complete pattern for keyset pagination.',
            true
        ),
        (
            v_pk_bob,
            'FraiseQL vs Traditional ORMs',
            'ORMs are convenient until they are not. This post benchmarks FraiseQL against SQLAlchemy and Prisma on a 10 M-row dataset and discusses when each approach wins.',
            true
        ),
        (
            v_pk_carol,
            'Designing a Multi-Tenant Schema',
            'Row-level security and schema-per-tenant are the two dominant multi-tenancy patterns for PostgreSQL. FraiseQL works naturally with both; here is how.',
            true
        ),
        (
            v_pk_carol,
            'GraphQL Subscriptions Over NATS',
            'FraiseQL''s NATS integration lets you push real-time updates to GraphQL subscribers without polling. This tutorial sets up a local NATS server and wires it to a live query.',
            true
        ),
        (
            v_pk_carol,
            'Securing Your FraiseQL API',
            'Rate limiting, JWT validation, and field-level authorisation are all first-class citizens in FraiseQL. This post covers a hardened production configuration.',
            true
        ),
        (
            v_pk_carol,
            'Performance Benchmarks: 1 M Rows',
            'Raw numbers for list queries, single-row lookups, and nested relation fetches on a 1 M-row PostgreSQL table — with and without FraiseQL''s Arrow data plane.',
            true
        ),
        (
            v_pk_carol,
            'Contributing to FraiseQL',
            'FraiseQL is open source and welcomes contributions. This guide covers the development workflow, test conventions, and how to open a pull request.',
            true
        )
    ON CONFLICT DO NOTHING;
END $$;

-- -----------------------------------------------------------------------------
-- Post–tag associations
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    -- post PKs (looked up by title prefix for brevity)
    pk_post_01 BIGINT; pk_post_02 BIGINT; pk_post_03 BIGINT;
    pk_post_04 BIGINT; pk_post_05 BIGINT; pk_post_06 BIGINT;
    pk_post_07 BIGINT; pk_post_08 BIGINT; pk_post_09 BIGINT;
    pk_post_10 BIGINT;
    -- tag PKs
    pk_graphql BIGINT;  pk_pg      BIGINT; pk_fraiseql   BIGINT;
    pk_perf    BIGINT;  pk_tut     BIGINT; pk_arch       BIGINT;
    pk_sec     BIGINT;  pk_oss     BIGINT;
BEGIN
    SELECT pk_post INTO pk_post_01 FROM tb_post WHERE title = 'Getting Started with FraiseQL';
    SELECT pk_post INTO pk_post_02 FROM tb_post WHERE title = 'Understanding the tb_/v_ Convention';
    SELECT pk_post INTO pk_post_03 FROM tb_post WHERE title = 'Writing Your First Mutation Function';
    SELECT pk_post INTO pk_post_04 FROM tb_post WHERE title = 'Pagination Without Headaches';
    SELECT pk_post INTO pk_post_05 FROM tb_post WHERE title = 'FraiseQL vs Traditional ORMs';
    SELECT pk_post INTO pk_post_06 FROM tb_post WHERE title = 'Designing a Multi-Tenant Schema';
    SELECT pk_post INTO pk_post_07 FROM tb_post WHERE title = 'GraphQL Subscriptions Over NATS';
    SELECT pk_post INTO pk_post_08 FROM tb_post WHERE title = 'Securing Your FraiseQL API';
    SELECT pk_post INTO pk_post_09 FROM tb_post WHERE title = 'Performance Benchmarks: 1 M Rows';
    SELECT pk_post INTO pk_post_10 FROM tb_post WHERE title = 'Contributing to FraiseQL';

    SELECT pk_tag INTO pk_graphql  FROM tb_tag WHERE slug = 'graphql';
    SELECT pk_tag INTO pk_pg       FROM tb_tag WHERE slug = 'postgresql';
    SELECT pk_tag INTO pk_fraiseql FROM tb_tag WHERE slug = 'fraiseql';
    SELECT pk_tag INTO pk_perf     FROM tb_tag WHERE slug = 'performance';
    SELECT pk_tag INTO pk_tut      FROM tb_tag WHERE slug = 'tutorial';
    SELECT pk_tag INTO pk_arch     FROM tb_tag WHERE slug = 'architecture';
    SELECT pk_tag INTO pk_sec      FROM tb_tag WHERE slug = 'security';
    SELECT pk_tag INTO pk_oss      FROM tb_tag WHERE slug = 'open-source';

    INSERT INTO tb_post_tag (fk_post, fk_tag) VALUES
        (pk_post_01, pk_graphql),  (pk_post_01, pk_fraiseql), (pk_post_01, pk_tut),
        (pk_post_02, pk_fraiseql), (pk_post_02, pk_arch),
        (pk_post_03, pk_graphql),  (pk_post_03, pk_fraiseql), (pk_post_03, pk_tut),
        (pk_post_04, pk_graphql),  (pk_post_04, pk_pg),       (pk_post_04, pk_perf),
        (pk_post_05, pk_fraiseql), (pk_post_05, pk_perf),     (pk_post_05, pk_arch),
        (pk_post_06, pk_pg),       (pk_post_06, pk_arch),     (pk_post_06, pk_sec),
        (pk_post_07, pk_graphql),  (pk_post_07, pk_fraiseql), (pk_post_07, pk_tut),
        (pk_post_08, pk_fraiseql), (pk_post_08, pk_sec),
        (pk_post_09, pk_fraiseql), (pk_post_09, pk_perf),     (pk_post_09, pk_pg),
        (pk_post_10, pk_fraiseql), (pk_post_10, pk_oss)
    ON CONFLICT DO NOTHING;
END $$;

-- -----------------------------------------------------------------------------
-- Comments (25) — spread across posts, authored by all five users
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    pk_alice BIGINT; pk_bob  BIGINT; pk_carol BIGINT;
    pk_dave  BIGINT; pk_eve  BIGINT;

    pk_post_01 BIGINT; pk_post_02 BIGINT; pk_post_03 BIGINT;
    pk_post_04 BIGINT; pk_post_05 BIGINT; pk_post_06 BIGINT;
    pk_post_07 BIGINT; pk_post_08 BIGINT; pk_post_09 BIGINT;
    pk_post_10 BIGINT;
BEGIN
    SELECT pk_user INTO pk_alice FROM tb_user WHERE email = 'alice@example.com';
    SELECT pk_user INTO pk_bob   FROM tb_user WHERE email = 'bob@example.com';
    SELECT pk_user INTO pk_carol FROM tb_user WHERE email = 'carol@example.com';
    SELECT pk_user INTO pk_dave  FROM tb_user WHERE email = 'dave@example.com';
    SELECT pk_user INTO pk_eve   FROM tb_user WHERE email = 'eve@example.com';

    SELECT pk_post INTO pk_post_01 FROM tb_post WHERE title = 'Getting Started with FraiseQL';
    SELECT pk_post INTO pk_post_02 FROM tb_post WHERE title = 'Understanding the tb_/v_ Convention';
    SELECT pk_post INTO pk_post_03 FROM tb_post WHERE title = 'Writing Your First Mutation Function';
    SELECT pk_post INTO pk_post_04 FROM tb_post WHERE title = 'Pagination Without Headaches';
    SELECT pk_post INTO pk_post_05 FROM tb_post WHERE title = 'FraiseQL vs Traditional ORMs';
    SELECT pk_post INTO pk_post_06 FROM tb_post WHERE title = 'Designing a Multi-Tenant Schema';
    SELECT pk_post INTO pk_post_07 FROM tb_post WHERE title = 'GraphQL Subscriptions Over NATS';
    SELECT pk_post INTO pk_post_08 FROM tb_post WHERE title = 'Securing Your FraiseQL API';
    SELECT pk_post INTO pk_post_09 FROM tb_post WHERE title = 'Performance Benchmarks: 1 M Rows';
    SELECT pk_post INTO pk_post_10 FROM tb_post WHERE title = 'Contributing to FraiseQL';

    INSERT INTO tb_comment (fk_post, fk_user, body) VALUES
        -- Post 01: Getting Started
        (pk_post_01, pk_dave,  'This is exactly the intro I needed. Got my first API running in under ten minutes.'),
        (pk_post_01, pk_eve,   'The two-command setup is genuinely impressive. Works perfectly on macOS too.'),
        (pk_post_01, pk_alice, 'Glad to hear it! Let us know if anything is unclear in the docs.'),

        -- Post 02: tb_/v_ Convention
        (pk_post_02, pk_dave,  'The separation between tables and views clicked for me after reading this. Really clean design.'),
        (pk_post_02, pk_carol, 'Exactly right — and it means your SQL views become the single source of truth for the API contract.'),

        -- Post 03: Mutation Functions
        (pk_post_03, pk_eve,   'Using plain SQL functions for mutations is refreshing. No hidden magic.'),
        (pk_post_03, pk_dave,  'Does this pattern support transactions spanning multiple tables? Would love a follow-up post.'),
        (pk_post_03, pk_bob,   'Yes — just wrap multiple inserts in a single function body. A transaction is implicit.'),

        -- Post 04: Pagination
        (pk_post_04, pk_alice, 'Keyset pagination is so much better than OFFSET for large datasets. Good to see it covered here.'),
        (pk_post_04, pk_eve,   'Would love a worked example with a compound sort key — e.g. (created_at, id).'),

        -- Post 05: FraiseQL vs ORMs
        (pk_post_05, pk_dave,  'The benchmark numbers are striking. 3x throughput over Prisma on deep relation queries.'),
        (pk_post_05, pk_alice, 'Worth noting the numbers are on a tuned Postgres instance with proper indexes. YMMV on a cold box.'),

        -- Post 06: Multi-Tenancy
        (pk_post_06, pk_eve,   'RLS in Postgres is underused. Good to see FraiseQL treating it as a first-class citizen.'),
        (pk_post_06, pk_dave,  'Schema-per-tenant has migration headaches at scale. Any advice on tooling for that?'),
        (pk_post_06, pk_carol, 'We use a custom migration runner that loops over tenant schemas. Happy to write that up separately.'),

        -- Post 07: Subscriptions over NATS
        (pk_post_07, pk_alice, 'The NATS integration is one of my favourite parts of FraiseQL. Zero-config fan-out is magic.'),
        (pk_post_07, pk_dave,  'Does this work with JetStream for durable message delivery?'),
        (pk_post_07, pk_bob,   'JetStream support landed in v0.9. Check the NATS feature docs for the config options.'),

        -- Post 08: Security
        (pk_post_08, pk_eve,   'The JWT validation section saved me hours. I was about to roll my own middleware.'),
        (pk_post_08, pk_dave,  'Rate limiting by field resolver granularity is a feature I have not seen in any other GraphQL server.'),

        -- Post 09: Performance Benchmarks
        (pk_post_09, pk_alice, 'Apache Arrow for the data plane is a bold choice. The memory reduction numbers are impressive.'),
        (pk_post_09, pk_carol, 'Would be interesting to see the same benchmark with connection pooling via PgBouncer.'),
        (pk_post_09, pk_dave,  'These numbers make a compelling case for moving our internal API off REST.'),

        -- Post 10: Contributing
        (pk_post_10, pk_eve,   'The contributor guide is thorough. Opened my first PR yesterday and it was merged the same day!'),
        (pk_post_10, pk_dave,  'Good to know the maintainers are responsive. I have a bug fix I have been sitting on.');
END $$;
