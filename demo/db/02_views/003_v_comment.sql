CREATE OR REPLACE VIEW v_comment AS
SELECT
    c.id,
    jsonb_build_object(
        'id',         c.id::text,
        'body',       c.body,
        'created_at', c.created_at,
        'author',     vu.data
    ) AS data
FROM tb_comment c
JOIN v_user vu ON vu.id = (
    SELECT id FROM tb_user WHERE pk_user = c.fk_user
);
