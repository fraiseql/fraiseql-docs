---
title: Error Handling
description: Complete guide to FraiseQL error handling, error codes, and recovery strategies
---

# Error Handling

This guide covers error handling in FraiseQL, including all error codes, response structures, recovery strategies, and best practices for production systems.

## Error Response Structure

Every FraiseQL error response follows a consistent structure:

```json
{
  "errors": [
    {
      "message": "User not found",
      "extensions": {
        "code": "NOT_FOUND",
        "statusCode": 404,
        "userId": "abc123",
        "timestamp": "2024-01-15T10:30:00Z"
      }
    }
  ],
  "data": null
}
```

### Error Fields

| Field | Type | Description |
|-------|------|-------------|
| `message` | string | Human-readable error description |
| `extensions.code` | string | Machine-readable error code |
| `extensions.statusCode` | number | HTTP status code |
| `extensions.context` | object | Additional context (varies by error) |
| `extensions.timestamp` | string | ISO 8601 timestamp |
| `data` | object/null | Partial response data (if applicable) |

## Authentication Errors (400-403)

### 400: Invalid Credentials

```json
{
  "errors": [{
    "message": "Invalid API key format",
    "extensions": {
      "code": "INVALID_CREDENTIALS",
      "statusCode": 400
    }
  }]
}
```

**Recovery:**
```python
try:
    response = await client.query(query)
except AuthenticationError as e:
    if e.code == "INVALID_CREDENTIALS":
        # Check API key format
        # Verify key is in environment variables
        logging.error("Check your FRAISEQL_API_KEY environment variable")
```

### 401: Unauthorized

```json
{
  "errors": [{
    "message": "Unauthorized",
    "extensions": {
      "code": "UNAUTHORIZED",
      "statusCode": 401,
      "reason": "Token expired"
    }
  }]
}
```

**Recovery:**
```python
try:
    response = await client.query(query)
except UnauthorizedError as e:
    if e.reason == "Token expired":
        # Refresh token
        new_token = await refresh_auth_token()
        client = Client(url=API_URL, auth=BearerAuth(new_token))
    else:
        logging.error("Authentication failed - check credentials")
```

### 403: Forbidden

```json
{
  "errors": [{
    "message": "Insufficient permissions",
    "extensions": {
      "code": "FORBIDDEN",
      "statusCode": 403,
      "requiredScopes": ["users:read", "users:write"],
      "grantedScopes": ["users:read"]
    }
  }]
}
```

**Recovery:**
```python
except ForbiddenError as e:
    required = set(e.required_scopes)
    granted = set(e.granted_scopes)
    missing = required - granted

    if missing:
        print(f"Request missing scopes: {missing}")
        # Redirect to re-authentication with new scopes
```

## Validation Errors (422)

### 422: Query Validation

```json
{
  "errors": [{
    "message": "Cannot query field 'invalidField' on type 'User'",
    "extensions": {
      "code": "GRAPHQL_VALIDATION_FAILED",
      "statusCode": 422,
      "field": "invalidField",
      "type": "User"
    }
  }]
}
```

**Recovery:**
```python
try:
    response = await client.query(query)
except ValidationError as e:
    if e.code == "GRAPHQL_VALIDATION_FAILED":
        logging.error(f"Invalid query on {e.type}.{e.field}")
        # Review schema reference at /reference/graphql-api
```

### 422: Input Validation

```json
{
  "errors": [{
    "message": "Invalid input for field 'email'",
    "extensions": {
      "code": "INVALID_INPUT",
      "statusCode": 422,
      "field": "email",
      "reason": "Must be valid email format"
    }
  }]
}
```

**Recovery:**
```python
try:
    result = await client.mutate(mutation, variables={"input": data})
except InvalidInputError as e:
    # Validate input before sending
    if not is_valid_email(data["email"]):
        print(f"Invalid email: {e.reason}")
        # Re-prompt user for valid input
```

## Rate Limiting (429)

### 429: Too Many Requests

```json
{
  "errors": [{
    "message": "Rate limit exceeded",
    "extensions": {
      "code": "RATE_LIMITED",
      "statusCode": 429,
      "retryAfter": 60,
      "limit": 1000,
      "current": 1050,
      "resetAt": "2024-01-15T10:31:00Z"
    }
  }]
}
```

