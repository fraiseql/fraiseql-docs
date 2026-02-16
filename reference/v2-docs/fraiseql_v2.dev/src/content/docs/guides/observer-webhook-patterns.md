---
title: Observer-Webhook Integration Patterns
description: Advanced patterns for combining observers and webhooks
---

Observers and webhooks are powerful independently, but when combined they create sophisticated event-driven architectures. This guide shows production patterns for integrating these features.

## Overview: When to Use Each

**Observers** react to database mutations:
- Watch specific entity changes (INSERT, UPDATE, DELETE)
- Define conditions (field-level, value-based)
- Trigger actions synchronously or async

**Webhooks** send external notifications:
- HTTP POST to external services
- Signed payloads for security
- Automatic retries with exponential backoff

**Together** they enable:
- Event-driven workflows
- Multi-service coordination
- Audit trails and compliance
- Real-time synchronization

## Basic Observer-Webhook Pattern

### Simple Order Notification

```python
from fraiseql import type, observer, webhook

@type
class Order:
    id: ID
    customer_email: str
    total: float
    status: str

@observer(
    entity="Order",
    event="INSERT",
    actions=[
        webhook(
            url="https://api.example.com/notifications",
            method="POST",
            headers={"Authorization": "Bearer ${WEBHOOK_API_KEY}"},
            body={
                "event": "order.created",
                "order_id": "{{ id }}",
                "customer_email": "{{ customer_email }}",
                "total": "{{ total }}",
                "timestamp": "{{ _timestamp }}"
            }
        )
    ]
)
def on_order_created():
    """Notify external service when order is created."""
    pass
```

**Execution flow:**
1. User creates order via GraphQL mutation
2. Order inserted into database
3. Observer triggers
4. Webhook payload built with order data
5. HMAC signature added
6. POST sent to external service
7. Response logged

## Advanced Patterns

### Pattern 1: Conditional Webhooks

Only trigger webhooks for specific conditions:

```python
@observer(
    entity="Order",
    event="UPDATE",
    condition="status.changed() && status == 'shipped'",
    actions=[
        webhook(
            url="https://shipping.example.com/tracking",
            body={
                "order_id": "{{ id }}",
                "tracking_number": "{{ tracking_number }}",
                "customer_email": "{{ customer_email }}"
            }
        )
    ]
)
def notify_shipping_update():
    """Only notify when status changes to 'shipped'."""
    pass
```

**Condition types:**
- `field.changed()` — Any change to field
- `field.old == value && field.new == other` — Specific state transition
- `total > 1000` — Business logic
- Complex: `(status == 'shipped' && total > 500) || is_priority`

### Pattern 2: Webhook Chaining

Multiple webhooks triggered in sequence:

```python
@observer(
    entity="Payment",
    event="INSERT",
    condition="status == 'approved'",
    actions=[
        webhook(
            url="https://inventory.example.com/reserve",
            body={"order_id": "{{ order_id }}", "items": "{{ items }}"}
        ),
        webhook(
            url="https://shipping.example.com/create-label",
            body={"order_id": "{{ order_id }}", "address": "{{ shipping_address }}"}
        ),
        webhook(
            url="https://analytics.example.com/track",
            body={"event": "payment_approved", "amount": "{{ amount }}"}
        )
    ]
)
def process_payment():
    """Execute multiple webhooks in order."""
    pass
```

**Execution:**
```
Payment approved
    ↓ (webhook 1)
Inventory reserved
    ↓ (webhook 2)
Shipping label created
    ↓ (webhook 3)
Analytics event tracked
```

If webhook 2 fails, retries happen (webhook 3 may wait or execute in parallel).

### Pattern 3: Fan-Out Pattern

One observer triggers different webhooks based on data:

```python
@observer(
    entity="User",
    event="INSERT",
    actions=[
        webhook(
            url="https://crm.example.com/contacts",
            condition="country == 'US'",
            body={"email": "{{ email }}", "country": "{{ country }}"}
        ),
        webhook(
            url="https://gdpr.example.com/register",
            condition="country IN ('DE', 'FR', 'UK')",
            body={"email": "{{ email }}", "country": "{{ country }}", "gdpr_required": True}
        ),
        webhook(
            url="https://analytics.example.com/signup",
            body={"user_id": "{{ id }}", "signup_date": "{{ created_at }}"}
        )
    ]
)
def fan_out_user_registration():
    """Route webhooks based on user attributes."""
    pass
```

