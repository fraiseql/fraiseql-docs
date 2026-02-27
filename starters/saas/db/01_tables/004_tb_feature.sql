CREATE TABLE IF NOT EXISTS tb_feature (
    pk_feature BIGINT   GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id         UUID     DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    fk_tenant  BIGINT   NOT NULL
                        REFERENCES tb_tenant (pk_tenant)
                        ON DELETE CASCADE,
    name       TEXT     NOT NULL,
    enabled    BOOLEAN  DEFAULT true,
    UNIQUE (fk_tenant, name)
);
