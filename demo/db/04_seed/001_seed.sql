-- =============================================================================
-- Demo seed data for FraiseQL interactive playground
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Users
-- -----------------------------------------------------------------------------
INSERT INTO tb_user (name, email, role) VALUES
    ('Alice Martin',   'alice@example.com',  'admin'),
    ('Bob Nguyen',     'bob@example.com',    'author'),
    ('Carol Schmidt',  'carol@example.com',  'author'),
    ('Dave Okafor',    'dave@example.com',   'reader'),
    ('Eve Johansson',  'eve@example.com',    'reader');

-- -----------------------------------------------------------------------------
-- Tags
-- -----------------------------------------------------------------------------
INSERT INTO tb_tag (name, slug) VALUES
    ('GraphQL',     'graphql'),
    ('PostgreSQL',  'postgresql'),
    ('Rust',        'rust'),
    ('Performance', 'performance'),
    ('Tutorial',    'tutorial'),
    ('API',         'api'),
    ('Database',    'database'),
    ('Real-time',   'real-time');

-- -----------------------------------------------------------------------------
-- Posts  (12 published posts, distributed between authors Bob and Carol)
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    pk_bob   BIGINT;
    pk_carol BIGINT;
    pk_alice BIGINT;
BEGIN
    SELECT pk_user INTO pk_bob   FROM tb_user WHERE email = 'bob@example.com';
    SELECT pk_user INTO pk_carol FROM tb_user WHERE email = 'carol@example.com';
    SELECT pk_user INTO pk_alice FROM tb_user WHERE email = 'alice@example.com';

    INSERT INTO tb_post (fk_user, title, content, published) VALUES
        -- Bob's posts
        (pk_bob,   'Getting Started with FraiseQL',
         'FraiseQL turns your PostgreSQL schema into a fully-typed GraphQL API with zero boilerplate. In this post we walk through installing the CLI, writing your first view, and running your first query. By the end you will have a live endpoint ready to connect to any frontend.',
         true),

        (pk_bob,   'Why JSONB Views Beat ORM Magic',
         'Traditional ORMs resolve relationships by firing N+1 queries behind the scenes. FraiseQL instead composes data at the database layer using JSONB views, so a single SQL query returns a fully nested document. This article explains the pattern and benchmarks it against Prisma and TypeORM.',
         true),

        (pk_bob,   'Persisted Queries in Production',
         'Persisted queries reduce bandwidth and eliminate arbitrary query execution from untrusted clients. FraiseQL supports APQ out of the box: hash your query on the client, register it once, and send only the hash on every subsequent request. Here is how to wire it up end-to-end.',
         true),

        (pk_bob,   'Cursor-based Pagination with FraiseQL',
         'Offset pagination breaks under concurrent inserts and deletions. Cursor-based pagination solves this by anchoring to a stable row identifier. We show how FraiseQL exposes Relay-compatible connection types directly from a PostgreSQL view with no extra code.',
         true),

        (pk_bob,   'Real-time Subscriptions over NATS',
         'FraiseQL integrates with NATS JetStream to push GraphQL subscription events to connected clients. When a database trigger publishes a message to a subject, FraiseQL fans it out to every subscriber watching that query. This post covers the full setup from NATS configuration to browser client.',
         true),

        (pk_bob,   'Federation: Stitching Microservices into One Graph',
         'FraiseQL implements the Apollo Federation subgraph spec, so you can compose multiple independent services into a single supergraph. We federate a product catalogue subgraph with an orders subgraph and show how the gateway merges them transparently for clients.',
         true),

        -- Carol's posts
        (pk_carol, 'Designing a Bulletproof PostgreSQL Schema',
         'A great GraphQL API starts with a well-designed relational schema. This guide covers naming conventions, surrogate UUID keys, check constraints, and partial indexes — all through the lens of a FraiseQL project where the schema is the source of truth.',
         true),

        (pk_carol, 'Row-level Security and Multi-tenancy',
         'PostgreSQL row-level security policies let you enforce tenant isolation at the database layer, so no application bug can ever leak cross-tenant data. FraiseQL forwards the JWT claims as session variables, which RLS policies can then reference. Walk through the full setup here.',
         true),

        (pk_carol, 'Custom Scalars: Dates, Money, and More',
         'GraphQL scalars extend the type system beyond String, Int, and Boolean. FraiseQL ships built-in scalars for DateTime, UUID, and JSON, and makes it trivial to register your own. We implement a Money scalar that serialises to a decimal string and validates on input.',
         true),

        (pk_carol, 'Benchmarking GraphQL Servers: FraiseQL vs Apollo',
         'We ran a suite of latency and throughput benchmarks comparing FraiseQL, Apollo Server, and Hasura under identical workloads. The results reveal how pushing aggregation into PostgreSQL dramatically reduces round-trips and cuts p99 latency by 60 percent.',
         true),

        (pk_carol, 'Encrypting Sensitive Columns with pgcrypto',
         'Some fields — social security numbers, payment tokens, personal health data — must never be stored in plaintext. PostgreSQL pgcrypto provides symmetric and asymmetric encryption functions that FraiseQL can call transparently through computed columns. This tutorial walks through the full implementation.',
         true),

        -- Alice's post (admin perspective)
        (pk_alice, 'Observability: Tracing Every GraphQL Request',
         'FraiseQL emits OpenTelemetry spans for every resolver, database query, and network hop. By connecting a Jaeger or Tempo backend you can visualise exactly where latency hides in complex nested queries. We share our production tracing setup and the dashboards we use daily.',
         true);
