CREATE TABLE IF NOT EXISTS tb_tenant (
    pk_tenant  BIGINT      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id         UUID        DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    name       TEXT        NOT NULL,
    slug       TEXT        NOT NULL UNIQUE,
    plan       TEXT        NOT NULL DEFAULT 'free'
                           CHECK (plan IN ('free', 'pro', 'enterprise')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);
