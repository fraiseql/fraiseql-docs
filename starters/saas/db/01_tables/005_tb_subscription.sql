CREATE TABLE IF NOT EXISTS tb_subscription (
    pk_subscription    BIGINT      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id                 UUID        DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    fk_tenant          BIGINT      NOT NULL
                                   REFERENCES tb_tenant (pk_tenant)
                                   ON DELETE CASCADE,
    plan               TEXT        NOT NULL,
    status             TEXT        NOT NULL DEFAULT 'active'
                                   CHECK (status IN ('active', 'cancelled', 'past_due')),
    current_period_end TIMESTAMPTZ NOT NULL,
    created_at         TIMESTAMPTZ DEFAULT NOW()
);
