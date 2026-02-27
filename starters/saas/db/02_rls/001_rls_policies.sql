-- Helper function: resolves the current tenant's integer PK from the
-- app.tenant_id session variable (a UUID set by the JWT middleware).
-- Returns NULL when the setting is absent so RLS blocks all rows safely.
CREATE OR REPLACE FUNCTION get_current_tenant_pk()
RETURNS BIGINT
LANGUAGE sql
STABLE
AS $$
    SELECT pk_tenant
    FROM   tb_tenant
    WHERE  id = current_setting('app.tenant_id', true)::uuid
$$;

-- ─── tb_tenant_user ──────────────────────────────────────────────────────────

ALTER TABLE tb_tenant_user ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tb_tenant_user
    USING (fk_tenant = get_current_tenant_pk());

-- ─── tb_feature ──────────────────────────────────────────────────────────────

ALTER TABLE tb_feature ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tb_feature
    USING (fk_tenant = get_current_tenant_pk());

-- ─── tb_subscription ─────────────────────────────────────────────────────────

ALTER TABLE tb_subscription ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tb_subscription
    USING (fk_tenant = get_current_tenant_pk());
