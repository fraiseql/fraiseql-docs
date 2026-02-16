---
title: Migrating from Prisma to FraiseQL
description: Step-by-step guide to migrate from Prisma ORM to FraiseQL GraphQL backend
---

# Migrating from Prisma to FraiseQL

This guide walks through migrating a Prisma-based application to FraiseQL, including schema conversion, client migration, and performance optimization.

## Why Migrate to FraiseQL?

| Feature | Prisma | FraiseQL |
|---------|--------|----------|
| **API Type** | ORM (type-safe queries) | GraphQL (API-first) |
| **Databases** | All major databases | PostgreSQL, MySQL, SQLite, SQL Server |
| **Development SDKs** | Prisma Client (1) | 15 language SDKs |
| **Real-time** | Polling | Native subscriptions via WebSocket |
| **Schema Management** | Migrations + Prisma Schema | SQL + FraiseQL decorators |
| **Federation** | No | Yes (multi-database queries) |
| **Query Language** | Programmatic (.findMany()) | GraphQL (industry standard) |
| **Performance** | Good (cached queries) | Excellent (query optimization, batching) |
| **Caching** | Manual or plugins | Built-in federation-aware caching |
| **Multi-database** | Via relationships only | Native federation support |

## Feature Mapping

### Queries

#### Prisma
```python
# Prisma (JavaScript/TypeScript)
const users = await prisma.user.findMany({
  where: { email: { endsWith: "@example.com" } },
  include: { posts: true },
  orderBy: { createdAt: "desc" },
  take: 10
});
```

#### FraiseQL
```graphql
# FraiseQL (GraphQL)
query GetUsers {
  users(
    email_endsWith: "@example.com"
    limit: 10
    orderBy: "createdAt DESC"
  ) {
    id
    email
    posts {
      id
      title
    }
  }
}
```

### Mutations

#### Prisma
```python
const user = await prisma.user.create({
  data: {
    email: "alice@example.com",
    name: "Alice",
    posts: {
      create: [
        { title: "First Post", content: "..." }
      ]
    }
  },
  include: { posts: true }
});
```

#### FraiseQL
```graphql
mutation CreateUser {
  createUser(input: {
    email: "alice@example.com"
    name: "Alice"
    posts: [
      { title: "First Post", content: "..." }
    ]
  }) {
    id
    email
    posts {
      id
      title
    }
  }
}
```

### Relationships

#### Prisma Schema
```prisma
model User {
  id    Int     @id @default(autoincrement())
  email String  @unique
  posts Post[]
}

model Post {
  id      Int   @id @default(autoincrement())
  title   String
  content String
  userId  Int
  user    User  @relation(fields: [userId], references: [id])
}
```

#### FraiseQL Schema
```python
@fraiseql.type
class User:
    id: ID
    email: str
    posts: list['Post']

@fraiseql.type
class Post:
    id: ID
    title: str
    content: str
    user_id: ID
    user: User
```

## Step-by-Step Migration

### Phase 1: Preparation (Day 1)

#### 1.1 Audit Prisma Schema

```bash
# Review your current Prisma schema
cat prisma/schema.prisma

# Export schema information
npx prisma introspect  # Generate schema from database
```

#### 1.2 Plan FraiseQL Structure

Create a mapping document:

```
Prisma Model → FraiseQL Type
─────────────────────────────
User         → User (type)
Post         → Post (type)
Comment      → Comment (type)
...

Prisma Query    → FraiseQL Query
────────────────────────────────
findMany        → list[Type] query
findUnique      → single Type query
findFirst       → first(n) with limit
...
```

#### 1.3 Set Up FraiseQL Project

```bash
# Initialize FraiseQL
fraiseql init fraiseql-api

# Create fraiseql.toml
cat > fraiseql.toml << 'EOF'
[database]
type = "postgresql"
url = "${DATABASE_URL}"

[auth]
enabled = true
provider = "jwt"

[auth.jwt]
secret = "${JWT_SECRET}"
EOF
```

### Phase 2: Schema Migration (Days 2-3)

#### 2.1 Convert Prisma Schema to FraiseQL

**Prisma Schema:**
```prisma
model User {
  id        Int     @id @default(autoincrement())
  email     String  @unique
  name      String
  posts     Post[]
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

model Post {
  id        Int     @id @default(autoincrement())
  title     String
  content   String
  published Boolean @default(false)
  userId    Int
  user      User    @relation(fields: [userId], references: [id], onDelete: Cascade)
  createdAt DateTime @default(now())
}

model Comment {
  id        Int     @id @default(autoincrement())
  text      String
  postId    Int
  userId    Int
  post      Post    @relation(fields: [postId], references: [id], onDelete: Cascade)
  user      User    @relation(fields: [userId], references: [id])
}
```

