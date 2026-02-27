CREATE TABLE tb_user (
    pk_user   BIGINT      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id        UUID        NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    name      TEXT        NOT NULL,
    email     TEXT        NOT NULL UNIQUE,
    role      TEXT        NOT NULL DEFAULT 'reader'
                          CHECK (role IN ('reader', 'author', 'admin')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
