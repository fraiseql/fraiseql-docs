---
title: Federation Example - E-Commerce Platform
description: Complete multi-database e-commerce architecture using FraiseQL federation and saga patterns
---

# Federation Example: E-Commerce Platform

This guide walks through building a complete e-commerce backend using FraiseQL's federation capabilities to coordinate across three separate databases.

## Architecture Overview

```

      │                                                      │
      ↓                                                      ↓


                            ┌────────────────────────────────────┐
                            │ Inventory DB  │││ Payments DB      │
                            │  (Products,   │││ (Ledger,         │
                            │   Stock,      │││  Refunds,        │
                            ↓  Reserves)    ↓↓↓  Billing)        ↓
                            └────────────────────────────────────┘
```

## Database Setup

### 1. Primary Database (Orders & Customers)

```sql
-- PostgreSQL

-- Customers
CREATE TABLE tb_customer (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    phone TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Orders
CREATE TABLE tb_order (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES tb_customer(id),
    total DECIMAL(10, 2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Order Items
CREATE TABLE tb_order_item (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES tb_order(id),
    product_id UUID NOT NULL,  -- FK to inventory DB
    quantity INT NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Shipping Info
CREATE TABLE tb_shipping (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL UNIQUE REFERENCES tb_order(id),
    address TEXT NOT NULL,
    city TEXT NOT NULL,
    postal_code TEXT NOT NULL,
    country TEXT NOT NULL,
    tracking_number TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    estimated_delivery DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Views for FraiseQL
CREATE VIEW v_order AS
SELECT
    id, customer_id, total, status,
    created_at, updated_at
FROM tb_order
WHERE deleted_at IS NULL;

CREATE VIEW v_customer AS
SELECT id, name, email, phone, created_at
FROM tb_customer
WHERE deleted_at IS NULL;
```

### 2. Inventory Database (Products & Stock)

```sql
-- PostgreSQL (separate instance)

CREATE TABLE tb_product (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sku TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    weight_grams INT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE tb_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES tb_product(id),
    warehouse TEXT NOT NULL,
    quantity INT NOT NULL DEFAULT 0,
    reserved INT NOT NULL DEFAULT 0,
    available INT GENERATED ALWAYS AS (quantity - reserved) STORED,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(product_id, warehouse)
);

CREATE TABLE tb_reservation (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,  -- FK to primary DB
    product_id UUID NOT NULL REFERENCES tb_product(id),
    quantity INT NOT NULL,
    status TEXT NOT NULL DEFAULT 'reserved',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    released_at TIMESTAMPTZ
);

CREATE VIEW v_product AS
SELECT id, sku, name, price FROM tb_product;

CREATE VIEW v_inventory_status AS
SELECT
    p.id, p.sku, p.name,
    i.warehouse, i.quantity, i.reserved, i.available
FROM tb_product p
LEFT JOIN tb_inventory i ON p.id = i.product_id;
```

### 3. Payments Database (Transactions & Ledger)

```sql
-- PostgreSQL (separate instance)

CREATE TABLE tb_payment_method (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,  -- FK to primary DB
    type TEXT NOT NULL,  -- 'card', 'bank_transfer', 'wallet'
    token TEXT NOT NULL,  -- Tokenized payment info
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE tb_transaction (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL UNIQUE,  -- FK to primary DB
    customer_id UUID NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    payment_method_id UUID REFERENCES tb_payment_method(id),
    gateway TEXT,  -- 'stripe', 'paypal', 'square'
    gateway_transaction_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ
);

CREATE TABLE tb_refund (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID NOT NULL REFERENCES tb_transaction(id),
    order_id UUID NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    reason TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    processed_at TIMESTAMPTZ
);

CREATE VIEW v_transaction AS
SELECT id, order_id, customer_id, amount, status, created_at
FROM tb_transaction;
```

## FraiseQL Schema with Federation

