---
title: NATS Event Pipeline Example
description: Event-driven order processing using NATS, JetStream, and FraiseQL
---

# NATS Event Pipeline: Order Processing System

This guide demonstrates a complete event-driven order processing system using FraiseQL's NATS integration with JetStream persistence, CDC (Change Data Capture), and multiple microservices.

## Architecture Overview

```

│                                                           │
↓                                                           ↓

                  │
                  │
                  ↓

        │                                               │
        ↓                                               ↓

        │                                               │
        │                                               │
        │                                               │
        ↓                                               ↓






 │       │  │           │ │        │        │          │
 ↓       ↓  ↓           ↓ ↓        ↓        ↓          ↓
```

## NATS Configuration

```toml
# fraiseql.toml

[nats]
enabled = true
urls = ["nats://localhost:4222"]
prefix = "fraiseql"

[nats.auth]
type = "token"
token = "${NATS_TOKEN}"

# Enable CDC (Change Data Capture)
[nats.cdc]
enabled = true
tables = ["tb_order", "tb_order_item", "tb_inventory", "tb_shipping"]

# JetStream configuration
[nats.jetstream]
enabled = true
stream = "fraiseql-events"
subjects = ["fraiseql.>"]
retention = "limits"
max_msgs = 1000000
max_bytes = 10737418240  # 10GB
max_age = "720h"  # 30 days

# Event Stream: Orders
[nats.jetstream.streams.orders]
name = "orders"
subjects = ["fraiseql.order.>", "fraiseql.order_item.>"]
replicas = 3
max_msgs = 500000
max_bytes = 5368709120  # 5GB

# Event Stream: Inventory
[nats.jetstream.streams.inventory]
name = "inventory"
subjects = ["fraiseql.inventory.>", "fraiseql.reservation.>"]
replicas = 3
max_msgs = 300000
max_bytes = 3221225472  # 3GB

# Event Stream: Shipping
[nats.jetstream.streams.shipping]
name = "shipping"
subjects = ["fraiseql.shipping.>"]
replicas = 3
max_msgs = 200000
max_bytes = 2147483648  # 2GB

# Consumer: Order Processor Service
[nats.jetstream.consumers.order-processor]
stream = "orders"
durable_name = "order-processor"
deliver_policy = "all"
ack_policy = "explicit"
ack_wait = "30s"
max_deliver = 3

# Consumer: Inventory Service
[nats.jetstream.consumers.inventory-processor]
stream = "inventory"
durable_name = "inventory-processor"
deliver_policy = "all"
ack_policy = "explicit"
max_deliver = 3

# Consumer: Analytics
[nats.jetstream.consumers.analytics-consumer]
stream = "orders"
durable_name = "analytics"
deliver_policy = "new"  # Only new messages
ack_policy = "explicit"

# Dead Letter Queue
[nats.jetstream.dlq]
enabled = true
subject = "fraiseql.dlq"
max_deliver = 3
```

## FraiseQL Schema with CDC and Subscriptions

