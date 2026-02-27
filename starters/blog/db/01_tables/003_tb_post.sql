CREATE TABLE IF NOT EXISTS tb_post (
    pk_post    BIGINT      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id         UUID        NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    fk_user    BIGINT      NOT NULL REFERENCES tb_user(pk_user) ON DELETE CASCADE,
    title      TEXT        NOT NULL,
    content    TEXT        NOT NULL,
    published  BOOLEAN     NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
