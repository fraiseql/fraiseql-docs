---
title: Analytics
description: Aggregations, measures, dimensions, and analytical queries
---

FraiseQL supports analytical queries with aggregations, dimensions, and measures for building dashboards and reports.

## Concepts

### Dimensions

Categorical attributes for grouping:

```python
@fraiseql.dimension
class ProductCategory:
    """Product category for grouping."""
    id: ID
    name: str
    parent: 'ProductCategory | None'
```

Common dimensions:
- Time (day, week, month, year)
- Geography (country, region, city)
- Category (product, customer type)
- Status (order status, user state)

### Measures

Numeric values to aggregate:

```python
@fraiseql.measure
class OrderMetrics:
    """Order-related measures."""
    order_count: int
    total_revenue: Decimal
    avg_order_value: Decimal
    items_sold: int
```

Common measures:
- Counts (orders, users, events)
- Sums (revenue, quantity)
- Averages (order value, response time)
- Percentiles (p50, p95, p99)

## Calendar Dimension Table

### tb_calendar Structure

Master calendar table providing pre-computed temporal dimensions for all fact tables:

```sql
CREATE TABLE tb_calendar (
    id UUID DEFAULT gen_random_uuid() UNIQUE,
    reference_date DATE PRIMARY KEY,

    -- Time period numbers
    week INT,
    week_n_days INT,                    -- Always 7
    half_month INT,                     -- 1 or 2
    half_month_n_days INT,              -- Days in this half
    month INT,
    month_n_days INT,                   -- 28-31
    quarter INT,                        -- 1-4
    quarter_n_days INT,                 -- 90-92
    semester INT,                       -- 1 or 2
    semester_n_days INT,                -- 181-184
    year INT,
    year_n_days INT,                    -- 365 or 366

    -- Pre-computed JSONB for each granularity
    date_info JSONB,
    week_info JSONB,
    half_month_info JSONB,
    month_info JSONB,
    quarter_info JSONB,
    semester_info JSONB,
    year_info JSONB,

    -- Reference dates (first day of each period)
    week_reference_date DATE,           -- Monday of week
    half_month_reference_date DATE,     -- 1st or 16th
    month_reference_date DATE,          -- 1st of month
    quarter_reference_date DATE,        -- 1st of quarter
    semester_reference_date DATE,       -- Jan 1 or Jul 1
    year_reference_date DATE,           -- Jan 1

    -- Boolean flags for reference dates
    is_week_reference_date BOOLEAN,
    is_half_month_reference_date BOOLEAN,
    is_month_reference_date BOOLEAN,
    is_quarter_reference_date BOOLEAN,
    is_semester_reference_date BOOLEAN,
    is_year_reference_date BOOLEAN
);
```

### date_info JSONB Structure

```json
{
    "date": "2024-03-15",
    "week": 11,
    "half_month": 1,
    "month": 3,
    "quarter": 1,
    "semester": 1,
    "year": 2024
}
```

### Seed Data Generation

```sql
INSERT INTO tb_calendar (reference_date, week, month, quarter, semester, year, date_info, ...)
SELECT
    d::DATE AS reference_date,
    EXTRACT(WEEK FROM d)::INT AS week,
    EXTRACT(MONTH FROM d)::INT AS month,
    EXTRACT(QUARTER FROM d)::INT AS quarter,
    CASE WHEN EXTRACT(MONTH FROM d) <= 6 THEN 1 ELSE 2 END AS semester,
    EXTRACT(YEAR FROM d)::INT AS year,
    jsonb_build_object(
        'date', d::text,
        'week', EXTRACT(WEEK FROM d),
        'half_month', CASE WHEN EXTRACT(DAY FROM d) <= 15 THEN 1 ELSE 2 END,
        'month', EXTRACT(MONTH FROM d),
        'quarter', EXTRACT(QUARTER FROM d),
        'semester', CASE WHEN EXTRACT(MONTH FROM d) <= 6 THEN 1 ELSE 2 END,
        'year', EXTRACT(YEAR FROM d)
    ) AS date_info,
    DATE_TRUNC('month', d)::DATE AS month_reference_date,
    (EXTRACT(DAY FROM d) = 1) AS is_month_reference_date
FROM generate_series('2015-01-01'::date, '2035-12-31'::date, '1 day') AS d;
```

## Fact Tables

