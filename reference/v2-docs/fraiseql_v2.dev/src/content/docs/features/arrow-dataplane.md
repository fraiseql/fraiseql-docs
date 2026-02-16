---
title: Arrow Flight Dataplane
description: High-performance columnar data access with Apache Arrow Flight
---

FraiseQL includes an Apache Arrow Flight dataplane for high-throughput columnar data access, enabling efficient analytics, OLAP queries, and data science workloads.

## Overview

Arrow Flight provides:
- **Columnar data transfer**: Efficient for analytical queries
- **Zero-copy reads**: Minimal memory overhead
- **Streaming**: Handle datasets larger than memory
- **Language interop**: Python, R, Julia, Rust clients

## Configuration

### Enable Arrow Flight

```toml
[arrow]
enabled = true
port = 8081
host = "0.0.0.0"

[arrow.options]
max_batch_size = 65536
compression = "zstd"
```

### Authentication

```toml
[arrow.auth]
enabled = true
type = "bearer"
validate_endpoint = "http://auth-service/validate"
```

## Defining Arrow Views

### va_ Views (Views for Arrow)

Create views optimized for columnar access:

```sql
-- Analytics view for Arrow
CREATE VIEW va_orders_daily AS
SELECT
    date_trunc('day', created_at) AS order_date,
    customer_region,
    product_category,
    COUNT(*) AS order_count,
    SUM(total) AS revenue,
    AVG(total) AS avg_order_value
FROM tb_order o
JOIN tb_customer c ON c.pk_customer = o.fk_customer
JOIN tb_product p ON p.pk_product = o.fk_product
GROUP BY 1, 2, 3;
```

### ta_ Tables (Tables for Arrow)

Create tables for columnar storage:

```sql
-- Fact table for Arrow analytics
CREATE TABLE ta_events (
    event_id UUID,
    event_type TEXT,
    user_id UUID,
    session_id UUID,
    page_url TEXT,
    referrer TEXT,
    device_type TEXT,
    country TEXT,
    properties JSONB,
    created_at TIMESTAMPTZ
);

-- Columnar storage (if using TimescaleDB or similar)
SELECT create_hypertable('ta_events', 'created_at');
```

### Python Schema

```python
import fraiseql
from fraiseql.scalars import ID, DateTime, Decimal

@fraiseql.type(dataplane="arrow")
class OrdersDaily:
    """Daily order aggregates for analytics."""
    order_date: DateTime
    customer_region: str
    product_category: str
    order_count: int
    revenue: Decimal
    avg_order_value: Decimal

@fraiseql.arrow_query(sql_source="va_orders_daily")
def orders_daily(
    start_date: DateTime,
    end_date: DateTime,
    regions: list[str] | None = None
) -> list[OrdersDaily]:
    """Query daily order aggregates."""
    pass
```

## Querying via Arrow Flight

### Python Client (PyArrow)

```python
import pyarrow.flight as flight

# Connect to FraiseQL Arrow Flight server
client = flight.connect("grpc://localhost:8081")

# Authenticate
token = client.authenticate_basic_token("user", "password")
options = flight.FlightCallOptions(headers=[(b"authorization", token)])

# Execute query
ticket = flight.Ticket(b'{"query": "orders_daily", "variables": {"start_date": "2024-01-01"}}')
reader = client.do_get(ticket, options)

# Read as Arrow Table
table = reader.read_all()
print(table.to_pandas())
```

### Using with Pandas

```python
import pandas as pd
import pyarrow.flight as flight

def query_fraiseql(query: str, variables: dict = None) -> pd.DataFrame:
    """Execute FraiseQL Arrow query and return DataFrame."""
    client = flight.connect("grpc://localhost:8081")

    payload = {"query": query, "variables": variables or {}}
    ticket = flight.Ticket(json.dumps(payload).encode())

    reader = client.do_get(ticket)
    return reader.read_pandas()

# Usage
df = query_fraiseql(
    "orders_daily",
    {"start_date": "2024-01-01", "end_date": "2024-12-31"}
)
```

### Using with DuckDB

```python
import duckdb

# Register Arrow Flight data source
duckdb.execute("""
    INSTALL arrow;
    LOAD arrow;
""")

# Query directly from FraiseQL
result = duckdb.execute("""
    SELECT
        order_date,
        SUM(revenue) as total_revenue
    FROM arrow_scan('grpc://localhost:8081', 'orders_daily')
    WHERE order_date >= '2024-01-01'
    GROUP BY order_date
    ORDER BY order_date
""").fetchdf()
```

## Streaming Large Datasets

### Chunked Reading

```python
def stream_large_dataset(query: str, chunk_size: int = 100000):
    """Stream large datasets in chunks."""
    client = flight.connect("grpc://localhost:8081")

    ticket = flight.Ticket(json.dumps({"query": query}).encode())
    reader = client.do_get(ticket)

    for chunk in reader:
        batch = chunk.data
        # Process batch
        yield batch.to_pandas()
```

### Memory-Efficient Processing

```python
import pyarrow as pa

def process_without_loading_all(query: str):
    """Process data without loading entire dataset into memory."""
    client = flight.connect("grpc://localhost:8081")

    ticket = flight.Ticket(json.dumps({"query": query}).encode())
    reader = client.do_get(ticket)

    total_revenue = 0
    row_count = 0

    for chunk in reader:
        batch = chunk.data
        # Process each batch
        revenue_col = batch.column("revenue")
        total_revenue += pa.compute.sum(revenue_col).as_py()
        row_count += len(batch)

    return {"total_revenue": total_revenue, "rows": row_count}
```