```python
from fraiseql import FraiseQL, Type, Query, Mutation, Subscription, ID, publish
from typing import Optional, Any
from decimal import Decimal
from datetime import datetime, timedelta
import json

fraiseql = FraiseQL()

# ==================== TYPES ====================

@fraiseql.type
class Order:
    id: ID
    customer_id: ID
    total: Decimal
    status: str  # 'pending', 'confirmed', 'shipped', 'delivered', 'cancelled'
    created_at: datetime
    updated_at: datetime

@fraiseql.type
class OrderItem:
    id: ID
    order_id: ID
    product_id: ID
    quantity: int
    unit_price: Decimal

@fraiseql.type
class Reservation:
    id: ID
    order_id: ID
    product_id: ID
    quantity: int
    status: str
    created_at: datetime
    expires_at: Optional[datetime]

@fraiseql.type
class Shipping:
    id: ID
    order_id: ID
    address: str
    status: str
    tracking_number: Optional[str]
    estimated_delivery: Optional[datetime]

@fraiseql.type
class OrderEvent:
    """Base event structure for all order events."""
    type: str
    timestamp: datetime
    order_id: ID
    data: Any

# ==================== MUTATIONS ====================

@fraiseql.mutation(sql_source="fn_create_order", operation="CREATE")
async def create_order(
    customer_id: ID,
    items: list[dict],
    shipping_address: dict
) -> Order:
    """Create order and publish event to NATS."""
    pass

# Publish custom event after order creation
@fraiseql.after_mutation("create_order")
async def after_create_order(order: Order, context):
    """Publish order created event for other services."""

    # Publish to NATS
    await publish(
        subject="fraiseql.order.created",
        data={
            "type": "order.created",
            "timestamp": datetime.utcnow().isoformat(),
            "order_id": order.id,
            "customer_id": order.customer_id,
            "total": str(order.total),
            "data": {
                "customer_id": order.customer_id,
                "items": context.variables.get("items"),
                "shipping_address": context.variables.get("shipping_address")
            }
        }
    )

@fraiseql.mutation(sql_source="fn_update_order_status", operation="UPDATE")
async def update_order_status(id: ID, status: str) -> Order:
    """Update order status and publish event."""
    pass

@fraiseql.after_mutation("update_order_status")
async def after_update_order_status(order: Order):
    """Publish status changed event."""
    await publish(
        subject="fraiseql.order.status_changed",
        data={
            "type": "order.status_changed",
            "timestamp": datetime.utcnow().isoformat(),
            "order_id": order.id,
            "new_status": order.status
        }
    )

# ==================== SUBSCRIPTIONS ====================

@fraiseql.subscription(
    entity_type="Order",
    topic="order_created",
    jetstream=True,
    replay=False  # Only new orders
)
def order_created() -> Order:
    """Subscribe to newly created orders."""
    pass

@fraiseql.subscription(
    entity_type="Order",
    topic="order_status_changed",
    jetstream=True,
    filter="new_status == 'shipped'"
)
def order_shipped() -> Order:
    """Subscribe only to shipped orders."""
    pass

@fraiseql.subscription(
    entity_type="Order",
    topic="order_status_changed",
    jetstream=True,
    replay=True,
    replay_from="2024-01-01T00:00:00Z"
)
def order_status_history() -> Order:
    """Replay all status changes from a point in time."""
    pass

# ==================== QUERIES ====================

@fraiseql.query(sql_source="v_order")
def order(id: ID) -> Order:
    """Get order by ID."""
    pass

@fraiseql.query(sql_source="v_order")
def orders_by_status(status: str, limit: int = 100) -> list[Order]:
    """Get orders by status."""
    pass
```

## Event Processing Services

### Service 1: Order Orchestration Service

```python
from fraiseql import subscribe, publish, request
import asyncio
from datetime import datetime, timedelta

@subscribe("fraiseql.order.created")
async def handle_order_created(event: dict):
    """
    Orchestrate order processing:
    1. Request inventory reservation
    2. Request shipping quote
    3. Publish order.confirmed when ready
    """

    order_id = event["data"]["order_id"]
    items = event["data"]["items"]
    customer_id = event["data"]["customer_id"]

    try:
        # Step 1: Request inventory service to reserve items
        print(f"[Order {order_id}] Requesting inventory reservation...")
        reservation = await request(
            subject="inventory.reserve",
            data={
                "order_id": order_id,
                "items": items
            },
            timeout=5000
        )

        if not reservation.get("success"):
            await publish(
                subject="fraiseql.order.failed",
                data={
                    "type": "order.reservation_failed",
                    "timestamp": datetime.utcnow().isoformat(),
                    "order_id": order_id,
                    "reason": reservation.get("reason")
                }
            )
            return

        # Step 2: Request shipping service
        print(f"[Order {order_id}] Requesting shipping quote...")
        shipping = await request(
            subject="shipping.quote",
            data={
                "order_id": order_id,
                "address": event["data"]["shipping_address"],
                "items": items
            },
            timeout=5000
        )

        # Step 3: Publish confirmation
        print(f"[Order {order_id}] Order confirmed!")
        await publish(
            subject="fraiseql.order.confirmed",
            data={
                "type": "order.confirmed",
                "timestamp": datetime.utcnow().isoformat(),
                "order_id": order_id,
                "reservation_id": reservation.get("reservation_id"),
                "shipping_id": shipping.get("shipping_id"),
                "estimated_delivery": shipping.get("estimated_delivery")
            }
        )

    except Exception as e:
        print(f"[Order {order_id}] Failed: {e}")
        await publish(
            subject="fraiseql.order.error",
            data={
                "type": "order.error",
                "timestamp": datetime.utcnow().isoformat(),
                "order_id": order_id,
                "error": str(e)
            }
        )
```

### Service 2: Inventory Service