**Recovery with Exponential Backoff:**
```python
import asyncio
from functools import wraps

def retry_on_rate_limit(max_retries=3):
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            for attempt in range(max_retries):
                try:
                    return await func(*args, **kwargs)
                except RateLimitedError as e:
                    if attempt == max_retries - 1:
                        raise

                    wait_time = min(
                        e.retry_after or (2 ** attempt),
                        300  # Max 5 minutes
                    )
                    logging.warning(f"Rate limited. Waiting {wait_time}s")
                    await asyncio.sleep(wait_time)
        return wrapper
    return decorator

@retry_on_rate_limit()
async def safe_query(query):
    return await client.query(query)
```

## Server Errors (500+)

### 500: Internal Server Error

```json
{
  "errors": [{
    "message": "Internal server error",
    "extensions": {
      "code": "INTERNAL_ERROR",
      "statusCode": 500,
      "requestId": "req_abc123",
      "timestamp": "2024-01-15T10:30:00Z"
    }
  }]
}
```

**Recovery:**
```python
try:
    response = await client.query(query)
except InternalServerError as e:
    # Log with request ID for support
    logging.error(f"Server error. Request ID: {e.request_id}")

    # Implement circuit breaker pattern
    if should_open_circuit_breaker(e):
        # Stop sending requests temporarily
        await notify_operations(f"API down: {e.request_id}")
```

### 503: Service Unavailable

```json
{
  "errors": [{
    "message": "Service temporarily unavailable",
    "extensions": {
      "code": "SERVICE_UNAVAILABLE",
      "statusCode": 503,
      "retryAfter": 120
    }
  }]
}
```

**Recovery:**
```python
try:
    response = await client.query(query)
except ServiceUnavailableError as e:
    retry_after = e.retry_after or 60

    # Queue for retry
    retry_queue.put((time.time() + retry_after, query))
    logging.warning(f"Service unavailable. Retrying after {retry_after}s")

    # Use fallback/cached data if available
    return get_cached_response(query)
```

## Database-Specific Errors

### PostgreSQL Errors

#### Connection Timeout

```json
{
  "errors": [{
    "message": "Database connection timeout",
    "extensions": {
      "code": "DB_CONNECTION_TIMEOUT",
      "database": "postgresql",
      "timeout": 30000
    }
  }]
}
```

**Recovery:**
```python
# Increase connection pool
client = Client(
    url=API_URL,
    db_connection_pool_size=20,
    db_connection_timeout=60000
)
```

#### Constraint Violation

```json
{
  "errors": [{
    "message": "Unique constraint violation",
    "extensions": {
      "code": "CONSTRAINT_VIOLATION",
      "database": "postgresql",
      "constraint": "unique_email",
      "table": "users",
      "column": "email"
    }
  }]
}
```

**Recovery:**
```python
try:
    result = await client.mutate(create_user, {"email": email})
except ConstraintViolationError as e:
    if e.constraint == "unique_email":
        # Email already exists
        existing_user = await get_user_by_email(email)
        return existing_user
```

### MySQL Errors

#### Deadlock Detected

```json
{
  "errors": [{
    "message": "Deadlock detected",
    "extensions": {
      "code": "DB_DEADLOCK",
      "database": "mysql",
      "transaction_id": "tx_123"
    }
  }]
}
```

**Recovery:**
```python
async def retry_on_deadlock(query, max_retries=3):
    for attempt in range(max_retries):
        try:
            return await client.query(query)
        except DatabaseDeadlockError:
            if attempt == max_retries - 1:
                raise
            wait = (2 ** attempt) + random()
            await asyncio.sleep(wait)
```

### SQLite Errors

#### Database Locked

```json
{
  "errors": [{
    "message": "Database locked",
    "extensions": {
      "code": "DB_LOCKED",
      "database": "sqlite",
      "locked_by": "writer_process_123"
    }
  }]
}
```

**Recovery:**
```python
# SQLite has single writer - serialize operations
class SQLiteQuerySerializer:
    def __init__(self):
        self.lock = asyncio.Lock()

    async def query(self, query):
        async with self.lock:
            return await client.query(query)
```

### SQL Server Errors

#### Login Timeout

```json
{
  "errors": [{
    "message": "Login timeout expired",
    "extensions": {
      "code": "DB_LOGIN_TIMEOUT",
      "database": "sqlserver"
    }
  }]
}
```

**Recovery:**
```python
# Increase login timeout
client = Client(
    url=API_URL,
    db_login_timeout=60000  # 60 seconds
)
```

## Error Code Reference

### Authentication (AUTH_*)

| Code | Status | Description | Recovery |
|------|--------|-------------|----------|
| `INVALID_CREDENTIALS` | 400 | API key format invalid | Verify API key format |
| `UNAUTHORIZED` | 401 | Token missing/expired | Re-authenticate |
| `FORBIDDEN` | 403 | Insufficient permissions | Request additional scopes |
| `INVALID_TOKEN` | 401 | Token signature invalid | Refresh token |
| `TOKEN_EXPIRED` | 401 | Token lifetime exceeded | Use refresh token |
| `SCOPE_REQUIRED` | 403 | Missing required scope | Re-authenticate with scope |

