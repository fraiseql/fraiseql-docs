---
title: Federation + NATS Integration
description: Coordinating synchronous federation with asynchronous event-driven architecture
---

# Federation + NATS Integration

This guide shows how to combine FraiseQL's federation (synchronous cross-database access) with NATS (asynchronous event-driven communication) to build robust, scalable distributed systems.

## When to Use Each Approach

### Use Federation For:
- **Synchronous queries** requiring immediate results
- **Strong consistency** needs
- **Simple joins** across databases
- **Read-heavy operations** with complex relationships
- **Small result sets** (pagination)







                        ─

### Use Both For:
- **Distributed transactions** (saga pattern with event confirmation)
- **Event sourcing** with live query capability
- **Compliance workflows** (audit events + strong consistency)
- **Microservices with historical queries** (NATS + federation)

## Pattern 1: Synchronous Saga with Event Confirmation

**Use Case**: You need ACID guarantees but want event notifications.

                          ─                 ─

```python
from fraiseql import saga, publish, compensate

@saga(steps=["create_order", "reserve_inventory", "process_payment"])
@fraiseql.mutation
async def create_order_with_events(
    customer_id: ID,
    items: list[dict],
    payment_method_id: ID
) -> Order:
    """
    Synchronous saga that:
    1. Uses federation to coordinate atomically
    2. Publishes events for other services
    3. Returns immediately with guaranteed state
    """
    pass

# Step 1: Create order (federation to primary DB)
@saga.step("create_order", database="primary")
async def step_create_order(ctx, customer_id, items):
    order = await execute_order_creation(customer_id, items)
    ctx.order_id = order['id']

    # Publish event for async subscribers
    await publish(
        subject="fraiseql.order.created",
        data={
            "order_id": order['id'],
            "customer_id": customer_id,
            "total": order['total'],
            "items": items
        }
    )

    return order

# Step 2: Reserve inventory (federation to inventory DB)
@saga.step("reserve_inventory", database="inventory")
async def step_reserve_inventory(ctx, items):
    reservations = await reserve_items_atomically(ctx.order_id, items)
    ctx.reservations = reservations

    # Publish event
    await publish(
        subject="fraiseql.inventory.reserved",
        data={
            "order_id": ctx.order_id,
            "reservations": reservations
        }
    )

    return reservations

# Step 3: Process payment (federation to payments DB)
@saga.step("process_payment", database="payments")
async def step_process_payment(ctx, customer_id, total, payment_method_id):
    transaction = await process_payment_atomically(
        ctx.order_id, customer_id, total, payment_method_id
    )

    # Publish event (final step - no compensation possible)
    await publish(
        subject="fraiseql.payment.processed",
        data={
            "order_id": ctx.order_id,
            "transaction_id": transaction['id'],
            "amount": transaction['amount'],
            "status": "completed"
        }
    )

    ctx.transaction_id = transaction['id']
    return transaction

# Compensation: Use federation to clean up atomically
@compensate("create_order")
async def compensate_order_creation(ctx):
    await cancel_order_atomically(ctx.order_id)

    # Notify others about cancellation
    await publish(
        subject="fraiseql.order.cancelled",
        data={
            "order_id": ctx.order_id,
            "reason": "saga_compensated"
        }
    )

@compensate("reserve_inventory")
async def compensate_inventory_reservation(ctx):
    await release_reservations_atomically(ctx.reservations)

    await publish(
        subject="fraiseql.inventory.released",
        data={
            "order_id": ctx.order_id,
            "reservations": ctx.reservations
        }
    )
```

## Pattern 2: Event Sourcing with Federation Projection

**Use Case**: You want immutable event log + live queries on latest state.

                 ─                                ─

```python
from fraiseql import subscribe, publish
from datetime import datetime
from decimal import Decimal

# Events are published to NATS (immutable log)
# Federation queries read the current projected state

@subscribe("fraiseql.order.>")
async def project_order_state(event: dict):
    """
    Subscribe to all order events and update the projection
    (current state that federation queries read from).
    """

    event_type = event.get("type")
    order_id = event["data"]["order_id"]

    if event_type == "order.created":
        await handle_order_created_event(event)

    elif event_type == "order.confirmed":
        await handle_order_confirmed_event(event)

    elif event_type == "order.shipped":
        await handle_order_shipped_event(event)

    elif event_type == "order.cancelled":
        await handle_order_cancelled_event(event)

async def handle_order_created_event(event: dict):
    """Project order.created event into current state."""

    # Insert into projection table (what federation queries read)
    await execute_sql(
        """
        INSERT INTO tb_order_projection (
            order_id, customer_id, total, status, created_at
        ) VALUES ($1, $2, $3, 'created', NOW())
        """,
        [
            event["data"]["order_id"],
            event["data"]["customer_id"],
            event["data"]["total"]
        ]
    )

async def handle_order_confirmed_event(event: dict):
    """Project order.confirmed event."""

    await execute_sql(
        """
        UPDATE tb_order_projection
        SET status = 'confirmed', updated_at = NOW()
        WHERE order_id = $1
        """,
        [event["data"]["order_id"]]
    )

async def handle_order_shipped_event(event: dict):
    """Project order.shipped event."""

    await execute_sql(
        """
        UPDATE tb_order_projection
        SET status = 'shipped', updated_at = NOW()
        WHERE order_id = $1
        """,
        [event["data"]["order_id"]]
    )

# Now federation queries always read the projected state
@fraiseql.query(sql_source="v_order_projection", database="primary")
def order(id: ID) -> Order:
    """Query reads current projected state."""
    pass

# You can also rebuild projection from events
async def rebuild_projection_from_events(start_time: datetime):
    """Rebuild projection by replaying events from NATS."""

    # Subscribe to all past events
    subscription = await subscribe_to_history(
        subject="fraiseql.order.>",
        start_time=start_time
    )

    async for event in subscription:
        await project_order_state(event)

    print("Projection rebuilt successfully")
```

