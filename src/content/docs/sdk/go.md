---
title: Go SDK
description: Production-ready FraiseQL client for Go with Gin, Echo, and Chi framework support
---

# Go SDK

The FraiseQL Go SDK provides full type safety through Go's interface and generic systems, with built-in support for concurrent queries, HTTP/2, and cloud deployments. Perfect for microservices, APIs, and backend systems.

## Installation

Install the FraiseQL Go SDK using `go get`:

```bash
# Add dependency to your Go project
go get github.com/fraiseql/go-client

# Then import in your code
import "github.com/fraiseql/go-client"
```

**Requirements:**
- Go 1.18+ (for generics support)
- `net/http` standard library
- Optional: Depends will auto-generate types from schema

## Quick Start

### 1. Initialize the Client

```go
package main

import (
    "context"
    "github.com/fraiseql/go-client"
)

func main() {
    client := fraiseql.New(
        fraiseql.WithURL("https://your-api.fraiseql.dev/graphql"),
        fraiseql.WithAuth(fraiseql.APIKeyAuth("your-api-key")),
    )
    defer client.Close()

    // Use client...
}
```

### 2. Execute a Query

```go
package main

import (
    "context"
    "log"
)

type User struct {
    ID    string `json:"id"`
    Name  string `json:"name"`
    Email string `json:"email"`
}

type GetUsersResponse struct {
    Users []User `json:"users"`
}

func main() {
    client := fraiseql.New(
        fraiseql.WithURL("https://your-api.fraiseql.dev/graphql"),
    )
    defer client.Close()

    var result GetUsersResponse

    err := client.Query(context.Background(), `
        query GetUsers {
            users(limit: 10) {
                id
                name
                email
            }
        }
    `, &result)

    if err != nil {
        log.Fatal(err)
    }

    for _, user := range result.Users {
        log.Printf("%s (%s)", user.Name, user.Email)
    }
}
```

### 3. Execute a Mutation

```go
type CreateUserInput struct {
    Name  string `json:"name"`
    Email string `json:"email"`
}

type CreateUserResponse struct {
    CreateUser User `json:"createUser"`
}

func createUser(ctx context.Context, client *fraiseql.Client) (*User, error) {
    var result CreateUserResponse

    err := client.Mutate(ctx, `
        mutation CreateUser($input: CreateUserInput!) {
            createUser(input: $input) {
                id
                name
                email
            }
        }
    `, map[string]interface{}{
        "input": CreateUserInput{
            Name:  "Alice",
            Email: "alice@example.com",
        },
    }, &result)

    if err != nil {
        return nil, err
    }

    return &result.CreateUser, nil
}
```

## Type Safety & Code Generation

Go's generics and code generation ensure type safety at compile time.

### Using Code Generation

```bash
# Generate types from GraphQL schema
fraiseql codegen \
  --schema ./schema.graphql \
  --output ./generated \
  --lang go

# This generates types automatically
```

### Generated Types Example

```go
// generated/queries.go (auto-generated)
type GetUsersQuery struct {
    Users []struct {
        ID    string
        Name  string
        Email string
    }
}

// In your code
var query GetUsersQuery
err := client.Query(ctx, GetUsersQueryString, &query)
```

### Strongly Typed Queries

```go
type QueryVariables struct {
    Limit  int    `json:"limit"`
    Search string `json:"search"`
}

func listUsers(ctx context.Context, vars QueryVariables) ([]User, error) {
    var result struct {
        Users []User `json:"users"`
    }

    err := client.Query(ctx,
        "query GetUsers($limit: Int!, $search: String) { ... }",
        vars,
        &result,
    )

    return result.Users, err
}
```

## Real-World Examples

### Gin Framework Integration

```go
package main

import (
    "github.com/gin-gonic/gin"
    "github.com/fraiseql/go-client"
)

func setupRouter(client *fraiseql.Client) *gin.Engine {
    r := gin.Default()

    // Middleware to inject client
    r.Use(func(c *gin.Context) {
        c.Set("fraiseql", client)
        c.Next()
    })

    r.GET("/api/users", getUsers)
    return r
}

func getUsers(c *gin.Context) {
    client := c.MustGet("fraiseql").(*fraiseql.Client)

    var result struct {
        Users []User `json:"users"`
    }

    err := client.Query(c.Request.Context(), `
        query GetUsers {
            users(limit: 50) {
                id
                name
                email
            }
        }
    `, &result)

    if err != nil {
        c.JSON(500, gin.H{"error": err.Error()})
        return
    }

    c.JSON(200, result.Users)
}
```

### Concurrent Queries

```go
import (
    "context"
    "sync"
)

func getDashboardData(ctx context.Context, client *fraiseql.Client) {
    var wg sync.WaitGroup
    var mu sync.Mutex

    dashboard := struct {
        UserCount    int
        PostCount    int
        CommentCount int
    }{}

    // Query 1: User count
    wg.Add(1)
    go func() {
        defer wg.Done()

        var result struct {
            Users []struct{} `json:"users"`
        }

        if err := client.Query(ctx, "query { users { id } }", &result); err == nil {
            mu.Lock()
            dashboard.UserCount = len(result.Users)
            mu.Unlock()
        }
    }()

    // Query 2: Post count (similar pattern)
    // Query 3: Comment count (similar pattern)

    wg.Wait()
    return dashboard
}
```

