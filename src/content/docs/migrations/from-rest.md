---
title: Migrating from REST API to GraphQL
description: Guide to convert REST API to GraphQL using FraiseQL
---

# Migrating from REST API to GraphQL

This guide shows how to migrate from traditional REST APIs to GraphQL using FraiseQL.

## Why Migrate?

| Problem | REST | GraphQL |
|---------|------|---------|
| **Over-fetching** | GET /users returns all fields | Query only needed fields |
| **Under-fetching** | Must chain API calls | Get all data in one request |
| **Versioning** | /v1/, /v2/ endpoints | Single endpoint, evolves safely |
| **Documentation** | Separate docs | Self-documenting via schema |
| **Client bloat** | Multiple endpoints | Single endpoint |
| **Real-time** | WebSocket polling | Native subscriptions |

## Conversion Examples

### Getting a User with Posts

**REST API (Over/under-fetching):**
```bash
# Request 1: Get user (gets all fields)
GET /api/users/123
# Response: 500 bytes with fields you don't need

# Request 2: Get user's posts
GET /api/users/123/posts
# Response: another round-trip

# Request 3: Get post comments
GET /api/posts/456/comments
# Total: 3 requests, lots of unused data
```

**GraphQL (Exact data needed):**
```graphql
query {
  user(id: 123) {
    name
    email
    posts {
      title
      comments {
        text
      }
    }
  }
}
# Single request, exactly what you need
```

## Step-by-Step Conversion

### Step 1: Document REST Endpoints

```bash
# List all endpoints
GET /api/users              → Get all users
GET /api/users/:id          → Get user
POST /api/users             → Create user
PUT /api/users/:id          → Update user
DELETE /api/users/:id       → Delete user
GET /api/users/:id/posts    → Get user's posts
GET /api/posts              → Get all posts
GET /api/posts/:id          → Get post
POST /api/posts             → Create post
```

### Step 2: Map to GraphQL

| REST | GraphQL |
|------|---------|
| `GET /users` | `query { users { ... } }` |
| `GET /users/:id` | `query { user(id: ...) { ... } }` |
| `POST /users` | `mutation { createUser(...) { ... } }` |
| `PUT /users/:id` | `mutation { updateUser(...) { ... } }` |
| `DELETE /users/:id` | `mutation { deleteUser(...) { ... } }` |
| `GET /users/:id/posts` | `query { user { posts { ... } } }` |

### Step 3: Define GraphQL Types

**REST implementation:**
```python
# routes/users.py
@app.get("/api/users")
def get_users():
    return {"users": User.all()}

@app.get("/api/users/{user_id}")
def get_user(user_id: int):
    return {"user": User.get(user_id)}

@app.post("/api/users")
def create_user(data: UserInput):
    return {"user": User.create(data)}
```

**FraiseQL implementation:**
```python
@fraiseql.type
class User:
    id: ID
    name: str
    email: str
    posts: list['Post']

@fraiseql.query(sql_source="v_user")
def users(limit: int = 50) -> list[User]:
    """GET /users → query { users { ... } }"""
    pass

@fraiseql.query(sql_source="v_user")
def user(id: ID) -> User:
    """GET /users/:id → query { user(id: ...) { ... } }"""
    pass

@fraiseql.mutation(sql_source="fn_create_user", operation="CREATE")
def create_user(name: str, email: str) -> User:
    """POST /users → mutation { createUser(...) { ... } }"""
    pass
```

## Request/Response Comparison

### Get User with Posts

**REST (3 requests):**
```bash
# Request 1
GET /api/users/123
Content-Type: application/json

# Response 1
{
  "id": 123,
  "name": "Alice",
  "email": "alice@example.com",
  "createdAt": "2024-01-01",
  "updatedAt": "2024-01-15"
  # Over-fetching: we don't need createdAt, updatedAt
}

# Request 2
GET /api/users/123/posts
Accept: application/json

# Response 2
{
  "posts": [
    {
      "id": 456,
      "title": "First Post",
      "content": "...",
      "userId": 123,
      "likes": 42,
      "comments_count": 3
    }
  ]
}

# Request 3
GET /api/posts/456/comments

# Response 3
{
  "comments": [...]
}

# Total: 3 requests + latency
```

