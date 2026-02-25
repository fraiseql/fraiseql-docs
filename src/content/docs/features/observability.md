---
title: Observability
description: Prometheus metrics, OpenTelemetry tracing, and structured logging
---

FraiseQL provides comprehensive observability through metrics, distributed tracing, and structured logging.

## Prometheus Metrics

### Enable Metrics

```toml
[metrics]
enabled = true
endpoint = "/metrics"
port = 9090  # Separate port for metrics

# Optional: require auth for metrics
token = "${METRICS_TOKEN}"
```

### Available Metrics

#### HTTP Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `fraiseql_http_requests_total` | Counter | Total HTTP requests |
| `fraiseql_http_request_duration_seconds` | Histogram | Request latency |
| `fraiseql_http_requests_in_flight` | Gauge | Active requests |
| `fraiseql_http_response_size_bytes` | Histogram | Response sizes |

#### GraphQL Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `fraiseql_graphql_queries_total` | Counter | Total queries |
| `fraiseql_graphql_mutations_total` | Counter | Total mutations |
| `fraiseql_graphql_subscriptions_active` | Gauge | Active subscriptions |
| `fraiseql_graphql_errors_total` | Counter | GraphQL errors |
| `fraiseql_graphql_query_duration_seconds` | Histogram | Query execution time |
| `fraiseql_graphql_query_complexity` | Histogram | Query complexity scores |

#### Database Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `fraiseql_db_connections_active` | Gauge | Active connections |
| `fraiseql_db_connections_idle` | Gauge | Idle connections |
| `fraiseql_db_query_duration_seconds` | Histogram | SQL query latency |
| `fraiseql_db_errors_total` | Counter | Database errors |

#### Cache Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `fraiseql_cache_hits_total` | Counter | Cache hits |
| `fraiseql_cache_misses_total` | Counter | Cache misses |
| `fraiseql_cache_size_bytes` | Gauge | Cache memory usage |
| `fraiseql_cache_evictions_total` | Counter | Cache evictions |

#### Authentication Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `fraiseql_auth_attempts_total` | Counter | Auth attempts |
| `fraiseql_auth_success_total` | Counter | Successful auth |
| `fraiseql_auth_failure_total` | Counter | Failed auth |
| `fraiseql_auth_sessions_active` | Gauge | Active sessions |

### Metric Labels

Common labels across metrics:

| Label | Description |
|-------|-------------|
| `operation` | GraphQL operation name |
| `type` | query, mutation, subscription |
| `status` | success, error |
| `error_code` | Error code if failed |

### Grafana Dashboard

Example queries for dashboards:

```
# Request rate
rate(fraiseql_http_requests_total[5m])

# P99 latency
histogram_quantile(0.99, rate(fraiseql_http_request_duration_seconds_bucket[5m]))

# Error rate
rate(fraiseql_graphql_errors_total[5m]) / rate(fraiseql_graphql_queries_total[5m])

# Cache hit ratio
rate(fraiseql_cache_hits_total[5m]) /
(rate(fraiseql_cache_hits_total[5m]) + rate(fraiseql_cache_misses_total[5m]))

# Active connections
fraiseql_db_connections_active / fraiseql_db_connections_max
```

## OpenTelemetry Tracing

### Enable Tracing

```toml
[tracing]
enabled = true
service_name = "fraiseql-api"

[tracing.otlp]
endpoint = "http://otel-collector:4317"
protocol = "grpc"  # or "http"

# Sampling
[tracing.sampling]
ratio = 0.1  # Sample 10% of requests
# Or always sample errors
always_sample_errors = true
```

### Trace Spans

FraiseQL creates spans for:

```




│
│   │
│   ↓
│
↓

| Attribute | Description |
|-----------|-------------|
| `graphql.operation.name` | Operation name |
| `graphql.operation.type` | query/mutation/subscription |
| `graphql.document` | Query document (if enabled) |
| `db.system` | Database type |
| `db.statement` | SQL query (if enabled) |
| `db.operation` | SELECT/INSERT/UPDATE/DELETE |
| `user.id` | Authenticated user ID |
| `tenant.id` | Tenant ID |

### Trace Context Propagation

FraiseQL propagates trace context via headers:

```
traceparent: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01
tracestate: fraiseql=user:123
```

### Jaeger Integration

```toml
[tracing]
enabled = true
exporter = "jaeger"

[tracing.jaeger]
agent_host = "jaeger-agent"
agent_port = 6831
```

### Zipkin Integration

```toml
[tracing]
enabled = true
exporter = "zipkin"

