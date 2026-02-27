CREATE OR REPLACE VIEW v_post AS
SELECT
    p.id,
    jsonb_build_object(
        'id',         p.id::text,
        'title',      p.title,
        'content',    p.content,
        'published',  p.published,
        'created_at', p.created_at,
        'author',     vu.data,
        'comments',   COALESCE(
                          (
                              SELECT jsonb_agg(vc.data ORDER BY c.pk_comment)
                              FROM   tb_comment c
                              JOIN   v_comment  vc ON vc.id = c.id
                              WHERE  c.fk_post = p.pk_post
                          ),
                          '[]'::jsonb
                      ),
        'tags',       COALESCE(
                          (
                              SELECT jsonb_agg(vt.data)
                              FROM   tb_post_tag pt
                              JOIN   tb_tag      t  ON t.pk_tag  = pt.fk_tag
                              JOIN   v_tag       vt ON vt.id     = t.id
                              WHERE  pt.fk_post = p.pk_post
                          ),
                          '[]'::jsonb
                      )
    ) AS data
FROM  tb_post  p
JOIN  tb_user  u  ON u.pk_user = p.fk_user
JOIN  v_user   vu ON vu.id     = u.id
WHERE p.published = true;
