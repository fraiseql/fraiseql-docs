CREATE OR REPLACE VIEW v_tag AS
SELECT
    t.id,
    jsonb_build_object(
        'id',   t.id::text,
        'name', t.name,
        'slug', t.slug
    ) AS data
FROM tb_tag t;
