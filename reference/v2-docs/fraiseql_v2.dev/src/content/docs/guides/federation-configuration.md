---
title: Multi-Database Federation Configuration
description: Configure FraiseQL to query across multiple databases
---

Multi-database federation enables FraiseQL to query, join, and aggregate data across PostgreSQL, MySQL, SQLite, and SQL Server instances simultaneously. This guide covers configuration, schema mapping, performance tuning, and production best practices.

## Overview

Federation architecture:

```
┌─────────────────────────────────────────┐
│    FraiseQL GraphQL API Layer           │
│    (Query Planning & Execution)         │
└────────┬────────────────┬────────────────┘
         │                │
    ┌────▼─────┐     ┌─────▼────┐
    │ Users DB │     │ Orders DB │
    │PostgreSQL│     │   MySQL   │
    └──────────┘     └───────────┘
         ▲                ▲
         │ Direct SQL     │ Direct SQL
         │ Execution      │ Execution
```

Why federate?
- **Microservices**: Independently deployed databases
- **Legacy systems**: Integrate without refactoring
- **Vendor lock-in**: Use best database for each use case
- **Multi-region**: Query across geographic regions
- **Performance**: Parallelize queries across databases

## Basic Multi-Database Setup

### Configuration File Structure

Create `fraiseql.toml` with multiple database definitions:

```toml
# fraiseql.toml

# Primary database (default for all queries)
[databases.default]
driver = "postgresql"
host = "localhost"
port = 5432
database = "fraiseql"
username = "${DB_USERNAME}"
password = "${DB_PASSWORD}"
pool_size = 10

# Users database (separate PostgreSQL instance)
[databases.users_db]
driver = "postgresql"
host = "users.internal.example.com"
port = 5432
database = "users"
username = "${USERS_DB_USERNAME}"
password = "${USERS_DB_PASSWORD}"
pool_size = 10
ssl_mode = "require"

# Orders database (MySQL)
[databases.orders_db]
driver = "mysql"
host = "orders.internal.example.com"
port = 3306
database = "orders"
username = "${ORDERS_DB_USERNAME}"
password = "${ORDERS_DB_PASSWORD}"
pool_size = 20
charset = "utf8mb4"

# Analytics database (SQL Server)
[databases.analytics_db]
driver = "sqlserver"
host = "analytics.internal.example.com"
port = 1433
database = "analytics"
username = "${ANALYTICS_DB_USERNAME}"
password = "${ANALYTICS_DB_PASSWORD}"
pool_size = 5

# Legacy SQLite database (file-based)
[databases.legacy_db]
driver = "sqlite"
path = "/data/legacy.db"
pool_size = 2
```

### Environment Variables

Store secrets securely:

```bash
# .env
DB_USERNAME=fraiseql_user
DB_PASSWORD=secure_password_here

USERS_DB_USERNAME=users_service
USERS_DB_PASSWORD=users_password_here

ORDERS_DB_USERNAME=orders_service
ORDERS_DB_PASSWORD=orders_password_here

ANALYTICS_DB_USERNAME=analytics_service
ANALYTICS_DB_PASSWORD=analytics_password_here
```

## Federation Configuration

### Global Settings

```toml
[federation]
# Enable multi-database queries
enabled = true

# Timeout for entire federation query (not per-database)
timeout = "30s"

# Maximum parallel queries to different databases
max_concurrent_queries = 100

# Join strategy (see below)
join_strategy = "parallel"

# Query planning cache
planning_cache_enabled = true
planning_cache_size = 1000
```

### Circuit Breaker

Prevent cascading failures:

```toml
[federation.circuit_breaker]
enabled = true

# Fail-open after N consecutive failures
failure_threshold = 5

# How long to stay open before trying again
timeout = "60s"

# Half-open state: allow N requests to test recovery
half_open_requests = 3

# Per-database override
[federation.circuit_breaker.per_database.orders_db]
failure_threshold = 10
timeout = "120s"
```

### Retry Policy

Handle transient failures:

```toml
[federation.retry]
# Maximum attempts per query
max_attempts = 3

# Backoff strategy: linear, exponential, or fibonacci
backoff = "exponential"

# Initial delay before first retry
initial_delay = "100ms"

# Maximum delay between retries
max_delay = "5s"

# Don't retry on these HTTP status codes
dont_retry_on = [400, 401, 403, 404]

# Per-database override
[federation.retry.per_database.analytics_db]
max_attempts = 5
backoff = "linear"
initial_delay = "50ms"
```

## Schema Mapping

### Assigning Tables to Databases