## Analytics Patterns

### Time Series Aggregation

```sql
CREATE VIEW va_metrics_hourly AS
SELECT
    date_trunc('hour', created_at) AS hour,
    metric_name,
    COUNT(*) AS sample_count,
    AVG(value) AS avg_value,
    MIN(value) AS min_value,
    MAX(value) AS max_value,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY value) AS p50,
    percentile_cont(0.95) WITHIN GROUP (ORDER BY value) AS p95,
    percentile_cont(0.99) WITHIN GROUP (ORDER BY value) AS p99
FROM ta_metrics
GROUP BY 1, 2;
```

### Cohort Analysis

```sql
CREATE VIEW va_user_cohorts AS
WITH first_purchase AS (
    SELECT
        user_id,
        date_trunc('month', MIN(created_at)) AS cohort_month
    FROM tb_order
    GROUP BY 1
)
SELECT
    fp.cohort_month,
    date_trunc('month', o.created_at) AS order_month,
    COUNT(DISTINCT o.user_id) AS users,
    SUM(o.total) AS revenue
FROM first_purchase fp
JOIN tb_order o ON o.user_id = fp.user_id
GROUP BY 1, 2;
```

### Funnel Analysis

```sql
CREATE VIEW va_funnel AS
WITH events AS (
    SELECT
        session_id,
        event_type,
        created_at,
        ROW_NUMBER() OVER (PARTITION BY session_id ORDER BY created_at) AS event_order
    FROM ta_events
    WHERE event_type IN ('page_view', 'add_to_cart', 'checkout', 'purchase')
)
SELECT
    date_trunc('day', e1.created_at) AS day,
    COUNT(DISTINCT e1.session_id) AS page_views,
    COUNT(DISTINCT e2.session_id) AS add_to_cart,
    COUNT(DISTINCT e3.session_id) AS checkout,
    COUNT(DISTINCT e4.session_id) AS purchase
FROM events e1
LEFT JOIN events e2 ON e2.session_id = e1.session_id AND e2.event_type = 'add_to_cart'
LEFT JOIN events e3 ON e3.session_id = e1.session_id AND e3.event_type = 'checkout'
LEFT JOIN events e4 ON e4.session_id = e1.session_id AND e4.event_type = 'purchase'
WHERE e1.event_type = 'page_view'
GROUP BY 1;
```

## Performance

### Compression

Configure compression for transfer:

```toml
[arrow.options]
compression = "zstd"  # or "lz4", "none"
compression_level = 3
```

### Batch Size

Tune batch size for your workload:

```toml
[arrow.options]
max_batch_size = 65536  # Rows per batch
```

| Batch Size | Use Case |
|------------|----------|
| 1,024 | Low latency, small queries |
| 65,536 | General purpose (default) |
| 1,000,000 | Large analytics, high throughput |

### Predicate Pushdown

FraiseQL pushes filters to the database:

```python
# This query
query_fraiseql(
    "orders_daily",
    {"start_date": "2024-01-01", "regions": ["US", "CA"]}
)

# Generates SQL with WHERE clause
# SELECT ... FROM va_orders_daily
# WHERE order_date >= '2024-01-01'
# AND customer_region IN ('US', 'CA')
```

### Column Pruning

Only requested columns are transferred:

```python
# Request specific columns
ticket = flight.Ticket(json.dumps({
    "query": "orders_daily",
    "columns": ["order_date", "revenue"]  # Only these columns
}).encode())
```

## Monitoring

### Arrow Metrics

| Metric | Description |
|--------|-------------|
| `fraiseql_arrow_requests_total` | Total Arrow Flight requests |
| `fraiseql_arrow_bytes_sent` | Bytes transferred |
| `fraiseql_arrow_batches_sent` | Number of record batches |
| `fraiseql_arrow_query_duration` | Query execution time |

### Connection Stats

```bash
fraiseql status --arrow

# Arrow Flight Server
# Status: Running
# Port: 8081
# Active connections: 12
# Bytes sent (24h): 1.2 TB
# Queries (24h): 45,230
```

## Security

### TLS

```toml
[arrow.tls]
enabled = true
cert_file = "/path/to/cert.pem"
key_file = "/path/to/key.pem"
```

### Query Authorization

```python
@fraiseql.arrow_query(
    sql_source="va_sensitive_metrics",
    requires_scope="analytics:read"
)
def sensitive_metrics() -> list[Metric]:
    """Requires analytics:read scope."""
    pass
```

## Best Practices

### Design for Analytics

```sql
-- Good: Pre-aggregated view
CREATE VIEW va_sales_summary AS
SELECT
    date_trunc('day', created_at) AS day,
    SUM(total) AS revenue
FROM tb_order
GROUP BY 1;

-- Avoid: Raw transaction data
-- (Use ta_ table for raw event storage)
```

### Use Appropriate Storage

| Data Type | Table Prefix | Use Case |
|-----------|--------------|----------|
| Aggregates | `va_` | Pre-computed summaries |
| Raw events | `ta_` | Event streams, logs |
| Facts | `tf_` | Star schema analytics |

### Index for Filters

```sql
-- Index on commonly filtered columns
CREATE INDEX idx_ta_events_created ON ta_events(created_at);
CREATE INDEX idx_ta_events_type ON ta_events(event_type);
CREATE INDEX idx_ta_events_user ON ta_events(user_id);
```

## Next Steps

- [Analytics](/features/analytics) — Analytics patterns and aggregations
- [Performance](/guides/performance) — Query optimization
- [NATS](/features/nats) — Real-time event streaming