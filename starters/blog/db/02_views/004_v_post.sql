CREATE OR REPLACE VIEW v_post AS
SELECT
    p.id,
    jsonb_build_object(
        'id',         p.id::text,
        'title',      p.title,
        'content',    p.content,
        'published',  p.published,
        'created_at', p.created_at,
        'author',     jsonb_build_object(
                          'id',    u.id::text,
                          'name',  u.name,
                          'email', u.email,
                          'role',  u.role
                      ),
        'comments',   COALESCE(
                          (
                              SELECT jsonb_agg(
                                  jsonb_build_object(
                                      'id',         c.id::text,
                                      'body',       c.body,
                                      'created_at', c.created_at,
                                      'author',     jsonb_build_object(
                                                        'id',    cu.id::text,
                                                        'name',  cu.name,
                                                        'email', cu.email,
                                                        'role',  cu.role
                                                    )
                                  )
                                  ORDER BY c.created_at
                              )
                              FROM tb_comment c
                              JOIN tb_user    cu ON cu.pk_user = c.fk_user
                              WHERE c.fk_post = p.pk_post
                          ),
                          '[]'::jsonb
                      ),
        'tags',       COALESCE(
                          (
                              SELECT jsonb_agg(
                                  jsonb_build_object(
                                      'id',   t.id::text,
                                      'name', t.name,
                                      'slug', t.slug
                                  )
                                  ORDER BY t.name
                              )
                              FROM tb_post_tag pt
                              JOIN tb_tag      t  ON t.pk_tag = pt.fk_tag
                              WHERE pt.fk_post = p.pk_post
                          ),
                          '[]'::jsonb
                      )
    ) AS data
FROM tb_post p
JOIN tb_user u ON u.pk_user = p.fk_user
WHERE p.published = true;
