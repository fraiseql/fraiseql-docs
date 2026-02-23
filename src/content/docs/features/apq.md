---
title: Automatic Persisted Queries
description: Reduce bandwidth and latency with APQ
---

Automatic Persisted Queries (APQ) reduce bandwidth and improve latency by caching query strings on the server.

## How APQ Works

Instead of sending the full query text on every request, clients send a query hash:

```
┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                    First Request                                                                                                                                                   │
│────────────────────────────────────────────────────────────                                                                                                                        │
│ Client                                     Server                                                                                                                                  │
│ ┌─────────────────┐                       ┌─────────────┐                               │                                                                                          │
│ │ Query + Hash    │ ─────────────────────→│ Cache query │                               │                                                                                          │
↓ │                 │ ←────────────────────→│ Return data │                               ↓                                                                                          │
↓ └─────────────────┘                       └─────────────┘                               ↓                                                                                          ↓
└────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                 Subsequent Requests                                                                                                                                                │
│────────────────────────────────────────────────────────────                                                                                                                        │
│ Client                                     Server                                                                                                                                  │
│ ┌─────────────────┐                       ┌─────────────┐                               │                                                                                          │
│ │ Hash only       │ ─────────────────────→│ Lookup query│                               │                                                                                          │
↓ │ (small!)        │ ←────────────────────→│ Return data │                               ↓                                                                                          │
↓ └─────────────────┘                       └─────────────┘                               ↓                                                                                          ↓
└────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

## Configuration

### Enable APQ

```toml
[graphql.apq]
enabled = true
cache_size = 10000  # Max cached queries
ttl = 86400         # Cache TTL in seconds (24 hours)
```

### Cache Backend

```toml
# In-memory (default)
[graphql.apq]
enabled = true
backend = "memory"
cache_size = 10000

# Redis (for distributed deployments)
[graphql.apq]
enabled = true
backend = "redis"
redis_url = "${REDIS_URL}"
key_prefix = "apq:"
ttl = 86400
```

## Client Implementation

### Request Format

APQ uses extensions to send the query hash:

```json
{
    "extensions": {
        "persistedQuery": {
            "version": 1,
            "sha256Hash": "abc123def456..."
        }
    },
    "variables": {
        "id": "user-123"
    }
}
```

### Flow

1. **First request**: Client sends hash only
2. **Cache miss**: Server returns `PersistedQueryNotFound` error
3. **Retry with query**: Client sends hash + full query
4. **Cached**: Server caches query, returns data
5. **Subsequent requests**: Client sends hash only, server uses cache

### Client Code (JavaScript)

```javascript
const sha256 = require('crypto-js/sha256');

async function executeQuery(query, variables) {
    const hash = sha256(query).toString();

    // Try with hash only
    let response = await fetch('/graphql', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            extensions: {
                persistedQuery: { version: 1, sha256Hash: hash }
            },
            variables
        })
    });

    let result = await response.json();

    // If not found, send with full query
    if (result.errors?.[0]?.message === 'PersistedQueryNotFound') {
        response = await fetch('/graphql', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                query,
                extensions: {
                    persistedQuery: { version: 1, sha256Hash: hash }
                },
                variables
            })
        });
        result = await response.json();
    }

    return result;
}
```

### Apollo Client

Apollo Client supports APQ out of the box:

```javascript
import { ApolloClient, InMemoryCache } from '@apollo/client';
import { createPersistedQueryLink } from '@apollo/client/link/persisted-queries';
import { createHttpLink } from '@apollo/client/link/http';
import { sha256 } from 'crypto-hash';

const httpLink = createHttpLink({ uri: '/graphql' });
const persistedQueriesLink = createPersistedQueryLink({ sha256 });

const client = new ApolloClient({
    cache: new InMemoryCache(),
    link: persistedQueriesLink.concat(httpLink)
});
```

### urql

```javascript
import { createClient, fetchExchange } from 'urql';
import { persistedExchange } from '@urql/exchange-persisted';

const client = createClient({
    url: '/graphql',
    exchanges: [
        persistedExchange({
            preferGetForPersistedQueries: true
        }),
        fetchExchange
    ]
});
```

## GET Requests

With APQ, you can use GET requests for cached queries:

```toml
[graphql.apq]
enabled = true
allow_get = true
```

```
GET /graphql?extensions={"persistedQuery":{"version":1,"sha256Hash":"abc123"}}&variables={"id":"123"}
```

Benefits:
- HTTP caching (CDN, browser)
- Bookmarkable URLs
- Reduced server load

## Prepopulating the Cache

For production, prepopulate the APQ cache at build time:

### Extract Queries

```javascript
// extract-queries.js
const fs = require('fs');
const crypto = require('crypto');
const glob = require('glob');