### Query (GRAPHQL_*)

| Code | Status | Description | Recovery |
|------|--------|-------------|----------|
| `GRAPHQL_VALIDATION_FAILED` | 422 | Query syntax invalid | Review schema |
| `GRAPHQL_PARSE_ERROR` | 400 | Query parse failed | Fix GraphQL syntax |
| `GRAPHQL_EXECUTION_ERROR` | 500 | Resolver error | Check logs |
| `GRAPHQL_TYPE_ERROR` | 422 | Type mismatch | Verify input types |

### Input (INPUT_*)

| Code | Status | Description | Recovery |
|------|--------|-------------|----------|
| `INVALID_INPUT` | 422 | Input validation failed | Review error details |
| `MISSING_REQUIRED_FIELD` | 422 | Required field missing | Provide all required fields |
| `INVALID_FORMAT` | 422 | Field format incorrect | Use correct format |
| `INVALID_ENUM_VALUE` | 422 | Enum value invalid | Use valid enum values |

### Rate Limiting (RATE_*)

| Code | Status | Description | Recovery |
|------|--------|-------------|----------|
| `RATE_LIMITED` | 429 | Request rate exceeded | Back off and retry |
| `QUOTA_EXCEEDED` | 429 | Usage quota exceeded | Wait for reset |
| `THROTTLED` | 429 | Temporarily throttled | Implement backoff |

### Database (DB_*)

| Code | Status | Description | Recovery |
|------|--------|-------------|----------|
| `DB_CONNECTION_ERROR` | 500 | Connection failed | Check database server |
| `DB_CONNECTION_TIMEOUT` | 500 | Connection timeout | Increase timeout |
| `DB_QUERY_TIMEOUT` | 504 | Query exceeded timeout | Optimize query |
| `DB_CONSTRAINT_VIOLATION` | 422 | Constraint failed | Check input data |
| `DB_DEADLOCK` | 503 | Deadlock detected | Retry with backoff |
| `DB_LOCKED` | 503 | Database locked | Retry later |

### Server (SERVER_*)

| Code | Status | Description | Recovery |
|------|--------|-------------|----------|
| `INTERNAL_ERROR` | 500 | Unhandled error | Report with request ID |
| `SERVICE_UNAVAILABLE` | 503 | Service down | Retry after delay |
| `MAINTENANCE_MODE` | 503 | Scheduled maintenance | Wait for completion |
| `OVERLOAD` | 503 | Server overloaded | Implement backoff |

## Best Practices

### 1. Structured Error Logging

```python
import logging
import json
from datetime import datetime

class StructuredLogger:
    def log_error(self, error, context=None):
        log_entry = {
            "timestamp": datetime.utcnow().isoformat(),
            "error_code": error.code,
            "error_message": error.message,
            "status_code": error.status_code,
            "context": context or {},
            "request_id": error.request_id,
        }
        logging.error(json.dumps(log_entry))

# Usage
logger = StructuredLogger()
try:
    await client.query(query)
except Exception as e:
    logger.log_error(e, context={"query": query[:100]})
```

### 2. Error Recovery Strategies

```python
class ResilientClient:
    async def query_with_fallback(self, query, fallback_data=None):
        try:
            return await self.client.query(query)
        except RateLimitedError:
            await asyncio.sleep(60)
            return await self.client.query(query)
        except ServiceUnavailableError:
            return fallback_data or {}
        except Exception as e:
            logging.error(f"Query failed: {e}")
            raise
```

### 3. Monitoring Error Rates

```python
from prometheus_client import Counter, Histogram

error_counter = Counter(
    'fraiseql_errors_total',
    'Total FraiseQL errors',
    ['error_code', 'status_code']
)

response_time = Histogram(
    'fraiseql_response_time_seconds',
    'FraiseQL response time'
)

@response_time.time()
async def monitored_query(query):
    try:
        return await client.query(query)
    except Exception as e:
        error_counter.labels(
            error_code=e.code,
            status_code=e.status_code
        ).inc()
        raise
```

## Related Guides

- [Authentication](/guides/authentication) - Set up authentication properly
- [Performance](/guides/performance) - Optimize queries to reduce errors
- [Troubleshooting](/guides/troubleshooting) - Common issues and solutions
- [Rate Limiting](/features/rate-limiting) - Understand rate limit configuration