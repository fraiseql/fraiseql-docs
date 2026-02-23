---
title: TypeScript SDK
description: Full-featured FraiseQL client for TypeScript and Node.js with Next.js and Express support
---

# TypeScript SDK

The FraiseQL TypeScript SDK offers complete type safety with native TypeScript generics, automatic schema-based code generation, and first-class support for Node.js, browsers, and edge runtimes (Vercel, Cloudflare Workers).

## Installation

Install the FraiseQL TypeScript SDK using your preferred package manager:

```bash
# Using npm
npm install @fraiseql/client

# Using yarn
yarn add @fraiseql/client

# Using pnpm (recommended)
pnpm add @fraiseql/client

# Using bun
bun add @fraiseql/client
```

**Supported Environments:**
- Node.js 16+
- Modern browsers (Chrome, Firefox, Safari, Edge)
- Edge runtimes (Vercel, Cloudflare Workers, Netlify)
- Electron, Tauri, and Capacitor

## Quick Start

### 1. Initialize the Client

```typescript
import { Client, createAuth } from '@fraiseql/client';

const client = new Client({
  url: 'https://your-api.fraiseql.dev/graphql',
  auth: createAuth.apiKey('your-api-key'),
});
```

### 2. Execute a Query

```typescript
import { gql } from '@fraiseql/client';

interface User {
  id: string;
  name: string;
  email: string;
}

const query = gql`
  query GetUsers {
    users(limit: 10) {
      id
      name
      email
    }
  }
`;

// Fully typed response
const { data } = await client.query<{ users: User[] }>(query);

// TypeScript knows the structure
data.users.forEach(user => {
  console.log(`${user.name} (${user.email})`);
});
```

### 3. Execute a Mutation

```typescript
const mutation = gql`
  mutation CreateUser($input: CreateUserInput!) {
    createUser(input: $input) {
      id
      name
      email
    }
  }
`;

const result = await client.mutate<
  { createUser: User },
  { input: CreateUserInput }
>(mutation, {
  variables: {
    input: {
      name: 'Alice',
      email: 'alice@example.com',
    },
  },
});

console.log(result.data.createUser.id);
```

## Type Safety & Generated Types

FraiseQL generates TypeScript types automatically from your GraphQL schema.

### Auto-Generated Types

```typescript
import type { GetUsersQuery, GetUsersQueryVariables } from '@fraiseql/generated';

const result = await client.query<GetUsersQuery, GetUsersQueryVariables>(query);

// Full autocomplete and type checking
const users = result.data.users;
users.forEach(user => {
  console.log(user.name); // IDE autocomplete works!
});
```

### Codegen Setup

```bash
# Install codegen tools
npm install -D @fraiseql/codegen graphql

# Run code generation
fraiseql codegen --schema ./schema.graphql --output ./src/generated
```

## Real-World Examples

### Next.js Server Component

```typescript
// app/dashboard/page.tsx
import { Client } from '@fraiseql/client';

const client = new Client({
  url: process.env.FRAISEQL_URL,
  auth: { token: process.env.FRAISEQL_TOKEN },
});

export default async function DashboardPage() {
  const { data } = await client.query(gql`
    query GetDashboard {
      stats {
        totalUsers
        totalPosts
        activeUsers
      }
    }
  `);

  return (
    <div>
      <h1>Dashboard</h1>
      <p>Total Users: {data.stats.totalUsers}</p>
      <p>Total Posts: {data.stats.totalPosts}</p>
    </div>
  );
}
```

### React Hook

```typescript
import { useQuery } from '@fraiseql/react';

function UserList() {
  const { data, loading, error } = useQuery(gql`
    query GetUsers {
      users(limit: 50) {
        id
        name
        email
      }
    }
  `);

  if (loading) return <p>Loading...</p>;
  if (error) return <p>Error: {error.message}</p>;

  return (
    <ul>
      {data.users.map(user => (
        <li key={user.id}>{user.name}</li>
      ))}
    </ul>
  );
}
```

### Express.js Middleware

```typescript
import express from 'express';
import { Client } from '@fraiseql/client';

const app = express();

// Create client per request
app.use((req, res, next) => {
  req.fraiseql = new Client({
    url: process.env.FRAISEQL_URL,
    auth: { token: req.headers.authorization },
  });
  next();
});

app.get('/api/users', async (req, res) => {
  const { data } = await req.fraiseql.query(gql`
    query GetUsers {
      users(limit: 50) {
        id
        name
        email
      }
    }
  `);
  res.json(data);
});
```

### Batch Operations

