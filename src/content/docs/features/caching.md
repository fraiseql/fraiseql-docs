---
title: Caching
description: Response caching and cache invalidation with graphql-cascade
---

FraiseQL provides intelligent response caching with automatic invalidation based on data dependencies.

## Overview

FraiseQL caching:
- Caches GraphQL responses
- Tracks entity dependencies
- Automatically invalidates on mutations
- Supports Redis and in-memory backends

## Configuration

### Enable Caching

```toml
[cache]
enabled = true
provider = "memory"
ttl = 300  # 5 minutes default

[cache.memory]
max_size = 10000  # Max cached responses
```

### Redis Backend

```toml
[cache]
enabled = true
provider = "redis"
ttl = 300

[cache.redis]
url = "${REDIS_URL}"
prefix = "fraiseql:cache:"
```

### Per-Query TTL

```python
@fraiseql.query(
    sql_source="v_user",
    cache_ttl=3600  # Cache for 1 hour
)
def user(id: ID) -> User | None:
    pass

@fraiseql.query(
    sql_source="v_post",
    cache_ttl=60  # Cache for 1 minute (frequently updated)
)
def posts(limit: int = 20) -> list[Post]:
    pass
```

### Disable Caching

```python
@fraiseql.query(
    sql_source="v_user",
    cache=False  # Never cache this query
)
def me() -> User:
    """Current user - always fresh."""
    pass
```

## Cache Keys

Cache keys are computed from:
- Query name
- Variables
- User context (if relevant)

```
fraiseql:cache:user:{"id":"123"}
fraiseql:cache:posts:{"limit":20,"offset":0}
```

### User-Scoped Caching

For user-specific data:

```python
@fraiseql.query(
    sql_source="v_order",
    cache_scope="user"  # Cache per-user
)
def my_orders() -> list[Order]:
    pass
```

Cache key includes user ID:

```
fraiseql:cache:my_orders:user:456:{"limit":20}
```

## Automatic Invalidation

### Entity Tracking

FraiseQL tracks which entities are in each cached response:

```graphql
query {
    post(id: "123") {
        id
        title
        author { id name }
        comments { id content }
    }
}
```

Tracked entities:
- `Post:123`
- `User:456` (author)
- `Comment:789`, `Comment:790` (comments)

### Mutation Invalidation

When entities are mutated, related caches are invalidated:

```graphql
# This mutation
mutation {
    updatePost(id: "123", title: "New Title") { id }
}

# Invalidates all caches containing Post:123
```

### Cascade Rules

Configure how invalidation cascades:

```toml
[cache.invalidation]
cascade = true

[cache.invalidation.rules]
# When a Comment is added, invalidate parent Post
Comment = ["Post"]

# When a Post is updated, invalidate author's stats
Post = ["User"]
```

## graphql-cascade Integration

FraiseQL uses graphql-cascade for fine-grained cache control.

### Cache Hints

Add cache hints in responses:

```python
@fraiseql.query(sql_source="v_post")
def posts() -> list[Post]:
    """
    Cache hints:
    - max-age: 300
    - stale-while-revalidate: 60
    - entities: Post, User
    """
    pass
```

### Response Headers

```
Cache-Control: max-age=300, stale-while-revalidate=60
X-Cache-Tags: Post:123,User:456,Comment:789
```

### CDN Integration

Configure CDN cache headers:

```toml
[cache.cdn]
enabled = true
vary = ["Authorization"]
surrogate_keys = true  # For Fastly/Cloudflare
```

## Cache Warming

### Startup Warming

Warm cache on server startup:

```toml
[cache.warm]
enabled = true
queries = [
    "popularPosts",
    "featuredProducts",
    "siteConfig"
]
```

### Background Refresh

Refresh cache before expiry:

```toml
[cache.background_refresh]
enabled = true
threshold = 0.8  # Refresh when 80% of TTL elapsed
```

## Cache Patterns

### Read-Through

Default behavior - cache miss triggers database query:

```
        ─            ─          ─           ─
        ─           ─
```

### Write-Through

Update cache on mutations:

