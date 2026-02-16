---
title: Webhooks
description: Send and receive webhooks with signature verification
---

FraiseQL provides both outgoing webhooks (via Observers) and incoming webhook verification for secure integrations.

## Outgoing Webhooks

Send webhooks when data changes using the Observer system.

### Basic Webhook

```python
from fraiseql import observer, webhook

@observer(
    entity="Order",
    event="INSERT",
    actions=[
        webhook("https://api.example.com/orders/new")
    ]
)
def on_new_order():
    pass
```

### Custom Headers

```python
webhook(
    "https://api.example.com/orders",
    headers={
        "Authorization": "Bearer ${WEBHOOK_API_KEY}",
        "X-Source": "fraiseql"
    }
)
```

### Custom Body

```python
webhook(
    "https://api.example.com/orders",
    body_template='''
    {
        "event": "order.created",
        "order_id": "{{id}}",
        "total": {{total}},
        "customer": "{{customer_email}}",
        "timestamp": "{{_timestamp}}"
    }
    '''
)
```

### URL from Environment

```python
webhook(url_env="ORDER_WEBHOOK_URL")
```

## Webhook Signatures

FraiseQL signs all outgoing webhooks with HMAC-SHA256.

### Configuration

```toml
[webhooks]
signing_enabled = true
signing_secret = "${WEBHOOK_SIGNING_SECRET}"
signing_algorithm = "sha256"  # or "sha512"

# Headers for signature
signature_header = "X-FraiseQL-Signature"
timestamp_header = "X-FraiseQL-Timestamp"
```

### Signature Format

```
X-FraiseQL-Signature: sha256=abc123def456...
X-FraiseQL-Timestamp: 1704067200
```

Signature computed as:

```
HMAC-SHA256(secret, timestamp + "." + body)
```

### Verification (Receiver Side)

**Python:**

```python
import hmac
import hashlib
import time

def verify_webhook(
    payload: bytes,
    signature: str,
    timestamp: str,
    secret: str,
    max_age_seconds: int = 300
) -> bool:
    # Check timestamp freshness
    ts = int(timestamp)
    if abs(time.time() - ts) > max_age_seconds:
        return False  # Replay attack protection

    # Compute expected signature
    message = f"{timestamp}.".encode() + payload
    expected = "sha256=" + hmac.new(
        secret.encode(),
        message,
        hashlib.sha256
    ).hexdigest()

    # Constant-time comparison
    return hmac.compare_digest(signature, expected)

# Usage in Flask
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

**Node.js:**

```javascript
const crypto = require('crypto');

function verifyWebhook(payload, signature, timestamp, secret, maxAge = 300) {
    // Check timestamp freshness
    const ts = parseInt(timestamp);
    if (Math.abs(Date.now() / 1000 - ts) > maxAge) {
        return false;
    }

    // Compute expected signature
    const message = `${timestamp}.${payload}`;
    const expected = 'sha256=' + crypto
        .createHmac('sha256', secret)
        .update(message)
        .digest('hex');

    // Constant-time comparison
    return crypto.timingSafeEqual(
        Buffer.from(signature),
        Buffer.from(expected)
    );
}

// Express middleware
app.post('/webhook', express.raw({ type: 'application/json' }), (req, res) => {
    const valid = verifyWebhook(
        req.body.toString(),
        req.headers['x-fraiseql-signature'],
        req.headers['x-fraiseql-timestamp'],
        process.env.WEBHOOK_SECRET
    );

    if (!valid) {
        return res.status(401).send('Invalid signature');
    }

    const data = JSON.parse(req.body);
    // Process webhook...
    res.send('OK');
});
```

**Go:**

```go
package main

import (
    "crypto/hmac"
    "crypto/sha256"
    "encoding/hex"
    "fmt"
    "math"
    "strconv"
    "time"
)

func verifyWebhook(payload []byte, signature, timestamp, secret string, maxAge int64) bool {
    // Check timestamp freshness
    ts, err := strconv.ParseInt(timestamp, 10, 64)
    if err != nil {
        return false
    }
    if math.Abs(float64(time.Now().Unix()-ts)) > float64(maxAge) {
        return false
    }

    // Compute expected signature
    message := fmt.Sprintf("%s.%s", timestamp, string(payload))
    mac := hmac.New(sha256.New, []byte(secret))
    mac.Write([]byte(message))
    expected := "sha256=" + hex.EncodeToString(mac.Sum(nil))

    // Constant-time comparison
    return hmac.Equal([]byte(signature), []byte(expected))
}
```

## Incoming Webhooks

Receive webhooks from external services with verification.

### GitHub Webhooks

```toml
[webhooks.incoming.github]
enabled = true
path = "/webhooks/github"
secret = "${GITHUB_WEBHOOK_SECRET}"
signature_header = "X-Hub-Signature-256"
events = ["push", "pull_request", "issues"]
```

### Stripe Webhooks

```toml
[webhooks.incoming.stripe]
enabled = true
path = "/webhooks/stripe"
secret = "${STRIPE_WEBHOOK_SECRET}"
signature_header = "Stripe-Signature"
tolerance_seconds = 300
```

### Custom Provider

```toml
[webhooks.incoming.custom]
enabled = true
path = "/webhooks/custom"
secret = "${CUSTOM_WEBHOOK_SECRET}"
signature_header = "X-Signature"
signature_format = "sha256={signature}"
timestamp_header = "X-Timestamp"
```

## Retry Configuration

### Outgoing Webhooks

```toml
[webhooks.retry]
enabled = true
max_attempts = 5
initial_delay_ms = 1000
max_delay_ms = 60000
backoff_multiplier = 2.0

