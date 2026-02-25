---
title: Migrating from Hasura to FraiseQL
description: Guide to migrate from Hasura to FraiseQL for type-safe GraphQL backends
---

# Migrating from Hasura to FraiseQL

This guide covers migrating from Hasura (database-first GraphQL) to FraiseQL (code-first GraphQL).

## Comparison

| Feature | Hasura | FraiseQL |
|---------|--------|----------|
| **Approach** | Database-first (auto-schema from DB) | Code-first (schema from Python) |
| **Configuration** | Web UI + YAML | Python decorators + TOML |
| **Type Safety** | GraphQL generated | Native SDK types |
| **Hosting** | Cloud or self-hosted | Any server (Docker, K8s) |
| **Custom Logic** | Actions + Webhooks | Built-in resolvers |
| **Federation** | No | Yes (multi-database) |
| **Performance** | Good | Excellent (auto-batching) |
| **Learning Curve** | Low (UI-driven) | Medium (code-driven) |

## Architecture Difference



                ─                      ─
```



             ─                     ─
```

## Migration Path

### Step 1: Export Hasura Configuration

```bash
# Get current Hasura metadata
hasura metadata export

# Review generated metadata
cat metadata/databases/default/tables/
```

### Step 2: Map Hasura Tables to FraiseQL Types

**Hasura setup (in YAML):**
```
# metadata/databases/default/tables/user.yaml
table:
  name: user
  schema: public
select_permissions:
  - role: user
    permission:
      columns: [id, email, name]
      filter:
        id:
          _eq: X-Hasura-User-Id
relationships:
  - name: posts
    type: array
    using:
      foreign_key_constraint_on:
        column: user_id
        table:
          name: post
          schema: public
```

**FraiseQL equivalent:**
```python
@fraiseql.type
class User:
    id: ID
    email: str
    name: str
    posts: list['Post']  # Relationship

@fraiseql.query(sql_source="v_user", requires_scope="read:User")
def user(id: ID) -> User:
    """Get user (enforces RLS filter)."""
    pass
```

### Step 3: Replicate Permissions

**Hasura (YAML):**
```
select_permissions:
  - role: user
    permission:
      columns: [id, name, email]
      filter:
        id:
          _eq: X-Hasura-User-Id
```

**FraiseQL (Python):**
```python
@fraiseql.query(sql_source="v_user_filtered", requires_scope="read:User")
def my_profile() -> User:
    """User can only see their own profile."""
    pass

# In database:
# CREATE VIEW v_user_filtered AS
# SELECT * FROM tb_user WHERE id = current_user_id();
```

### Step 4: Migrate Custom Logic

**Hasura (Actions):**
```
# Webhook-based action
actions:
  - name: sendEmail
    definition:
      kind: action
      arguments:
        - name: email
          type: String!
        - name: message
          type: String!
      output_type: ActionOutput
      webhook_url: https://myapp.com/send-email
      timeout: 30
```

**FraiseQL (Native mutation):**
```python
@fraiseql.mutation
async def send_email(email: str, message: str) -> dict:
    """Send email directly."""
    result = await send_email_service(email, message)
    return {"success": result.success, "message": result.message}
```

### Step 5: Real-time Subscriptions

**Hasura (Subscriptions):**
```graphql
subscription OnUserCreated {
  user(event: insert) {
    id
    name
    email
  }
}
```

**FraiseQL (with NATS):**
```python
@fraiseql.subscription(entity_type="User", topic="created")
def user_created() -> User:
    """Subscribe to new users."""
    pass
```

## Query Syntax (Mostly Compatible)

### Filtering

**Hasura:**
```graphql
query {
  user(where: {
    email: { _eq: "alice@example.com" }
    posts: { title: { _ilike: "hello%" } }
  }) {
    id
    email
  }
}
```

**FraiseQL:**
```graphql
query {
  user(
    email_eq: "alice@example.com"
    posts_title_contains: "hello"
  ) {
    id
    email
  }
}
```

### Ordering

**Hasura:**
```graphql
query {
  users(order_by: { created_at: desc }) {
    id
    name
  }
}
```

**FraiseQL:**
```graphql
query {
  users(orderBy: "created_at DESC") {
    id
    name
  }
}
```

### Pagination

Both use limit/offset:
```graphql
query {
  users(limit: 10, offset: 20) {
    id
    name
  }
}
```

## Performance Improvements

### Hasura
- Manual N+1 optimization
- No automatic batching
- Requires careful query planning

### FraiseQL
- Automatic N+1 batching
- Query optimization built-in
- Typically 3-5x faster

```
Hasura query (10 users with posts):
├── users: 1 query
├── user[0].posts: 1 query (N+1!)
├── user[1].posts: 1 query
├── ... (8 more)
└── Total: 11 queries

FraiseQL query (10 users with posts):
├── users: 1 query
├── posts (batched): 1 query
└── Total: 2 queries
```

## Migration Checklist

- [ ] Export Hasura metadata and config
- [ ] Document all tables and relationships
- [ ] Map to FraiseQL types
- [ ] Replicate permission rules
- [ ] Migrate custom actions to mutations
- [ ] Migrate subscriptions to NATS
- [ ] Update client queries
- [ ] Performance test
- [ ] Decommission Hasura

## Cost Comparison

**Hasura Cloud:**
- Starter: $25/month
- Professional: $99/month
- Plus infrastructure cost

**FraiseQL (Self-hosted):**
- Server: $20-50/month
- Database: Existing
- No additional licensing

**Savings: 50-80%** plus better performance.

## Related Guides

- [Prisma Migration](/migrations/from-prisma)
- [Apollo Migration](/migrations/from-apollo)
- [REST Migration](/migrations/from-rest)
- [API Reference](/reference/graphql-api)