### tf_ Table Structure

Fact tables use the `tf_` prefix and join to `tb_calendar`:

```sql
CREATE TABLE tf_sales (
    pk_sales BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    -- Measures (direct columns for fast aggregation)
    quantity INT NOT NULL,
    revenue DECIMAL(12,2) NOT NULL,
    cost DECIMAL(12,2) NOT NULL,
    discount DECIMAL(12,2) DEFAULT 0,

    -- Dimension data (JSONB for flexibility)
    data JSONB NOT NULL,

    -- Calendar foreign key (joins to tb_calendar)
    occurred_at DATE NOT NULL,

    -- Denormalized columns for indexed filtering
    customer_id UUID NOT NULL,
    product_id UUID NOT NULL,
    product_category TEXT,
    customer_region TEXT
);

CREATE INDEX idx_tf_sales_occurred ON tf_sales(occurred_at);
CREATE INDEX idx_tf_sales_category ON tf_sales(product_category);
CREATE INDEX idx_tf_sales_data ON tf_sales USING GIN(data);
```

### Query-Side View with Calendar JOIN

```sql
CREATE VIEW v_sales AS
SELECT
    s.pk_sales,
    jsonb_build_object(
        'dimensions', s.data || jsonb_build_object('date_info', cal.date_info),
        'measures', jsonb_build_object(
            'quantity', s.quantity,
            'revenue', s.revenue,
            'cost', s.cost
        )
    ) AS data
FROM tf_sales s
LEFT JOIN tb_calendar cal ON cal.reference_date = s.occurred_at;
```

### Dimension Data (`data` column)

Flexible dimension data stored as JSONB:

```json
{
    "category": "electronics",
    "region": "US",
    "channel": "online",
    "product": {
        "id": "prod-123",
        "name": "Widget Pro",
        "category": "Electronics"
    },
    "customer": {
        "id": "cust-456",
        "name": "Acme Corp",
        "type": "Enterprise"
    }
}
```

### Performance Impact

Using the `tb_calendar` JOIN provides **10-16x faster** temporal aggregations:

| Query | Runtime DATE_TRUNC | Pre-computed calendar | Speedup |
|-------|---------------------|----------------------|---------|
| `GROUP BY month` (1M rows) | 500ms | 30ms | 16x |
| `GROUP BY quarter` (10M rows) | 5000ms | 300ms | 16x |

### Benefits of tb_calendar Approach

- **Single source of truth**: All calendar dimensions in one table
- **Reference dates**: Enable efficient time-series aggregation
- **Boolean flags**: Support "first day of period" filtering
- **`*_n_days` columns**: Enable weighted averages
- **No trigger overhead**: Calendar computed once, not per fact row

## Defining Analytics Types

### Aggregate Type

```python
import fraiseql
from fraiseql.scalars import Decimal, Date

@fraiseql.type
class SalesAggregate:
    """Aggregated sales metrics."""
    period: str           # Day, week, month
    product_category: str
    customer_region: str
    order_count: int
    revenue: Decimal
    avg_order_value: Decimal
    items_sold: int
```

### Analytics Query

```python
@fraiseql.query(sql_source="va_sales_by_period")
def sales_by_period(
    start_date: Date,
    end_date: Date,
    granularity: str = "day",  # day, week, month
    product_category: str | None = None,
    customer_region: str | None = None
) -> list[SalesAggregate]:
    """Query sales aggregates by time period."""
    pass
```

### Supporting View

```sql
CREATE VIEW va_sales_by_period AS
SELECT
    date_trunc('day', order_date) AS period,
    product_category,
    customer_region,
    COUNT(*) AS order_count,
    SUM(revenue) AS revenue,
    AVG(revenue) AS avg_order_value,
    SUM(quantity) AS items_sold
FROM tf_sales
GROUP BY 1, 2, 3;
```

## Time-Based Analytics

### Time Granularity

```sql
-- Daily aggregates
CREATE VIEW va_metrics_daily AS
SELECT
    date_trunc('day', created_at) AS day,
    COUNT(*) AS count,
    SUM(value) AS total
FROM ta_events
GROUP BY 1;

-- Weekly aggregates
CREATE VIEW va_metrics_weekly AS
SELECT
    date_trunc('week', created_at) AS week,
    COUNT(*) AS count,
    SUM(value) AS total
FROM ta_events
GROUP BY 1;

-- Monthly aggregates
CREATE VIEW va_metrics_monthly AS
SELECT
    date_trunc('month', created_at) AS month,
    COUNT(*) AS count,
    SUM(value) AS total
FROM ta_events
GROUP BY 1;
```