```python
from fraiseql import FraiseQL, Type, Query, Mutation, ID
from typing import Optional, Annotated
from decimal import Decimal
from datetime import datetime

fraiseql = FraiseQL()

# ==================== PRIMARY DATABASE ====================

@fraiseql.type(database="primary")
class Customer:
    id: ID
    name: str
    email: str
    phone: Optional[str]
    created_at: datetime

    # Federated field from payments DB
    payment_methods: list['PaymentMethod'] = fraiseql.federated(
        database="payments",
        lookup="customer_id"
    )

@fraiseql.type(database="primary")
class OrderItem:
    id: ID
    product_id: ID
    quantity: int
    unit_price: Decimal

    # Federated product info from inventory DB
    product: 'Product' = fraiseql.federated(
        database="inventory",
        local_key="product_id",
        remote_key="id"
    )

@fraiseql.type(database="primary")
class Shipping:
    id: ID
    order_id: ID
    address: str
    city: str
    postal_code: str
    country: str
    tracking_number: Optional[str]
    status: str
    estimated_delivery: Optional[str]

@fraiseql.type(database="primary")
class Order:
    id: ID
    customer_id: ID
    total: Decimal
    status: str
    created_at: datetime
    updated_at: datetime

    # Local relation
    items: list[OrderItem]
    shipping: Shipping

    # Federated relations
    customer: Customer = fraiseql.federated(
        database="primary",
        local_key="customer_id",
        remote_key="id"
    )

    # Federated payment info from payments DB
    payment: 'Transaction' = fraiseql.federated(
        database="payments",
        local_key="id",
        remote_key="order_id"
    )

    # Federated reservations from inventory DB
    reservations: list['Reservation'] = fraiseql.federated(
        database="inventory",
        lookup="order_id"
    )

# ==================== INVENTORY DATABASE ====================

@fraiseql.type(database="inventory")
class Product:
    id: ID
    sku: str
    name: str
    price: Decimal

@fraiseql.type(database="inventory")
class InventoryStatus:
    product_id: ID
    sku: str
    name: str
    warehouse: str
    quantity: int
    reserved: int
    available: int

@fraiseql.type(database="inventory")
class Reservation:
    id: ID
    order_id: ID
    product_id: ID
    quantity: int
    status: str
    created_at: datetime
    expires_at: Optional[datetime]
    released_at: Optional[datetime]

    # Federated product info
    product: Product = fraiseql.federated(
        database="inventory",
        local_key="product_id",
        remote_key="id"
    )

# ==================== PAYMENTS DATABASE ====================

@fraiseql.type(database="payments")
class PaymentMethod:
    id: ID
    customer_id: ID
    type: str
    is_default: bool

@fraiseql.type(database="payments")
class Transaction:
    id: ID
    order_id: ID
    customer_id: ID
    amount: Decimal
    status: str
    gateway: Optional[str]
    created_at: datetime
    processed_at: Optional[datetime]

@fraiseql.type(database="payments")
class Refund:
    id: ID
    transaction_id: ID
    order_id: ID
    amount: Decimal
    reason: Optional[str]
    status: str
    created_at: datetime

# ==================== QUERIES ====================

@fraiseql.query(sql_source="v_order", database="primary")
def order(id: ID) -> Order:
    """Get order by ID with all federated relations."""
    pass

@fraiseql.query(sql_source="v_order", database="primary")
def orders(customer_id: Optional[ID] = None, limit: int = 20) -> list[Order]:
    """Get orders, optionally filtered by customer."""
    pass

@fraiseql.query(sql_source="v_customer", database="primary")
def customer(id: ID) -> Customer:
    """Get customer with payment methods."""
    pass

@fraiseql.query(sql_source="v_inventory_status", database="inventory")
def inventory_status(product_id: Optional[ID] = None) -> list[InventoryStatus]:
    """Get current inventory status across warehouses."""
    pass

# ==================== MUTATIONS ====================

@fraiseql.mutation(database="primary", operation="CREATE")
def create_order(
    customer_id: ID,
    items: list['CreateOrderItemInput'],
    shipping_address: str,
    shipping_city: str,
    shipping_postal: str,
    shipping_country: str
) -> Order:
    """Create order with inventory reservation and payment processing."""
    pass
```

## Saga Pattern: Create Order

The create-order mutation is a saga that coordinates across all three databases:

