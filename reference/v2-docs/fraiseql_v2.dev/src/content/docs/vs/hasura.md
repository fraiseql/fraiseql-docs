---
title: FraiseQL vs Hasura
description: How FraiseQL compares to Hasura GraphQL Engine
---

Both FraiseQL and Hasura provide GraphQL APIs over databases. Here's how they differ.

## The Fundamental Difference

**Hasura** is a runtime GraphQL engine that interprets queries and generates SQL on-the-fly.

**FraiseQL** is a compiled GraphQL framework that pre-generates optimized SQL views at build time.

```
                 ─                ─               ─
                 ─                ─                ─
```

## Side-by-Side Comparison

| Aspect | FraiseQL | Hasura |
|--------|----------|--------|
| **Architecture** | Compiled | Interpreted |
| **Query execution** | Pre-built SQL views | Runtime SQL generation |
| **N+1 handling** | Eliminated by design | Runtime batching |
| **Configuration** | TOML | Console + YAML |
| **Schema source** | Code (Python, TS, Go...) | Database introspection |
| **Database support** | PostgreSQL, MySQL, SQLite, SQL Server | PostgreSQL (primary), others via connectors |
| **Deployment** | Single binary | Docker container + metadata |
| **Performance** | Predictable, sub-ms | Variable, depends on query |
| **Custom logic** | Observers (reactive events) | Actions (HTTP), Remote Schemas |
| **Pricing** | Open source (Apache 2.0) | Open source core, paid cloud |

## Performance

### FraiseQL Approach

```sql
-- Composed views: tb_ tables, v_ views, child .data embedded in parent
CREATE VIEW v_user AS
SELECT id, jsonb_build_object('id', id, 'name', name, 'email', email) AS data
FROM tb_user;

CREATE VIEW v_post AS
SELECT p.id,
    jsonb_build_object('id', p.id, 'title', p.title, 'author', vu.data) AS data
FROM tb_post p
JOIN v_user vu ON vu.id = p.fk_user;
```

Query execution: **Single indexed view lookup**

### Hasura Approach

```sql
-- Generated at runtime per query
SELECT u.* FROM users u WHERE u.id = $1;
SELECT p.* FROM posts p WHERE p.author_id IN ($1, $2, ...);
-- Results assembled in memory
```

Query execution: **Multiple queries + assembly**

## Configuration

### FraiseQL: Single TOML File

```toml title="fraiseql.toml"
[project]
name = "my-api"

[database]
type = "postgresql"
url = "${DATABASE_URL}"

[server]
port = 8080

[auth]
type = "jwt"
jwt_secret = "${JWT_SECRET}"
```

### Hasura: Console + YAML + Database Metadata

```
# config.yaml
version: 3
metadata_directory: metadata
actions:
  handler_webhook_baseurl: http://localhost:3000
```

Plus separate files for:
- `tables.yaml`
- `relationships.yaml`
- `permissions.yaml`
- `remote_schemas.yaml`
- etc.

## Schema Definition

### FraiseQL: Code-First

```python
@fraiseql.type
class User:
    """User with posts."""
    id: str
    name: str
    email: str
    posts: list['Post']
```

- Full IDE support
- Type checking
- Refactoring tools
- Version control friendly

### Hasura: Database-First

1. Create tables in database
2. Hasura introspects schema
3. Configure relationships in console
4. Track tables/views

- Quick to start
- Limited to database capabilities
- Configuration in metadata

## Custom Logic

### FraiseQL: Observers

FraiseQL uses **observers** for reactive business logic — you define conditions and actions that trigger on database changes:

```python
from fraiseql import observer, webhook, slack, email
from fraiseql.observers import RetryConfig

@observer(
    entity="Order",
    event="INSERT",
    condition="total > 1000",
    actions=[
        webhook("https://api.example.com/high-value-orders"),
        slack("#sales", "🎉 High-value order {id}: ${total}"),
        email(
            to="sales@example.com",
            subject="High-value order {id}",
            body="Order {id} for ${total} was created",
        ),
    ],
    retry=RetryConfig(max_attempts=5, backoff_strategy="exponential"),
)
def on_high_value_order():
    """Triggered when a high-value order is created."""
    pass
```

