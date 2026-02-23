---
title: GraphQL API
description: Complete reference for generated GraphQL queries, mutations, and subscriptions
---

FraiseQL generates a complete GraphQL API from your schema. This reference covers all generated operations.

## Schema Structure

```graphql
type Query {
    # Entity queries
    user(id: ID!): User
    users(where: UserWhereInput, limit: Int, offset: Int, orderBy: UserOrderByInput): [User!]!

    # Relationship queries
    postsByAuthor(authorId: ID!, limit: Int): [Post!]!
}

type Mutation {
    # CRUD operations
    createUser(input: CreateUserInput!): User!
    updateUser(id: ID!, input: UpdateUserInput!): User!
    deleteUser(id: ID!): Boolean!

    # Custom mutations
    publishPost(id: ID!): Post!
}

type Subscription {
    # Real-time updates
    userCreated: User!
    postUpdated(authorId: ID): Post!
}
```

## Queries

### Single Entity Query

```graphql
query GetUser($id: ID!) {
    user(id: $id) {
        id
        name
        email
        createdAt
    }
}
```

**Variables:**
```json
{
    "id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Response:**
```json
{
    "data": {
        "user": {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "name": "John Doe",
            "email": "john@example.com",
            "createdAt": "2024-01-15T10:30:00Z"
        }
    }
}
```

### List Query

```graphql
query GetUsers($limit: Int, $offset: Int) {
    users(limit: $limit, offset: $offset) {
        id
        name
        email
    }
}
```

**With Filtering:**
```graphql
query GetActiveUsers {
    users(where: { isActive: { _eq: true } }, limit: 20) {
        id
        name
    }
}
```

**With Ordering:**
```graphql
query GetRecentUsers {
    users(orderBy: { createdAt: DESC }, limit: 10) {
        id
        name
        createdAt
    }
}
```

### Nested Queries

```graphql
query GetPostWithAuthor($id: ID!) {
    post(id: $id) {
        id
        title
        content
        author {
            id
            name
            email
        }
        comments {
            id
            content
            author {
                name
            }
        }
    }
}
```

## Mutations

### Create

```graphql
mutation CreateUser($input: CreateUserInput!) {
    createUser(input: $input) {
        id
        email
        name
        createdAt
    }
}
```

**Variables:**
```json
{
    "input": {
        "email": "new@example.com",
        "name": "New User",
        "bio": "Hello world"
    }
}
```

### Update

```graphql
mutation UpdateUser($id: ID!, $input: UpdateUserInput!) {
    updateUser(id: $id, input: $input) {
        id
        name
        bio
        updatedAt
    }
}
```

**Variables:**
```json
{
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "input": {
        "name": "Updated Name",
        "bio": "New bio"
    }
}
```

### Delete

```graphql
mutation DeleteUser($id: ID!) {
    deleteUser(id: $id)
}
```

**Response:**
```json
{
    "data": {
        "deleteUser": true
    }
}
```

### Custom Mutations

```graphql
mutation PublishPost($id: ID!) {
    publishPost(id: $id) {
        id
        isPublished
        publishedAt
    }
}
```

## Subscriptions

### Entity Created

```graphql
subscription OnUserCreated {
    userCreated {
        id
        name
        email
    }
}
```

### Entity Updated

```graphql
subscription OnPostUpdated($authorId: ID) {
    postUpdated(authorId: $authorId) {
        id
        title
        updatedAt
    }
}
```

### Using with WebSocket

```javascript
const ws = new WebSocket('ws://localhost:8080/subscriptions');

ws.onopen = () => {
    ws.send(JSON.stringify({
        type: 'subscribe',
        id: '1',
        payload: {
            query: `subscription { userCreated { id name } }`
        }
    }));
};

ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    console.log('New user:', data.payload.data.userCreated);
};
```

## Input Types

### Create Input

```graphql
input CreateUserInput {
    email: String!
    name: String!
    bio: String
    avatarUrl: String
}
```

### Update Input

```graphql
input UpdateUserInput {
    name: String
    bio: String
    avatarUrl: String
}
```

All fields optional - only provided fields are updated.

### Filter Input

```graphql
input UserWhereInput {
    id: IDFilter
    email: StringFilter
    name: StringFilter
    isActive: BooleanFilter
    createdAt: DateTimeFilter
    _and: [UserWhereInput!]
    _or: [UserWhereInput!]
    _not: UserWhereInput
}

