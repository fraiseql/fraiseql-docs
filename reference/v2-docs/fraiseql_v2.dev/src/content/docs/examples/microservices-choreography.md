---
title: Microservices Choreography with NATS
description: Event-driven microservices coordination using federation and NATS
---

A complete microservices architecture using event-driven choreography with federation and NATS for distributed order processing.

## System Architecture

```d2
direction: right

order_service: {
  shape: frame
  label: "📦 Order Service"

  create_order: "Create Order"
  db: "Orders DB"
}

inventory_service: {
  shape: frame
  label: "📊 Inventory Service"

  reserve: "Reserve Stock"
  inv_db: "Inventory DB"
}

payment_service: {
  shape: frame
  label: "💳 Payment Service"

  charge: "Charge Card"
  payment_db: "Payments DB"
}

shipping_service: {
  shape: frame
  label: "🚚 Shipping Service"

  create_label: "Create Label"
  shipping_db: "Shipping DB"
}

nats_bus: {
  shape: box
  label: "🔗 NATS Event Bus"
}

order_service.create_order -> nats_bus: "order.created"
nats_bus -> inventory_service.reserve: "order.created"
inventory_service.reserve -> nats_bus: "inventory.reserved"
nats_bus -> payment_service.charge: "inventory.reserved"
payment_service.charge -> nats_bus: "payment.charged"
nats_bus -> shipping_service.create_label: "payment.charged"

order_service.db -> order_service.create_order
inventory_service.inv_db -> inventory_service.reserve
payment_service.payment_db -> payment_service.charge
shipping_service.shipping_db -> shipping_service.create_label
```

## Order Service (Initiator)

```python
import fraiseql
from fraiseql import ID
from datetime import datetime
from decimal import Decimal






                           ─          ─      ─

@fraiseql.mutation(operation="CREATE")
async def create_order(
    user_id: ID,
    items: list[dict],
    total: Decimal
) -> Order:
    """
    Create order and emit event.
    Does NOT block waiting for downstream services.
    Event-driven choreography handles the rest.
    """
    order = await ctx.db.insert("tb_order", {
        "user_id": user_id,
        "total": total,
        "status": "pending",
        "created_at": datetime.now()
    })

    # Publish event (fire and forget)
    await fraiseql.nats.publish(
        subject="events.order.created",
        data={
            "order_id": str(order.id),
            "user_id": str(user_id),
            "items": items,
            "total": float(total),
            "timestamp": datetime.now().isoformat()
        }
    )

    return Order(**order)

# Track order status updates from other services
@fraiseql.observer(
    entity="Order",
    event="CUSTOM:inventory.reserved"
)
async def on_inventory_reserved(message, ctx):
    """Update order status when inventory is reserved."""
    await ctx.db.update(
        "tb_order",
        {"status": "reserved"},
        where={"id": message.data["order_id"]}
    )

@fraiseql.observer(
    entity="Order",
    event="CUSTOM:payment.charged"
)
async def on_payment_charged(message, ctx):
    """Update order status when payment is charged."""
    await ctx.db.update(
        "tb_order",
        {"status": "paid"},
        where={"id": message.data["order_id"]}
    )

@fraiseql.observer(
    entity="Order",
    event="CUSTOM:order.shipped"
)
async def on_order_shipped(message, ctx):
    """Update order status when shipped."""
    await ctx.db.update(
        "tb_order",
        {"status": "shipped"},
        where={"id": message.data["order_id"]}
    )
```

## Inventory Service (Consumer)

```python
import fraiseql

# Listen for order events
@fraiseql.nats.subscribe(
    subject="events.order.created",
    consumer_group="inventory_processors",
    max_concurrent=10
)
async def on_order_created(message):
    """
    React to order creation.
    Reserve inventory or emit failure event.
    """
    order_data = message.data
    order_id = order_data["order_id"]
    items = order_data["items"]

    try:
        # Check and reserve inventory
        for item in items:
            available = await ctx.db.query_one(
                "SELECT quantity FROM tb_inventory WHERE sku = $1",
                [item["sku"]]
            )

            if available["quantity"] < item["quantity"]:
                raise Exception(f"Insufficient inventory for {item['sku']}")

            # Reserve (decrease available quantity)
            await ctx.db.update(
                "tb_inventory",
                {
                    "quantity": available["quantity"] - item["quantity"],
                    "reserved": available["reserved"] + item["quantity"]
                },
                where={"sku": item["sku"]}
            )

        # Emit success event
        await fraiseql.nats.publish(
            subject="events.inventory.reserved",
            data={
                "order_id": order_id,
                "reserved_at": datetime.now().isoformat()
            }
        )

        await message.ack()

    except Exception as e:
        # Emit failure event
        await fraiseql.nats.publish(
            subject="events.order.failed",
            data={
                "order_id": order_id,
                "reason": "inventory_unavailable",
                "error": str(e)
            }
        )

        # Don't ack - will be retried
        await message.nak(timeout=5000)
```

## Payment Service (Sequential Consumer)

