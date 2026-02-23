---
title: Migrating from Apollo Server to FraiseQL
description: Guide to migrate from Apollo Server to FraiseQL's database-first GraphQL approach
---

# Migrating from Apollo Server to FraiseQL

This guide walks through migrating from manually-built Apollo Server GraphQL backends to FraiseQL's database-first approach.

## Architecture Comparison

### Apollo Server (Manual)
```
1. Write TypeScript interfaces
2. Write GraphQL schema by hand
3. Implement resolvers manually
4. Connect to database
5. Handle N+1 queries manually
6. Implement caching manually
```

### FraiseQL (Automated)
```python
1. Define Python/SQL types
2. Schema derived from types
3. Resolvers mapped to hand-written SQL views
4. Automatic N+1 batching
5. Built-in caching
6. Deployment ready
```python

## Key Differences

| Aspect | Apollo | FraiseQL |
|--------|--------|----------|
| **Schema Definition** | GraphQL SDL (manual) | Python types (mapped to SQL) |
| **Resolvers** | Hand-written | Mapped to SQL views |
| **Database** | Custom queries | Hand-written SQL views |
| **Caching** | redis-apollo-link | Built-in federation cache |
| **Subscriptions** | WebSocket (manual) | Native with NATS |
| **Performance** | Manual optimization | Automatic batching |
| **Type Safety** | apollo-codegen | Native SDK types |
| **Complexity** | High (resolver logic) | Low (decorators) |

## Step-by-Step Migration

### Phase 1: Understand Current Apollo Setup

**Current Apollo Server:**
```typescript
import { ApolloServer, gql } from 'apollo-server-express';
import { PrismaClient } from '@prisma/client';

const typeDefs = gql`
  type User {
    id: ID!
    email: String!
    name: String!
    posts: [Post!]!
  }

  type Post {
    id: ID!
    title: String!
    content: String!
    author: User!
  }

  type Query {
    user(id: ID!): User
    users(limit: Int): [User!]!
    post(id: ID!): Post
    posts(limit: Int): [Post!]!
  }

  type Mutation {
    createUser(email: String!, name: String!): User!
    createPost(title: String!, content: String!, authorId: ID!): Post!
  }
`;

const resolvers = {
  Query: {
    user: async (_, { id }) => prisma.user.findUnique({ where: { id } }),
    users: async (_, { limit }) => prisma.user.findMany({ take: limit }),
    post: async (_, { id }) => prisma.post.findUnique({ where: { id } }),
    posts: async (_, { limit }) => prisma.post.findMany({ take: limit })
  },

  User: {
    posts: async (user) => prisma.post.findMany({ where: { userId: user.id } })
    // N+1 problem: runs once per user!
  },

  Post: {
    author: async (post) => prisma.user.findUnique({ where: { id: post.userId } })
  },

  Mutation: {
    createUser: async (_, { email, name }) =>
      prisma.user.create({ data: { email, name } }),
    createPost: async (_, { title, content, authorId }) =>
      prisma.post.create({ data: { title, content, userId: authorId } })
  }
};
```

### Phase 2: Convert to FraiseQL

**FraiseQL equivalent:**

```python
from fraiseql import FraiseQL, Type, Query, Mutation, ID

fraiseql = FraiseQL()

@fraiseql.type
class User:
    id: ID
    email: str
    name: str
    posts: list['Post']

@fraiseql.type
class Post:
    id: ID
    title: str
    content: str
    author_id: ID
    author: User

# Queries - FraiseQL maps these to SQL views
@fraiseql.query(sql_source="v_user")
def user(id: ID) -> User:
    """Get single user."""
    pass

@fraiseql.query(sql_source="v_user")
def users(limit: int = 50) -> list[User]:
    """Get multiple users."""
    pass

@fraiseql.query(sql_source="v_post")
def post(id: ID) -> Post:
    """Get single post."""
    pass

@fraiseql.query(sql_source="v_post")
def posts(limit: int = 50) -> list[Post]:
    """Get multiple posts."""
    pass

# Mutations - FraiseQL maps these to SQL functions
@fraiseql.mutation(sql_source="fn_create_user", operation="CREATE")
def create_user(email: str, name: str) -> User:
    """Create user."""
    pass

@fraiseql.mutation(sql_source="fn_create_post", operation="CREATE")
def create_post(title: str, content: str, author_id: ID) -> Post:
    """Create post."""
    pass
```

