---
title: Custom Resolvers & Lifecycle Hooks
description: Advanced resolver patterns, lifecycle hooks, middleware, and business logic integration
---

Advanced resolver patterns for implementing custom business logic, middleware, and lifecycle hooks in FraiseQL.

## Custom Resolver Fundamentals

### Resolver Execution Flow

```d2
direction: down

graphql_request: {
  label: "👤 GraphQL Request"
  shape: box
}

parse: {
  label: "Parse Query"
  shape: box
}

validate: {
  label: "Validate Schema"
  shape: box
}

plan: {
  label: "Create Execution Plan"
  shape: box
}

resolver_pipeline: {
  shape: frame
  label: "🔄 Resolver Pipeline"

  before_hook: "❌ Before Hook"
  field_resolver: "⚙️ Field Resolver"
  after_hook: "✅ After Hook"
  error_handler: "🛡️ Error Handler"
}

db_query: {
  label: "Execute Query"
  shape: box
}

response: {
  label: "📤 Response"
  shape: box
}

graphql_request -> parse
parse -> validate
validate -> plan
plan -> resolver_pipeline.before_hook

resolver_pipeline.before_hook -> resolver_pipeline.field_resolver
resolver_pipeline.field_resolver -> resolver_pipeline.after_hook
resolver_pipeline.after_hook -> db_query

db_query -> response: "Success path"
resolver_pipeline.error_handler -> response: "Error path"
```

### Basic Custom Resolver

```python
import fraiseql
from fraiseql import Context, FieldResolver

@fraiseql.type
class User:
    id: fraiseql.ID
    name: str
    email: str

    # Custom resolver for derived field
    @fraiseql.field_resolver
    async def display_name(self, ctx: Context) -> str:
        """
        Custom resolver: doesn't come from database.
        Derived field computed at query time.
        """
        return f"{self.name} ({self.email})"

    # Resolver with dependencies
    @fraiseql.field_resolver
    async def post_count(self, ctx: Context) -> int:
        """
        Count posts by this user.
        Called per object in list.
        """
        count = await ctx.db.query(
            "SELECT COUNT(*) FROM tb_post WHERE user_id = $1",
            [self.id]
        )
        return count.get("count", 0)

# GraphQL query usage:
# query {
#   user(id: "123") {
#     id
#     name
#     displayName  # Custom resolver invoked
#     postCount    # Custom resolver invoked
#   }
# }
```

### Root Query Custom Resolvers

```python
@fraiseql.query
async def featured_posts(ctx: Context, limit: int = 10) -> list['Post']:
    """
    Custom root query with business logic.
    Not just a direct database view.
    """
    # Step 1: Get trending posts
    trending = await ctx.db.query(
        """SELECT id, title, view_count
           FROM v_post
           WHERE view_count > $1
           ORDER BY view_count DESC
           LIMIT $2""",
        [1000, limit]
    )

    # Step 2: Filter by quality score
    posts = []
    for row in trending:
        quality_score = await calculate_quality(row.id)
        if quality_score > 0.8:
            posts.append(row)

    # Step 3: Enrich with metadata
    enriched = await enrich_posts(posts, ctx)
    return enriched

@fraiseql.query
async def trending_users(
    ctx: Context,
    time_range: str = "7d",
    limit: int = 20
) -> list['User']:
    """
    Complex business logic: trending users.
    Combines multiple data sources.
    """
    cutoff_date = calculate_date(time_range)

    # Get users with activity
    users = await ctx.db.query(
        """SELECT u.id, u.name, COUNT(p.id) as activity_score
           FROM tb_user u
           LEFT JOIN tb_post p ON u.id = p.user_id
           WHERE p.created_at > $1
           GROUP BY u.id
           ORDER BY activity_score DESC
           LIMIT $2""",
        [cutoff_date, limit]
    )

    return [await User.from_row(row) for row in users]
```

---

## Lifecycle Hooks

### Hook Execution Sequence

