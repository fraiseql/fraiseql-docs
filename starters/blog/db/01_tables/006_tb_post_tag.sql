CREATE TABLE IF NOT EXISTS tb_post_tag (
    fk_post BIGINT NOT NULL REFERENCES tb_post(pk_post) ON DELETE CASCADE,
    fk_tag  BIGINT NOT NULL REFERENCES tb_tag(pk_tag)  ON DELETE CASCADE,
    PRIMARY KEY (fk_post, fk_tag)
);