[tracing.zipkin]
endpoint = "http://zipkin:9411/api/v2/spans"
```

## Structured Logging

### Configuration

```toml
[logging]
level = "info"  # trace, debug, info, warn, error
format = "json"  # or "pretty" for development

# Output
output = "stdout"  # or file path

# Include fields
include_timestamp = true
include_level = true
include_target = true
include_span = true
```

### Log Format (JSON)

```json
{
    "timestamp": "2024-01-15T10:30:00.123Z",
    "level": "INFO",
    "target": "fraiseql_server::graphql",
    "message": "Query executed",
    "span": {
        "request_id": "abc-123",
        "user_id": "user-456"
    },
    "fields": {
        "operation": "getUser",
        "duration_ms": 45,
        "cache_hit": true
    }
}
```

### Log Levels by Component

```toml
[logging.levels]
# Default level
default = "info"

# Per-component levels
"fraiseql_server" = "info"
"fraiseql_core::cache" = "debug"
"fraiseql_core::db" = "warn"
"tower_http" = "debug"
"sqlx" = "warn"
```

### Request Context

Every log includes request context:

```toml
[logging.context]
include_request_id = true
include_user_id = true
include_tenant_id = true
include_operation = true
```

## Health Checks

### Endpoints

```toml
[health]
enabled = true
path = "/health"
detailed_path = "/health/detailed"
```

**Basic health:**
```bash
curl http://localhost:8080/health
# {"status": "ok"}
```

**Detailed health:**
```bash
curl http://localhost:8080/health/detailed
```

```json
{
    "status": "ok",
    "checks": {
        "database": {
            "status": "ok",
            "latency_ms": 2
        },
        "cache": {
            "status": "ok",
            "size": 1500,
            "max_size": 10000
        },
        "schema": {
            "status": "ok",
            "version": "1.0.0",
            "loaded_at": "2024-01-15T10:00:00Z"
        }
    },
    "version": "2.0.0",
    "uptime_seconds": 3600
}
```

### Kubernetes Probes

```
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health/detailed
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

## Alerting Rules

Example Prometheus alerting rules:

```
groups:
  - name: fraiseql
    rules:
      - alert: HighErrorRate
        expr: |
          rate(fraiseql_graphql_errors_total[5m]) /
          rate(fraiseql_graphql_queries_total[5m]) > 0.05
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High GraphQL error rate"

      - alert: HighLatency
        expr: |
          histogram_quantile(0.99,
            rate(fraiseql_http_request_duration_seconds_bucket[5m])
          ) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "P99 latency above 1 second"

      - alert: LowCacheHitRate
        expr: |
          rate(fraiseql_cache_hits_total[5m]) /
          (rate(fraiseql_cache_hits_total[5m]) + rate(fraiseql_cache_misses_total[5m])) < 0.5
        for: 15m
        labels:
          severity: info
        annotations:
          summary: "Cache hit rate below 50%"

      - alert: DatabaseConnectionPoolExhausted
        expr: |
          fraiseql_db_connections_active / fraiseql_db_connections_max > 0.9
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Database connection pool nearly exhausted"
```

## Best Practices

### Sampling Strategy

```toml
[tracing.sampling]
# Sample 100% of errors
always_sample_errors = true

# Sample 10% of successful requests
ratio = 0.1

# Always sample slow requests
slow_request_threshold_ms = 1000
```

### Log Retention

```toml
[logging.rotation]
enabled = true
max_size_mb = 100
max_files = 10
compress = true
```

### Metric Cardinality

Avoid high-cardinality labels:

```toml
[metrics]
# Don't include user_id as label (too many values)
exclude_labels = ["user_id", "request_id"]

# Group operations by type instead
group_by_type = true
```

## Troubleshooting

### Missing Metrics

1. Verify `metrics.enabled = true`
2. Check metrics endpoint is accessible
3. Verify Prometheus can scrape endpoint

### Missing Traces

1. Check OTLP endpoint connectivity
2. Verify sampling isn't too aggressive
3. Check trace context propagation headers

### Log Spam

1. Adjust log levels per component
2. Enable sampling for high-volume logs
3. Filter in log aggregator

## Next Steps

- [Deployment](/guides/deployment) - Production monitoring setup
- [Performance](/guides/performance) - Using metrics to optimize
- [Troubleshooting](/guides/troubleshooting) - Debugging with logs and traces