### Error Handling with Types

```go
type APIError struct {
    Code    string                 `json:"code"`
    Message string                 `json:"message"`
    Details map[string]interface{} `json:"details"`
}

func safeQuery(ctx context.Context, client *fraiseql.Client) error {
    var result interface{}

    err := client.Query(ctx, "query { ... }", &result)

    if err != nil {
        if gqlErr, ok := err.(fraiseql.GraphQLError); ok {
            // Handle GraphQL errors
            log.Printf("GraphQL Error: %s", gqlErr.Message)

            for _, ext := range gqlErr.Extensions {
                log.Printf("Code: %v", ext["code"])
            }
        } else {
            // Handle network errors
            log.Printf("Network error: %v", err)
        }
        return err
    }

    return nil
}
```

## Error Handling

FraiseQL errors are structured and predictable.

### Error Types

```go
import "github.com/fraiseql/go-client"

// GraphQL errors
gqlErr := err.(fraiseql.GraphQLError)
log.Printf("Message: %s", gqlErr.Message)

// Network errors
if errors.Is(err, context.DeadlineExceeded) {
    log.Println("Request timed out")
}

// Validation errors
if errors.Is(err, fraiseql.ErrValidation) {
    log.Println("Query validation failed")
}
```

### Retry Logic

```go
import "github.com/fraiseql/go-client/retry"

client := fraiseql.New(
    fraiseql.WithURL("https://api.fraiseql.dev/graphql"),
    fraiseql.WithRetry(
        retry.WithMaxAttempts(3),
        retry.WithBackoff(time.Second),
    ),
)
```

## Testing

### Unit Testing with Mock Client

```go
import (
    "testing"
    "github.com/fraiseql/go-client/mock"
)

func TestGetUsers(t *testing.T) {
    mockClient := mock.New()

    mockClient.Mock("GetUsers", []User{
        {ID: "1", Name: "Alice"},
        {ID: "2", Name: "Bob"},
    })

    var result struct {
        Users []User
    }

    err := mockClient.Query(context.Background(), "query GetUsers { users { id name } }", &result)

    if err != nil {
        t.Fatal(err)
    }

    if len(result.Users) != 2 {
        t.Fatalf("Expected 2 users, got %d", len(result.Users))
    }
}
```

### Integration Testing

```go
func TestIntegration(t *testing.T) {
    if testing.Short() {
        t.Skip("Skipping integration test")
    }

    client := fraiseql.New(
        fraiseql.WithURL(os.Getenv("FRAISEQL_TEST_URL")),
    )
    defer client.Close()

    var result struct {
        Users []User
    }

    err := client.Query(context.Background(), "query { users { id } }", &result)

    if err != nil {
        t.Fatalf("Query failed: %v", err)
    }
}
```

## Performance

### Connection Pooling

```go
client := fraiseql.New(
    fraiseql.WithURL("https://api.fraiseql.dev/graphql"),
    fraiseql.WithMaxConnections(50),
    fraiseql.WithTimeout(30 * time.Second),
)
```

### Batch Requests

```go
// Multiple queries in single request
queries := []string{
    "query { users { count } }",
    "query { posts { count } }",
    "query { comments { count } }",
}

results := client.Batch(context.Background(), queries...)
```

### Streaming Results

```go
// Stream large result sets
stream, err := client.Stream(context.Background(), largeQuery)

for result := range stream {
    if result.Error != nil {
        log.Fatal(result.Error)
    }

    // Process each result
    processRow(result.Data)
}
```

## Troubleshooting

### "Connection refused"

```go
// Check URL and ensure server is running
client := fraiseql.New(
    fraiseql.WithURL("http://localhost:8000/graphql"),
)
```

### "Unauthorized"

```go
// Verify authentication token
client := fraiseql.New(
    fraiseql.WithAuth(fraiseql.BearerAuth(os.Getenv("FRAISEQL_TOKEN"))),
)
```

### Timeout Issues

```go
ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
defer cancel()

err := client.Query(ctx, query, &result)
```

## Framework Integration

- **Gin**: Fast HTTP framework
- **Echo**: Modern HTTP framework
- **Chi**: Composable HTTP router
- **Buffalo**: Full web framework
- **Standard net/http**: Works with any HTTP router

## Related SDKs

The Go SDK works seamlessly with other FraiseQL SDKs:

- **[TypeScript SDK](/sdk/typescript/)** - For Node.js and browser clients
- **[Python SDK](/sdk/python/)** - For Python backends and data science
- **[Rust SDK](/sdk/rust/)** - For high-performance systems programming

View all [17 supported language SDKs](/sdk/).

## Next Steps

- [SDK Overview](/sdk) - Explore other language SDKs
- [Go Best Practices](/deployment) - Go-specific patterns
- [API Reference](/reference/graphql-api) - Complete GraphQL API
- [Error Handling](/guides/error-handling) - Advanced error patterns