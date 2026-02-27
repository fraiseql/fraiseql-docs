CREATE OR REPLACE VIEW v_comment AS
SELECT
    c.id,
    jsonb_build_object(
        'id',         c.id::text,
        'body',       c.body,
        'created_at', c.created_at,
        'author',     jsonb_build_object(
                          'id',    u.id::text,
                          'name',  u.name,
                          'email', u.email,
                          'role',  u.role
                      )
    ) AS data
FROM tb_comment c
JOIN tb_user    u ON u.pk_user = c.fk_user;