const queries = {};

// Find all GraphQL queries in source
glob.sync('src/**/*.graphql').forEach(file => {
    const query = fs.readFileSync(file, 'utf8');
    const hash = crypto.createHash('sha256').update(query).digest('hex');
    queries[hash] = query;
});

fs.writeFileSync('queries.json', JSON.stringify(queries, null, 2));
```

### Upload to Server

```bash
# Upload extracted queries
fraiseql apq upload --file queries.json
```

### CLI Commands

```bash
# List cached queries
fraiseql apq list

# Clear cache
fraiseql apq clear

# Upload queries
fraiseql apq upload --file queries.json

# Export cached queries
fraiseql apq export --output cached-queries.json
```

## Metrics

Monitor APQ performance:

| Metric | Description |
|--------|-------------|
| `fraiseql_apq_hits_total` | Cache hits |
| `fraiseql_apq_misses_total` | Cache misses |
| `fraiseql_apq_cache_size` | Current cache size |
| `fraiseql_apq_bytes_saved` | Bandwidth saved |

### Grafana Dashboard

```
# APQ hit rate
sum(rate(fraiseql_apq_hits_total[5m])) /
(sum(rate(fraiseql_apq_hits_total[5m])) + sum(rate(fraiseql_apq_misses_total[5m])))

# Bandwidth saved (MB/s)
sum(rate(fraiseql_apq_bytes_saved[5m])) / 1024 / 1024
```

## Security Considerations

### Hash Verification

FraiseQL verifies that the query matches the hash:

```json
// Request
{
    "query": "{ users { id } }",
    "extensions": {
        "persistedQuery": {
            "sha256Hash": "wrong-hash"
        }
    }
}

// Response
{
    "errors": [{
        "message": "Provided sha does not match query"
    }]
}
```

### Query Allowlisting

For maximum security, only allow prepopulated queries:

```toml
[graphql.apq]
enabled = true
require_prepopulated = true  # Reject queries not in cache
```

This prevents arbitrary queries in production.

## Benefits

### Bandwidth Reduction

Typical GraphQL queries are 1-10 KB. Hashes are 64 bytes.

| Query Size | With APQ | Savings |
|------------|----------|---------|
| 1 KB | 64 B | 94% |
| 5 KB | 64 B | 99% |
| 10 KB | 64 B | 99% |

### Latency Improvement

- Less data to transmit
- Faster parsing (no query parsing after first request)
- CDN caching (with GET requests)

### Mobile Benefits

- Reduced cellular data usage
- Faster responses on slow connections
- Better battery life (less radio usage)

## Best Practices

### Warm the Cache

Prepopulate in CI/CD:

```
# .github/workflows/deploy.yml
- name: Extract and upload queries
  run: |
    npm run extract-queries
    fraiseql apq upload --file queries.json
```

### Monitor Hit Rate

Target > 90% hit rate in production:

```
fraiseql_apq_hits_total / (fraiseql_apq_hits_total + fraiseql_apq_misses_total) > 0.9
```

### Size the Cache

```toml
# Estimate: unique queries × 2 (for safety margin)
[graphql.apq]
cache_size = 10000  # For ~5000 unique queries
```

### Use Redis for Distributed

Single-instance memory cache doesn't share across servers:

```toml
# Production with multiple instances
[graphql.apq]
backend = "redis"
redis_url = "${REDIS_URL}"
```

## Troubleshooting

### Low Hit Rate

1. Check client is sending hashes correctly
2. Verify cache TTL isn't too short
3. Check for query variations (different whitespace, variable names)

### Cache Not Working

```bash
# Check APQ status
fraiseql apq status

# Test a query
fraiseql apq lookup --hash "abc123..."
```

### Hash Mismatch

Ensure client and server use same hashing:
- Algorithm: SHA-256
- Input: Query string with normalized whitespace
- Output: Hex-encoded lowercase

## Next Steps

- [Caching](/features/caching) — Response caching
- [Performance](/guides/performance) — Additional optimizations
- [Deployment](/guides/deployment) — Production configuration
`3
`3