```python
from fraiseql import Hook, HookContext
import datetime

@fraiseql.type(database="primary")
class Order:
    id: fraiseql.ID
    user_id: fraiseql.ID
    total: fraiseql.Decimal
    status: str
    created_at: datetime.datetime

    # Lifecycle hooks
    @Hook.BEFORE_CREATE
    async def validate_order(self, ctx: HookContext):
        """Before insert - validation."""
        if self.total < 0:
            raise ValueError("Total cannot be negative")

    @Hook.AFTER_CREATE
    async def init_order_state(self, ctx: HookContext):
        """After insert - initialize related data."""
        self.status = "pending"
        await ctx.db.insert(
            "tb_order_status",
            {
                "order_id": self.id,
                "status": "created",
                "timestamp": datetime.datetime.now()
            }
        )

    @Hook.BEFORE_UPDATE
    async def validate_update(self, self_new, ctx: HookContext):
        """Before update - ensure valid transitions."""
        if self.status == "shipped" and self_new.status != "shipped":
            raise ValueError("Cannot change status after shipping")

    @Hook.AFTER_UPDATE
    async def track_state_change(self, self_new, ctx: HookContext):
        """After update - audit trail."""
        await ctx.db.insert(
            "tb_order_audit",
            {
                "order_id": self.id,
                "change": json.dumps({
                    "from": self.__dict__,
                    "to": self_new.__dict__
                }),
                "timestamp": datetime.datetime.now()
            }
        )

    @Hook.BEFORE_DELETE
    async def prevent_critical_delete(self, ctx: HookContext):
        """Before delete - prevent mistakes."""
        if self.status == "shipped":
            raise ValueError("Cannot delete shipped orders")

    @Hook.AFTER_DELETE
    async def cleanup_order(self, ctx: HookContext):
        """After delete - cleanup related data."""
        await ctx.db.delete_where(
            "tb_order_item",
            "order_id = $1",
            [self.id]
        )
```

### Hook Order During Mutation

```

                   ─→

                   ─→

                   ─→

                   ─→
```

---

## Context & Authorization

### Context Propagation

```python
from fraiseql import Context
from typing import Optional

class TenantContext(Context):
    """Extended context with tenant info."""
    tenant_id: str
    user_id: str
    roles: list[str]
    request_id: str

@fraiseql.query
async def user_profile(ctx: TenantContext, id: str) -> Optional['User']:
    """Access tenant info in resolver."""
    # Query is automatically filtered to tenant
    user = await ctx.db.query_one(
        """SELECT * FROM tb_user
           WHERE id = $1 AND tenant_id = $2""",
        [id, ctx.tenant_id]
    )

    if not user:
        return None

    # Track in audit log
    await ctx.db.insert(
        "tb_audit_log",
        {
            "user_id": ctx.user_id,
            "action": "view_profile",
            "target_id": id,
            "request_id": ctx.request_id,
            "timestamp": datetime.now()
        }
    )

    return user
```

### Field-Level Authorization

```python
from fraiseql import Directive, AuthError

@fraiseql.type
class User:
    id: fraiseql.ID
    name: str
    email: str

    @fraiseql.field_resolver
    async def email(self, ctx: Context) -> str:
        """
        Email field with authorization.
        Only visible to self or admins.
        """
        if ctx.user_id != self.id and "admin" not in ctx.roles:
            raise AuthError("Not authorized to view email")
        return self.email

    @fraiseql.field_resolver
    async def password_hash(self, ctx: Context) -> str:
        """
        Password hash - never exposed to client.
        """
        if "system" not in ctx.roles:
            raise AuthError("System access only")
        return await ctx.db.query_one(
            "SELECT password_hash FROM tb_user WHERE id = $1",
            [self.id]
        )
```

---

## Middleware & Interceptors

### Query Middleware

```python
from fraiseql import Middleware, MiddlewareContext
import time

class PerformanceMiddleware(Middleware):
    """Monitor resolver performance."""

    async def before_resolve(self, ctx: MiddlewareContext):
        """Executed before each resolver."""
        ctx.start_time = time.time()

    async def after_resolve(self, ctx: MiddlewareContext, result):
        """Executed after each resolver."""
        duration = time.time() - ctx.start_time
        if duration > 1.0:  # Slow query
            await send_alert(
                f"Slow resolver: {ctx.field_name} took {duration:.2f}s"
            )
        return result

    async def on_error(self, ctx: MiddlewareContext, error):
        """Executed on resolver error."""
        await log_error({
            "field": ctx.field_name,
            "error": str(error),
            "context": ctx.to_dict()
        })

@fraiseql.register_middleware(PerformanceMiddleware())
```

### Request-Level Middleware

```python
class AuthenticationMiddleware(Middleware):
    """Validate authentication before resolving."""

    async def before_request(self, ctx: MiddlewareContext):
        """Run before any resolvers."""
        token = ctx.headers.get("Authorization")
        if not token:
            raise AuthError("Missing authorization")

        user = await verify_token(token)
        ctx.user = user
        ctx.tenant_id = user.tenant_id

@fraiseql.register_middleware(AuthenticationMiddleware())
```