END $$;

-- -----------------------------------------------------------------------------
-- Comments  (30 comments distributed across posts)
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    pk_alice BIGINT;
    pk_bob   BIGINT;
    pk_carol BIGINT;
    pk_dave  BIGINT;
    pk_eve   BIGINT;

    -- post PKs indexed by title prefix for readability
    post_1  BIGINT;
    post_2  BIGINT;
    post_3  BIGINT;
    post_4  BIGINT;
    post_5  BIGINT;
    post_6  BIGINT;
    post_7  BIGINT;
    post_8  BIGINT;
    post_9  BIGINT;
    post_10 BIGINT;
    post_11 BIGINT;
    post_12 BIGINT;
BEGIN
    SELECT pk_user INTO pk_alice FROM tb_user WHERE email = 'alice@example.com';
    SELECT pk_user INTO pk_bob   FROM tb_user WHERE email = 'bob@example.com';
    SELECT pk_user INTO pk_carol FROM tb_user WHERE email = 'carol@example.com';
    SELECT pk_user INTO pk_dave  FROM tb_user WHERE email = 'dave@example.com';
    SELECT pk_user INTO pk_eve   FROM tb_user WHERE email = 'eve@example.com';

    SELECT pk_post INTO post_1  FROM tb_post WHERE title = 'Getting Started with FraiseQL';
    SELECT pk_post INTO post_2  FROM tb_post WHERE title = 'Why JSONB Views Beat ORM Magic';
    SELECT pk_post INTO post_3  FROM tb_post WHERE title = 'Persisted Queries in Production';
    SELECT pk_post INTO post_4  FROM tb_post WHERE title = 'Cursor-based Pagination with FraiseQL';
    SELECT pk_post INTO post_5  FROM tb_post WHERE title = 'Real-time Subscriptions over NATS';
    SELECT pk_post INTO post_6  FROM tb_post WHERE title = 'Federation: Stitching Microservices into One Graph';
    SELECT pk_post INTO post_7  FROM tb_post WHERE title = 'Designing a Bulletproof PostgreSQL Schema';
    SELECT pk_post INTO post_8  FROM tb_post WHERE title = 'Row-level Security and Multi-tenancy';
    SELECT pk_post INTO post_9  FROM tb_post WHERE title = 'Custom Scalars: Dates, Money, and More';
    SELECT pk_post INTO post_10 FROM tb_post WHERE title = 'Benchmarking GraphQL Servers: FraiseQL vs Apollo';
    SELECT pk_post INTO post_11 FROM tb_post WHERE title = 'Encrypting Sensitive Columns with pgcrypto';
    SELECT pk_post INTO post_12 FROM tb_post WHERE title = 'Observability: Tracing Every GraphQL Request';

    INSERT INTO tb_comment (fk_post, fk_user, body) VALUES
        -- post 1: Getting Started
        (post_1,  pk_dave,  'This is exactly the guide I needed. Got my first endpoint running in under ten minutes.'),
        (post_1,  pk_eve,   'The CLI install was painless. Any plans to add a web-based schema editor?'),
        (post_1,  pk_carol, 'Great intro Bob. I would add a note about running migrations before starting the server.'),

        -- post 2: JSONB Views
        (post_2,  pk_alice, 'The N+1 elimination is what sold me on this approach. Our API response times dropped immediately.'),
        (post_2,  pk_dave,  'Do the nested JSONB aggregations add meaningful overhead compared to separate queries?'),
        (post_2,  pk_bob,   'Good question Dave — the overhead is negligible because PostgreSQL can push the aggregation to the storage layer.'),

        -- post 3: Persisted Queries
        (post_3,  pk_eve,   'We use APQ in production and the bandwidth savings on mobile are very noticeable.'),
        (post_3,  pk_dave,  'Does this work with subscriptions as well, or only queries and mutations?'),

        -- post 4: Pagination
        (post_4,  pk_alice, 'Relay cursors are a must for any serious production app. Glad this is a first-class feature.'),
        (post_4,  pk_carol, 'How does the cursor encode position — is it the row UUID or a composite key?'),
        (post_4,  pk_eve,   'Switching from offset to cursor pagination fixed a duplicate-item bug we had been chasing for weeks.'),

        -- post 5: NATS subscriptions
        (post_5,  pk_dave,  'We have been looking at NATS for our event pipeline. The FraiseQL integration makes this much simpler.'),
        (post_5,  pk_alice, 'Excellent write-up. Worth mentioning JetStream persistence for durable subscribers.'),
        (post_5,  pk_eve,   'Real-time felt complex before reading this. The subject routing is elegant.'),

        -- post 6: Federation
        (post_6,  pk_carol, 'We federate six subgraphs at work and the DX is fantastic once everything is set up.'),
        (post_6,  pk_dave,  'Does FraiseQL support the @key directive on multiple fields for composite entity keys?'),

        -- post 7: Schema design
        (post_7,  pk_bob,   'The surrogate UUID pattern is something every team should adopt from day one. Great reference.'),
        (post_7,  pk_eve,   'I especially liked the section on partial indexes. Those are easy to overlook.'),
        (post_7,  pk_dave,  'Would be useful to see an ERD diagram alongside the DDL examples.'),

        -- post 8: RLS
        (post_8,  pk_bob,   'Row-level security was the missing piece for our SaaS product. This post saved us days of research.'),
        (post_8,  pk_eve,   'The JWT session variable approach is clever. Does it survive connection pooling with PgBouncer?'),
        (post_8,  pk_alice, 'We set connection pooler mode to session (not transaction) to preserve SET LOCAL calls.'),

        -- post 9: Custom scalars
        (post_9,  pk_dave,  'The Money scalar example is practical and easy to adapt for other domains.'),
        (post_9,  pk_bob,   'We use a similar pattern for phone numbers — validating E.164 format in the scalar coercion.'),

        -- post 10: Benchmarks
        (post_10, pk_alice, 'The 60 percent p99 improvement matches what we saw in our own load tests.'),
        (post_10, pk_dave,  'Were the benchmark workloads read-heavy, write-heavy, or mixed?'),
        (post_10, pk_eve,   'Would love to see a follow-up with Strawberry and Graphene in the mix.'),

        -- post 11: Encryption
        (post_11, pk_bob,   'We handle medical records and this post covers exactly what our compliance team requires.'),
        (post_11, pk_dave,  'Is there a performance cost to decrypting on every read, or can results be cached?'),
        (post_11, pk_carol, 'FraiseQL response caching can hold the decrypted payload — just scope the cache key to the user.'),

        -- post 12: Observability
        (post_12, pk_carol, 'OpenTelemetry support was the last blocker for us adopting FraiseQL in production. Shipped!'),
        (post_12, pk_dave,  'Which Grafana dashboard template do you use for the span data?'),
        (post_12, pk_eve,   'The resolver-level spans are incredibly useful for pinpointing slow nested fields.');