## Pattern 3: Distributed Transactions with Event Notification

**Use Case**: Atomically update across databases, then notify external systems.

                                   ─                            ─

```python
from fraiseql import saga, publish, request
from typing import Optional
import asyncio

@saga(steps=["update_customer", "update_balance", "record_transaction"])
@fraiseql.mutation
async def transfer_funds_between_accounts(
    from_account_id: ID,
    to_account_id: ID,
    amount: Decimal
) -> dict:
    """
    Transfer funds with:
    1. Federation: Atomic updates to accounts
    2. NATS: Notification to compliance and notifications services
    """
    pass

@saga.step("update_customer", database="primary")
async def step_update_customer(ctx, from_account_id, to_account_id):
    # Ensure both accounts exist
    from_account = await execute_sql(
        "SELECT id FROM tb_account WHERE id = $1 FOR UPDATE",
        [from_account_id]
    )
    to_account = await execute_sql(
        "SELECT id FROM tb_account WHERE id = $1 FOR UPDATE",
        [to_account_id]
    )

    if not from_account or not to_account:
        raise ValueError("One or both accounts not found")

    ctx.from_account_id = from_account_id
    ctx.to_account_id = to_account_id

@saga.step("update_balance", database="ledger")
async def step_update_balance(ctx, amount):
    # Debit from account
    await execute_sql(
        "UPDATE tb_balance SET balance = balance - $1 WHERE account_id = $2",
        [amount, ctx.from_account_id]
    )

    # Credit to account
    await execute_sql(
        "UPDATE tb_balance SET balance = balance + $1 WHERE account_id = $2",
        [amount, ctx.to_account_id]
    )

@saga.step("record_transaction", database="ledger")
async def step_record_transaction(ctx, amount):
    transaction = await execute_sql(
        """
        INSERT INTO tb_transaction (
            from_account_id, to_account_id, amount, status, created_at
        ) VALUES ($1, $2, $3, 'completed', NOW())
        RETURNING id
        """,
        [ctx.from_account_id, ctx.to_account_id, amount]
    )

    ctx.transaction_id = transaction['id']

    # Publish events after atomic completion
    await publish(
        subject="fraiseql.transaction.completed",
        data={
            "type": "transaction.completed",
            "transaction_id": transaction['id'],
            "from_account_id": ctx.from_account_id,
            "to_account_id": ctx.to_account_id,
            "amount": str(amount)
        }
    )

    # Notify compliance service (async, doesn't block response)
    await publish(
        subject="compliance.transaction.created",
        data={
            "transaction_id": transaction['id'],
            "amount": str(amount),
            "timestamp": datetime.utcnow().isoformat()
        }
    )

    return transaction

# External compliance service processes event
@subscribe("compliance.transaction.created")
async def compliance_check_transaction(event: dict):
    """Compliance service checks for suspicious patterns."""

    transaction_id = event["data"]["transaction_id"]
    amount = Decimal(event["data"]["amount"])

    # Check against risk rules
    is_suspicious = await check_against_risk_rules(amount)

    if is_suspicious:
        # Publish alert
        await publish(
            subject="compliance.alert.suspicious_transaction",
            data={
                "transaction_id": transaction_id,
                "amount": str(amount),
                "reason": "exceeds_daily_limit"
            }
        )
```

## Pattern 4: Query + Events (Hybrid Read Model)

**Use Case**: Some data from federation (consistency), some from events (completeness).