---

## Batch Loading & N+1 Prevention

### Batch Loader Pattern

```python
from dataloader import DataLoader

class UserDataLoader:
    """Batch load users to prevent N+1."""

    def __init__(self, db):
        self.db = db
        # DataLoader batches requests and caches
        self.loader = DataLoader(self.batch_get_users)

    async def batch_get_users(self, user_ids):
        """Load multiple users in one query."""
        users = await self.db.query(
            """SELECT * FROM tb_user WHERE id = ANY($1)""",
            [user_ids]
        )
        # Return in same order as requested
        user_map = {u.id: u for u in users}
        return [user_map.get(uid) for uid in user_ids]

    async def load(self, user_id):
        """Load single user (batched automatically)."""
        return await self.loader.load(user_id)

# Usage in field resolver
@fraiseql.type
class Post:
    id: fraiseql.ID
    title: str
    author_id: fraiseql.ID

    @fraiseql.field_resolver
    async def author(self, ctx: Context) -> 'User':
        """
        Resolve author - batched automatically.
        100 posts will make 1 query, not 100.
        """
        user_loader = ctx.get_loader(UserDataLoader)
        return await user_loader.load(self.author_id)

# GraphQL query:
# query {
#   posts(limit: 100) {
#     title
#     author { name }  # Only 2 queries total (1 for posts, 1 for 100 authors)
#   }
# }
```

---

## Error Handling in Resolvers

### Structured Error Handling

```python
from enum import Enum
from dataclasses import dataclass

class ErrorCode(Enum):
    """Application-specific error codes."""
    USER_NOT_FOUND = "USER_NOT_FOUND"
    INVALID_INPUT = "INVALID_INPUT"
    INSUFFICIENT_BALANCE = "INSUFFICIENT_BALANCE"
    DATABASE_ERROR = "DATABASE_ERROR"
    TIMEOUT = "TIMEOUT"

@dataclass
class AppError(Exception):
    """Structured error with code and context."""
    code: ErrorCode
    message: str
    context: dict = None

@fraiseql.query
async def transfer_funds(
    ctx: Context,
    from_id: str,
    to_id: str,
    amount: float
) -> 'TransferResult':
    """Transfer with comprehensive error handling."""
    try:
        # Validate inputs
        if amount <= 0:
            raise AppError(
                ErrorCode.INVALID_INPUT,
                "Amount must be positive",
                {"amount": amount}
            )

        # Check balances
        from_account = await ctx.db.query_one(
            "SELECT balance FROM tb_account WHERE id = $1",
            [from_id]
        )

        if not from_account:
            raise AppError(
                ErrorCode.USER_NOT_FOUND,
                f"Account {from_id} not found",
                {"account_id": from_id}
            )

        if from_account.balance < amount:
            raise AppError(
                ErrorCode.INSUFFICIENT_BALANCE,
                "Insufficient funds",
                {
                    "available": float(from_account.balance),
                    "requested": amount
                }
            )

        # Execute transfer
        result = await ctx.db.transaction(
            transfer_transaction,
            from_id, to_id, amount
        )

        return result

    except AppError as e:
        # Return structured error to client
        raise GraphQLError(
            message=e.message,
            extensions={
                "code": e.code.value,
                "context": e.context
            }
        )

    except asyncio.TimeoutError:
        raise AppError(
            ErrorCode.TIMEOUT,
            "Operation timed out",
            {"timeout": "30s"}
        )

    except Exception as e:
        # Log unexpected errors
        await log_error({
            "error": str(e),
            "type": type(e).__name__,
            "context": {
                "from": from_id,
                "to": to_id,
                "amount": amount
            }
        })
        raise AppError(
            ErrorCode.DATABASE_ERROR,
            "An error occurred processing your request"
        )
```

---

## Advanced Patterns

### Caching in Resolvers

```python
from functools import lru_cache
import hashlib

class CachedResolver:
    def __init__(self, ttl=300):
        self.ttl = ttl
        self.cache = {}

    async def get_with_cache(self, key, fn, *args):
        """Get value from cache or compute."""
        cache_key = hashlib.md5(str(key).encode()).hexdigest()

        if cache_key in self.cache:
            value, expire_at = self.cache[cache_key]
            if time.time() < expire_at:
                return value

        # Cache miss - compute value
        value = await fn(*args)
        self.cache[cache_key] = (value, time.time() + self.ttl)
        return value

@fraiseql.type
class Post:
    id: fraiseql.ID
    title: str

    @fraiseql.field_resolver
    async def engagement_score(self, ctx: Context) -> float:
        """
        Expensive calculation - cache result.
        """
        cache = ctx.get_cache(CachedResolver)
        return await cache.get_with_cache(
            f"engagement:{self.id}",
            calculate_engagement,
            self.id
        )
```

