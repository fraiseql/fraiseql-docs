-- RLS on tb_subscription enforces tenant isolation automatically.
CREATE OR REPLACE VIEW v_subscription AS
SELECT
    s.id,
    jsonb_build_object(
        'id',                 s.id::text,
        'plan',               s.plan,
        'status',             s.status,
        'current_period_end', s.current_period_end
    ) AS data
FROM tb_subscription s;
