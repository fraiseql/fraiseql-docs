---
title: Rust SDK
description: High-performance FraiseQL client for Rust with Actix, Axum, and Rocket support
---

# Rust SDK

The FraiseQL Rust SDK provides zero-cost abstractions with Rust's type system, async/await support, and seamless integration with Tokio and other async runtimes.

## Installation

```toml
[dependencies]
fraiseql = "1.0"
tokio = { version = "1", features = ["full"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
```

## Quick Start

```rust
use fraiseql::Client;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize)]
struct User {
    id: String,
    name: String,
    email: String,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let client = Client::new(
        "https://your-api.fraiseql.dev/graphql",
        "your-api-key"
    );

    let query = r#"
        query {
            users(limit: 10) {
                id
                name
                email
            }
        }
    "#;

    let users: Vec<User> = client.query(query).await?;

    for user in users {
        println!("{} ({})", user.name, user.email);
    }

    Ok(())
}
```

## Type Safety

Rust's type system ensures compile-time safety:

```rust
#[derive(Serialize, Deserialize)]
struct GetUsersResponse {
    users: Vec<User>,
}

// Full type checking at compile time
let response: GetUsersResponse = client.query(query).await?;
```

## Async Patterns

```rust
async fn get_users(client: &Client) -> Result<Vec<User>, Box<dyn std::error::Error>> {
    client.query::<Vec<User>>(r#"
        query {
            users { id name email }
        }
    "#).await
}

// Execute multiple queries concurrently
async fn dashboard_data(client: &Client) -> Result<(), Box<dyn std::error::Error>> {
    let (users, posts, comments) = tokio::join!(
        get_users(client),
        get_posts(client),
        get_comments(client)
    );

    Ok(())
}
```

## Axum Framework Integration

```rust
use axum::{extract::State, Json};

#[derive(Clone)]
struct AppState {
    client: Client,
}

async fn list_users(
    State(state): State<AppState>,
) -> Json<Vec<User>> {
    let users = state.client.query::<Vec<User>>(
        r#"query { users { id name email } }"#
    ).await.unwrap_or_default();

    Json(users)
}
```

## Error Handling

```rust
use fraiseql::GraphQLError;

match client.query::<Vec<User>>(query).await {
    Ok(users) => println!("Got {} users", users.len()),
    Err(GraphQLError::ValidationError(msg)) => eprintln!("Invalid query: {}", msg),
    Err(GraphQLError::NetworkError(err)) => eprintln!("Network error: {}", err),
    Err(e) => eprintln!("Error: {}", e),
}
```

## Testing

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_get_users() {
        let client = Client::new("http://localhost:4000/graphql", "test-key");

        let users: Result<Vec<User>, _> = client.query(r#"
            query {
                users { id name }
            }
        "#).await;

        assert!(users.is_ok());
    }
}
```

## Performance

```rust
// Connection pooling
let client = Client::builder()
    .url("https://api.fraiseql.dev/graphql")
    .max_connections(50)
    .timeout(Duration::from_secs(30))
    .build();

// Stream large result sets
let stream = client.stream::<User>(large_query).await?;
```

## Troubleshooting

- **Lifetime Issues**: Use owned `String` instead of `&str` in response types
- **Async Runtime**: Ensure you're using `#[tokio::main]` or equivalent
- **Serialization**: Verify serde attributes on types

See also: [Rust Framework Guides](/deployment)

## Related SDKs

The Rust SDK works seamlessly with other FraiseQL SDKs:

- **[TypeScript SDK](/sdk/typescript/)** - For Node.js and browser clients
- **[Go SDK](/sdk/go/)** - For high-performance backend services
- **[Python SDK](/sdk/python/)** - For data science and ML applications

View all [17 supported language SDKs](/sdk/).