---
title: Pagination
description: Automatic LIMIT/OFFSET, cursor pagination, and total counts
---

FraiseQL provides automatic pagination for list queries, supporting both offset-based and cursor-based patterns.

## Offset Pagination

### Enabling Pagination

```python
@fraiseql.query(
    sql_source="v_post",
    auto_params={"limit": True, "offset": True}
)
def posts(limit: int = 20, offset: int = 0) -> list[Post]:
    """Query posts with pagination."""
    pass
```

### Usage

```graphql
# First page
query {
    posts(limit: 20, offset: 0) {
        id
        title
    }
}

# Second page
query {
    posts(limit: 20, offset: 20) {
        id
        title
    }
}

# Third page
query {
    posts(limit: 20, offset: 40) {
        id
        title
    }
}
```

### Resulting Query

```sql
SELECT data FROM v_post
ORDER BY data->>'created_at' DESC
LIMIT 20 OFFSET 40
```

## Configuration

### Default Limits

```toml
[graphql.pagination]
default_limit = 20
max_limit = 100
```

```python
# If client requests limit > max_limit, it's capped
query {
    posts(limit: 500) { ... }  # Capped to 100
}
```

### Per-Query Limits

```python
@fraiseql.query(
    sql_source="v_user",
    auto_params={"limit": True, "offset": True},
    max_limit=50,
    default_limit=10
)
def users(limit: int = 10, offset: int = 0) -> list[User]:
    pass
```

## Total Counts

### Enabling Counts

```python
@fraiseql.query(
    sql_source="v_post",
    auto_params={"limit": True, "offset": True, "total_count": True}
)
def posts(
    limit: int = 20,
    offset: int = 0,
    include_count: bool = False
) -> PostsResult:
    pass

@fraiseql.type
class PostsResult:
    items: list[Post]
    total_count: int | None
```

### Usage

```graphql
query {
    posts(limit: 20, offset: 0, includeCount: true) {
        items {
            id
            title
        }
        totalCount  # Total matching records
    }
}
```

### Response

```json
{
    "data": {
        "posts": {
            "items": [...],
            "totalCount": 1547
        }
    }
}
```

## Cursor Pagination

For large datasets, cursor pagination is more efficient than offset:

### Defining Connections

```python
@fraiseql.type
class PageInfo:
    has_next_page: bool
    has_previous_page: bool
    start_cursor: str | None
    end_cursor: str | None

@fraiseql.type
class PostEdge:
    node: Post
    cursor: str

@fraiseql.type
class PostConnection:
    edges: list[PostEdge]
    page_info: PageInfo
    total_count: int | None

@fraiseql.query(
    sql_source="v_post",
    pagination="cursor"
)
def posts(
    first: int | None = None,
    after: str | None = None,
    last: int | None = None,
    before: str | None = None
) -> PostConnection:
    pass
```

### Usage

```graphql
# First page
query {
    posts(first: 20) {
        edges {
            node {
                id
                title
            }
            cursor
        }
        pageInfo {
            hasNextPage
            endCursor
        }
    }
}

# Next page (using cursor)
query {
    posts(first: 20, after: "eyJpZCI6IjEyMyIsImNyZWF0ZWRfYXQiOiIyMDI0LTAxLTE1In0=") {
        edges {
            node {
                id
                title
            }
            cursor
        }
        pageInfo {
            hasNextPage
            endCursor
        }
    }
}
```

### Cursor Format

Cursors are base64-encoded JSON:

```json
// Decoded cursor
{
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "created_at": "2024-01-15T10:30:00Z"
}
```

### SQL Implementation

```sql
-- First page
SELECT data FROM v_post
ORDER BY created_at DESC, id DESC
LIMIT 21  -- +1 to check hasNextPage

-- After cursor
SELECT data FROM v_post
WHERE (created_at, id) < ($cursor_created_at, $cursor_id)
ORDER BY created_at DESC, id DESC
LIMIT 21
```python

## Relay Specification