```python
from fraiseql import saga, compensate, nats_publish

@saga(
    steps=[
        "create_order_record",
        "reserve_inventory",
        "process_payment",
        "confirm_shipping"
    ]
)
@fraiseql.mutation(database="primary", operation="CREATE")
async def create_order(
    customer_id: ID,
    items: list['CreateOrderItemInput'],
    shipping_address: str,
    payment_method_id: ID
) -> Order:
    """
    Multi-step saga for order creation:
    1. Create order in primary DB
    2. Reserve inventory from inventory DB
    3. Process payment from payments DB
    4. Mark shipping as ready

    Any failure triggers compensation.
    """
    pass

# ==================== SAGA STEPS ====================

@saga.step("create_order_record", database="primary")
async def step_create_order(ctx, customer_id, items, shipping_address):
    """Step 1: Create order record in primary database."""
    order = await execute_sql(
        """
        INSERT INTO tb_order (customer_id, total, status)
        VALUES ($1, $2, 'pending')
        RETURNING id, customer_id, total, status, created_at
        """,
        [customer_id, calculate_total(items)]
    )

    # Create order items
    for item in items:
        await execute_sql(
            """
            INSERT INTO tb_order_item (order_id, product_id, quantity, unit_price)
            VALUES ($1, $2, $3, $4)
            """,
            [order['id'], item['product_id'], item['quantity'], item['unit_price']]
        )

    # Create shipping record
    await execute_sql(
        """
        INSERT INTO tb_shipping (order_id, address, city, postal_code, country, status)
        VALUES ($1, $2, $3, $4, $5, 'pending')
        """,
        [order['id'], shipping_address['address'], shipping_address['city'],
         shipping_address['postal'], shipping_address['country']]
    )

    ctx.order_id = order['id']
    return order

@compensate("create_order_record")
async def compensate_create_order(ctx):
    """Compensation: Cancel the order if later steps fail."""
    await execute_sql(
        "UPDATE tb_order SET status = 'cancelled' WHERE id = $1",
        [ctx.order_id]
    )

# ==================== STEP 2: RESERVE INVENTORY ====================

@saga.step("reserve_inventory", database="inventory")
async def step_reserve_inventory(ctx, items):
    """Step 2: Reserve inventory in inventory database."""
    reservations = []

    for item in items:
        # Check availability
        inventory = await execute_sql(
            """
            SELECT id, available FROM tb_inventory
            WHERE product_id = $1 AND available >= $2
            FOR UPDATE  -- Lock for exclusive access
            """,
            [item['product_id'], item['quantity']]
        )

        if not inventory:
            raise Exception(
                f"Insufficient inventory for product {item['product_id']}"
            )

        # Create reservation
        reservation = await execute_sql(
            """
            INSERT INTO tb_reservation (order_id, product_id, quantity, status)
            VALUES ($1, $2, $3, 'reserved')
            RETURNING id
            """,
            [ctx.order_id, item['product_id'], item['quantity']]
        )

        # Update reserved count
        await execute_sql(
            """
            UPDATE tb_inventory
            SET reserved = reserved + $1
            WHERE product_id = $2
            """,
            [item['quantity'], item['product_id']]
        )

        reservations.append(reservation['id'])

    ctx.reservations = reservations
    return reservations

@compensate("reserve_inventory")
async def compensate_reserve_inventory(ctx):
    """Compensation: Release reserved inventory."""
    for reservation_id in ctx.reservations:
        # Get reservation details
        reservation = await execute_sql(
            "SELECT product_id, quantity FROM tb_reservation WHERE id = $1",
            [reservation_id]
        )

        # Release reserved count
        await execute_sql(
            """
            UPDATE tb_inventory
            SET reserved = reserved - $1
            WHERE product_id = $2
            """,
            [reservation['quantity'], reservation['product_id']]
        )

        # Mark reservation released
        await execute_sql(
            """
            UPDATE tb_reservation
            SET status = 'released', released_at = NOW()
            WHERE id = $1
            """,
            [reservation_id]
        )

# ==================== STEP 3: PROCESS PAYMENT ====================

@saga.step("process_payment", database="payments")
async def step_process_payment(ctx, customer_id, total, payment_method_id):
    """Step 3: Process payment in payments database."""

    # Create transaction record
    transaction = await execute_sql(
        """
        INSERT INTO tb_transaction (order_id, customer_id, amount, status, payment_method_id)
        VALUES ($1, $2, $3, 'processing', $4)
        RETURNING id
        """,
        [ctx.order_id, customer_id, total, payment_method_id]
    )

    # Call payment gateway (pseudo-code)
    try:
        gateway_result = await charge_payment_gateway(
            amount=total,
            payment_method_id=payment_method_id,
            idempotency_key=ctx.order_id  # Prevent duplicate charges
        )

        # Update transaction with gateway response
        await execute_sql(
            """
            UPDATE tb_transaction
            SET status = 'completed', gateway_transaction_id = $1, processed_at = NOW()
            WHERE id = $2
            """,
            [gateway_result['transaction_id'], transaction['id']]
        )

        ctx.transaction_id = transaction['id']
        return transaction

    except Exception as e:
        # Mark transaction as failed
        await execute_sql(
            """
            UPDATE tb_transaction
            SET status = 'failed', failed_at = NOW()
            WHERE id = $1
            """,
            [transaction['id']]
        )
        raise

# Payment step has NO compensation - refunds are handled separately
# This ensures payment is the final, irreversible step

# ==================== STEP 4: CONFIRM SHIPPING ====================

@saga.step("confirm_shipping", database="primary")
async def step_confirm_shipping(ctx):
    """Step 4: Confirm shipping is ready."""

    shipping = await execute_sql(
        """
        UPDATE tb_shipping
        SET status = 'confirmed'
        WHERE order_id = $1
        RETURNING id
        """,
        [ctx.order_id]
    )

    # Mark order as confirmed
    await execute_sql(
        """
        UPDATE tb_order
        SET status = 'confirmed'
        WHERE id = $1
        """,
        [ctx.order_id]
    )

    return shipping

@compensate("confirm_shipping")
async def compensate_confirm_shipping(ctx):
    """Compensation: Reset shipping status."""
    await execute_sql(
        """
        UPDATE tb_shipping
        SET status = 'pending'
        WHERE order_id = $1
        """,
        [ctx.order_id]
    )
```