END $$;

-- -----------------------------------------------------------------------------
-- Post-tag associations  (2–4 tags per post)
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    -- post PKs
    post_1  BIGINT;
    post_2  BIGINT;
    post_3  BIGINT;
    post_4  BIGINT;
    post_5  BIGINT;
    post_6  BIGINT;
    post_7  BIGINT;
    post_8  BIGINT;
    post_9  BIGINT;
    post_10 BIGINT;
    post_11 BIGINT;
    post_12 BIGINT;

    -- tag PKs
    tag_graphql     BIGINT;
    tag_postgresql  BIGINT;
    tag_rust        BIGINT;
    tag_performance BIGINT;
    tag_tutorial    BIGINT;
    tag_api         BIGINT;
    tag_database    BIGINT;
    tag_realtime    BIGINT;
BEGIN
    SELECT pk_post INTO post_1  FROM tb_post WHERE title = 'Getting Started with FraiseQL';
    SELECT pk_post INTO post_2  FROM tb_post WHERE title = 'Why JSONB Views Beat ORM Magic';
    SELECT pk_post INTO post_3  FROM tb_post WHERE title = 'Persisted Queries in Production';
    SELECT pk_post INTO post_4  FROM tb_post WHERE title = 'Cursor-based Pagination with FraiseQL';
    SELECT pk_post INTO post_5  FROM tb_post WHERE title = 'Real-time Subscriptions over NATS';
    SELECT pk_post INTO post_6  FROM tb_post WHERE title = 'Federation: Stitching Microservices into One Graph';
    SELECT pk_post INTO post_7  FROM tb_post WHERE title = 'Designing a Bulletproof PostgreSQL Schema';
    SELECT pk_post INTO post_8  FROM tb_post WHERE title = 'Row-level Security and Multi-tenancy';
    SELECT pk_post INTO post_9  FROM tb_post WHERE title = 'Custom Scalars: Dates, Money, and More';
    SELECT pk_post INTO post_10 FROM tb_post WHERE title = 'Benchmarking GraphQL Servers: FraiseQL vs Apollo';
    SELECT pk_post INTO post_11 FROM tb_post WHERE title = 'Encrypting Sensitive Columns with pgcrypto';
    SELECT pk_post INTO post_12 FROM tb_post WHERE title = 'Observability: Tracing Every GraphQL Request';

    SELECT pk_tag INTO tag_graphql     FROM tb_tag WHERE slug = 'graphql';
    SELECT pk_tag INTO tag_postgresql  FROM tb_tag WHERE slug = 'postgresql';
    SELECT pk_tag INTO tag_rust        FROM tb_tag WHERE slug = 'rust';
    SELECT pk_tag INTO tag_performance FROM tb_tag WHERE slug = 'performance';
    SELECT pk_tag INTO tag_tutorial    FROM tb_tag WHERE slug = 'tutorial';
    SELECT pk_tag INTO tag_api         FROM tb_tag WHERE slug = 'api';
    SELECT pk_tag INTO tag_database    FROM tb_tag WHERE slug = 'database';
    SELECT pk_tag INTO tag_realtime    FROM tb_tag WHERE slug = 'real-time';

    INSERT INTO tb_post_tag (fk_post, fk_tag) VALUES
        -- Getting Started with FraiseQL
        (post_1,  tag_graphql),
        (post_1,  tag_tutorial),
        (post_1,  tag_api),

        -- Why JSONB Views Beat ORM Magic
        (post_2,  tag_postgresql),
        (post_2,  tag_database),
        (post_2,  tag_performance),

        -- Persisted Queries in Production
        (post_3,  tag_graphql),
        (post_3,  tag_performance),
        (post_3,  tag_api),

        -- Cursor-based Pagination
        (post_4,  tag_graphql),
        (post_4,  tag_api),
        (post_4,  tag_database),

        -- Real-time Subscriptions over NATS
        (post_5,  tag_graphql),
        (post_5,  tag_realtime),
        (post_5,  tag_api),

        -- Federation
        (post_6,  tag_graphql),
        (post_6,  tag_api),
        (post_6,  tag_performance),

        -- Designing a Bulletproof PostgreSQL Schema
        (post_7,  tag_postgresql),
        (post_7,  tag_database),
        (post_7,  tag_tutorial),

        -- Row-level Security
        (post_8,  tag_postgresql),
        (post_8,  tag_database),
        (post_8,  tag_api),

        -- Custom Scalars
        (post_9,  tag_graphql),
        (post_9,  tag_api),
        (post_9,  tag_tutorial),

        -- Benchmarking
        (post_10, tag_graphql),
        (post_10, tag_performance),
        (post_10, tag_database),
        (post_10, tag_rust),

        -- Encrypting Sensitive Columns
        (post_11, tag_postgresql),
        (post_11, tag_database),
        (post_11, tag_tutorial),

        -- Observability
        (post_12, tag_graphql),
        (post_12, tag_performance),
        (post_12, tag_api),
        (post_12, tag_rust);
END $$;