### Pattern 4: Aggregation Pattern

Batch multiple events before sending webhook:

```python
@observer(
    entity="Order",
    event="INSERT",
    condition="true",
    actions=[
        webhook(
            url="https://analytics.example.com/batch",
            batch={
                "size": 10,
                "timeout": "5s"
            },
            body={
                "orders": [
                    {"id": "{{ id }}", "total": "{{ total }}"}
                ],
                "batch_timestamp": "{{ _timestamp }}"
            }
        )
    ]
)
def batch_order_analytics():
    """Aggregate 10 orders or wait 5s before sending."""
    pass
```

**Benefits:**
- Reduces webhook calls by 90%
- Improves analytics ingestion efficiency
- Lowers HTTP overhead

## Retry Strategies

### Default Retry Behavior

```toml
[webhooks.retry]
max_attempts = 3
backoff = "exponential"
initial_delay = "100ms"
max_delay = "5s"
```

Timeline:
```
Attempt 1: 0ms      (immediate)
Attempt 2: 100ms    (100ms delay)
Attempt 3: 500ms    (exponential: 100ms * 2.5)
If all fail → Dead Letter Queue
```

### Custom Retry Per Observer

```python
@observer(
    entity="Payment",
    event="INSERT",
    retry={
        "max_attempts": 5,
        "backoff": "linear",
        "initial_delay": "1s"
    },
    actions=[...]
)
def critical_payment_notification():
    """More aggressive retries for critical payments."""
    pass
```

### Selective Retry

```python
[webhooks.retry]
# Retry on transient errors
retry_on = [408, 429, 500, 502, 503, 504]

# Don't retry on client errors
dont_retry_on = [400, 401, 403, 404, 422]
```

| Status | Retry? | Reason |
|--------|--------|--------|
| 500 | ✅ Yes | Server error (transient) |
| 400 | ❌ No | Bad request (our payload is wrong) |
| 429 | ✅ Yes | Rate limited (temporary) |
| 401 | ❌ No | Unauthorized (credentials wrong) |

## Dead Letter Queue (DLQ) Handling

### Configuration

```toml
[webhooks.dlq]
enabled = true
backend = "postgresql"
table = "webhook_dlq"
retention = "7d"
max_size = "10GB"
```

### Supported Backends

**PostgreSQL:**
```toml
[webhooks.dlq]
backend = "postgresql"
table = "webhook_dlq"
schema = "public"
```

**NATS JetStream:**
```toml
[webhooks.dlq]
backend = "nats"
stream = "WEBHOOK_DLQ"
bucket = "webhook-failures"
```

**File-based:**
```toml
[webhooks.dlq]
backend = "file"
path = "/var/log/fraiseql/webhook_dlq.jsonl"
rotation = "daily"
compress = true
```

### DLQ Operations

**Query failed webhooks:**
```sql
SELECT * FROM webhook_dlq
WHERE failed_at > NOW() - INTERVAL '24 hours'
ORDER BY failed_at DESC;
```

**Replay a failed webhook:**
```python
from fraiseql.webhooks import replay_dlq

# Replay single webhook
replay_dlq(dlq_id="webhook_123")

# Replay all failures from last 24 hours
replay_dlq(
    failed_after="2025-02-10",
    filter={"observer": "on_payment_created"}
)

# Replay with custom delay
replay_dlq(
    dlq_id="webhook_456",
    delay="30s"
)
```

## Security Patterns

### Webhook Signature Verification

FraiseQL automatically signs all webhooks with HMAC-SHA256:

```toml
[webhooks.signing]
enabled = true
algorithm = "sha256"
secret = "${WEBHOOK_SECRET}"
header = "X-FraiseQL-Signature"
timestamp_header = "X-FraiseQL-Timestamp"
```

**Signature format:**
```
X-FraiseQL-Signature: sha256=abcd1234...
X-FraiseQL-Timestamp: 1707604800
```