## Query Examples

### Get Complete Order with All Relations

```graphql
query GetOrder {
    order(id: "550e8400-e29b-41d4-a716-446655440000") {
        id
        status
        total

        # Local relations (primary DB)
        customer {
            name
            email
            # Federated from payments DB
            paymentMethods {
                type
                isDefault
            }
        }

        # Local relation (primary DB)
        items {
            quantity
            unitPrice
            # Federated from inventory DB
            product {
                sku
                name
                price
            }
        }

        # Federated from inventory DB
        reservations {
            status
            product {
                name
            }
        }

        # Federated from payments DB
        payment {
            amount
            status
            processedAt
        }
    }
}
```

### Check Inventory Status

```graphql
query CheckInventory {
    inventoryStatus(limit: 100) {
        productId
        sku
        name
        warehouse
        quantity
        reserved
        available
    }
}
```

## Performance Considerations

### 1. Batching Lookups

When fetching multiple orders with products, FraiseQL automatically batches the federated lookups:

```sql
# Naive approach: N+1 queries
SELECT * FROM orders LIMIT 100;  -- 1 query
SELECT * FROM products WHERE id = $1;  -- 100 queries per item

# FraiseQL optimized: Batched federation
SELECT * FROM orders LIMIT 100;  -- 1 query to primary DB
SELECT * FROM products WHERE id IN ($1, $2, ..., $100);  -- 1 batch query
```

### 2. Connection Pooling

Configure separate connection pools for each database:

```toml
[databases.primary]
url = "${PRIMARY_DB}"
pool_size = 50
pool_timeout = 30000

[databases.inventory]
url = "${INVENTORY_DB}"
pool_size = 30
pool_timeout = 30000

[databases.payments]
url = "${PAYMENTS_DB}"
pool_size = 20
pool_timeout = 30000
```

### 3. Denormalization

For frequently accessed data across federations, consider denormalizing:

```python
@fraiseql.type(database="primary")
class Order:
    id: ID
    customer_name: str  # Denormalized from customer
    total: Decimal

    # Still federated for updates
    customer: Customer = fraiseql.federated(...)
```

### 4. Timeout Configuration

Set appropriate timeouts for federated queries:

```toml
[federation]
default_timeout = 5000  # 5 seconds
batch_size = 100

[federation.retry]
max_attempts = 2
backoff = "exponential"
```

## Related Guides

- [Federation](/features/federation) - Complete federation reference
- [NATS Integration](/features/nats) - Event coordination
- [Error Handling](/guides/error-handling) - Saga failure recovery
- [Multi-Tenancy](/guides/multi-tenancy) - Scaling this pattern
- [Performance](/guides/performance) - Query optimization
