CREATE OR REPLACE FUNCTION fn_invite_user(
    p_tenant_id UUID,
    p_name      TEXT,
    p_email     TEXT,
    p_role      TEXT DEFAULT 'member'
)
RETURNS mutation_response
LANGUAGE plpgsql
AS $$
DECLARE
    v_pk_tenant BIGINT;
    v_user_id   UUID;
BEGIN
    SELECT pk_tenant
    INTO   v_pk_tenant
    FROM   tb_tenant
    WHERE  id = p_tenant_id;

    IF v_pk_tenant IS NULL THEN
        RETURN ROW(
            'failed:not_found',
            format('Tenant with id %s not found', p_tenant_id),
            NULL, 'TenantUser', NULL, NULL::TEXT[], NULL::JSONB, NULL::JSONB
        )::mutation_response;
    END IF;

    INSERT INTO tb_tenant_user (fk_tenant, name, email, role)
    VALUES (v_pk_tenant, p_name, p_email, p_role)
    RETURNING id INTO v_user_id;

    RETURN ROW(
        'created',
        'User invited',
        v_user_id::TEXT,
        'TenantUser',
        NULL::JSONB,
        NULL::TEXT[],
        NULL::JSONB,
        NULL::JSONB
    )::mutation_response;
END;
$$;
