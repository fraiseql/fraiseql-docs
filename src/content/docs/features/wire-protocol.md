---
title: Wire Protocol
description: Low-memory streaming for large result sets
---

The FraiseQL Wire protocol provides memory-efficient streaming for large query results, using PostgreSQL's COPY protocol for minimal overhead.

## Overview

Traditional query execution loads entire result sets into memory:

```
                ─         ─               ─
                ─         ─             ─
```

Wire protocol is ideal for:
- Exporting large datasets
- ETL pipelines
- Reports with millions of rows
- Memory-constrained environments

## When to Use Wire

| Scenario | Standard | Wire |
|----------|----------|------|
| < 10,000 rows | Recommended | Overkill |
| 10,000 - 100,000 rows | Acceptable | Recommended |
| > 100,000 rows | May OOM | Required |
| Real-time queries | Recommended | Overhead |
| Batch exports | Memory issues | Ideal |

## Configuration

### Enable Wire Backend

```toml
[server]
backend = "wire"

[wire]
# Connection settings
connection_timeout_ms = 5000
query_timeout_ms = 300000  # 5 minutes for large queries

# Chunking
adaptive_chunking = true
initial_chunk_size = 1000
max_chunk_size = 10000
target_memory_mb = 100
```

### Feature Flag

Wire is an optional feature:

```bash
# Build with wire support
cargo build --features wire-backend
```

## How It Works

### PostgreSQL COPY Protocol

Wire uses PostgreSQL's binary COPY protocol for efficient data transfer:

```sql
┌─────────────┐     COPY (SELECT ...) TO STDOUT     ┌─────────────┐
│  PostgreSQL │ ─────────────────────────────────→  │   FraiseQL  │
│   Server    │      Binary row stream              │    Wire     │
└─────────────┘                                      └─────────────┘
                                                            │
                                                            ↓
                                                     ┌─────────────┐
                                                     │   Chunked   │
                                                     │    JSON     │
                                                     └─────────────┘
```

### Adaptive Chunking

Wire dynamically adjusts chunk sizes based on row size:

```rust
// Small rows (< 1KB): larger chunks
chunk_size = 10_000

// Large rows (10KB+): smaller chunks
chunk_size = 100

// Memory target maintained regardless of row size
```

## Client Usage

### Streaming Response

Wire returns newline-delimited JSON:

```bash
curl -N http://localhost:8080/graphql \
    -H "Content-Type: application/json" \
    -H "Accept: application/x-ndjson" \
    -d '{"query": "{ allOrders { id total } }"}'
```

Response (streamed):

```json
{"data":{"allOrders":[{"id":"1","total":99.99}
{"id":"2","total":149.99}
{"id":"3","total":249.99}
...
]}}
```

### JavaScript Streaming

```javascript
async function* streamQuery(query) {
    const response = await fetch('/graphql', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/x-ndjson'
        },
        body: JSON.stringify({ query })
    });

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';

    while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() || '';

        for (const line of lines) {
            if (line.trim()) {
                yield JSON.parse(line);
            }
        }
    }
}

// Usage
for await (const row of streamQuery('{ allOrders { id total } }')) {
    console.log('Row:', row);
}
```

### Python Streaming

```python
import httpx

def stream_query(query: str):
    with httpx.stream(
        "POST",
        "http://localhost:8080/graphql",
        json={"query": query},
        headers={"Accept": "application/x-ndjson"}
    ) as response:
        for line in response.iter_lines():
            if line.strip():
                yield json.loads(line)

# Usage
for row in stream_query("{ allOrders { id total } }"):
    print(f"Order: {row}")
```

## Memory Management

### Bounded Memory

Wire maintains bounded memory regardless of result size:

```toml
[wire]
target_memory_mb = 100  # Stay under 100MB
```

Memory usage stays constant:

```
Rows        Standard Memory    Wire Memory
10,000      50 MB             ~10 MB
100,000     500 MB            ~10 MB
1,000,000   5 GB (OOM!)       ~10 MB
```

### Memory Estimation

Wire estimates row sizes to prevent OOM:

```rust
// Estimates before fetching
estimated_row_size = avg(sample_rows)
safe_chunk_size = target_memory / estimated_row_size
```

## Authentication

Wire supports SCRAM-SHA-256 authentication:

```toml
[wire.auth]
method = "scram-sha-256"
username = "${DB_USER}"
password = "${DB_PASSWORD}"
```

## TLS Support

```toml
[wire.tls]
mode = "require"  # disable, prefer, require
ca_cert = "/path/to/ca.crt"
```

## Metrics

| Metric | Description |
|--------|-------------|
| `fraiseql_wire_rows_streamed` | Rows streamed |
| `fraiseql_wire_bytes_sent` | Bytes sent |
| `fraiseql_wire_chunk_size` | Current chunk size |
| `fraiseql_wire_memory_usage` | Memory usage |
| `fraiseql_wire_query_duration_ms` | Query duration |

## Comparison with Arrow

| Feature | Wire | Arrow |
|---------|------|-------|
| Format | JSON (NDJSON) | Columnar binary |
| Memory | Bounded | Bounded |
| Speed | Fast | Faster |
| Compatibility | Universal | Arrow clients |
| Use case | Web clients, ETL | Analytics, ML |

Use **Wire** for:
- JSON-based clients
- Simple streaming exports
- Maximum compatibility

Use **Arrow** for:
- Analytics workloads
- Data science pipelines
- Maximum performance

## Best Practices

### Set Appropriate Timeouts

```toml
[wire]
query_timeout_ms = 300000  # 5 min for exports
connection_timeout_ms = 10000
```

### Monitor Memory

```
# Alert if memory exceeds target
fraiseql_wire_memory_usage > 150_000_000
```

### Use for Exports Only

Don't use Wire for:
- Real-time queries (use standard)
- Small result sets (overhead not worth it)
- Interactive UIs (latency-sensitive)

## Troubleshooting

### Connection Timeouts

```toml
[wire]
connection_timeout_ms = 30000  # Increase timeout
```

### Slow Streaming

1. Check network latency to database
2. Verify indexes on queried tables
3. Increase chunk size for small rows

### Memory Spikes

1. Reduce `target_memory_mb`
2. Enable `adaptive_chunking`
3. Check for unexpectedly large rows

## Next Steps

- [Arrow Dataplane](/features/arrow-dataplane) - Columnar streaming
- [Analytics](/features/analytics) - Large dataset queries
- [Performance](/guides/performance) - Optimization guide