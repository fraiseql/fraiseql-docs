CREATE TABLE IF NOT EXISTS tb_comment (
    pk_comment BIGINT      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id         UUID        NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    fk_post    BIGINT      NOT NULL REFERENCES tb_post(pk_post) ON DELETE CASCADE,
    fk_user    BIGINT      NOT NULL REFERENCES tb_user(pk_user) ON DELETE CASCADE,
    body       TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