```python
@fraiseql.type
class OrderWithHistory:
    # Current state from federation (consistent)
    id: ID
    customer_id: ID
    status: str
    total: Decimal

    # Historical state from event stream
    status_history: list[StatusChange]
    all_events: list[dict]

@fraiseql.query(sql_source="v_order", database="primary")
def order_with_history(id: ID) -> OrderWithHistory:
    """
    Hybrid query:
    1. Get current state from federation
    2. Get event history from NATS
    """
    pass

async def resolve_order_with_history(order_id: ID) -> OrderWithHistory:
    # Parallel fetch: federation query + NATS event replay
    current_order, events = await asyncio.gather(
        # Fetch current state from federation
        fraiseql.query(f"""
            query {{
                order(id: "{order_id}") {{
                    id status total customer_id
                }}
            }}
        """),

        # Fetch event history from NATS
        query_event_history(order_id)
    )

    # Build status history from events
    status_history = [
        StatusChange(
            status=event["data"]["new_status"],
            timestamp=event["timestamp"]
        )
        for event in events
        if event["type"] == "order.status_changed"
    ]

    return OrderWithHistory(
        **current_order,
        status_history=status_history,
        all_events=events
    )

async def query_event_history(order_id: ID) -> list[dict]:
    """Query NATS JetStream for all events for an order."""
    consumer = await nats_connection.jetstream().subscribe(
        subject="fraiseql.order.*",
        deliver_policy="all"  # All messages, starting from beginning
    )

    events = []
    async for msg in consumer:
        event = json.loads(msg.data)
        if event["data"]["order_id"] == order_id:
            events.append(event)

    return events
```

## Handling Partial Failures

When using both federation and NATS, you may have partial failures:

```python
@saga.step("create_and_notify", database="primary")
async def step_create_order_and_notify(ctx, customer_id, items):
    # Step 1: Create order (federation - can fail/compensate)
    order = await execute_order_creation(customer_id, items)
    ctx.order_id = order['id']

    # Step 2: Publish event (NATS - best-effort)
    try:
        await publish(
            subject="fraiseql.order.created",
            data={...}
        )
    except Exception as e:
        # NATS publish failed, but order was created successfully
        # Log it for retry, but don't fail the whole saga
        logging.warning(f"Failed to publish event for order {order['id']}: {e}")

        # Optionally: Store in dead letter table for later retry
        await store_failed_event(
            subject="fraiseql.order.created",
            data={...},
            error=str(e)
        )

        # Continue without failing - NATS is best-effort

    return order
```

## Consistency Models

### Immediate Consistency
Use **federation alone** - synchronous, atomic, consistent.

```python
@fraiseql.query(sql_source="v_order", database="primary")
def order(id: ID) -> Order:
    """Immediate, consistent read."""
    pass
```

### Eventual Consistency
Use **NATS alone** - asynchronous, will eventually be consistent.

```python
@subscribe("fraiseql.order.created")
async def handle_order_created(event: dict):
    """Asynchronous, eventually consistent update."""
    await update_cache(event["data"]["order_id"])
```

### Hybrid Consistency
Use **both together**:
- Write: Federation (immediate consistency)
- Read: Federation for current state + NATS for history/audit

```python
# Write with federation
await create_order_via_federation(...)

# Read current + events
current_order = await federation_query(...)
history = await nats_event_query(...)
```

## Monitoring Combined Workflows

```python
import time
from datetime import datetime

@fraiseql.mutation
async def monitored_create_order(customer_id, items) -> Order:
    """Create order with monitoring."""

    start_time = time.time()

    try:
        # Federation saga
        federation_start = time.time()
        order = await execute_saga(customer_id, items)
        federation_duration = time.time() - federation_start

        # Event publishing
        nats_start = time.time()
        await publish_order_events(order)
        nats_duration = time.time() - nats_start

        # Record metrics
        await metrics.observe("order.creation.federation_duration", federation_duration)
        await metrics.observe("order.creation.nats_duration", nats_duration)
        await metrics.increment("orders.created")

        return order

    except Exception as e:
        await metrics.increment(f"order.creation.error.{type(e).__name__}")
        raise
    finally:
        total_duration = time.time() - start_time
        await metrics.observe("order.creation.total_duration", total_duration)
```

## Best Practices

### 1. Order Matters
```python
# GOOD: Write with federation first, publish after
order = await federation_saga(...)  # Atomic
await publish_event(order)  # Notification

# BAD: Publish before federation is complete
await publish_event(...)  # Event published
order = await federation_saga(...)  # What if this fails?
```

### 2. Idempotent Publishing
```python
# GOOD: Include order ID in event, publish idempotently
await publish(
    subject="fraiseql.order.created",
    data={"order_id": order_id, ...},
    idempotency_key=order_id  # Prevents duplicates
)

# If publish fails, retry is safe
```

### 3. Compensation Across Both Systems
```python
@compensate("saga_step")
async def compensate_with_notification():
    # Undo federation changes
    await federation_cleanup(...)

    # Notify others of cleanup
    await publish(
        subject="fraiseql.saga.compensated",
        data={...}
    )
```

### 4. Fallback Patterns
```python
try:
    # Try federation first (consistent)
    result = await federation_query(...)
except TimeoutError:
    # Fall back to cached/eventual result
    result = await cache.get(...) or await nats_query(...)
```

## Related Guides

- [Federation](/features/federation) - Synchronous federation reference
- [NATS Integration](/features/nats) - Event-driven NATS reference
- [Federation Example](/examples/federation-ecommerce) - Complete federation example
- [NATS Example](/examples/nats-event-pipeline) - Complete event pipeline example
- [Error Handling](/guides/error-handling) - Error recovery patterns
- [Multi-Tenancy](/guides/multi-tenancy) - Scaling across tenants