**GraphQL (1 request):**
```bash
POST /graphql
Content-Type: application/json

{
  "query": "query { user(id: 123) { name email posts { title comments { text } } } }"
}

# Response
{
  "data": {
    "user": {
      "name": "Alice",
      "email": "alice@example.com",
      "posts": [
        {
          "title": "First Post",
          "comments": [
            { "text": "Nice!" },
            { "text": "Great article!" }
          ]
        }
      ]
    }
  }
}

# Total: 1 request, exact data needed
```

## Pagination

### REST
```bash
GET /api/users?limit=10&offset=20
```

### GraphQL
```graphql
query {
  users(limit: 10, offset: 20) {
    id
    name
  }
}
```

Same syntax, better structure.

## Filtering

### REST
```bash
GET /api/posts?status=published&author_id=123&sort=-created_at
```

### GraphQL
```graphql
query {
  posts(
    status_eq: "published"
    author_id_eq: 123
    orderBy: "created_at DESC"
  ) {
    id
    title
  }
}
```

## Error Handling

### REST (HTTP Status Codes)
```
404 Not Found
400 Bad Request
500 Internal Server Error
401 Unauthorized
```

### GraphQL (200 OK + error in body)
```json
{
  "errors": [
    {
      "message": "User not found",
      "extensions": {
        "code": "NOT_FOUND",
        "userId": "123"
      }
    }
  ]
}
```

FraiseQL includes helpful error codes and context.

## Migration Strategy

### Option 1: Gradual Migration (Recommended)

```
Week 1-2: Build GraphQL alongside REST
Week 3-4: Route 50% of traffic to GraphQL
Week 5-6: Route 100% to GraphQL
Week 7+: Decommission REST
```

### Option 2: Full Migration

```
1. Build complete GraphQL API
2. Update all clients to use GraphQL
3. Remove REST endpoints
```

## Client Code Changes

### REST Client

```typescript
// Before
async function getUser(userId: number) {
  const userRes = await fetch(`/api/users/${userId}`);
  const user = await userRes.json();

  const postsRes = await fetch(`/api/users/${userId}/posts`);
  const posts = await postsRes.json();

  return { ...user, posts: posts.posts };
}
```

### GraphQL Client

```typescript
// After
async function getUser(userId: number) {
  const response = await client.query(`
    query {
      user(id: ${userId}) {
        name
        email
        posts {
          id
          title
        }
      }
    }
  `);

  return response.data.user;
}
```

Much simpler!

## Subscriptions (New Capability)

REST doesn't have good real-time support. GraphQL does:

```graphql
subscription {
  postCreated {
    id
    title
    author {
      name
    }
  }
}
```

FraiseQL provides this with NATS automatically.

## Performance Impact

**Before (REST):**
- 3+ requests per view
- 200-500ms per view
- Over-fetching: 50-70% unused data
- Client-side filtering/joining

**After (GraphQL):**
- 1 request per view
- 50-100ms per view (3-5x faster)
- Exact data requested (0% unused)
- Server-side joining/batching

## Deployment Simplification

**REST:**
```
Multiple endpoints
├── /api/v1/users
├── /api/v1/posts
├── /api/v1/comments
├── /api/v2/users (new version!)
└── /api/v2/posts
```

**GraphQL:**
```
Single endpoint
└── /graphql
   (Schema evolves, versioning built-in)
```

## Migration Checklist

- [ ] Document all REST endpoints
- [ ] Map endpoints to GraphQL queries/mutations
- [ ] Define GraphQL types and queries
- [ ] Build GraphQL API alongside REST
- [ ] Update client code
- [ ] Performance test
- [ ] Route traffic gradually
- [ ] Decommission REST endpoints

## Key Advantages of GraphQL

1. **Single Request** - Get all data in one call
2. **Exact Data** - No over/under-fetching
3. **Self-Documenting** - Schema is documentation
4. **Subscriptions** - Real-time updates
5. **Evolves Safely** - Add fields without breaking clients
6. **Better Performance** - Automatic optimization

## Related Guides

- [Prisma Migration](/migrations/from-prisma)
- [Apollo Migration](/migrations/from-apollo)
- [Hasura Migration](/migrations/from-hasura)
- [API Reference](/reference/graphql-api)
- [Getting Started](/getting-started/introduction)