```typescript
import { batch } from '@fraiseql/client';

const results = await batch(client, [
  client.query(gql`query { users { count } }`),
  client.query(gql`query { posts { count } }`),
  client.query(gql`query { comments { count } }`),
]);

// Requests are automatically batched into single HTTP request
console.log(results); // [users_result, posts_result, comments_result]
```

## Error Handling

FraiseQL provides detailed typed errors for better debugging.

### Handle Query Errors

```typescript
import { GraphQLError, ValidationError } from '@fraiseql/client';

try {
  const result = await client.query(query, {
    variables: { id: 'invalid' },
  });
} catch (error) {
  if (error instanceof ValidationError) {
    // Handle validation errors
    console.error('Invalid input:', error.message);
  } else if (error instanceof GraphQLError) {
    // Handle GraphQL errors
    console.error('Query failed:', error.message);
    console.error('Code:', error.extensions?.code);
  }
}
```

### Partial Success Handling

```typescript
const result = await client.query(query);

if (result.errors) {
  // Handle errors while still using partial data
  console.warn('Partial errors:', result.errors);
  console.log('Partial data:', result.data);
}
```

## Testing

### Using vitest with FraiseQL

```typescript
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Client } from '@fraiseql/client';

describe('User queries', () => {
  let client: Client;

  beforeEach(() => {
    client = new Client({
      url: 'http://localhost:4000/graphql',
    });
  });

  it('fetches users', async () => {
    const result = await client.query(gql`
      query GetUsers {
        users {
          id
          name
        }
      }
    `);

    expect(result.data.users).toHaveLength(greaterThan(0));
  });

  it('handles errors gracefully', async () => {
    const result = await client.query(gql`
      query { invalidQuery }
    `);

    expect(result.errors).toBeDefined();
  });
});
```

### Mock Client for Testing

```typescript
import { MockClient } from '@fraiseql/testing';

const mockClient = new MockClient();

mockClient.mock(
  gql`query GetUser { user { id name } }`,
  { user: { id: '1', name: 'Alice' } }
);

const result = await mockClient.query(gql`query GetUser { user { id name } }`);
expect(result.data.user.name).toBe('Alice');
```

## Performance

### Query Caching

```typescript
const client = new Client({
  url: 'https://api.fraiseql.dev/graphql',
  cache: 'default', // Browser cache or memory cache
});

// Second request uses cached result
await client.query(query); // Network request
await client.query(query); // Cached result
```

### Request Batching

```typescript
import { createBatchClient } from '@fraiseql/client';

const client = createBatchClient({
  url: 'https://api.fraiseql.dev/graphql',
  batchSize: 10,
  batchDelay: 5, // ms
});

// Multiple requests automatically batched
Promise.all([
  client.query(query1),
  client.query(query2),
  client.query(query3),
]); // Single batched request
```

## Troubleshooting

### "CORS Error" in Browser

```typescript
// Server needs to allow your domain
const client = new Client({
  url: 'https://api.fraiseql.dev/graphql',
  headers: {
    'Origin': window.location.origin,
  },
});
```

### "Unauthorized" Error

```typescript
// Verify token is valid
const client = new Client({
  url: 'https://api.fraiseql.dev/graphql',
  auth: createAuth.bearer(process.env.FRAISEQL_TOKEN!),
});
```

### Type Errors with Generated Types

```typescript
// Regenerate types if schema changed
npm run fraiseql:codegen

// Import from generated module
import type { MyQuery } from '@fraiseql/generated/types';
```

## Framework Integration

- **Next.js**: [Next.js Integration Guide](/deployment)
- **Express**: [Express Integration Guide](/deployment)
- **React**: `@fraiseql/react` package with hooks
- **Vue**: `@fraiseql/vue` package with composables
- **Svelte**: `@fraiseql/svelte` package with stores
- **Angular**: `@fraiseql/angular` package with services

## Related SDKs

The TypeScript SDK works seamlessly with other FraiseQL SDKs:

- **[Python SDK](/sdk/python/)** - For Python backends and data science applications
- **[Go SDK](/sdk/go/)** - For high-performance backend services
- **[Rust SDK](/sdk/rust/)** - For systems programming and performance-critical applications
- **[Java SDK](/sdk/java/)** - For enterprise Java applications

View all [17 supported language SDKs](/sdk/).

## Next Steps

- [SDK Overview](/sdk) - Explore other language SDKs
- [Next.js Integration](/deployment) - Build with Next.js
- [Express Integration](/deployment) - Build with Express
- [API Reference](/reference/graphql-api) - Complete GraphQL API
- [Error Handling](/guides/error-handling) - Advanced patterns
`3
`3