Built-in actions for webhooks, Slack, and email. No external services required.

### Hasura

```
# actions.yaml
- name: processOrder
  definition:
    kind: synchronous
    handler: http://business-logic-service:3000/process-order
```

Plus a separate HTTP service to handle the logic. Hasura also has event triggers, but they require external webhook handlers.

## Input Validation

### FraiseQL: Compile-Time Validation

FraiseQL enforces validation during schema compilation, before any query executes:

- **13 built-in validators** across 4 categories
  - Standard: required, pattern, length, range, enum, checksum
  - Cross-field: comparison operators, conditionals
  - Mutual exclusivity: OneOf, AnyOf, ConditionalRequired, RequiredIfAbsent
- **No runtime overhead** — validation rules are baked into the schema
- **Impossible to deploy invalid schemas** — validation rule conflicts caught at build time
- **Zero database errors** — invalid data never reaches the database

All validation is declarative via TOML:

```toml
[fraiseql.validation]
email = { pattern = "^[^@]+@[^@]+\\.[^@]+$" }
age = { range = { min = 0, max = 150 } }
phone = { length = 10 }
```

### Hasura: Runtime Validation

Hasura relies primarily on GraphQL's built-in type system for validation:

- **Type checking** — scalar types, required fields (from GraphQL spec)
- **Basic validation** — Only what the type system provides
- **Runtime only** — Validation happens during query execution
- **Custom validation via Actions** — HTTP webhooks for complex logic

For anything beyond GraphQL type checking, Hasura users must implement custom Actions (external HTTP services).

### Comparison

| Aspect | FraiseQL | Hasura |
|--------|----------|--------|
| Built-in validators | 13 rules | ~3 (via GraphQL types) |
| Compile-time enforcement | ✅ Yes | ❌ No |
| Mutual exclusivity | OneOf, AnyOf, ConditionalRequired, RequiredIfAbsent | @oneOf only |
| Cross-field validation | ✅ Yes | ❌ Custom Actions required |
| Database protection | Invalid data impossible | Possible without Actions |
| Configuration | Declarative TOML | GraphQL directives + Actions |

## When to Use Hasura

Hasura is a better choice when:

- **You need rapid prototyping** — Point at a database, get instant API
- **Your team prefers GUI configuration** — Console-based setup
- **You have an existing database** — Introspection works great
- **You need event triggers** — Hasura's event system is mature
- **You want managed hosting** — Hasura Cloud is polished

## When to Use FraiseQL

FraiseQL is a better choice when:

- **You want predictable performance** — Compiled queries, no surprises
- **You prefer code over configuration** — Schema in your language
- **You need multi-database support** — PostgreSQL, MySQL, SQLite, SQL Server
- **You want simple deployment** — Single binary, no orchestration
- **You value readability** — TOML over YAML, one file over many

## Migration from Hasura

### Step 1: Export Your Schema

```bash
# Get your Hasura table definitions
hasura metadata export
```

### Step 2: Convert to FraiseQL Types

Hasura table:
```
# tables.yaml
- table:
    name: users
    schema: public
  object_relationships:
    - name: posts
      using:
        foreign_key_constraint_on:
          column: author_id
          table:
            name: posts
```

FraiseQL equivalent:
```python
@fraiseql.type
class User:
    id: str
    name: str
    email: str
    posts: list['Post']

@fraiseql.type
class Post:
    id: str
    title: str
    author: User
```

### Step 3: Migrate Actions to Observers

Hasura Action:
```
- name: processPayment
  definition:
    kind: synchronous
    handler: http://payments:3000/process
```

FraiseQL observer:
```python
@observer(
    entity="Order",
    event="UPDATE",
    condition="status = 'pending_payment'",
    actions=[
        webhook("https://payments.internal/process",
                body={"order_id": "{id}", "amount": "{total}"}),
    ],
)
def on_pending_payment():
    """Process payment when order status changes."""
    pass
```

## Summary

| Choose | When |
|--------|------|
| **Hasura** | Rapid prototyping, existing databases, GUI preference |
| **FraiseQL** | Predictable performance, code-first, multi-database |

Both are excellent tools. Choose based on your team's preferences and requirements.
`3
`3