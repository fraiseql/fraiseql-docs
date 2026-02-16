---
title: Resilience
description: Circuit breakers, retries, and graceful degradation
---

FraiseQL includes resilience patterns to handle failures gracefully and maintain service availability.

## Circuit Breaker

Prevent cascading failures by stopping requests to failing services.

### Configuration

```toml
[resilience.circuit_breaker]
enabled = true

# Failure threshold to open circuit
failure_threshold = 5
failure_window_seconds = 60

# Time before attempting recovery
reset_timeout_seconds = 30

# Requests allowed in half-open state
half_open_requests = 3

# Success threshold to close circuit
success_threshold = 3
```

### States

```
┌──────────┐   failures >= threshold   ┌──────────┐
│  CLOSED  │ ────────────────────────→ │   OPEN   │
│ (normal) │                           │ (reject) │
└──────────┘                           └──────────┘
     ↑                                      │
     │                              reset_timeout
     │                                      │
     │      successes >= threshold    ┌─────↓─────┐
     └─────────────────────────────── │ HALF-OPEN │
                                      │  (probe)  │
                                      └───────────┘
```

### Per-Endpoint Configuration

```toml
[resilience.circuit_breaker.endpoints]
# Stricter settings for critical endpoints
"database" = { failure_threshold = 3, reset_timeout_seconds = 60 }

# Lenient settings for optional services
"analytics" = { failure_threshold = 10, reset_timeout_seconds = 10 }
```

### Monitoring

```
# Circuit breaker state (0=closed, 1=open, 2=half-open)
fraiseql_circuit_breaker_state{endpoint="database"}

# Requests rejected by open circuit
rate(fraiseql_circuit_breaker_rejected_total[5m])
```

## Retry Policies

Automatically retry transient failures.

### Configuration

```toml
[resilience.retry]
enabled = true
max_attempts = 3

# Backoff strategy
strategy = "exponential"  # or "linear", "fixed"
initial_delay_ms = 100
max_delay_ms = 5000
multiplier = 2.0

# Jitter to prevent thundering herd
jitter = 0.1  # ±10%
```

### Retryable Errors

```toml
[resilience.retry.errors]
# HTTP status codes to retry
status_codes = [408, 429, 500, 502, 503, 504]

# Database errors to retry
database = ["connection_reset", "timeout", "deadlock"]

# Custom error codes
custom = ["TRANSIENT_ERROR", "TEMPORARILY_UNAVAILABLE"]
```

### Non-Retryable Operations

```toml
[resilience.retry]
# Don't retry mutations by default (not idempotent)
skip_mutations = true

# Specific operations to never retry
never_retry = ["createPayment", "sendEmail"]
```

### Backoff Strategies

**Exponential (recommended):**
```
Attempt 1: 100ms
Attempt 2: 200ms
Attempt 3: 400ms
Attempt 4: 800ms
...
```

**Linear:**
```
Attempt 1: 100ms
Attempt 2: 200ms
Attempt 3: 300ms
...
```

**Fixed:**
```
Attempt 1: 100ms
Attempt 2: 100ms
Attempt 3: 100ms
...
```python

## Timeouts

Prevent requests from hanging indefinitely.

### Configuration

```toml
[resilience.timeouts]
# Overall request timeout
request_timeout_ms = 30000

# Database query timeout
query_timeout_ms = 10000

# Connection timeout
connect_timeout_ms = 5000

# Idle timeout
idle_timeout_ms = 60000
```

### Per-Operation Timeouts

```toml
[resilience.timeouts.operations]
# Expensive analytics queries get more time
"salesAggregate" = 60000

# Simple lookups should be fast
"user" = 5000
```

## Bulkhead

Isolate failures by limiting concurrent requests.

### Configuration

```toml
[resilience.bulkhead]
enabled = true

# Global concurrency limit
max_concurrent = 1000

# Per-operation limits
[resilience.bulkhead.operations]
"importData" = 10  # Expensive operation
"analyticsQuery" = 50
```

### Queue Behavior

```toml
[resilience.bulkhead]
# Queue requests when limit reached
queue_size = 100
queue_timeout_ms = 5000

# Or reject immediately
reject_when_full = false
```

