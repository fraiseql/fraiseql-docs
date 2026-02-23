---
title: Federation
description: Multi-database federation and saga patterns in FraiseQL
---

FraiseQL supports federation across multiple databases, enabling distributed data access and saga patterns for cross-database transactions.

## Overview

Federation allows you to:
- Query data from multiple databases in a single GraphQL request
- Join entities across database boundaries
- Implement saga patterns for distributed transactions
- Maintain data consistency across services

## Configuring Multiple Databases

### Database Configuration

Define multiple databases in `fraiseql.toml`:

```toml
[databases.primary]
type = "postgresql"
url = "${PRIMARY_DATABASE_URL}"
pool_max = 50

[databases.analytics]
type = "postgresql"
url = "${ANALYTICS_DATABASE_URL}"
pool_max = 20

[databases.legacy]
type = "postgresql"
url = "${LEGACY_DATABASE_URL}"
pool_max = 10
```

### Schema Assignment

Assign types to databases:

```python
import fraiseql

@fraiseql.type(database="primary")
class User:
    id: ID
    name: str
    email: str

@fraiseql.type(database="analytics")
class UserAnalytics:
    user_id: ID
    page_views: int
    sessions: int
    last_active: DateTime

@fraiseql.type(database="legacy")
class LegacyCustomer:
    customer_id: str
    name: str
```python

## Cross-Database Queries

### Federated Fields

Reference types from other databases:

```python
@fraiseql.type(database="primary")
class User:
    id: ID
    name: str
    email: str

    # Federated field from analytics database
    analytics: 'UserAnalytics' = fraiseql.federated(
        database="analytics",
        lookup="user_id"  # Field in UserAnalytics that matches
    )
```

### Query Resolution

FraiseQL resolves federated queries efficiently:

```graphql
query {
    user(id: "...") {
        name
        email
        analytics {  # Fetched from analytics database
            page_views
            sessions
        }
    }
}
```

Execution:
1. Fetch `User` from primary database
2. Fetch `UserAnalytics` from analytics database (using `user_id`)
3. Combine results

### Batched Lookups

For list queries, FraiseQL batches federated lookups:

```graphql
query {
    users(limit: 100) {
        name
        analytics { page_views }
    }
}
```

Instead of 100 individual queries to analytics database, FraiseQL:
1. Fetches all users from primary
2. Batches user IDs
3. Single query to analytics for all matching records

## Entity References

### Defining References

Reference entities by ID across databases:

```python
@fraiseql.type(database="primary")
class Order:
    id: ID
    total: Decimal

    # Reference to user (same database)
    customer: User

    # Reference to inventory (different database)
    items: list['InventoryItem'] = fraiseql.federated(
        database="inventory",
        lookup="order_id"
    )

@fraiseql.type(database="inventory")
class InventoryItem:
    id: ID
    order_id: ID  # Reference back
    product_sku: str
    quantity: int
```

### Resolution Keys

Customize how entities are matched:

```python
@fraiseql.type(database="legacy")
class LegacyCustomer:
    customer_id: str  # Legacy uses string IDs
    name: str

@fraiseql.type(database="primary")
class User:
    id: ID
    legacy_customer_id: str  # Link to legacy

    legacy_data: 'LegacyCustomer' = fraiseql.federated(
        database="legacy",
        local_key="legacy_customer_id",  # Field on User
        remote_key="customer_id"          # Field on LegacyCustomer
    )
```

## Saga Patterns

### Distributed Transactions

For operations spanning multiple databases, use sagas:

```python
from fraiseql import saga, compensate

@fraiseql.mutation(operation="CREATE")
@saga(steps=["create_order", "reserve_inventory", "process_payment"])
def create_order(
    customer_id: ID,
    items: list[OrderItemInput]
) -> Order:
    """
    Saga steps:
    1. Create order in primary database
    2. Reserve inventory in inventory database
    3. Process payment in payment database

    If any step fails, previous steps are compensated.
    """
    pass
```

### Saga Steps

Define individual saga steps:

```python
@saga.step("create_order", database="primary")
def step_create_order(ctx, customer_id, items):
    """Create the order record."""
    return fn_create_order(customer_id, items)

@saga.step("reserve_inventory", database="inventory")
def step_reserve_inventory(ctx, order_id, items):
    """Reserve inventory for order items."""
    return fn_reserve_inventory(order_id, items)

@saga.step("process_payment", database="payments")
def step_process_payment(ctx, order_id, amount):
    """Charge customer payment method."""
    return fn_process_payment(order_id, amount)
```

### Compensation

Define compensation for rollback:

```python
@compensate("create_order")
def compensate_create_order(ctx, order_id):
    """Cancel the order if later steps fail."""
    fn_cancel_order(order_id)

@compensate("reserve_inventory")
def compensate_reserve_inventory(ctx, reservation_id):
    """Release reserved inventory."""
    fn_release_inventory(reservation_id)

# Payment step has no compensation - it's the final step
```