### Rolling Windows

```sql
-- 7-day rolling average
CREATE VIEW va_rolling_7d AS
SELECT
    day,
    revenue,
    AVG(revenue) OVER (
        ORDER BY day
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS rolling_avg_7d
FROM va_metrics_daily;

-- 30-day rolling sum
CREATE VIEW va_rolling_30d AS
SELECT
    day,
    orders,
    SUM(orders) OVER (
        ORDER BY day
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ) AS rolling_sum_30d
FROM va_metrics_daily;
```

### Period Comparisons

```sql
-- Year-over-year comparison
CREATE VIEW va_yoy_comparison AS
SELECT
    current.month,
    current.revenue AS current_revenue,
    previous.revenue AS previous_revenue,
    ROUND(
        (current.revenue - previous.revenue) / previous.revenue * 100,
        2
    ) AS yoy_growth_pct
FROM va_metrics_monthly current
LEFT JOIN va_metrics_monthly previous
    ON previous.month = current.month - INTERVAL '1 year';
```

## Common Analytics Patterns

### Top N

```python
@fraiseql.query(sql_source="va_top_products")
def top_products(
    limit: int = 10,
    metric: str = "revenue"  # revenue, quantity, orders
) -> list[ProductRanking]:
    """Get top products by specified metric."""
    pass
```

```sql
CREATE VIEW va_top_products AS
SELECT
    product_id,
    product_name,
    SUM(revenue) AS revenue,
    SUM(quantity) AS quantity,
    COUNT(*) AS orders,
    ROW_NUMBER() OVER (ORDER BY SUM(revenue) DESC) AS revenue_rank,
    ROW_NUMBER() OVER (ORDER BY SUM(quantity) DESC) AS quantity_rank
FROM tf_sales
GROUP BY product_id, product_name;
```

### Distribution

```sql
-- Revenue distribution by bucket
CREATE VIEW va_order_distribution AS
SELECT
    CASE
        WHEN revenue < 50 THEN 'Under $50'
        WHEN revenue < 100 THEN '$50-$100'
        WHEN revenue < 250 THEN '$100-$250'
        WHEN revenue < 500 THEN '$250-$500'
        ELSE 'Over $500'
    END AS revenue_bucket,
    COUNT(*) AS order_count,
    SUM(revenue) AS total_revenue
FROM tf_sales
GROUP BY 1
ORDER BY MIN(revenue);
```

### Percentiles

```sql
CREATE VIEW va_latency_percentiles AS
SELECT
    date_trunc('hour', created_at) AS hour,
    percentile_cont(0.50) WITHIN GROUP (ORDER BY latency_ms) AS p50,
    percentile_cont(0.90) WITHIN GROUP (ORDER BY latency_ms) AS p90,
    percentile_cont(0.95) WITHIN GROUP (ORDER BY latency_ms) AS p95,
    percentile_cont(0.99) WITHIN GROUP (ORDER BY latency_ms) AS p99
FROM ta_request_logs
GROUP BY 1;
```

### Cohort Analysis

```sql
CREATE VIEW va_retention_cohorts AS
WITH first_action AS (
    SELECT
        user_id,
        date_trunc('week', MIN(created_at)) AS cohort_week
    FROM ta_events
    WHERE event_type = 'signup'
    GROUP BY 1
),
weekly_activity AS (
    SELECT
        user_id,
        date_trunc('week', created_at) AS activity_week
    FROM ta_events
    WHERE event_type = 'login'
)
SELECT
    fa.cohort_week,
    EXTRACT(WEEK FROM wa.activity_week - fa.cohort_week) AS weeks_since_signup,
    COUNT(DISTINCT wa.user_id) AS active_users,
    COUNT(DISTINCT fa.user_id) AS cohort_size,
    ROUND(
        COUNT(DISTINCT wa.user_id)::numeric /
        COUNT(DISTINCT fa.user_id) * 100,
        2
    ) AS retention_pct
FROM first_action fa
LEFT JOIN weekly_activity wa ON wa.user_id = fa.user_id
    AND wa.activity_week >= fa.cohort_week
GROUP BY 1, 2;
```

