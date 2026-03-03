CREATE OR REPLACE FUNCTION fn_create_tenant(
    p_name TEXT,
    p_slug TEXT,
    p_plan TEXT DEFAULT 'free'
)
RETURNS mutation_response
LANGUAGE plpgsql
AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO tb_tenant (name, slug, plan)
    VALUES (p_name, p_slug, p_plan)
    RETURNING id INTO v_id;

    RETURN ROW(
        'created',
        'Tenant created',
        v_id::TEXT,
        'Tenant',
        NULL::JSONB,
        NULL::TEXT[],
        NULL::JSONB,
        NULL::JSONB
    )::mutation_response;
END;
$$;
