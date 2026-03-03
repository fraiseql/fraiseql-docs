CREATE OR REPLACE FUNCTION fn_create_post(
    p_title     TEXT,
    p_content   TEXT,
    p_author_id UUID
)
RETURNS mutation_response
LANGUAGE plpgsql
AS $$
DECLARE
    v_pk_user BIGINT;
    v_post_id UUID;
BEGIN
    -- Resolve author UUID to internal integer PK
    SELECT pk_user
      INTO v_pk_user
      FROM tb_user
     WHERE id = p_author_id;

    IF v_pk_user IS NULL THEN
        RETURN ROW(
            'failed:not_found',
            format('User with id %s not found', p_author_id),
            NULL, 'Post', NULL, NULL::TEXT[], NULL::JSONB, NULL::JSONB
        )::mutation_response;
    END IF;

    -- Insert the new post and capture the generated UUID
    INSERT INTO tb_post (fk_user, title, content, published)
    VALUES (v_pk_user, p_title, p_content, true)
    RETURNING id INTO v_post_id;

    RETURN ROW(
        'created',
        'Post created',
        v_post_id::TEXT,
        'Post',
        NULL::JSONB,
        NULL::TEXT[],
        NULL::JSONB,
        NULL::JSONB
    )::mutation_response;
END;
$$;