input StringFilter {
    _eq: String
    _neq: String
    _in: [String!]
    _nin: [String!]
    _like: String
    _ilike: String
    _is_null: Boolean
}
```

### Order By Input

```graphql
input UserOrderByInput {
    id: OrderDirection
    name: OrderDirection
    email: OrderDirection
    createdAt: OrderDirection
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

## Scalar Types

| Scalar | GraphQL | JSON Format |
|--------|---------|-------------|
| `ID` | `ID` | UUID string |
| `String` | `String` | UTF-8 string |
| `Int` | `Int` | 32-bit integer |
| `Float` | `Float` | Double precision |
| `Boolean` | `Boolean` | true/false |
| `DateTime` | `DateTime` | ISO 8601 |
| `Date` | `Date` | YYYY-MM-DD |
| `Time` | `Time` | HH:MM:SS |
| `Decimal` | `Decimal` | String (precision) |
| `JSON` | `JSON` | Any JSON value |

## Error Responses

### Validation Error

```json
{
    "errors": [{
        "message": "Variable '$email' expected type 'String!' but got null",
        "locations": [{"line": 1, "column": 15}],
        "extensions": {
            "code": "GRAPHQL_VALIDATION_FAILED"
        }
    }]
}
```

### Not Found

```json
{
    "data": {
        "user": null
    }
}
```

### Authorization Error

```json
{
    "errors": [{
        "message": "Forbidden: missing scope read:User.email",
        "path": ["user", "email"],
        "extensions": {
            "code": "FORBIDDEN"
        }
    }]
}
```

### Business Logic Error

```json
{
    "errors": [{
        "message": "User with email already exists",
        "path": ["createUser"],
        "extensions": {
            "code": "DUPLICATE_EMAIL"
        }
    }]
}
```

## Introspection

### Schema Query

```graphql
query {
    __schema {
        types {
            name
            kind
        }
    }
}
```

### Type Query

```graphql
query {
    __type(name: "User") {
        name
        fields {
            name
            type {
                name
                kind
            }
        }
    }
}
```

**Note:** Introspection can be disabled in production:

```toml
[graphql]
introspection = false
```

## Playground

Access the GraphQL playground at:

```
http://localhost:8080/graphql
```

Features:
- Interactive query editor
- Schema explorer
- Variable editor
- Response viewer
- Query history

**Disable in production:**

```toml
[graphql]
playground = false
```

## Batching

Send multiple operations in one request:

```json
[
    {
        "query": "query { user(id: \"1\") { name } }"
    },
    {
        "query": "query { user(id: \"2\") { name } }"
    }
]
```

**Response:**
```json
[
    {"data": {"user": {"name": "User 1"}}},
    {"data": {"user": {"name": "User 2"}}}
]
```

**Limit:**
```toml
[graphql]
batch_limit = 10  # Max operations per batch
```

## HTTP Details

### Endpoint

```
POST /graphql
Content-Type: application/json
```

### Request Format

```json
{
    "query": "query GetUser($id: ID!) { user(id: $id) { name } }",
    "operationName": "GetUser",
    "variables": {
        "id": "123"
    }
}
```

### GET Requests (APQ)

```
GET /graphql?extensions={"persistedQuery":{"version":1,"sha256Hash":"..."}}
    &variables={"id":"123"}
```

### Headers

| Header | Description |
|--------|-------------|
| `Authorization` | Bearer token for auth |
| `X-Request-ID` | Request tracing ID |
| `Content-Type` | `application/json` |

## Next Steps

- [Decorators](/reference/decorators) — Define schema elements
- [Operators](/reference/operators) — Filter operators
- [Scalars](/reference/scalars) — Type reference