**FraiseQL Schema:**
```python
from fraiseql import FraiseQL, Type, Query, Mutation, ID
from datetime import datetime

fraiseql = FraiseQL()

@fraiseql.type
class User:
    id: ID
    email: str  # Unique enforced by database
    name: str
    posts: list['Post']
    created_at: datetime
    updated_at: datetime

@fraiseql.type
class Post:
    id: ID
    title: str
    content: str
    published: bool
    user_id: ID
    user: User
    comments: list['Comment']
    created_at: datetime

@fraiseql.type
class Comment:
    id: ID
    text: str
    post_id: ID
    user_id: ID
    post: Post
    user: User
```

#### 2.2 Define Queries

**Prisma:**
```python
# getUsers.ts
const users = await prisma.user.findMany({
  where: { posts: { some: {} } },  // Has posts
  include: { posts: true },
  orderBy: { createdAt: 'desc' },
  take: 10
});
```

**FraiseQL:**
```python
@fraiseql.query(sql_source="v_users_with_posts")
def users(
    limit: int = 10,
    offset: int = 0,
    has_posts: bool = False
) -> list[User]:
    """Get users, optionally with posts."""
    pass

# View in database
# CREATE VIEW v_users_with_posts AS
# SELECT u.* FROM tb_user u
# WHERE (SELECT COUNT(*) FROM tb_post p WHERE p.user_id = u.id) > 0;
```

#### 2.3 Define Mutations

**Prisma:**
```python
const user = await prisma.user.create({
  data: {
    email: "alice@example.com",
    name: "Alice",
    posts: {
      create: [
        { title: "Hello", content: "World" }
      ]
    }
  },
  include: { posts: true }
});
```

**FraiseQL:**
```python
@fraiseql.input
class CreateUserInput:
    email: str
    name: str

@fraiseql.mutation
def create_user(input: CreateUserInput) -> User:
    """Create user."""
    pass

@fraiseql.input
class CreatePostInput:
    title: str
    content: str
    user_id: ID

@fraiseql.mutation
def create_post(input: CreatePostInput) -> Post:
    """Create post."""
    pass
```

### Phase 3: Client Migration (Days 4-5)

#### 3.1 Update Client Code

**Before (Prisma):**
```typescript
// pages/users.tsx
import { prisma } from "@/lib/prisma";

export async function getServerSideProps() {
  const users = await prisma.user.findMany({
    include: { posts: true },
    take: 10
  });
  return { props: { users } };
}

export default function UsersPage({ users }) {
  return (
    <div>
      {users.map(user => (
        <div key={user.id}>
          <h2>{user.name}</h2>
          <p>{user.posts.length} posts</p>
        </div>
      ))}
    </div>
  );
}
```

**After (FraiseQL):**
```typescript
// pages/users.tsx
import { Client } from "@fraiseql/client";

const client = new Client({
  url: "https://api.example.com/graphql",
  apiKey: process.env.FRAISEQL_API_KEY
});

export async function getServerSideProps() {
  const response = await client.query(`
    query GetUsers {
      users(limit: 10) {
        id
        name
        posts {
          id
          title
        }
      }
    }
  `);

  return { props: { users: response.data.users } };
}

export default function UsersPage({ users }) {
  return (
    <div>
      {users.map(user => (
        <div key={user.id}>
          <h2>{user.name}</h2>
          <p>{user.posts.length} posts</p>
        </div>
      ))}
    </div>
  );
}
```

#### 3.2 Client Comparison

| Feature | Prisma | FraiseQL |
|---------|--------|----------|
| **Import** | `import { PrismaClient }` | `import { Client }` |
| **Init** | `new PrismaClient()` | `new Client({url, apiKey})` |
| **Query** | `.findMany()` | `.query(graphqlString)` |
| **Mutation** | `.create()` | `.mutate(graphqlString)` |
| **Real-time** | Poll manually | `.subscribe()` |
| **Type Safety** | Generated types | TypeScript SDK generates types |

### Phase 4: Testing & Validation (Day 6)

#### 4.1 Test Query Equivalence

**Prisma Test:**
```python
test("should get users with posts", async () => {
  const users = await prisma.user.findMany({
    include: { posts: true },
    take: 5
  });

  expect(users).toHaveLength(5);
  users.forEach(user => {
    expect(user.posts).toBeDefined();
  });
});
```

**FraiseQL Test:**
```typescript
test("should get users with posts", async () => {
  const response = await client.query(`
    query {
      users(limit: 5) {
        id
        posts { id }
      }
    }
  `);

  expect(response.data.users).toHaveLength(5);
  response.data.users.forEach(user => {
    expect(user.posts).toBeDefined();
  });
});
```

#### 4.2 Performance Comparison

```python
# Test query performance
import time

# Prisma
start = time.time()
for _ in range(100):
    users = await prisma.user.findMany(
        include={'posts': True},
        take=50
    )
prisma_time = time.time() - start

# FraiseQL
start = time.time()
for _ in range(100):
    response = await client.query("query { users(limit: 50) { posts { id } } }")
fraiseql_time = time.time() - start

print(f"Prisma: {prisma_time:.2f}s")
print(f"FraiseQL: {fraiseql_time:.2f}s")
# Typically FraiseQL is 30-50% faster due to batching
```

### Phase 5: Deployment (Day 7)