### Side Effects & Outbound Calls

```python
@fraiseql.mutation(operation="CREATE")
async def create_user(
    ctx: Context,
    email: str,
    name: str
) -> 'User':
    """
    Create user with side effects.
    Calls external services.
    """
    try:
        # Create in database
        user = await ctx.db.insert(
            "tb_user",
            {"email": email, "name": name}
        )

        # Send welcome email (fire and forget)
        asyncio.create_task(send_welcome_email(email, name))

        # Notify analytics service
        await notify_analytics(
            "user_created",
            {"user_id": user.id, "email": email}
        )

        return user

    except Exception as e:
        # Cleanup on error
        await ctx.db.delete_where(
            "tb_user",
            "email = $1",
            [email]
        )
        raise
```

---

## Testing Custom Resolvers

### Unit Testing Resolvers

```python
import pytest
from unittest.mock import MagicMock, AsyncMock

@pytest.fixture
def mock_context():
    """Mock FraiseQL context for testing."""
    ctx = MagicMock()
    ctx.db = AsyncMock()
    ctx.user_id = "test-user"
    ctx.tenant_id = "test-tenant"
    return ctx

@pytest.mark.asyncio
async def test_featured_posts_resolver(mock_context):
    """Test featured_posts custom resolver."""
    # Mock database response
    mock_context.db.query.return_value = [
        {"id": "1", "title": "Post 1", "view_count": 1500},
        {"id": "2", "title": "Post 2", "view_count": 2000},
    ]

    # Execute resolver
    result = await featured_posts(mock_context, limit=10)

    # Verify database was called
    mock_context.db.query.assert_called_once()

    # Verify result
    assert len(result) == 2
    assert result[0].id == "1"
```

### Integration Testing

```python
import pytest
from fraiseql.testing import FraiseQLTestClient

@pytest.fixture
async def client():
    """Create test client."""
    return await FraiseQLTestClient.create(
        config="fraiseql.test.toml"
    )

@pytest.mark.asyncio
async def test_featured_posts_integration(client):
    """Test resolver with real database."""
    query = """
        query {
            featuredPosts(limit: 5) {
                id
                title
                viewCount
            }
        }
    """

    result = await client.execute(query)
    assert result["data"]["featuredPosts"] is not None
```

---

## Performance Considerations

### Resolver Complexity

```


│              │  │              │     │              │
│              │  │              │     │              │
│              │  │              │     │              │
↓              ↓  ↓              ↓     ↓              ↓
```

### Resolver Timeout Management

```python
import asyncio

@fraiseql.query
async def complex_report(ctx: Context) -> 'Report':
    """
    Long-running resolver with timeout.
    """
    try:
        result = await asyncio.wait_for(
            generate_report(ctx),
            timeout=30.0  # 30 second timeout
        )
        return result
    except asyncio.TimeoutError:
        raise AppError(
            ErrorCode.TIMEOUT,
            "Report generation timed out. Please try again."
        )
```

---

## Best Practices Checklist

### Design
- [ ] Keep resolvers single-responsibility
- [ ] Use DataLoader for related data
- [ ] Implement caching for expensive operations
- [ ] Validate inputs early
- [ ] Return clear error messages

### Implementation
- [ ] Always handle errors explicitly
- [ ] Log important operations
- [ ] Add request correlation IDs
- [ ] Use middleware for cross-cutting concerns
- [ ] Document resolver behavior

### Performance
- [ ] Profile resolver latency
- [ ] Detect and fix N+1 queries
- [ ] Implement appropriate caching
- [ ] Set resolver timeouts
- [ ] Monitor database query time

### Testing
- [ ] Unit test with mock context
- [ ] Integration test with real DB
- [ ] Test error conditions
- [ ] Test concurrent access
- [ ] Performance test with realistic data

---

## Next Steps

- [Advanced Federation](/guides/advanced-federation) — Multi-database resolvers
- [NATS Integration](/guides/advanced-nats) — Real-time side effects
- [Performance Tuning](/guides/performance) — Optimization strategies
- [Testing Guide](/guides/testing) — Comprehensive testing patterns
`3
`3