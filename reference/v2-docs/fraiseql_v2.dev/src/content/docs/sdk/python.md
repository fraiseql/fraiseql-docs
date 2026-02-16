---
title: Python SDK
description: Type-safe FraiseQL client for Python with FastAPI, Django, and asyncio support
---

# Python SDK

The FraiseQL Python SDK provides full type safety and async/await support for Python 3.8+. It works seamlessly with FastAPI, Django, Flask, and any async Python framework.

## Installation

Install the FraiseQL Python SDK using `uv` or `pip`:

```bash
# Using uv (recommended for modern Python projects)
uv add fraiseql

# Using pip
pip install fraiseql
```

**Requirements:**
- Python 3.8 or higher
- `aiohttp` for async HTTP support
- Type hints support (built-in to Python 3.8+)

## Quick Start

### 1. Initialize the Client

```python
from fraiseql import Client, auth

# Create a client for your FraiseQL API
client = Client(
    url="https://your-api.fraiseql.dev/graphql",
    auth=auth.api_key("your-api-key")
)
```

### 2. Execute a Query

```python
from typing import TypedDict

class User(TypedDict):
    id: str
    name: str
    email: str

# Execute a GraphQL query with full type safety
users = await client.query("""
    query GetUsers {
        users(limit: 10) {
            id
            name
            email
        }
    }
""", response_type=User)

# users is a list[User] with full IDE autocomplete
for user in users:
    print(f"{user['name']} ({user['email']})")
```

### 3. Execute a Mutation

```python
class CreateUserInput(TypedDict):
    name: str
    email: str

class UserPayload(TypedDict):
    id: str
    name: str

# Execute a mutation with typed inputs
result = await client.mutate("""
    mutation CreateUser($input: CreateUserInput!) {
        createUser(input: $input) {
            id
            name
        }
    }
""", variables={"input": CreateUserInput(name="Alice", email="alice@example.com")})
```

## Type Safety & Code Generation

FraiseQL generates Python types automatically from your GraphQL schema.

### Generated Types

```python
from fraiseql.generated import types

# Fully typed query execution
users: list[types.User] = await client.query("""
    query GetUsers { users { id name email } }
""")

# IDE autocomplete on response fields
for user in users:
    name: str = user.name  # Type checker knows this is string
    id: str = user.id      # Type checker knows this is string
```

### Type Checking with mypy

```python
# Install type checker
uv add --dev mypy

# Run type checking
mypy src/
```

## Real-World Examples

### FastAPI Integration

```python
from fastapi import FastAPI, Depends
from fraiseql import Client

app = FastAPI()

# Create a client dependency
async def get_fraiseql_client() -> Client:
    return Client(
        url="https://api.fraiseql.dev/graphql",
        auth=auth.bearer_token()  # Uses request context
    )

@app.get("/api/users")
async def list_users(client: Client = Depends(get_fraiseql_client)):
    users = await client.query("""
        query GetUsers {
            users(limit: 50) {
                id name email
            }
        }
    """)
    return {"users": users}
```

### Async Iteration

```python
# Paginate through large result sets
async def get_all_posts():
    page = 1
    while True:
        posts = await client.query(f"""
            query GetPosts {{
                posts(limit: 100, offset: {(page-1)*100}) {{
                    id
                    title
                    author {{ name }}
                }}
            }}
        """)

        if not posts:
            break

        for post in posts:
            yield post

        page += 1

# Usage
async for post in get_all_posts():
    print(f"Processing: {post['title']}")
```

### Batch Operations

```python
# Execute multiple queries in parallel
import asyncio

async def get_dashboard_data():
    results = await asyncio.gather(
        client.query("query { users { count } }"),
        client.query("query { posts { count } }"),
        client.query("query { comments { count } }"),
    )

    users_count, posts_count, comments_count = results
    return {
        "users": users_count,
        "posts": posts_count,
        "comments": comments_count,
    }
```

## Error Handling

FraiseQL provides typed error handling for better debugging.

### Handle Query Errors