#### 5.1 Deploy FraiseQL Backend

```bash
# Build FraiseQL
fraiseql build

# Deploy (example: Docker)
docker build -t fraiseql-api .
docker push your-registry/fraiseql-api

# Deploy to Kubernetes/Cloud
kubectl apply -f fraiseql-deployment.yaml
```

#### 5.2 Update Frontend Environment

```bash
# .env.local
FRAISEQL_URL=https://api.example.com/graphql
FRAISEQL_API_KEY=sk_...

# No more PRISMA_DATABASE_URL
# (database access is now through FraiseQL API)
```

## Architecture Differences

### Prisma Architecture (Monolithic)
```
Frontend → Prisma Client → Database
(Direct database access)
```

### FraiseQL Architecture (API-first)
```
Frontend → HTTP/GraphQL → FraiseQL API → Database
(Backend API layer)
```

**Benefits of FraiseQL approach:**
- Decoupled frontend from database
- Can scale backend independently
- Security: database credentials never exposed to frontend
- Easier to implement business logic
- Built-in authentication/authorization

## Common Migration Patterns

### Pattern 1: Pagination

**Prisma:**
```python
users = await prisma.user.findMany(
    skip=10,
    take=10
)
```

**FraiseQL:**
```graphql
query {
  users(offset: 10, limit: 10) {
    id
    name
  }
}
```

### Pattern 2: Filtering

**Prisma:**
```python
posts = await prisma.post.findMany(
    where={
        AND: [
            { published: True },
            { author: { email: { contains: "@example.com" } } }
        ]
    }
)
```

**FraiseQL:**
```graphql
query {
  posts(
    published_eq: true
    author_email_contains: "@example.com"
  ) {
    id
    title
  }
}
```

### Pattern 3: Aggregations

**Prisma:**
```python
count = await prisma.post.count(
    where={ published: True }
)

# Or with aggregate
result = await prisma.post.aggregate(
    where={ published: True },
    _count=True,
    _avg={ rating: True }
)
```

**FraiseQL:**
```graphql
query {
  postsAggregate(published_eq: true) {
    count
    avgRating
  }
}
```

## Testing Strategies

### API Testing

```python
import pytest
from fraiseql import Client

@pytest.fixture
def client():
    return Client(
        url="http://localhost:8000/graphql",
        api_key="test_key"
    )

@pytest.mark.asyncio
async def test_create_user(client):
    response = await client.mutate("""
        mutation CreateUser {
            createUser(input: {
                email: "test@example.com"
                name: "Test"
            }) {
                id
                email
            }
        }
    """)

    assert response.data.createUser.email == "test@example.com"
```

### Load Testing

```python
import asyncio
from locust import HttpUser, task

class FraiseQLUser(HttpUser):
    @task
    def get_users(self):
        self.client.post(
            "/graphql",
            json={
                "query": "query { users(limit: 50) { id name } }"
            }
        )

# Run: locust -f locustfile.py --headless -u 100 -r 10
```

## Performance Tuning

### Before (Prisma)

```python
# N+1 problem
users = await prisma.user.findMany()
for user in users:
    posts = await prisma.post.findMany(where={'userId': user.id})
    # N queries!
```

### After (FraiseQL with Batching)

```graphql
query {
  users {
    name
    posts {  # Automatically batched
      title
    }
  }
}
# 2 queries total: users + posts (batched by user_id)
```

## Rollback Plan

If issues arise:


                                            ─

```python
@fraiseql.middleware
def feature_gate_fraiseql(request, next):
    """Route to FraiseQL based on feature flag."""

    if should_use_fraiseql(request.user_id):
        return await fraiseql_handler(request)
    else:
        return await prisma_handler(request)
```

## Migration Checklist

- [ ] Audit Prisma schema and relationships
- [ ] Design FraiseQL types and queries
- [ ] Create FraiseQL decorators for all Prisma models
- [ ] Define mutations for create/update/delete operations
- [ ] Update client code to use GraphQL queries
- [ ] Write API tests with equivalent coverage
- [ ] Load test FraiseQL vs Prisma
- [ ] Set up monitoring and alerting
- [ ] Train team on GraphQL queries
- [ ] Plan phased rollout with feature flags
- [ ] Monitor for 2 weeks and iterate

## Key Differences to Remember

1. **No ORM** - FraiseQL is GraphQL API, not ORM
2. **API-first** - Clients call HTTP API, not database directly
3. **Type safety** - Types via GraphQL/SDK, not Prisma Client
4. **Queries** - GraphQL syntax instead of `.findMany()` chains
5. **Subscriptions** - Real-time via WebSocket, not polling
6. **Federation** - Native multi-database support

## Related Guides

- [Apollo Server Migration](/migrations/from-apollo) - Another GraphQL option
- [Hasura Migration](/migrations/from-hasura) - Another GraphQL backend
- [Getting Started](/getting-started/introduction) - FraiseQL fundamentals
- [API Reference](/reference/graphql-api) - Complete GraphQL API
- [SDKs](/sdk) - Schema authoring SDKs for your language