## Funnel Analysis

```python
@fraiseql.type
class FunnelStep:
    step_name: str
    users: int
    conversion_rate: Decimal

@fraiseql.query(sql_source="va_checkout_funnel")
def checkout_funnel(
    start_date: Date,
    end_date: Date
) -> list[FunnelStep]:
    """Analyze checkout funnel conversion."""
    pass
```

```sql
CREATE VIEW va_checkout_funnel AS
WITH funnel AS (
    SELECT
        session_id,
        MAX(CASE WHEN event_type = 'product_view' THEN 1 ELSE 0 END) AS viewed,
        MAX(CASE WHEN event_type = 'add_to_cart' THEN 1 ELSE 0 END) AS added,
        MAX(CASE WHEN event_type = 'checkout_start' THEN 1 ELSE 0 END) AS started,
        MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS purchased
    FROM ta_events
    GROUP BY session_id
)
SELECT
    'Product View' AS step_name,
    SUM(viewed) AS users,
    100.0 AS conversion_rate

UNION ALL

SELECT
    'Add to Cart' AS step_name,
    SUM(added) AS users,
    ROUND(SUM(added)::numeric / NULLIF(SUM(viewed), 0) * 100, 2)

UNION ALL

SELECT
    'Checkout Start' AS step_name,
    SUM(started) AS users,
    ROUND(SUM(started)::numeric / NULLIF(SUM(added), 0) * 100, 2)

UNION ALL

SELECT
    'Purchase' AS step_name,
    SUM(purchased) AS users,
    ROUND(SUM(purchased)::numeric / NULLIF(SUM(started), 0) * 100, 2)

FROM funnel;
```

## Real-Time Analytics

### Streaming Aggregates

For real-time dashboards, maintain incremental aggregates:

```sql
-- Incremental counter table
CREATE TABLE ta_counters (
    counter_key TEXT PRIMARY KEY,
    value BIGINT DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Increment function
CREATE FUNCTION increment_counter(key TEXT, amount INT DEFAULT 1)
RETURNS VOID AS $$
BEGIN
    INSERT INTO ta_counters (counter_key, value)
    VALUES (key, amount)
    ON CONFLICT (counter_key)
    DO UPDATE SET
        value = ta_counters.value + amount,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;
```

### Live Dashboards

```python
@fraiseql.subscription(entity_type="Counter", topic="counter_updated")
def counter_updates(counter_keys: list[str]) -> Counter:
    """Subscribe to real-time counter updates."""
    pass
```

## Performance

### Pre-Aggregation

Pre-compute aggregates for common queries:

```sql
-- Daily summary table (populated by cron/observer)
CREATE TABLE ta_daily_summary (
    summary_date DATE PRIMARY KEY,
    total_orders INT,
    total_revenue DECIMAL(12,2),
    unique_customers INT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Populate function
CREATE FUNCTION refresh_daily_summary(for_date DATE) RETURNS VOID AS $$
BEGIN
    INSERT INTO ta_daily_summary (summary_date, total_orders, total_revenue, unique_customers)
    SELECT
        for_date,
        COUNT(*),
        SUM(revenue),
        COUNT(DISTINCT customer_id)
    FROM tf_sales
    WHERE order_date = for_date
    ON CONFLICT (summary_date) DO UPDATE SET
        total_orders = EXCLUDED.total_orders,
        total_revenue = EXCLUDED.total_revenue,
        unique_customers = EXCLUDED.unique_customers,
        created_at = NOW();
END;
$$ LANGUAGE plpgsql;
```

### Materialized Views

```sql
-- Materialized for heavy aggregations
CREATE MATERIALIZED VIEW mv_product_stats AS
SELECT
    product_id,
    COUNT(*) AS total_orders,
    SUM(quantity) AS total_sold,
    SUM(revenue) AS total_revenue,
    AVG(revenue) AS avg_order_value
FROM tf_sales
GROUP BY product_id;

-- Refresh periodically
CREATE UNIQUE INDEX ON mv_product_stats (product_id);
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_product_stats;
```

## Next Steps

- [Arrow Flight](/features/arrow-dataplane) — High-performance data access
- [Performance](/guides/performance) — Query optimization
- [Caching](/features/caching) — Cache analytics results
