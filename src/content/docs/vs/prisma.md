---
title: FraiseQL vs Prisma
description: How FraiseQL compares to Prisma ORM
---

Prisma is a popular ORM. FraiseQL is a GraphQL framework. Here's why you might choose one over the other.

## The Fundamental Difference

**Prisma** is an ORM that generates a type-safe database client. You still need to build your API layer.

**FraiseQL** generates the entire GraphQL API, including the database access layer.

```
                  ─            ─               ─
                  ─                      ─
```

## Side-by-Side Comparison

| Aspect | FraiseQL | Prisma |
|--------|----------|--------|
| **What it is** | GraphQL framework | ORM / Database client |
| **Output** | Complete GraphQL API | Database client library |
| **API layer** | Included | Build yourself |
| **Schema source** | Python, TS, Go, etc. | Prisma Schema Language |
| **N+1 handling** | Eliminated by design | `include` option (manual) |
| **Query language** | GraphQL (mapped from SQL views) | Prisma Client API |
| **Configuration** | TOML | `.prisma` files |
| **Database support** | PostgreSQL, MySQL, SQLite, SQL Server | Same + MongoDB, CockroachDB |
| **Migration** | Built-in | Prisma Migrate |

## What You Build

### With Prisma

```typescript
// 1. Define Prisma schema
// schema.prisma
model User {
  id    String @id @default(uuid())
  name  String
  email String @unique
  posts Post[]
}

model Post {
  id       String @id @default(uuid())
  title    String
  author   User   @relation(fields: [authorId], references: [id])
  authorId String
}

// 2. Generate client
// $ prisma generate

// 3. Build your API layer (Express, Fastify, etc.)
app.get('/users', async (req, res) => {
  const users = await prisma.user.findMany({
    include: { posts: true }
  });
  res.json(users);
});

app.get('/users/:id', async (req, res) => {
  const user = await prisma.user.findUnique({
    where: { id: req.params.id },
    include: { posts: true }
  });
  res.json(user);
});

app.post('/users', async (req, res) => {
  const user = await prisma.user.create({
    data: req.body
  });
  res.json(user);
});

// ... 50+ more endpoints
```

### With FraiseQL

```python
# 1. Define schema
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

# 2. Build and serve
# $ fraiseql build && fraiseql serve

# Done. GraphQL API with all CRUD operations is ready.
```


                     ─

## N+1 Query Handling

### Prisma: Manual `include`

```typescript
// Without include: N+1 problem
const users = await prisma.user.findMany();
for (const user of users) {
  user.posts = await prisma.post.findMany({
    where: { authorId: user.id }
  }); // N queries!
}

// With include: You must remember to add it
const users = await prisma.user.findMany({
  include: { posts: true }
});
```

If you forget `include`, you get N+1. If you include too much, you fetch unnecessary data.

### FraiseQL: Eliminated by Design

```graphql
# This query:
query {
  users {
    name
    posts { title }
  }
}

# Executes as:
SELECT u.name, p.title
FROM users u
LEFT JOIN posts p ON p.author_id = u.id;

# One query. Always.
```

You can't create N+1 queries because the SQL is pre-compiled.

## Schema Language

### Prisma: PSL (Prisma Schema Language)

```prisma
// schema.prisma
model User {
  id        String   @id @default(uuid())
  email     String   @unique
  name      String?
  posts     Post[]
  createdAt DateTime @default(now())

  @@index([email])
  @@map("users")
}

model Post {
  id        String   @id @default(uuid())
  title     String
  content   String?
  published Boolean  @default(false)
  author    User     @relation(fields: [authorId], references: [id])
  authorId  String

  @@map("posts")
}
```

- Custom DSL to learn
- Good tooling
- Limited to Prisma's features

### FraiseQL: Your Programming Language

```python
# schema.py
@fraiseql.type
class User:
    id: str
    email: str
    name: str | None
    posts: list['Post']
    created_at: datetime

@fraiseql.type
class Post:
    id: str
    title: str
    content: str | None
    published: bool = False
    author: User
```

- Use your existing language
- Full IDE support
- Any language features available

## Input Validation

### Prisma: External Libraries

Prisma doesn't include validation — you use external libraries:

```typescript
// Prisma + Zod for validation
import { z } from 'zod';

const createUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1),
  age: z.number().min(0).max(150)
});

app.post('/users', async (req, res) => {
  const validated = createUserSchema.parse(req.body); // Runtime validation
  const user = await prisma.user.create({
    data: validated
  });
  res.json(user);
});
```

- **External dependencies** — Zod, Joi, Yup, etc.
- **Runtime validation** — Happens during request handling
- **Your responsibility** — Must validate before database calls
- **Database risk** — Invalid data if validation is missed
- **Learning curve** — Different libraries, different APIs

### FraiseQL: Built-In Validators

FraiseQL includes 13 validators at compile-time:

```toml
[fraiseql.validation]
email = { pattern = "^[^@]+@[^@]+\\.[^@]+$" }
age = { range = { min = 0, max = 150 } }
name = { length = { min = 1 } }
```

- **13 built-in validators** — No external libraries needed
  - Standard: required, pattern, length, range, enum, checksum
  - Cross-field: comparison operators, conditionals
  - Mutual exclusivity: OneOf, AnyOf, ConditionalRequired, RequiredIfAbsent
- **Compile-time enforcement** — Invalid schemas impossible at runtime
- **Zero dependencies** — Everything built-in
- **Database protection** — Invalid data never reaches the database

### Comparison

| Aspect | FraiseQL | Prisma |
|--------|----------|--------|
| Built-in validators | 13 rules | 0 (requires external libs) |
| External dependencies | None | Zod, Joi, Yup, etc. |
| Compile-time enforcement | ✅ Yes | ❌ No |
| Runtime validation overhead | None | Per-request |
| Learning curve | Low | Medium (different per library) |
| Database protection | Guaranteed | Depends on implementation |

## When to Use Prisma

Prisma is a better choice when:

- **You're building a REST API** — Prisma doesn't care about your API layer
- **You need fine-grained control** — Build exactly the endpoints you want
- **You want to use GraphQL with custom resolvers** — Prisma + Apollo/Yoga/etc.
- **You need MongoDB support** — FraiseQL doesn't support MongoDB
- **Your API has complex business logic** — More control over request handling

## When to Use FraiseQL

FraiseQL is a better choice when:

- **You want a GraphQL API** — It's built-in
- **You want less code** — Schema only, no API layer
- **You need guaranteed N+1 prevention** — By design, not by discipline
- **You prefer compiled output** — Predictable performance
- **You want simple configuration** — TOML over multiple files

## Using Them Together

You can use Prisma's migration system with FraiseQL:

```bash
# Use Prisma for migrations
prisma migrate dev

# Use FraiseQL for the API
fraiseql build && fraiseql serve
```python

Or use FraiseQL for the main API and Prisma for admin/internal tools.

## Migration from Prisma

### Step 1: Convert Schema

Prisma:
```prisma
model User {
  id    String @id @default(uuid())
  name  String
  posts Post[]
}
```

FraiseQL:
```python
@fraiseql.type
class User:
    id: str
    name: str
    posts: list['Post']
```

### Step 2: Remove API Layer

Your Express/Fastify/etc. routes are replaced by the GraphQL API backed by your SQL views.

### Step 3: Move Business Logic

Prisma + Express:
```typescript
app.post('/orders/:id/process', async (req, res) => {
  const order = await prisma.order.findUnique({ where: { id: req.params.id } });
  await processPayment(order);
  await prisma.order.update({ where: { id }, data: { status: 'complete' } });
  res.json({ success: true });
});
```

FraiseQL (observer pattern — react to data changes):
```python
@observer(
    entity="Order",
    event="UPDATE",
    condition="status = 'pending'",
    actions=[
        webhook("https://payments.internal/process",
                body={"order_id": "{id}", "amount": "{total}"}),
    ],
)
def on_order_pending():
    """Process payment when order becomes pending."""
    pass
```

## Summary

| Choose | When |
|--------|------|
| **Prisma** | You want an ORM, building REST, need MongoDB, want full control |
| **FraiseQL** | You want GraphQL, less code, guaranteed N+1 prevention |

Prisma is a database client. FraiseQL is a complete GraphQL API.