### Phase 3: N+1 Problem Gone!

**Apollo (N+1):**
```typescript
// Querying 10 users with posts = 11 queries
const users = await prisma.user.findMany({ take: 10 });  // 1
// Then for each user's posts field:
// User.posts resolver called 10 times = 10 queries
// Total: 11 queries
```

**FraiseQL (Automatic batching):**
```graphql
query GetUsers {
  users(limit: 10) {
    name
    posts {  # Automatically batched!
      title
    }
  }
}
```

FraiseQL executes only **2 queries**:
1. SELECT * FROM users LIMIT 10
2. SELECT * FROM posts WHERE user_id IN (list_of_user_ids)

That's **5x fewer queries**!

### Phase 4: Client Code

The query syntax is identical - just update where it's called from:

**Apollo Client:**
```typescript
import { useQuery, gql } from '@apollo/client';

const GET_USERS = gql`
  query GetUsers {
    users(limit: 10) { id name }
  }
`;

function UsersList() {
  const { data } = useQuery(GET_USERS);
  // ...
}
```

**FraiseQL Client (same query, different client):**
```typescript
import { Client } from '@fraiseql/client';

const client = new Client({
  url: 'https://api.example.com/graphql',
  apiKey: process.env.FRAISEQL_API_KEY
});

async function getUsers() {
  return await client.query(`
    query GetUsers {
      users(limit: 10) { id name }
    }
  `);
}
```

## Performance Comparison

### Apollo Server
```
Users request (10 users with posts):
├── Query.users: 1 query
├── User[0].posts: 1 query
├── User[1].posts: 1 query
├── ... (8 more)
└── Total: 11 queries
Time: ~200ms
```




│
↓

**10x faster** with zero code changes to queries!

## Subscriptions

### Apollo (Complex)
```typescript
const pubsub = new PubSub();

const resolvers = {
  Subscription: {
    userCreated: {
      subscribe: () => pubsub.asyncIterator(['USER_CREATED'])
    }
  },
  Mutation: {
    createUser: async (_, { email, name }) => {
      const user = await prisma.user.create({ data: { email, name } });
      pubsub.publish('USER_CREATED', { userCreated: user });
      return user;
    }
  }
};
```

### FraiseQL (Simple)
```python
@fraiseql.subscription(entity_type="User", topic="created")
def user_created() -> User:
    """Subscribe to new users."""
    pass

# Client code stays the same!
```

## Migration Checklist

- [ ] Document all Apollo resolvers and queries
- [ ] Map Apollo types to FraiseQL types
- [ ] Create SQL views for queries
- [ ] Create SQL functions for mutations
- [ ] Define FraiseQL decorators
- [ ] Test FraiseQL produces same results
- [ ] Update frontend clients
- [ ] Migrate subscriptions
- [ ] Performance testing (expect 5-10x faster)
- [ ] Decommission Apollo

## Key Benefits Summary

| Metric | Apollo | FraiseQL |
|--------|--------|----------|
| **Resolver Lines** | 500+ | 0 (mapped to SQL views) |
| **Queries/Request** | 11 | 2 |
| **Request Time** | 200ms | 20ms |
| **Development Time** | High | Low |
| **Caching** | Manual | Automatic |
| **N+1 Problems** | Common | Impossible |

## Related Guides

- [Prisma Migration](/migrations/from-prisma)
- [Hasura Migration](/migrations/from-hasura)
- [NATS Integration](/features/nats) - For subscriptions
- [API Reference](/reference/graphql-api)
`3