CREATE TABLE tb_comment (
    pk_comment BIGINT      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id         UUID        NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    fk_post    BIGINT      NOT NULL REFERENCES tb_post(pk_post) ON DELETE CASCADE,
    fk_user    BIGINT      NOT NULL REFERENCES tb_user(pk_user),
    body       TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tb_comment_fk_post ON tb_comment(fk_post);
CREATE INDEX idx_tb_comment_fk_user ON tb_comment(fk_user);
