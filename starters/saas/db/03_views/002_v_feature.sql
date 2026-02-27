-- RLS on tb_feature enforces tenant isolation automatically.
CREATE OR REPLACE VIEW v_feature AS
SELECT
    f.id,
    jsonb_build_object(
        'id',      f.id::text,
        'name',    f.name,
        'enabled', f.enabled
    ) AS data
FROM tb_feature f;
