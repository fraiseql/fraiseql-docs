CREATE TABLE tb_post_tag (
    fk_post BIGINT NOT NULL REFERENCES tb_post(pk_post) ON DELETE CASCADE,
    fk_tag  BIGINT NOT NULL REFERENCES tb_tag(pk_tag)   ON DELETE CASCADE,
    PRIMARY KEY (fk_post, fk_tag)
);

CREATE INDEX idx_tb_post_tag_fk_tag ON tb_post_tag(fk_tag);