## Graceful Degradation

Reduce functionality when under stress.

### Load Shedding

```toml
[resilience.load_shedding]
enabled = true

# CPU threshold to start shedding
cpu_threshold = 0.8

# Memory threshold
memory_threshold = 0.9

# Actions when shedding
[resilience.load_shedding.actions]
disable_introspection = true
disable_analytics = true
reduce_cache_ttl = true
reject_new_subscriptions = true
```

### Feature Flags

```toml
[resilience.features]
# Disable non-critical features under load
analytics_enabled = true
subscriptions_enabled = true
introspection_enabled = true

# Auto-disable thresholds
[resilience.features.auto_disable]
analytics = { error_rate = 0.1, latency_p99_ms = 5000 }
```

### Fallback Responses

```toml
[resilience.fallback]
enabled = true

# Return cached data when database unavailable
use_stale_cache = true
stale_cache_max_age_seconds = 300

# Default responses for specific queries
[resilience.fallback.queries]
"featuredProducts" = { cache_key = "featured_products_fallback" }
```

## Health-Based Routing

Route traffic based on backend health.

### Configuration

```toml
[resilience.health_routing]
enabled = true

# Health check interval
check_interval_seconds = 10

# Unhealthy threshold
unhealthy_threshold = 3

# Remove unhealthy backends from rotation
remove_unhealthy = true
```

## Error Handling

### Error Classification

```toml
[resilience.errors]
# Classify errors for appropriate handling
[resilience.errors.transient]
codes = ["ECONNRESET", "ETIMEDOUT", "ECONNREFUSED"]
action = "retry"

[resilience.errors.permanent]
codes = ["INVALID_INPUT", "NOT_FOUND", "UNAUTHORIZED"]
action = "fail_fast"

[resilience.errors.unknown]
action = "retry_once"
```

### Error Budgets

```toml
[resilience.error_budget]
enabled = true

# Allow 0.1% error rate
threshold = 0.001

# Window for calculation
window_minutes = 60

# Actions when budget exhausted
[resilience.error_budget.actions]
alert = true
reduce_traffic = true
```

## Metrics

| Metric | Description |
|--------|-------------|
| `fraiseql_circuit_breaker_state` | Current state per endpoint |
| `fraiseql_circuit_breaker_rejected_total` | Rejected by open circuit |
| `fraiseql_retry_attempts_total` | Retry attempts |
| `fraiseql_retry_success_total` | Successful retries |
| `fraiseql_timeout_total` | Timeout occurrences |
| `fraiseql_bulkhead_rejected_total` | Rejected by bulkhead |
| `fraiseql_load_shedding_active` | Load shedding active |

## Best Practices

### Tune for Your Workload

```toml
# High-throughput, latency-sensitive
[resilience]
request_timeout_ms = 5000
retry.max_attempts = 2
circuit_breaker.failure_threshold = 10

# Batch processing, reliability-focused
[resilience]
request_timeout_ms = 60000
retry.max_attempts = 5
circuit_breaker.failure_threshold = 3
```

### Test Failure Scenarios

```bash
# Inject failures for testing
fraiseql-cli chaos inject --type timeout --probability 0.1
fraiseql-cli chaos inject --type error --code 500 --probability 0.05
```

### Monitor Resilience Metrics

```
# Circuit breaker open time
sum(fraiseql_circuit_breaker_state == 1) by (endpoint)

# Retry effectiveness
rate(fraiseql_retry_success_total[5m]) /
rate(fraiseql_retry_attempts_total[5m])
```

## Troubleshooting

### Circuit Breaker Opens Too Often

1. Check backend health
2. Increase failure threshold
3. Review error classification

### Too Many Retries

1. Check if errors are truly transient
2. Reduce max attempts
3. Add to non-retryable list

### Timeouts Under Normal Load

1. Profile slow queries
2. Check connection pool size
3. Review database indexes

## Next Steps

- [Observability](/features/observability) - Monitor resilience metrics
- [Performance](/guides/performance) - Optimize for resilience
- [Deployment](/guides/deployment) - Production resilience setup