```python
from fraiseql.errors import GraphQLError, ValidationError

try:
    user = await client.query("""
        query GetUser($id: ID!) {
            user(id: $id) { id name }
        }
    """, variables={"id": "invalid-id"})
except ValidationError as e:
    # Handle validation errors (invalid arguments)
    print(f"Invalid input: {e.message}")
except GraphQLError as e:
    # Handle GraphQL errors (resolver errors)
    print(f"Query failed: {e.message}")
    if e.extensions:
        print(f"Details: {e.extensions}")
```

### Error Response Structure

```python
# FraiseQL errors include helpful context
{
    "errors": [
        {
            "message": "User not found",
            "extensions": {
                "code": "NOT_FOUND",
                "userId": "abc123"
            }
        }
    ]
}
```

## Testing

### Using FraiseQL Test Client

```python
from fraiseql.testing import MockClient
import pytest

@pytest.fixture
async def mock_client():
    return MockClient(schema="path/to/schema.graphql")

async def test_get_users(mock_client):
    # Configure mock responses
    mock_client.mock_query(
        query="query GetUsers { users { id name } }",
        response={"users": [{"id": "1", "name": "Alice"}]}
    )

    users = await mock_client.query("query GetUsers { users { id name } }")
    assert len(users) == 1
    assert users[0]["name"] == "Alice"
```

### Integration Testing

```python
import pytest_asyncio

@pytest_asyncio.fixture
async def api_client():
    client = Client(url="http://localhost:8000/graphql")
    yield client
    # Cleanup
    await client.close()

@pytest.mark.asyncio
async def test_create_and_fetch_user(api_client):
    # Create user
    result = await api_client.mutate("""
        mutation CreateUser($input: CreateUserInput!) {
            createUser(input: $input) { id name }
        }
    """, variables={"input": {"name": "Bob", "email": "bob@example.com"}})

    user_id = result["id"]

    # Fetch user
    user = await api_client.query(f"""
        query GetUser {{
            user(id: "{user_id}") {{ id name }}
        }}
    """)

    assert user["name"] == "Bob"
```

## Performance

### Caching Query Results

```python
from datetime import timedelta

# Cache results for 5 minutes
results = await client.query(
    "query { posts(limit: 100) { id title } }",
    cache_ttl=timedelta(minutes=5)
)
```

### Connection Pooling

```python
# Client automatically manages connection pool
client = Client(
    url="https://api.fraiseql.dev/graphql",
    max_connections=10  # Default: 10
)

# Process many requests efficiently
tasks = [
    client.query(f"query {{ user(id: \"{i}\") {{ name }} }}")
    for i in range(1000)
]
results = await asyncio.gather(*tasks)
```

## Troubleshooting

### "Connection refused" Error

```python
# Ensure the FraiseQL server is running
# and the URL is correct
client = Client(
    url="http://localhost:8000/graphql"  # Check host/port
)
```

### "Unauthorized" Error

```python
# Verify your authentication credentials
client = Client(
    url="https://api.fraiseql.dev/graphql",
    auth=auth.api_key("your-actual-api-key")  # Check key
)
```

### Type Errors with mypy

```python
# Use `Any` for dynamic responses when needed
from typing import Any

result: Any = await client.query(query_string)
```

## Framework Integration

- **FastAPI**: [FastAPI Integration Guide](/deployment)
- **Django**: [Django Integration Guide](/deployment)
- **Flask**: Lightweight guide in FastAPI docs
- **Async Context**: Works with any async framework

## Related SDKs

The Python SDK works seamlessly with other FraiseQL SDKs:

- **[TypeScript SDK](/sdk/typescript/)** - For Node.js and browser applications
- **[Go SDK](/sdk/go/)** - For high-performance backend services
- **[Rust SDK](/sdk/rust/)** - For systems programming and microservices

View all [17 supported language SDKs](/sdk/).

## Next Steps

- [SDK Overview](/sdk) - See other language SDKs
- [FastAPI Integration](/deployment) - Build APIs with FastAPI
- [API Reference](/reference/graphql-api) - Complete GraphQL API reference
- [Error Handling](/guides/error-handling) - Advanced error patterns