```python
from fraiseql import type, federation

@type
@federation.database("users_db")
class User:
    id: ID
    email: str
    name: str
    created_at: datetime

@type
@federation.database("orders_db")
class Order:
    id: ID
    user_id: ID  # Foreign key to users_db
    total: float
    created_at: datetime

@type
@federation.database("analytics_db")
class UserAnalytics:
    user_id: ID
    total_orders: int
    lifetime_value: float
```

### Cross-Database Relationships

Link entities across databases:

```python
from fraiseql import type, relationship

@type
@federation.database("users_db")
class User:
    id: ID
    email: str
    # Join with orders_db.orders
    orders: list["Order"] = relationship(
        foreign_key="orders.user_id",
        database="orders_db"
    )
    analytics: "UserAnalytics" = relationship(
        foreign_key="user_analytics.user_id",
        database="analytics_db"
    )

@type
@federation.database("orders_db")
class Order:
    id: ID
    user_id: ID
    total: float
    # Back-reference to users_db
    user: "User" = relationship(
        foreign_key="user_id",
        database="users_db"
    )
```

### Type Compatibility Matrix

When joining across databases, types must be compatible:

```
PostgreSQL UUID  ←→  MySQL VARCHAR(36)  ←→  SQL Server UNIQUEIDENTIFIER
PostgreSQL BIGINT ←→ MySQL BIGINT        ←→ SQL Server BIGINT
PostgreSQL JSONB ←→  MySQL JSON         ←→ SQL Server NVARCHAR(MAX)
PostgreSQL TIMESTAMP ←→ MySQL DATETIME ←→ SQL Server DATETIME2
```

FraiseQL handles type conversion automatically:

```python
# Automatic conversion from different database types
@type
@federation.database("users_db")  # PostgreSQL UUID
class User:
    id: ID  # PostgreSQL UUID type

@type
@federation.database("orders_db")  # MySQL CHAR(36)
class Order:
    user_id: ID  # MySQL CHAR(36) - auto-converted to UUID

# Join works transparently
query {
    user(id: "550e8400-e29b-41d4-a716-446655440000") {
        orders {  # Joins UUID to CHAR(36)
            id
        }
    }
}
```

## Connection Pooling per Database

### Pool Configuration

```toml
# High-traffic database: larger pool
[databases.orders_db]
driver = "mysql"
pool_size = 50          # Maximum connections
min_idle = 10           # Keep connections warm
max_lifetime = "30m"    # Recycle connections
connection_timeout = "5s"

# Occasional analytics queries: small pool
[databases.analytics_db]
driver = "sqlserver"
pool_size = 5
min_idle = 0            # Don't keep idle connections
max_lifetime = "1h"
connection_timeout = "10s"

# Legacy system: minimal pool
[databases.legacy_db]
driver = "sqlite"
pool_size = 2
```

### Pool Monitoring

Monitor connection pool health:

```python
from fraiseql.federation import get_federation_stats

stats = get_federation_stats()
print(f"Orders DB pool: {stats['orders_db'].active_connections}/50")
print(f"Analytics pool: {stats['analytics_db'].active_connections}/5")
```

## Federation Strategies

### Parallel Execution

Query all databases simultaneously:

```toml
[federation]
join_strategy = "parallel"
```

```python
# GraphQL query:
query {
    user(id: "123") {
        id
        email
        orders {           # Queries orders_db in parallel
            id
            total
        }
        analytics {        # Queries analytics_db in parallel
            total_orders
            lifetime_value
        }
    }
}
```

**Execution timeline:**
```
Time: 0ms  Start
        ├─ PostgreSQL query: SELECT user
        ├─ MySQL query: SELECT orders WHERE user_id=123
        └─ SQL Server query: SELECT analytics WHERE user_id=123
     300ms ✓ All results returned
```

### Sequential Execution

Query databases in order:

```toml
[federation]
join_strategy = "sequential"
```

```python
# First query users_db, then orders_db, then analytics_db
query {
    user(id: "123") {
        orders {
            analytics {
                # Each level waits for previous
            }
        }
    }
}
```

**Execution timeline:**
```
Time: 0ms   Start PostgreSQL query
     100ms  ✓ Get user, use ID for next query
     100ms  Start MySQL query (WHERE user_id=123)
     200ms  ✓ Get orders, use order_id for next query
     200ms  Start SQL Server query
     400ms  ✓ All results returned
```

### Conditional Execution

Query based on previous results:

```python
from fraiseql import type, field

@type
@federation.database("users_db")
class User:
    id: ID
    email: str

    @field
    async def orders(self) -> list["Order"]:
        # Only fetch orders if user is premium
        if not await self.is_premium():
            return []

        # Query orders_db
        return await Order.query(user_id=self.id)

    async def is_premium(self) -> bool:
        # Check analytics_db
        analytics = await UserAnalytics.query(user_id=self.id)
        return analytics.lifetime_value > 10000
```

## Performance Tuning

### Query Planning

FraiseQL optimizes cross-database queries:

```python
# ✅ Good: Parallel queries
query {
    users {           # PostgeSQL
        id
        name
        orders {      # MySQL - parallel fetch
            total
        }
    }
}

# ❌ Bad: Sequential nested queries
query {
    users {           # PostgreSQL
        orders {      # MySQL - wait for each user ID
            items {   # SQLite - wait for each order ID
                details
            }
        }
    }
}
```

Enable query caching:

```toml
[federation]
planning_cache_enabled = true
planning_cache_size = 1000

[federation.query_caching]
enabled = true
ttl = "1h"
max_size = "100MB"
```

### Connection Reuse

```toml
# Keep connections alive between requests
[databases.users_db]
idle_timeout = "10m"
pool_recycle = "30m"
```

### Result Batching

Reduce round-trips with batch operations:

```python
# Instead of N queries
for user_id in user_ids:
    orders = await Order.query(user_id=user_id)

# Use batch API
orders_by_user = await Order.batch_query(
    user_ids=user_ids,
    index_by="user_id"
)
```

### Denormalization Strategy

```python
# ❌ Always join across databases
@type
class User:
    order_count: int  # Requires query to orders_db

# ✅ Cache in local database
@type
@federation.database("users_db")
class User:
    order_count: int  # Cached, updated by observer

    @observer(entity="Order", event="INSERT")
    def on_order_created():
        # Update order count in users_db
        pass
```

## Security Considerations

### Per-Database Credentials

```toml
[databases.users_db]
username = "${VAULT:database/creds/users/username}"
password = "${VAULT:database/creds/users/password}"

[databases.orders_db]
username = "${VAULT:database/creds/orders/username}"
password = "${VAULT:database/creds/orders/password}"
```

Supports:
- Environment variables: `${ENV_VAR}`
- HashiCorp Vault: `${VAULT:path/to/secret}`
- AWS Secrets Manager: `${AWS:secret-name}`
- Google Secret Manager: `${GCP:secret-name}`

### Connection Encryption

```toml
# PostgreSQL with SSL/TLS
[databases.users_db]
driver = "postgresql"
ssl_mode = "require"
ssl_root_cert = "/etc/ssl/certs/ca.crt"

# MySQL with SSL
[databases.orders_db]
driver = "mysql"
ssl_mode = "REQUIRED"
ssl_ca = "/etc/ssl/certs/ca.crt"
ssl_cert = "/etc/ssl/certs/client.crt"
ssl_key = "/etc/ssl/private/client.key"

# SQL Server with encryption
[databases.analytics_db]
driver = "sqlserver"
encrypt = "true"
trust_server_certificate = false
```

### Query Isolation

```python
# Enforce per-user database access
from fraiseql.security import require_auth

@type
class User:
    @require_auth(roles=["admin"])
    @federation.database("users_db")
    async def profile(self) -> "UserProfile":
        # Only admins can see profile from users_db
        pass
```

## Monitoring Federation

### Prometheus Metrics

```toml
[observability.prometheus]
enabled = true
port = 9090

# Per-database metrics
[observability.prometheus.federation]
track_per_database = true
track_query_plans = true
```

Exposed metrics:
```
fraiseql_federation_query_duration_seconds{database="orders_db"}
fraiseql_federation_query_errors_total{database="orders_db"}
fraiseql_federation_connection_pool_size{database="orders_db"}
fraiseql_federation_connection_pool_active{database="orders_db"}
fraiseql_federation_circuit_breaker_state{database="orders_db"}
```

### Distributed Tracing

```toml
[observability.tracing]
enabled = true
exporter = "jaeger"  # or "datadog", "honeycomb"
service_name = "fraiseql-api"

[observability.tracing.federation]
trace_per_database = true
trace_joins = true
```

Trace output shows:
- Database being queried
- Query execution time
- Connection pool wait time
- Network latency

### Grafana Dashboard

Import dashboard for federation monitoring:

```json
{
  "panels": [
    {
      "title": "Database Query Latency",
      "targets": [
        {
          "expr": "fraiseql_federation_query_duration_seconds"
        }
      ]
    },
    {
      "title": "Connection Pool Status",
      "targets": [
        {
          "expr": "fraiseql_federation_connection_pool_active / fraiseql_federation_connection_pool_size"
        }
      ]
    },
    {
      "title": "Circuit Breaker State",
      "targets": [
        {
          "expr": "fraiseql_federation_circuit_breaker_state"
        }
      ]
    }
  ]
}
```