```python
@fraiseql.mutation(
    sql_source="fn_update_user",
    operation="UPDATE",
    cache_update=True  # Update cache after mutation
)
def update_user(id: ID, name: str) -> User:
    pass
```

### Cache-Aside

Manually manage cache:

```python
from fraiseql import cache

async def get_user_with_cache(id: str):
    # Check cache
    cached = await cache.get(f"user:{id}")
    if cached:
        return cached

    # Fetch from database
    user = await fetch_user(id)

    # Update cache
    await cache.set(f"user:{id}", user, ttl=3600)

    return user
```

## Stale-While-Revalidate

Serve stale data while refreshing:

```toml
[cache]
stale_while_revalidate = 60  # Serve stale for 60s while refreshing
```

```python
┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│    Fresh    │ Stale-While-    │     Stale                               │                                                                         │
↓             │ Revalidate      │                                         ↓                                                                         │
│─────────────┼─────────────────┼─────────────────                                                                                                  │
│  0 - 300s   │  300 - 360s     │    > 360s                               │                                                                         │
│   (TTL)     │  (SWR window)   │   (Expired)                             │                                                                         │
│             │                 │                                         │                                                                         │
│ Serve from  │ Serve stale,    │ Fetch fresh,                            │                                                                         │
↓ cache       │ refresh bg      │ then serve                              ↓                                                                         ↓
└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

## Metrics

Monitor cache performance:

| Metric | Description |
|--------|-------------|
| `fraiseql_cache_hits_total` | Cache hits |
| `fraiseql_cache_misses_total` | Cache misses |
| `fraiseql_cache_invalidations_total` | Invalidations |
| `fraiseql_cache_size_bytes` | Current cache size |
| `fraiseql_cache_latency_seconds` | Cache operation latency |

### Hit Rate

```
# Cache hit rate
sum(rate(fraiseql_cache_hits_total[5m])) /
(sum(rate(fraiseql_cache_hits_total[5m])) + sum(rate(fraiseql_cache_misses_total[5m])))
```

Target: > 80% hit rate for read-heavy workloads.

## Debugging

### Cache Status Header

```toml
[cache]
debug_header = true
```

Response includes:

```
X-Cache: HIT
X-Cache-TTL: 245
X-Cache-Key: posts:{"limit":20}
```

### CLI Commands

```bash
# View cache stats
fraiseql cache stats

# Inspect a key
fraiseql cache get --key "user:123"

# Clear specific key
fraiseql cache delete --key "user:123"

# Clear all cache
fraiseql cache clear

# Clear by pattern
fraiseql cache clear --pattern "posts:*"
```

## Best Practices

### Set Appropriate TTLs

| Data Type | TTL | Reason |
|-----------|-----|--------|
| User profiles | 1 hour | Changes infrequently |
| Posts list | 5 minutes | Updates occasionally |
| Real-time data | 0 (no cache) | Must be fresh |
| Static config | 24 hours | Rarely changes |

### Size the Cache

```
cache_size = (requests_per_second × average_ttl × unique_query_ratio)
```





  ─

### Use Redis for Production

```toml
# Development
[cache]
provider = "memory"

# Production
[cache]
provider = "redis"
```

Benefits:
- Shared across instances
- Survives restarts
- Better eviction

### Monitor Invalidation Rate

High invalidation rate indicates:
- Over-caching mutable data
- Too-aggressive cascade rules
- Cache not effective

```
rate(fraiseql_cache_invalidations_total[5m]) / rate(fraiseql_cache_hits_total[5m]) < 0.1
```

## Troubleshooting

### Cache Not Working

1. Verify caching is enabled: `fraiseql cache stats`
2. Check query doesn't have `cache=False`
3. Verify TTL isn't 0
4. Check Redis connection (if using Redis)

### Low Hit Rate

1. TTL too short?
2. High mutation rate?
3. Too many unique queries?
4. User-scoped caching spreading cache thin?

### Stale Data

1. Invalidation not triggering?
2. Check cascade rules
3. Verify entity tracking
4. Check mutation hooks

## Next Steps

- [APQ](/features/apq) — Reduce query overhead
- [Performance](/guides/performance) — Overall optimization
- [Deployment](/guides/deployment) — Production cache setup
`3
`3