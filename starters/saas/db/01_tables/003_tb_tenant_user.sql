CREATE TABLE IF NOT EXISTS tb_tenant_user (
    pk_tenant_user BIGINT      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id             UUID        DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    fk_tenant      BIGINT      NOT NULL
                               REFERENCES tb_tenant (pk_tenant)
                               ON DELETE CASCADE,
    name           TEXT        NOT NULL,
    email          TEXT        NOT NULL,
    role           TEXT        NOT NULL DEFAULT 'member'
                               CHECK (role IN ('admin', 'member', 'viewer')),
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (fk_tenant, email)
);