**Receiver-side verification (Python):**
```python
import hmac
import hashlib
import time

def verify_webhook(payload: bytes, signature: str, timestamp: str, secret: str) -> bool:
    # Check timestamp freshness (prevent replay attacks)
    ts = int(timestamp)
    if abs(time.time() - ts) > 300:  # 5 minute window
        return False

    # Compute expected signature
    message = f"{timestamp}.".encode() + payload
    expected = "sha256=" + hmac.new(
        secret.encode(),
        message,
        hashlib.sha256
    ).hexdigest()

    # Constant-time comparison
    return hmac.compare_digest(signature, expected)

# Flask example
@app.route("/webhook", methods=["POST"])
def handle_webhook():
    if not verify_webhook(
        request.data,
        request.headers.get("X-FraiseQL-Signature"),
        request.headers.get("X-FraiseQL-Timestamp"),
        WEBHOOK_SECRET
    ):
        return "Invalid signature", 401

    data = request.json
    # Process webhook...
    return "OK", 200
```

### Payload Encryption

Encrypt sensitive data in webhook payloads:

```python
@observer(
    entity="User",
    event="INSERT",
    actions=[
        webhook(
            url="https://external.example.com/users",
            encryption={
                "enabled": True,
                "algorithm": "AES-256-GCM",
                "key": "${WEBHOOK_ENCRYPTION_KEY}"
            },
            body={
                "id": "{{ id }}",
                "email": "{{ email }}",  # Will be encrypted
                "ssn": "{{ ssn }}"       # Will be encrypted
            }
        )
    ]
)
def send_user_data():
    pass
```

## Performance Tuning

### Async Webhook Dispatch

```toml
[webhooks.dispatch]
# Don't block mutation on webhook completion
async = true
timeout = "30s"

# Queue failed webhooks in background
background_retry = true
max_queue_size = 1000
```

With async dispatch:
```
Mutation completes immediately
    ↓
Webhook queued for delivery
    ↓
(Happens in background)
Webhook sent with retries
```

### Batching Configuration

```toml
[webhooks.batching]
enabled = true
batch_size = 50
timeout = "10s"
```

With 100 order inserts:
- Batch 1: 50 webhooks (0-50ms)
- Batch 2: 50 webhooks (500-510ms)
- Total: 2 HTTP calls instead of 100

### Rate Limiting Observer Webhooks

```toml
[webhooks.rate_limiting]
enabled = true
max_per_second = 100
burst = 200
```

Prevents overwhelming external service:
- Sustain: 100 webhooks/second
- Burst: Up to 200/second
- Queues excess with backoff

## Testing Observer-Webhook Integrations

### Local Testing with ngrok

```bash
# Start ngrok tunnel
ngrok http 8000

# Update webhook URL in config
[webhooks]
test_url = "https://abc123.ngrok.io/webhook"

# Start local server
python -m flask run --port 8000
```

### Webhook Mocking in Tests

```python
from fraiseql.testing import MockWebhookServer

def test_order_webhook():
    with MockWebhookServer(port=9999) as mock:
        # Create order (triggers webhook)
        result = client.mutate("""
            mutation {
                createOrder(input: {
                    customer_email: "user@example.com"
                    total: 99.99
                }) {
                    id
                }
            }
        """)

        # Assert webhook was called
        assert mock.called
        assert mock.last_payload["customer_email"] == "user@example.com"

        # Assert retry behavior
        assert mock.call_count == 1  # or more if retried
```

### Integration Test Pattern

```python
@pytest.mark.integration
def test_payment_flow_with_webhooks(db_pool, webhook_server):
    # Setup: Register expected webhook calls
    webhook_server.expect_call(
        url="https://inventory.example.com/reserve",
        method="POST"
    )
    webhook_server.expect_call(
        url="https://shipping.example.com/label",
        method="POST"
    )

    # Action: Create payment
    result = client.mutate("""
        mutation {
            createPayment(input: {
                order_id: "123"
                amount: 50.00
            }) {
                id
                status
            }
        }
    """)

    # Assert: All webhooks were called
    assert result["data"]["createPayment"]["status"] == "approved"
    assert webhook_server.all_expectations_met()
```