FraiseQL implements **keyset-based pagination** fully compatible with the [Relay specification](https://relay.dev/docs/guides/graphql-server/), providing standard cursor pagination format for JavaScript clients.

> **Note**: Relay pagination (for queries) and GraphQL Cascade (for mutations) work together seamlessly. While Relay handles cache-friendly pagination for list queries, Cascade handles automatic cache updates from mutations. See [GraphQL Cascade](/features/function-shapes#graphql-cascade-advanced-mutations-with-side-effects) for mutation cache updates.

### Why Relay Specification?

- ✅ **Standard format** — `edges`, `pageInfo`, `cursor` follow Relay spec
- ✅ **Client library support** — Works with Apollo Client, Relay, URQL, and other GraphQL clients
- ✅ **Cache-friendly** — Relay client caches queries automatically
- ✅ **Bidirectional** — Forward (`first`/`after`) and backward (`last`/`before`) pagination
- ✅ **Scale-safe** — No OFFSET performance degradation at scale

### Relay Pagination Interface

The Relay-compatible interface automatically available on all cursor-paginated queries:

```graphql
# Relay compliant connection interface
type PostConnection {
  edges: [PostEdge!]!        # Array of nodes + cursors
  pageInfo: PageInfo!        # Navigation metadata
  totalCount: Int            # Optional: total matching records
}

type PostEdge {
  node: Post!                # The actual data
  cursor: String!            # Opaque cursor for next page
}

type PageInfo {
  hasNextPage: Boolean!      # More records forward
  hasPreviousPage: Boolean!  # More records backward
  startCursor: String        # Cursor of first edge
  endCursor: String          # Cursor of last edge
}
```

### JavaScript Client Example: Relay

```javascript
// Using Relay client
import { usePaginationFragment } from 'react-relay';

function PostList() {
  const { data, loadNext, hasNext } = usePaginationFragment(
    graphql`
      fragment PostList_posts on Query
      @refetchable(queryName: "PostListPaginationQuery") {
        posts(first: 20, after: $after) {
          edges {
            node {
              id
              title
            }
          }
          pageInfo {
            hasNextPage
            endCursor
          }
        }
      }
    `,
    relay_data
  );

  return (
    <>
      {data.posts.edges.map(edge => (
        <div key={edge.node.id}>{edge.node.title}</div>
      ))}
      {hasNext && (
        <button onClick={() => loadNext(20)}>Load more</button>
      )}
    </>
  );
}
```

### JavaScript Client Example: Apollo Client

```javascript
// Using Apollo Client
import { useQuery } from '@apollo/client';

const POSTS_QUERY = gql`
  query GetPosts($first: Int, $after: String) {
    posts(first: $first, after: $after) {
      edges {
        node {
          id
          title
        }
        cursor
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
`;

function Posts() {
  const { data, loading, fetchMore } = useQuery(POSTS_QUERY, {
    variables: { first: 20 }
  });

  return (
    <>
      {data?.posts.edges.map(edge => (
        <div key={edge.node.id}>{edge.node.title}</div>
      ))}
      {data?.posts.pageInfo.hasNextPage && (
        <button
          onClick={() =>
            fetchMore({
              variables: {
                after: data.posts.pageInfo.endCursor
              }
            })
          }
        >
          Load more
        </button>
      )}
    </>
  );
}
```

### Key Advantages over Offset Pagination

| Aspect | Offset | Relay (Keyset) |
|--------|--------|---|
| **Performance at 1M+ rows** | ❌ Slow (must skip rows) | ✅ Consistent O(limit) |
| **Reliable order** | ❌ Ties cause skips | ✅ Stable with keyset |
| **Concurrent updates** | ❌ Shifts results | ✅ Unaffected by inserts |
| **Client caching** | ❌ Manual cache busting | ✅ Automatic with Relay |
| **Cursor expiry** | N/A | ⚠️ Stateless (works forever) |

## Ordering

### Automatic Order By

```python
@fraiseql.query(
    sql_source="v_post",
    auto_params={"limit": True, "offset": True, "order_by": True}
)
def posts(
    limit: int = 20,
    offset: int = 0,
    order_by: PostOrderByInput | None = None
) -> list[Post]:
    pass
```

Generated input type:

```graphql
input PostOrderByInput {
    id: OrderDirection
    title: OrderDirection
    created_at: OrderDirection
    updated_at: OrderDirection
}

enum OrderDirection {
    ASC
    DESC
    ASC_NULLS_FIRST
    ASC_NULLS_LAST
    DESC_NULLS_FIRST
    DESC_NULLS_LAST
}
```

### Usage

```graphql
query {
    posts(
        limit: 20
        orderBy: { created_at: DESC }
    ) {
        id
        title
        created_at
    }
}
```

### Multiple Sort Fields

```graphql
query {
    posts(
        limit: 20
        orderBy: [
            { is_featured: DESC }
            { created_at: DESC }
        ]
    ) {
        id
        title
    }
}
```

## Combining Pagination with Filters

```graphql
query {
    posts(
        where: {
            is_published: { _eq: true }
            tags: { _contains: "tutorial" }
        }
        orderBy: { view_count: DESC }
        limit: 10
        offset: 0
    ) {
        id
        title
        view_count
        tags
    }
}
```

## Performance

### Offset Pagination Issues

Large offsets are slow:

```sql
-- Slow: PostgreSQL must scan 1,000,000 rows
SELECT * FROM posts OFFSET 1000000 LIMIT 20
```

For large datasets, use cursor pagination instead.

### Cursor Pagination Benefits

- Consistent performance regardless of page
- Works with real-time data (no skipping/duplication)
- Requires stable sort key

### Indexing for Pagination

```sql
-- Index for common ordering
CREATE INDEX idx_post_created ON tb_post(created_at DESC);

-- Composite index for cursor pagination
CREATE INDEX idx_post_cursor ON tb_post(created_at DESC, id DESC);

-- Index for filtered + ordered queries
CREATE INDEX idx_post_published_created ON tb_post(is_published, created_at DESC)
WHERE is_published = true;
```

## Best Practices

### Always Paginate

Never return unbounded lists:

```python
# Good: Has default limit
@fraiseql.query(auto_params={"limit": True})
def posts(limit: int = 20) -> list[Post]: pass

# Bad: No limit
@fraiseql.query()
def posts() -> list[Post]: pass  # Could return millions
```

### Enforce Max Limits

```toml
[graphql.pagination]
max_limit = 100  # Cap client requests
```

### Use Cursor for Large Datasets

| Dataset Size | Recommendation |
|--------------|----------------|
| < 10,000 | Offset OK |
| 10,000 - 100,000 | Consider cursor |
| > 100,000 | Use cursor |

### Stable Sort Keys

Always include a unique field in sort:

```graphql
# Good: id ensures stable order
orderBy: [{ created_at: DESC }, { id: DESC }]

# Bad: Ties cause inconsistent pagination
orderBy: { created_at: DESC }
```

### Count Carefully

Total counts require full table scan:

```python
# Only request count when needed
query {
    posts(includeCount: false) {  # Skip count for performance
        items { id }
    }
}
```

For approximate counts:

```sql
-- Approximate count (fast)
SELECT reltuples::bigint AS estimate
FROM pg_class
WHERE relname = 'tb_post';
```

## Next Steps

- [Automatic Where](/features/automatic-where) — Filtering
- [Operators](/reference/operators) — Sort and filter operators
- [Performance](/guides/performance) — Query optimization
`3
`3