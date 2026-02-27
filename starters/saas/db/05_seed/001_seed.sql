-- Seed two demo tenants with users, features, and subscriptions.
-- DO $$ blocks resolve PKs by slug to avoid hard-coding identity column values.

-- ─── Tenants ─────────────────────────────────────────────────────────────────

INSERT INTO tb_tenant (name, slug, plan)
VALUES
    ('Acme Corp', 'acme',   'pro'),
    ('BetaCo',    'betaco', 'free')
ON CONFLICT (slug) DO NOTHING;

-- ─── Users ───────────────────────────────────────────────────────────────────

DO $$
DECLARE
    v_pk_acme   BIGINT;
    v_pk_betaco BIGINT;
BEGIN
    SELECT pk_tenant INTO v_pk_acme   FROM tb_tenant WHERE slug = 'acme';
    SELECT pk_tenant INTO v_pk_betaco FROM tb_tenant WHERE slug = 'betaco';

    -- Acme Corp: one admin, two members
    INSERT INTO tb_tenant_user (fk_tenant, name, email, role)
    VALUES
        (v_pk_acme, 'Alice Nakamura', 'alice@acme.example',  'admin'),
        (v_pk_acme, 'Bob Okafor',     'bob@acme.example',    'member'),
        (v_pk_acme, 'Carol Silva',    'carol@acme.example',  'member')
    ON CONFLICT (fk_tenant, email) DO NOTHING;

    -- BetaCo: one admin, one member
    INSERT INTO tb_tenant_user (fk_tenant, name, email, role)
    VALUES
        (v_pk_betaco, 'Dana Reyes',  'dana@betaco.example',  'admin'),
        (v_pk_betaco, 'Evan Torres', 'evan@betaco.example',  'member')
    ON CONFLICT (fk_tenant, email) DO NOTHING;
END;
$$;

-- ─── Features ────────────────────────────────────────────────────────────────

DO $$
DECLARE
    v_pk_acme   BIGINT;
    v_pk_betaco BIGINT;
BEGIN
    SELECT pk_tenant INTO v_pk_acme   FROM tb_tenant WHERE slug = 'acme';
    SELECT pk_tenant INTO v_pk_betaco FROM tb_tenant WHERE slug = 'betaco';

    -- Acme Corp: pro plan — analytics, api_access, and sso enabled
    INSERT INTO tb_feature (fk_tenant, name, enabled)
    VALUES
        (v_pk_acme, 'analytics',  true),
        (v_pk_acme, 'api_access', true),
        (v_pk_acme, 'sso',        true)
    ON CONFLICT (fk_tenant, name) DO NOTHING;

    -- BetaCo: free plan — analytics only
    INSERT INTO tb_feature (fk_tenant, name, enabled)
    VALUES
        (v_pk_betaco, 'analytics', true)
    ON CONFLICT (fk_tenant, name) DO NOTHING;
END;
$$;

-- ─── Subscriptions ───────────────────────────────────────────────────────────

DO $$
DECLARE
    v_pk_acme   BIGINT;
    v_pk_betaco BIGINT;
BEGIN
    SELECT pk_tenant INTO v_pk_acme   FROM tb_tenant WHERE slug = 'acme';
    SELECT pk_tenant INTO v_pk_betaco FROM tb_tenant WHERE slug = 'betaco';

    INSERT INTO tb_subscription (fk_tenant, plan, status, current_period_end)
    VALUES
        (v_pk_acme,   'pro',  'active', NOW() + INTERVAL '30 days'),
        (v_pk_betaco, 'free', 'active', NOW() + INTERVAL '30 days')
    ON CONFLICT DO NOTHING;
END;
$$;