## Monitoring & Observability

### Prometheus Metrics

```toml
[observability.prometheus]
enabled = true
port = 9090
namespace = "fraiseql"
```

Exposed metrics:
```
fraiseql_webhook_total{observer="on_order_created"}
fraiseql_webhook_duration_seconds{observer="on_order_created", status="success"}
fraiseql_webhook_failures_total{observer="on_order_created", reason="timeout"}
fraiseql_webhook_retries_total{observer="on_order_created"}
fraiseql_dlq_size{observer="on_order_created"}
```

### Grafana Dashboard

Key panels:
- Webhook success rate by observer
- Latency distribution
- DLQ growth over time
- Retry patterns
- Failed webhook trends

### Alerting

```yaml
# Prometheus alerts
- alert: WebhookFailureRate
  expr: |
    rate(fraiseql_webhook_failures_total[5m]) /
    rate(fraiseql_webhook_total[5m]) > 0.05
  annotations:
    summary: "Webhook failure rate > 5%"

- alert: DLQBacklog
  expr: fraiseql_dlq_size > 1000
  annotations:
    summary: "Webhook DLQ has {{ $value }} items"
```

## Real-World Examples

### E-Commerce Order Fulfillment

```python
# Step 1: Order created
@observer(entity="Order", event="INSERT")
def on_order_created():
    webhook("https://inventory.example.com/reserve",
            body={"order_id": "{{ id }}", "items": "{{ items }}"})
    webhook("https://analytics.example.com/track",
            body={"event": "order_created", "amount": "{{ total }}"})

# Step 2: Payment confirmed
@observer(entity="Order", event="UPDATE",
          condition="status == 'payment_confirmed'")
def on_payment_confirmed():
    webhook("https://shipping.example.com/create-label",
            body={"order_id": "{{ id }}", "address": "{{ shipping_address }}"})

# Step 3: Shipped
@observer(entity="Order", event="UPDATE",
          condition="status == 'shipped'")
def on_shipped():
    webhook("https://notifications.example.com/email",
            body={"customer_email": "{{ customer_email }}",
                  "tracking": "{{ tracking_number }}"})
```

### User Registration Workflow

```python
# New user signup
@observer(entity="User", event="INSERT")
def on_signup():
    webhook("https://email.example.com/verify-email",
            body={"email": "{{ email }}", "user_id": "{{ id }}"})
    webhook("https://crm.example.com/add-contact",
            body={"email": "{{ email }}", "name": "{{ name }}"})

# Email verified
@observer(entity="User", event="UPDATE",
          condition="email_verified.changed() && email_verified == true")
def on_email_verified():
    webhook("https://welcome.example.com/send-onboarding",
            body={"email": "{{ email }}", "user_id": "{{ id }}"})
```

## Troubleshooting

### Webhook Not Triggering

**Check:**
1. Observer condition matches data
   ```sql
   SELECT * FROM orders WHERE /* observer condition */;
   ```

2. Webhook URL is accessible
   ```bash
   curl -X POST https://api.example.com/notify
   ```

3. Observer is registered in schema
   ```graphql
   query {
     __schema {
       # Check introspection for observers (if available)
     }
   }
   ```

### Webhook Timeouts

**Solutions:**
- Increase timeout:
  ```toml
  [webhooks]
  timeout = "60s"
  ```

- Make receiver async:
  ```python
  # Instead of processing in webhook
  @app.route("/webhook", methods=["POST"])
  def webhook_handler():
      task_queue.enqueue(process_payload, request.json)
      return "Accepted", 202  # Return immediately
  ```

### DLQ Growing Unbounded

**Debug:**
```sql
SELECT observer, COUNT(*), MAX(failed_at)
FROM webhook_dlq
GROUP BY observer
ORDER BY COUNT(*) DESC;
```

**Remediate:**
- Fix receiver service
- Replay DLQ
- Adjust retry policy

## Next Steps

- **[Observers](../concepts/observers.mdx)** - Deep dive into observer conditions and actions
- **[Webhooks](../features/webhooks.md)** - Comprehensive webhook reference
- **[NATS Integration](../features/nats.md)** - Multi-service messaging patterns
