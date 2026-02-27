-- v_tenant aggregates users and enabled features as nested JSONB arrays.
-- tb_tenant itself has no RLS; tenants are public records.  The nested
-- subqueries on tb_tenant_user and tb_feature are governed by the RLS
-- policies on those tables, so a caller only sees data they are entitled
-- to regardless of which tenant row they query.
CREATE OR REPLACE VIEW v_tenant AS
SELECT
    t.id,
    jsonb_build_object(
        'id',         t.id::text,
        'name',       t.name,
        'slug',       t.slug,
        'plan',       t.plan,
        'created_at', t.created_at,
        'users',      COALESCE(
                          (
                              SELECT jsonb_agg(vu.data)
                              FROM   tb_tenant_user u
                              JOIN   v_tenant_user  vu ON vu.id = u.id
                              WHERE  u.fk_tenant = t.pk_tenant
                          ),
                          '[]'::jsonb
                      ),
        'features',   COALESCE(
                          (
                              SELECT jsonb_agg(vf.data)
                              FROM   tb_feature f
                              JOIN   v_feature  vf ON vf.id = f.id
                              WHERE  f.fk_tenant = t.pk_tenant
                                AND  f.enabled = true
                          ),
                          '[]'::jsonb
                      )
    ) AS data
FROM tb_tenant t;