# Retry on these status codes
retry_status_codes = [408, 429, 500, 502, 503, 504]
```

### Dead Letter Queue

```toml
[webhooks.dlq]
enabled = true
storage = "postgres"  # or "redis"
retention_days = 7

[webhooks.dlq.postgres]
table_name = "tb_webhook_dlq"
```

Inspect failed webhooks:

```bash
# List failed webhooks
fraiseql-cli webhook dlq list

# Retry a specific webhook
fraiseql-cli webhook dlq retry --id "webhook-123"

# Retry all failed
fraiseql-cli webhook dlq retry-all --older-than 1h
```

## Timeouts and Limits

```toml
[webhooks]
# Connection timeout
connect_timeout_ms = 5000

# Request timeout
request_timeout_ms = 30000

# Max payload size
max_payload_bytes = 1048576  # 1MB

# Max concurrent requests
max_concurrent = 100
```sql

## Template Variables

Available in webhook body templates:

| Variable | Description |
|----------|-------------|
| `{{field_name}}` | Entity field value |
| `{{_id}}` | Entity ID |
| `{{_timestamp}}` | Event timestamp (ISO 8601) |
| `{{_event}}` | Event type (INSERT, UPDATE, DELETE) |
| `{{_entity}}` | Entity type name |
| `{{_json}}` | Entire entity as JSON |
| `{{_old}}` | Previous values (UPDATE only) |
| `{{_changed}}` | Changed fields (UPDATE only) |

### Example Template

```python
webhook(
    "https://api.example.com/events",
    body_template='''
    {
        "event_type": "{{_entity}}.{{_event}}",
        "entity_id": "{{_id}}",
        "timestamp": "{{_timestamp}}",
        "data": {{_json}},
        "changes": {{_changed}}
    }
    '''
)
```

## Metrics

| Metric | Description |
|--------|-------------|
| `fraiseql_webhook_requests_total` | Total webhook requests |
| `fraiseql_webhook_success_total` | Successful deliveries |
| `fraiseql_webhook_failure_total` | Failed deliveries |
| `fraiseql_webhook_retry_total` | Retry attempts |
| `fraiseql_webhook_latency_ms` | Delivery latency |
| `fraiseql_webhook_dlq_size` | Dead letter queue size |

## Best Practices

### Use Idempotency Keys

Include idempotency key for safe retries:

```python
webhook(
    "https://api.example.com/orders",
    headers={
        "Idempotency-Key": "{{_entity}}-{{_id}}-{{_timestamp}}"
    }
)
```

### Verify Signatures

Always verify incoming webhook signatures:

```python
if not verify_webhook(payload, signature, timestamp, secret):
    raise HTTPException(401, "Invalid signature")
```

### Handle Retries Gracefully

Expect duplicate deliveries:

```python
@app.post("/webhook")
def handle_webhook(data: dict):
    # Use idempotency key to prevent duplicate processing
    key = request.headers.get("Idempotency-Key")
    if already_processed(key):
        return {"status": "already_processed"}

    process_webhook(data)
    mark_processed(key)
    return {"status": "ok"}
```

### Monitor Delivery

```
# Webhook success rate
sum(rate(fraiseql_webhook_success_total[5m])) /
sum(rate(fraiseql_webhook_requests_total[5m]))

# Alert on DLQ growth
fraiseql_webhook_dlq_size > 100
```

## Troubleshooting

### Webhook Not Delivered

1. Check endpoint is reachable
2. Verify URL is correct
3. Check firewall rules
4. Review retry attempts in logs

### Signature Mismatch

1. Verify secret matches on both sides
2. Check timestamp tolerance
3. Ensure payload isn't modified (proxies, encoding)
4. Verify signature algorithm matches

### High Latency

1. Increase timeout settings
2. Check endpoint performance
3. Consider async processing on receiver

## Next Steps

- [Observers](/concepts/observers) - Event-driven webhooks
- [Security](/features/security) - Webhook authentication
- [Rate Limiting](/features/rate-limiting) - Protect webhook endpoints