```python
@fraiseql.nats.subscribe(
    subject="events.inventory.reserved",
    consumer_group="payment_processors",
    max_concurrent=5  # Limit concurrency for payment processing
)
async def on_inventory_reserved(message):
    """
    Process payment after inventory is reserved.
    Risk: inventory reserved but payment fails - must compensate.
    """
    event_data = message.data
    order_id = event_data["order_id"]

    try:
        # Get order details
        order = await ctx.db.query_one(
            "SELECT * FROM tb_order WHERE id = $1",
            [order_id]
        )

        # Attempt payment
        payment = await charge_credit_card(
            customer_id=order["user_id"],
            amount=order["total"]
        )

        # Record payment
        await ctx.db.insert("tb_payment", {
            "order_id": order_id,
            "amount": order["total"],
            "status": "succeeded",
            "payment_id": payment.id,
            "created_at": datetime.now()
        })

        # Emit success
        await fraiseql.nats.publish(
            subject="events.payment.charged",
            data={
                "order_id": order_id,
                "payment_id": payment.id,
                "amount": float(order["total"])
            }
        )

        await message.ack()

    except Exception as e:
        # Payment failed - emit compensation event
        await fraiseql.nats.publish(
            subject="events.payment.failed",
            data={
                "order_id": order_id,
                "reason": str(e),
                "action": "release_inventory"
            }
        )

        # Don't ack - retry will happen
        await message.nak(timeout=10000)

# Handle payment failures with compensation
@fraiseql.nats.subscribe(
    subject="events.payment.failed",
    consumer_group="compensation_handlers"
)
async def on_payment_failed(message):
    """Release reserved inventory if payment fails."""
    event_data = message.data
    order_id = event_data["order_id"]

    # Get original order and items
    order = await ctx.db.query_one(
        "SELECT items FROM tb_order WHERE id = $1",
        [order_id]
    )

    items = json.loads(order["items"])

    # Release inventory
    for item in items:
        await ctx.db.update(
            "tb_inventory",
            {
                "reserved": "reserved - $1::int",
                "quantity": "quantity + $1::int"
            },
            where={"sku": item["sku"]},
            params=[item["quantity"]]
        )

    # Emit order failed event
    await fraiseql.nats.publish(
        subject="events.order.failed",
        data={
            "order_id": order_id,
            "reason": "payment_failed",
            "compensated": True
        }
    )

    await message.ack()
```

## Shipping Service (Final Consumer)

```python
@fraiseql.nats.subscribe(
    subject="events.payment.charged",
    consumer_group="shipping_handlers"
)
async def on_payment_charged(message):
    """
    Create shipping label after payment succeeds.
    Last step in the choreography - no compensation needed.
    """
    event_data = message.data
    order_id = event_data["order_id"]

    try:
        # Get order details
        order = await ctx.db.query_one(
            "SELECT * FROM tb_order WHERE id = $1",
            [order_id]
        )

        # Create shipping label
        label = await create_shipping_label(
            order_id=order_id,
            address=order["shipping_address"]
        )

        # Store label
        await ctx.db.insert("tb_shipping", {
            "order_id": order_id,
            "label_id": label.id,
            "carrier": label.carrier,
            "tracking": label.tracking_number,
            "created_at": datetime.now()
        })

        # Publish completion event
        await fraiseql.nats.publish(
            subject="events.order.shipped",
            data={
                "order_id": order_id,
                "tracking_number": label.tracking_number
            }
        )

        await message.ack()

    except Exception as e:
        # Log for manual intervention
        await log_error({
            "order_id": order_id,
            "step": "shipping",
            "error": str(e)
        })
        # Don't ack - manual retry needed
        await message.nak(timeout=60000)
```

## Event Flow Monitoring

```python
# Track event propagation
@fraiseql.nats.subscribe(
    subject="events.>",
    consumer_group="event_monitoring"
)
async def monitor_events(message):
    """Monitor all events for debugging."""
    event_type = message.subject
    data = message.data

    await ctx.db.insert("tb_event_log", {
        "event_type": event_type,
        "order_id": data.get("order_id"),
        "data": json.dumps(data),
        "recorded_at": datetime.now()
    })

    # Alert on failures
    if "failed" in event_type:
        await send_alert({
            "severity": "warning",
            "event": event_type,
            "details": data
        })

    await message.ack()
```

## Testing Choreography

```python
@pytest.mark.asyncio
async def test_full_order_choreography():
    """Test complete happy path through all services."""
    # Create order
    order = await order_service.create_order(
        user_id="user-1",
        items=[{"sku": "WIDGET", "quantity": 2}],
        total=49.99
    )

    # Give services time to process
    await asyncio.sleep(1.0)

    # Verify final state
    final_order = await get_order(order.id)
    assert final_order.status == "shipped"

    # Verify all events were published
    events = await get_event_history(order.id)
    assert "order.created" in events
    assert "inventory.reserved" in events
    assert "payment.charged" in events
    assert "order.shipped" in events

@pytest.mark.asyncio
async def test_payment_failure_compensation():
    """Test compensation when payment fails."""
    # Create order
    order = await order_service.create_order(
        user_id="user-with-bad-card",
        items=[{"sku": "WIDGET", "quantity": 2}],
        total=49.99
    )

    # Payment will fail due to bad card
    await asyncio.sleep(1.0)

    # Verify compensation occurred
    final_order = await get_order(order.id)
    assert final_order.status == "failed"

    # Verify inventory was released
    inventory = await get_inventory("WIDGET")
    assert inventory.reserved == 0
```

## Key Patterns

1. **Fire and Forget**: Order service doesn't wait for other services
2. **Event-Driven**: Services communicate only through events
3. **No Transactions**: Each service manages its own state
4. **Compensation**: Services can undo work if downstream fails
5. **Idempotency**: Each event handler is idempotent (safe to replay)
6. **Visibility**: Event log provides complete audit trail

## Production Considerations

- Monitor event lag (how far behind consumers are)
- Set up DLQ for permanently failed messages
- Implement circuit breakers for external service calls
- Use consumer groups for load distribution
- Enable metrics for each service and event type

## Next Steps

- [Advanced Federation](/guides/advanced-federation) — Cross-service queries
- [Advanced NATS](/guides/advanced-nats) — Reliability patterns
- [Custom Resolvers](/guides/custom-resolvers) — Service-specific logic
`3
`3