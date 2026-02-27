-- RLS on tb_tenant_user enforces tenant isolation automatically.
-- No WHERE clause is needed here; the policy filters rows before
-- they reach this view.
CREATE OR REPLACE VIEW v_tenant_user AS
SELECT
    u.id,
    jsonb_build_object(
        'id',         u.id::text,
        'name',       u.name,
        'email',      u.email,
        'role',       u.role,
        'created_at', u.created_at
    ) AS data
FROM tb_tenant_user u;