### Saga Execution

```
create_order → reserve_inventory → process_payment
      ↓              ↓                   ↓
   SUCCESS        SUCCESS            FAILURE
      ↓              ↓                   ↓
      ↓              ↓         compensate_reserve_inventory
      ↓              ↓                   ↓
      ↓         compensate_create_order ←┘
      ↓              ↓
   ROLLBACK ←────────┘
```

## Federated Mutations

### Cross-Database Writes

```python
@fraiseql.mutation(operation="CREATE")
def create_user_with_analytics(
    name: str,
    email: str
) -> User:
    """
    Creates user in primary database and
    initializes analytics in analytics database.
    """
    pass
```

SQL implementation spans databases:

```sql
-- Primary database
CREATE FUNCTION fn_create_user_federated(
    user_name TEXT,
    user_email TEXT
) RETURNS UUID AS $$
DECLARE
    new_user_id UUID;
BEGIN
    -- Create user locally
    INSERT INTO tb_user (name, email, identifier)
    VALUES (user_name, user_email, user_email)
    RETURNING id INTO new_user_id;

    -- Signal analytics database (via NOTIFY or direct call)
    PERFORM pg_notify('user_created', new_user_id::text);

    RETURN new_user_id;
END;
$$ LANGUAGE plpgsql;
```

Analytics database listener:

```sql
-- Analytics database
CREATE FUNCTION init_user_analytics() RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO tb_user_analytics (user_id, page_views, sessions)
    VALUES (NEW.id, 0, 0);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

## Consistency Patterns

### Eventual Consistency

For non-critical data, accept eventual consistency:

```python
@fraiseql.type(database="primary")
class User:
    id: ID
    name: str

    # May be slightly stale
    analytics: UserAnalytics = fraiseql.federated(
        database="analytics",
        consistency="eventual"  # Default
    )
```

### Strong Consistency

For critical data, require strong consistency:

```python
@fraiseql.type(database="primary")
class Account:
    id: ID
    balance: Decimal

    # Must be consistent
    transactions: list[Transaction] = fraiseql.federated(
        database="ledger",
        consistency="strong"  # Uses distributed locks
    )
```

### Read-Your-Writes

Ensure users see their own writes:

```python
@fraiseql.mutation(operation="CREATE")
def create_post(author_id: ID, title: str) -> Post:
    """Post is immediately visible to author."""
    pass

@fraiseql.query(sql_source="v_post")
def my_posts(author_id: ID) -> list[Post]:
    """Includes posts just created by this author."""
    pass
```

## Configuration Options

```toml
[federation]
enabled = true
default_timeout = 5000  # ms
batch_size = 100

[federation.retry]
max_attempts = 3
backoff = "exponential"

[federation.circuit_breaker]
enabled = true
failure_threshold = 5
reset_timeout = 30000  # ms
```

## Monitoring

### Federation Metrics

| Metric | Description |
|--------|-------------|
| `fraiseql_federation_requests_total` | Total federated requests |
| `fraiseql_federation_latency_seconds` | Cross-database latency |
| `fraiseql_federation_errors_total` | Federation errors |
| `fraiseql_saga_steps_total` | Saga step executions |
| `fraiseql_saga_compensations_total` | Saga compensations |

### Tracing

Federation adds spans for cross-database calls:

```json
[request] user(id: "...")
├── [span] primary.v_user
└── [span] analytics.v_user_analytics (federated)
```

## Best Practices

### Minimize Cross-Database Joins

```python
# Avoid: Many federated fields
@fraiseql.type
class Order:
    customer: User = fraiseql.federated(...)
    payment: Payment = fraiseql.federated(...)
    shipping: Shipping = fraiseql.federated(...)
    items: list[Item] = fraiseql.federated(...)

# Better: Denormalize critical data
@fraiseql.type
class Order:
    customer_name: str  # Denormalized
    payment_status: str  # Denormalized
    items: list[Item] = fraiseql.federated(...)
```

### Use Saga for Critical Flows

```python
# Use sagas for:
# - Financial transactions
# - Inventory management
# - User registration across services

# Skip sagas for:
# - Analytics updates
# - Cache invalidation
# - Non-critical notifications
```

### Handle Partial Failures

```python
@fraiseql.query(sql_source="v_user")
def user_with_analytics(id: ID) -> UserWithAnalytics:
    """
    Returns user even if analytics database is unavailable.
    analytics field will be null.
    """
    pass
```

## Next Steps

- [NATS Integration](/features/nats) — Real-time across databases
- [Security](/features/security) — Cross-database authorization
- [Performance](/guides/performance) — Federation optimization