## Database-Specific Features

### PostgreSQL Advantages

```toml
[databases.users_db]
driver = "postgresql"

# Use PostgreSQL-specific features through FraiseQL
```

```python
# Leverage LISTEN/NOTIFY for real-time updates
@type
@federation.database("users_db")
class User:
    @subscription
    async def on_user_created(self) -> "User":
        async for user in User.listen_to("users:created"):
            yield user

# Full-text search
@type
class BlogPost:
    @field
    async def search(self, query: str) -> list["BlogPost"]:
        # PostgreSQL full-text search
        return await BlogPost.query(
            search_vector=f"@@ plainto_tsquery('{query}')"
        )
```

### MySQL Optimizations

```toml
[databases.orders_db]
driver = "mysql"
charset = "utf8mb4"
```

```python
# Bulk operations
orders = await Order.batch_insert([
    {"user_id": 1, "total": 100},
    {"user_id": 2, "total": 200},
    # ... 1000s of orders
], batch_size=1000)
```

### SQL Server Indexed Views

```toml
[databases.analytics_db]
driver = "sqlserver"
```

```python
# Aggregate views for fast analytics
@type
@federation.database("analytics_db")
class UserStats:
    # Backed by SQL Server indexed view
    user_id: ID
    total_spent: float
    order_count: int
```

### SQLite Limitations and Workarounds

```toml
[databases.legacy_db]
driver = "sqlite"
```

SQLite limitations:
- No concurrent writes
- Limited data types
- No distributed transactions

Workarounds:
```python
# Use SQLite for read-heavy, small datasets
@type
@federation.database("legacy_db")
class Config:
    key: str
    value: str

    # Async reads are safe
    @field
    async def get_all(self) -> dict:
        return await Config.query()

# Don't federate writes from SQLite
# Instead, write to primary DB and sync periodically
```

## Complete Real-World Example

SaaS platform with multi-tenant federation:

```toml
# fraiseql.toml

[databases.default]
driver = "postgresql"
host = "primary.example.com"
database = "fraiseql"

[databases.users]
driver = "postgresql"
host = "users-replica.example.com"
database = "users"

[databases.orders]
driver = "mysql"
host = "orders.example.com"
database = "orders"

[databases.analytics]
driver = "sqlserver"
host = "analytics.example.com"
database = "analytics"

[federation]
enabled = true
timeout = "30s"
max_concurrent_queries = 100
join_strategy = "parallel"

[federation.circuit_breaker]
failure_threshold = 5

[federation.retry]
max_attempts = 3
backoff = "exponential"
```

```python
from fraiseql import type, federation, relationship

@type
@federation.database("users")
class User:
    id: ID
    tenant_id: ID
    email: str
    created_at: datetime

    orders: list["Order"] = relationship(
        foreign_key="orders.user_id",
        database="orders"
    )
    analytics: "UserAnalytics" = relationship(
        foreign_key="user_analytics.user_id",
        database="analytics"
    )

@type
@federation.database("orders")
class Order:
    id: ID
    user_id: ID
    tenant_id: ID
    total: float
    created_at: datetime

@type
@federation.database("analytics")
class UserAnalytics:
    tenant_id: ID
    user_id: ID
    total_orders: int
    lifetime_value: float
    last_order_date: datetime
```

## Troubleshooting

### Connection Issues

```
Error: "users_db connection timeout"

Solution 1: Increase timeout
[federation]
timeout = "60s"

Solution 2: Check credentials
[databases.users_db]
username = "${USERS_DB_USERNAME}"
password = "${USERS_DB_PASSWORD}"

Solution 3: Verify network connectivity
```

### Type Mismatches

```
Error: "Cannot join UUID to CHAR(36)"

Solution: FraiseQL auto-converts, but ensure field types match
```

### Query Performance

```
Problem: Slow cross-database joins

Solution 1: Use parallel strategy
[federation]
join_strategy = "parallel"

Solution 2: Add database indexes on join columns
CREATE INDEX idx_orders_user_id ON orders(user_id);

Solution 3: Batch operations instead of N+1
```

## Next Steps

- **[Federation Guide](../features/federation.md)** - Core federation concepts
- **[NATS Integration](../features/nats.md)** - Distributed messaging
- **[Performance Benchmarks](./performance-benchmarks.md)** - Real-world metrics