```python
from fraiseql import service, subscribe, publish
import asyncio

# Request-Reply handler for inventory reservations
@service("inventory.reserve")
async def handle_inventory_reserve(data: dict) -> dict:
    """Handle inventory reservation request."""

    order_id = data["order_id"]
    items = data["items"]

    try:
        # Check inventory availability
        all_available = True
        reservations = []

        for item in items:
            product_id = item["product_id"]
            quantity = item["quantity"]

            # Query FraiseQL for availability
            available = await fraiseql.query(
                f"""
                query {{
                    inventoryStatus(productId: "{product_id}") {{
                        available
                    }}
                }}
                """
            )

            if available.get("available", 0) < quantity:
                all_available = False
                break

            reservations.append({
                "product_id": product_id,
                "quantity": quantity
            })

        if not all_available:
            return {
                "success": False,
                "reason": "Insufficient inventory"
            }

        # Create reservations
        reservation_id = await create_reservation_record(order_id, reservations)

        # Publish reservation event
        await publish(
            subject="fraiseql.inventory.reserved",
            data={
                "type": "inventory.reserved",
                "timestamp": datetime.utcnow().isoformat(),
                "order_id": order_id,
                "reservation_id": reservation_id
            }
        )

        return {
            "success": True,
            "reservation_id": reservation_id,
            "items": reservations
        }

    except Exception as e:
        return {
            "success": False,
            "reason": str(e)
        }

# Subscribe to reservation events for CDC sync
@subscribe("fraiseql.inventory.reserved")
async def on_inventory_reserved(event: dict):
    """Handle reserved inventory event."""
    # Update local inventory cache, sync to analytics, etc.
    print(f"Inventory reserved for order {event['data']['order_id']}")
```

### Service 3: Shipping Service

```python
from fraiseql import service, publish

@service("shipping.quote")
async def handle_shipping_quote(data: dict) -> dict:
    """Calculate shipping quote for order."""

    order_id = data["order_id"]
    address = data["address"]
    items = data["items"]

    try:
        # Calculate shipping based on weight and distance
        total_weight = sum(
            item.get("weight", 0.5) * item["quantity"]
            for item in items
        )

        shipping_cost, days = calculate_shipping(
            destination=address,
            weight=total_weight
        )

        estimated_delivery = datetime.utcnow() + timedelta(days=days)

        # Create shipping record
        shipping_id = await create_shipping_record(
            order_id=order_id,
            address=address,
            estimated_delivery=estimated_delivery
        )

        # Publish shipping event
        await publish(
            subject="fraiseql.shipping.quoted",
            data={
                "type": "shipping.quoted",
                "timestamp": datetime.utcnow().isoformat(),
                "order_id": order_id,
                "shipping_id": shipping_id,
                "cost": str(shipping_cost),
                "estimated_delivery": estimated_delivery.isoformat()
            }
        )

        return {
            "success": True,
            "shipping_id": shipping_id,
            "cost": shipping_cost,
            "estimated_delivery": estimated_delivery.isoformat()
        }

    except Exception as e:
        return {
            "success": False,
            "reason": str(e)
        }
```

### Service 4: Analytics Service

```python
from fraiseql import subscribe
from datetime import datetime
import json

@subscribe("fraiseql.order.>", queue_group="analytics")
async def process_order_event(event: dict):
    """
    Process all order events for analytics.
    Queue group ensures exactly-once processing.
    """

    event_type = event.get("type")
    order_id = event["data"].get("order_id")
    timestamp = event.get("timestamp")

    # Handle different event types
    if event_type == "order.created":
        await handle_order_created_analytics(event)

    elif event_type == "order.confirmed":
        await handle_order_confirmed_analytics(event)

    elif event_type == "order.status_changed":
        await handle_order_status_changed_analytics(event)

    elif event_type == "order.error":
        await handle_order_error_analytics(event)

    print(f"[Analytics] Processed {event_type} for order {order_id}")

async def handle_order_created_analytics(event: dict):
    """Track order creation for analytics."""
    order_id = event["data"]["order_id"]
    total = float(event["data"].get("total", 0))

    # Update aggregations
    await increment_metric("orders.created", 1)
    await increment_metric("orders.total_revenue", total)
    await set_gauge("orders.pending", await get_pending_order_count())

async def handle_order_confirmed_analytics(event: dict):
    """Track order confirmation."""
    await increment_metric("orders.confirmed", 1)
    await increment_metric("orders.confirmed_revenue", float(event["data"].get("total", 0)))

async def handle_order_error_analytics(event: dict):
    """Track order failures."""
    error = event["data"].get("error", "unknown")
    await increment_metric(f"orders.errors.{error}", 1)
    await increment_metric("orders.failed", 1)
```

## Event Schema and Formats

