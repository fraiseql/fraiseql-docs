CREATE OR REPLACE VIEW v_user AS
SELECT
    u.id,
    jsonb_build_object(
        'id',         u.id::text,
        'name',       u.name,
        'email',      u.email,
        'role',       u.role,
        'created_at', u.created_at
    ) AS data
FROM tb_user u;
