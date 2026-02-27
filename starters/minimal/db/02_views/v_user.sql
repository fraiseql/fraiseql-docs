CREATE VIEW IF NOT EXISTS v_user AS
SELECT
    u.id,
    json_object(
        'id',         u.id,
        'name',       u.name,
        'email',      u.email,
        'created_at', u.created_at
    ) AS data
FROM tb_user u;
