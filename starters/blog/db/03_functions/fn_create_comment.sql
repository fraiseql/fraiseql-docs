CREATE OR REPLACE FUNCTION fn_create_comment(
    p_body      TEXT,
    p_post_id   UUID,
    p_author_id UUID
)
RETURNS mutation_response
LANGUAGE plpgsql
AS $$
DECLARE
    v_pk_post    BIGINT;
    v_pk_user    BIGINT;
    v_comment_id UUID;
BEGIN
    -- Resolve post UUID to internal integer PK
    SELECT pk_post
      INTO v_pk_post
      FROM tb_post
     WHERE id = p_post_id;

    IF v_pk_post IS NULL THEN
        RETURN ROW(
            'failed:not_found',
            format('Post with id %s not found', p_post_id),
            NULL, 'Comment', NULL, NULL::TEXT[], NULL::JSONB, NULL::JSONB
        )::mutation_response;
    END IF;

    -- Resolve author UUID to internal integer PK
    SELECT pk_user
      INTO v_pk_user
      FROM tb_user
     WHERE id = p_author_id;

    IF v_pk_user IS NULL THEN
        RETURN ROW(
            'failed:not_found',
            format('User with id %s not found', p_author_id),
            NULL, 'Comment', NULL, NULL::TEXT[], NULL::JSONB, NULL::JSONB
        )::mutation_response;
    END IF;

    -- Insert the new comment and capture the generated UUID
    INSERT INTO tb_comment (fk_post, fk_user, body)
    VALUES (v_pk_post, v_pk_user, p_body)
    RETURNING id INTO v_comment_id;

    RETURN ROW(
        'created',
        'Comment created',
        v_comment_id::TEXT,
        'Comment',
        NULL::JSONB,
        NULL::TEXT[],
        NULL::JSONB,
        NULL::JSONB
    )::mutation_response;
END;
$$;