### Order Created Event

```json
{
    "type": "order.created",
    "timestamp": "2024-01-15T10:30:00Z",
    "order_id": "550e8400-e29b-41d4-a716-446655440000",
    "customer_id": "client-123",
    "total": "1234.56",
    "data": {
        "customer_id": "client-123",
        "items": [
            {
                "product_id": "prod-001",
                "quantity": 2,
                "unit_price": "99.99",
                "weight": 0.5
            }
        ],
        "shipping_address": {
            "street": "123 Main St",
            "city": "San Francisco",
            "postal": "94102",
            "country": "USA"
        }
    }
}
```

### Order Status Changed Event

```json
{
    "type": "order.status_changed",
    "timestamp": "2024-01-15T10:31:15Z",
    "order_id": "550e8400-e29b-41d4-a716-446655440000",
    "new_status": "confirmed",
    "previous_status": "pending",
    "data": {
        "reservation_id": "res-456",
        "shipping_id": "ship-789"
    }
}
```

## JetStream Consumer Configuration

### Create Durable Consumer for Service

```bash
# Use nats-cli to create consumer
nats consumer add orders order-processor \
    --deliver all \
    --ack explicit \
    --ack-wait 30s \
    --max-deliver 3

# Consumer receives messages with acknowledgment requirement
# Service must ACK within 30 seconds or message is redelivered
```

### Replay Capability

```bash
# Replay from specific time
nats consumer add orders analytics-replay \
    --deliver all-new \
    --start-time "2024-01-01T00:00:00Z"

# Consumers can ask to replay from beginning
nats consumer add orders migration-replay \
    --deliver first
```

## Idempotent Event Processing

Critical for exactly-once semantics:

```python
from fraiseql import subscribe
import hashlib

@subscribe("fraiseql.order.created")
async def handle_order_created_idempotent(event: dict):
    """Process event idempotently using event ID."""

    # Create deterministic event ID
    event_id = hashlib.sha256(
        f"{event['order_id']}-{event['timestamp']}".encode()
    ).hexdigest()

    # Check if already processed
    if await is_event_processed(event_id):
        print(f"Event {event_id} already processed, skipping")
        return

    try:
        # Process event
        await process_order(event)

        # Mark as processed
        await mark_event_processed(event_id)

    except Exception as e:
        # Let NATS retry (max_deliver = 3)
        raise

async def is_event_processed(event_id: str) -> bool:
    """Check if event was already processed (idempotency key)."""
    return await redis.exists(f"event_processed:{event_id}")

async def mark_event_processed(event_id: str):
    """Mark event as processed."""
    # Store with TTL of 30 days
    await redis.setex(f"event_processed:{event_id}", 30 * 24 * 3600, "true")
```

## Dead Letter Queue Handling

```python
from fraiseql import subscribe

@subscribe("fraiseql.dlq")
async def handle_dead_letter(event: dict):
    """Handle messages that failed 3 times."""

    print(f"Dead letter received: {event}")

    # Log for analysis
    await log_dead_letter({
        "timestamp": datetime.utcnow(),
        "event": event,
        "reason": "Max retries exceeded"
    })

    # Alert operations team
    await notify_ops(f"Dead letter: {event.get('order_id')}")

    # Optionally manual retry or escalation
    if should_manual_retry(event):
        await publish(
            subject="fraiseql.order.manual_review",
            data=event
        )
```

## Monitoring and Metrics

```bash
# Check JetStream status
nats account info

# Monitor consumers
nats consumer list orders

# Check consumer state
nats consumer info orders order-processor

# View pending messages
nats consumer info orders order-processor --raw | jq '.state.pending'

# Check for slow consumers
nats consumer report orders order-processor
```

## Best Practices

1. **Keep events small** - Publish minimal data, clients query for details
2. **Use JetStream** - Enable persistence for critical events
3. **Idempotent handlers** - Design for at-least-once delivery
4. **Dead letter queues** - Monitor and handle failed messages
5. **Partition by key** - Maintain ordering within partitions
6. **ACK explicitly** - Only ACK after successful processing
7. **Circuit breakers** - Fail gracefully when services are down
8. **Replay capability** - Design for time-travel debugging

## Related Guides

- [NATS Integration](/features/nats) - Complete NATS reference
- [Federation](/features/federation) - Synchronous cross-database access
- [Subscriptions](/features/subscriptions) - GraphQL subscriptions
- [Error Handling](/guides/error-handling) - Handle failures gracefully
- [Performance](/guides/performance) - Optimize event processing
