---
title: Multi-Tenant Blog Platform (SaaS)
description: Build a scalable SaaS blogging platform with FraiseQL
---

# Multi-Tenant SaaS Blog Platform

A complete example of a production-ready, multi-tenant blogging platform using FraiseQL.

**Repository**: [github.com/fraiseql/examples/saas-blog](https://github.com/fraiseql/examples/saas-blog)

## Features Demonstrated

- **Multi-Tenancy**: Tenant isolation with row-level security (RLS)
- **Authentication & Authorization**: JWT-based auth with role-based access control
- **Real-Time Updates**: WebSocket subscriptions for live blog updates
- **Soft Deletes**: Logical deletion of posts with recovery
- **Audit Trail**: Track all changes to posts and comments
- **Pagination**: Cursor-based pagination for large datasets
- **Search**: Full-text search across blog posts
- **Caching**: Redis caching for popular posts
- **Federation**: Support multiple databases for scale

## Architecture

```

        │

        │
```

## Data Model

```python
@fraiseql.type
class Tenant:
    id: str
    name: str
    created_at: datetime
    subscription_tier: str  # free, pro, enterprise

@fraiseql.type
class User:
    id: str
    tenant_id: str  # Multi-tenancy key
    email: str
    name: str
    role: str  # admin, editor, subscriber
    created_at: datetime

@fraiseql.type
class Post:
    id: str
    tenant_id: str
    user_id: str
    title: str
    content: str
    published: bool
    deleted_at: datetime | None  # Soft delete
    created_at: datetime
    updated_at: datetime

@fraiseql.type
class Comment:
    id: str
    tenant_id: str
    post_id: str
    user_id: str
    content: str
    created_at: datetime
```

## Key Queries

```graphql
# Get tenant's published posts (with pagination)
query {
  posts(first: 20, after: "cursor123") {
    edges {
      node {
        id
        title
        author { name }
        comments(first: 5) { edges { node { content author { name } } } }
      }
    }
    pageInfo { hasNextPage endCursor }
  }
}

# Real-time subscription for new comments
subscription {
  commentCreated(postId: "post123") {
    id
    content
    author { name }
    createdAt
  }
}

# Search posts
query {
  searchPosts(query: "GraphQL", first: 10) {
    id
    title
    highlight
  }
}
```

## Key Mutations

```graphql
# Create post
mutation {
  createPost(
    title: "Getting Started with FraiseQL"
    content: "..."
  ) {
    id
    title
    author { name }
  }
}

# Publish post
mutation {
  publishPost(id: "post123") {
    id
    published
  }
}

# Delete post (soft delete)
mutation {
  deletePost(id: "post123") {
    id
    deletedAt
  }
}

# Restore deleted post
mutation {
  restorePost(id: "post123") {
    id
    deletedAt
  }
}

# Add comment
mutation {
  createComment(postId: "post123", content: "Great post!") {
    id
    content
    author { name }
  }
}
```

## Authentication & Authorization

```python
# JWT token includes tenant and role
{
  "user_id": "user123",
  "tenant_id": "tenant456",
  "role": "editor",
  "scopes": ["read:posts", "write:posts", "read:comments"]
}

@fraiseql.query
@authenticated
def posts(info) -> list["Post"]:
    """Automatically filters to current tenant via RLS."""
    # PostgreSQL RLS policy:
    # WHERE tenant_id = current_setting('app.tenant_id')
    pass

@fraiseql.mutation
@authenticated
@requires_scope("write:posts")
def create_post(info, title: str, content: str) -> "Post":
    """Only editors can create posts."""
    user = get_current_user(info)
    if user['role'] not in ['admin', 'editor']:
        raise PermissionError("Only editors can create posts")
    pass
```

## Multi-Tenancy Implementation

### Row-Level Security (PostgreSQL)

```sql
-- Enable RLS on all tenant-scoped tables
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Create policy for post visibility
CREATE POLICY posts_tenant_isolation ON posts
USING (tenant_id = current_setting('app.tenant_id')::uuid)
WITH CHECK (tenant_id = current_setting('app.tenant_id')::uuid);

-- Create policy for soft-deleted posts
CREATE POLICY posts_exclude_deleted ON posts
USING (deleted_at IS NULL);

-- Set tenant context from request
SET app.tenant_id = 'tenant456';
```

### Application Middleware

```python
@fraiseql.middleware
async def set_tenant_context(request, next):
    """Set tenant context from JWT token."""
    user = get_current_user_from_request(request)
    if user:
        # Set PostgreSQL context
        await db.execute("SET app.tenant_id = $1", user['tenant_id'])
        request.user = user
    return await next(request)
```

## Soft Deletes & Recovery

```python
@fraiseql.query
@authenticated
def post(info, id: str) -> "Post":
    """Get single post (excluding soft-deleted)."""
    # Automatically excludes where deleted_at IS NOT NULL
    pass

@fraiseql.query
@authenticated
@requires_scope("admin:posts")
def deleted_posts(info, first: int = 10) -> list["Post"]:
    """Admin can see deleted posts."""
    # Filter: deleted_at IS NOT NULL
    pass

@fraiseql.mutation
@authenticated
@requires_scope("write:posts")
def restore_post(info, id: str) -> "Post":
    """Restore a soft-deleted post."""
    # UPDATE posts SET deleted_at = NULL WHERE id = $1
    pass
```

## Audit Trail

```python
@fraiseql.type
class AuditLog:
    id: str
    tenant_id: str
    user_id: str
    entity_type: str  # "post", "comment"
    entity_id: str
    action: str  # "create", "update", "delete"
    changes: dict  # { field: { old: value, new: value } }
    created_at: datetime

# Middleware to log all mutations
@fraiseql.middleware
async def audit_mutations(request, next):
    """Audit all data modifications."""
    result = await next(request)
    if is_mutation(request):
        changes = extract_changes(request, result)
        await log_audit_event(get_current_user(request), changes)
    return result
```

## Caching Strategy

```python
@fraiseql.query
@authenticated
@cached(ttl=3600)  # Cache for 1 hour
def popular_posts(info, first: int = 10) -> list["Post"]:
    """Cache popular posts to reduce database load."""
    pass

@fraiseql.query
@authenticated
@cached(ttl=300, key="user_{user_id}_posts")  # Cache per user
def user_posts(info, user_id: str) -> list["Post"]:
    """Cache user's posts for 5 minutes."""
    pass

# Invalidate cache on mutations
@fraiseql.mutation
@authenticated
async def create_post(info, title: str, content: str) -> "Post":
    """Invalidate post cache after creating."""
    post = await db.create("posts", ...)
    invalidate_cache("popular_posts")
    invalidate_cache(f"user_{info.context.user['id']}_posts")
    return post
```

## Deployment

- **Docker**: Complete Docker Compose setup with PostgreSQL, Redis, NATS
- **Kubernetes**: Helm charts for production deployment
- **AWS**: CloudFormation templates for ECS/RDS/ElastiCache

See [Deployment Guide](/deployment) for details.

## Getting Started

```bash
# Clone the example
git clone https://github.com/fraiseql/examples/saas-blog
cd saas-blog

# Setup environment
cp .env.example .env
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Start database
docker-compose up -d postgres redis

# Run migrations
alembic upgrade head

# Start FraiseQL server
fraiseql serve

# Visit GraphQL playground
open http://localhost:8000/graphql
```

## Learning Path

1. **Basic**: Create/read/delete posts for single tenant
2. **Multi-Tenancy**: Add row-level security for tenant isolation
3. **Real-Time**: Add subscriptions for live updates
4. **Advanced**: Add soft deletes, audit trail, and caching
5. **Production**: Deploy to Kubernetes with monitoring

## Next Steps

- [Multi-Tenancy Guide](/guides/multi-tenancy)
- [Advanced Patterns](/guides/advanced-patterns)
- [Deployment](/deployment)
- [Federation](/features/federation) — Scale to multiple databases