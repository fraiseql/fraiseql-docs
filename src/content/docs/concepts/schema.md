---
title: Schema Definition
description: Define your GraphQL schema in Python, TypeScript, Go, or other languages
---

FraiseQL lets you define your GraphQL schema in your preferred programming language. Each type maps to a SQL view you've written (e.g., `User` maps to `v_user`). This page covers the Python syntax; other languages follow similar patterns.

## Basic Types

### Object Types

```python
import fraiseql

@fraiseql.type
class User:
    """A user in the system."""
    id: str
    name: str
    email: str
    created_at: str
```

The docstring becomes the GraphQL type description.

### Field Types

| Python Type | GraphQL Type |
|-------------|--------------|
| `str` | `String!` |
| `int` | `Int!` |
| `float` | `Float!` |
| `bool` | `Boolean!` |
| `str \| None` | `String` |
| `list[str]` | `[String!]!` |
| `list[str] \| None` | `[String!]` |

### Optional Fields

```python
@fraiseql.type
class User:
    id: str
    name: str
    bio: str | None  # Optional field
```

### List Fields

```python
@fraiseql.type
class User:
    id: str
    tags: list[str]           # Required list
    nicknames: list[str] | None  # Optional list
```

## Relationships

### One-to-Many

```python
@fraiseql.type
class User:
    id: str
    name: str
    posts: list['Post']  # User has many posts

@fraiseql.type
class Post:
    id: str
    title: str
    author: User  # Post belongs to user
```

### Many-to-Many

```python
@fraiseql.type
class Post:
    id: str
    title: str
    tags: list['Tag']

@fraiseql.type
class Tag:
    id: str
    name: str
    posts: list['Post']
```

You create the join table (`tb_post_tag`) in your database schema. FraiseQL maps the relationship through your SQL view, which handles the join.

### Self-Referential

```python
@fraiseql.type
class Category:
    id: str
    name: str
    parent: 'Category | None'
    children: list['Category']
```

## Input Types

For mutations, define input types:

```python
@fraiseql.input
class CreateUserInput:
    name: str
    email: str
    bio: str | None = None  # Optional with default

@fraiseql.input
class UpdateUserInput:
    name: str | None = None
    email: str | None = None
    bio: str | None = None
```

## Enums

```python
import enum

class UserRole(enum.Enum):
    ADMIN = "admin"
    USER = "user"
    GUEST = "guest"

@fraiseql.type
class User:
    id: str
    name: str
    role: UserRole
```

## Custom Scalars

```python
from datetime import datetime
from decimal import Decimal
@fraiseql.type
class Order:
    id: ID
    total: Decimal
    created_at: datetime
```

Built-in scalar mappings:

| Python Type | GraphQL Scalar |
|-------------|----------------|
| `datetime` | `DateTime` |
| `date` | `Date` |
| `time` | `Time` |
| `Decimal` | `Decimal` |
| `UUID` | `UUID` |

## Queries

### Default Queries

FraiseQL creates default query endpoints for each type, mapped to the corresponding SQL view:

- `users` — List query (`SELECT data FROM v_user`)
- `user(id: ID!)` — Single record query (`SELECT data FROM v_user WHERE id = $1`)
- `posts` — List query (`SELECT data FROM v_post`)
- `post(id: ID!)` — Single record query (`SELECT data FROM v_post WHERE id = $1`)

### Custom Queries

```python
@fraiseql.query
async def active_users(info, limit: int = 10) -> list[User]:
    """Get recently active users."""
    return await info.context.db.query(
        "SELECT * FROM v_user WHERE last_seen > now() - interval '1 day' LIMIT $1",
        limit
    )

@fraiseql.query
async def search_posts(info, query: str) -> list[Post]:
    """Search posts by title or content."""
    return await info.context.db.query(
        "SELECT * FROM v_post WHERE title ILIKE $1 OR content ILIKE $1",
        f"%{query}%"
    )
```

## Mutations

### Default Mutations

FraiseQL creates default mutation endpoints mapped to SQL functions you write (`fn_create_user`, `fn_update_user`, `fn_delete_user`):

                                        ─
                                                 ─
                        ─

### Custom Mutations

```python
@fraiseql.mutation
async def publish_post(info, id: str) -> Post:
    """Publish a draft post."""
    await info.context.db.execute(
        "UPDATE posts SET published = true WHERE id = $1",
        id
    )
    return await info.context.db.find_one("v_post", id=id)

@fraiseql.mutation
async def archive_user(info, id: str) -> bool:
    """Archive a user and their content."""
    async with info.context.db.transaction():
        await info.context.db.execute(
            "UPDATE users SET archived = true WHERE id = $1", id
        )
        await info.context.db.execute(
            "UPDATE posts SET published = false WHERE author_id = $1", id
        )
    return True
```

## Directives

### Field Visibility

```python
@fraiseql.type
class User:
    id: str
    name: str
    email: str = fraiseql.field(private=True)  # Not in public API
    password_hash: str = fraiseql.field(exclude=True)  # Never exposed
```

### Computed Fields

```python
@fraiseql.type
class User:
    id: str
    first_name: str
    last_name: str

    @fraiseql.computed
    def full_name(self) -> str:
        return f"{self.first_name} {self.last_name}"
```

### Deprecation

```python
@fraiseql.type
class User:
    id: str
    name: str
    username: str = fraiseql.field(deprecated="Use 'name' instead")
```

## Multi-Language Support

### TypeScript

```typescript
// schema.ts
import { type, input, query } from 'fraiseql';

@type()
class User {
  id: string;
  name: string;
  email: string;
  posts: Post[];
}

@input()
class CreateUserInput {
  name: string;
  email: string;
}
```

### Go

```go
// schema.go
package schema

type User struct {
    ID    string `fraiseql:"id"`
    Name  string `fraiseql:"name"`
    Email string `fraiseql:"email"`
    Posts []Post `fraiseql:"posts"`
}
```

## Next Steps

- [Developer-Owned SQL](/concepts/developer-owned-sql) — Why you write the SQL views
- [CQRS Pattern](/concepts/cqrs) — The table/view separation
- [TOML Configuration](/concepts/configuration) — Configure your project
- [How It Works](/concepts/how-it-works) — Understand the compilation mapping
- [Queries and Mutations](/reference/graphql-api) — Full API reference