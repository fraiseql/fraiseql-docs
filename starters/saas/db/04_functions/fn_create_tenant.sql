CREATE OR REPLACE FUNCTION fn_create_tenant(
    p_name TEXT,
    p_slug TEXT,
    p_plan TEXT DEFAULT 'free'
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO tb_tenant (name, slug, plan)
    VALUES (p_name, p_slug, p_plan)
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;
