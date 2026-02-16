---
title: Java SDK
description: Enterprise-grade FraiseQL client for Java with Spring Boot, Quarkus, and Micronaut support
---

# Java SDK

The FraiseQL Java SDK provides production-grade GraphQL client support with full type safety through generics, Spring Boot integration, and first-class reactive support via Project Reactor and RxJava.

## Installation

### Maven

```xml
<dependency>
    <groupId>dev.fraiseql</groupId>
    <artifactId>fraiseql-client</artifactId>
    <version>1.0.0</version>
</dependency>
```

### Gradle

```groovy
dependencies {
    implementation 'dev.fraiseql:fraiseql-client:1.0.0'
}
```

## Quick Start

```java
import dev.fraiseql.client.FraiseQLClient;
import dev.fraiseql.client.auth.ApiKeyAuth;

public class Main {
    public static void main(String[] args) throws Exception {
        FraiseQLClient client = new FraiseQLClient(
            "https://your-api.fraiseql.dev/graphql",
            new ApiKeyAuth("your-api-key")
        );

        String query = "query { users(limit: 10) { id name email } }";
        UserListResponse response = client.query(query, UserListResponse.class);

        response.getUsers().forEach(user ->
            System.out.println(user.getName() + " (" + user.getEmail() + ")")
        );
    }
}
```

## Type Safety with Generics

```java
// Define response types
public static class User {
    private String id;
    private String name;
    private String email;

    // getters/setters...
}

// Query with type parameter
List<User> users = client.query(
    "query { users { id name email } }",
    new TypeReference<UserResponse>() {}
).getUsers();
```

## Spring Boot Integration

```java
import org.springframework.stereotype.Service;

@Service
public class UserService {
    private final FraiseQLClient client;

    public UserService(FraiseQLClient client) {
        this.client = client;
    }

    public List<User> getAllUsers() throws FraiseQLException {
        return client.query(
            "query { users { id name email } }",
            UserResponse.class
        ).getUsers();
    }
}
```

## Reactive Queries

```java
import reactor.core.publisher.Mono;

public Mono<List<User>> getUsersReactive() {
    return Mono.fromCallable(() ->
        client.query("query { users { id name } }", UserResponse.class).getUsers()
    );
}
```

## Error Handling

```java
try {
    UserResponse response = client.query(query, UserResponse.class);
    if (response.hasErrors()) {
        response.getErrors().forEach(error ->
            logger.error("GraphQL Error: {}", error.getMessage())
        );
    }
} catch (FraiseQLException e) {
    logger.error("Request failed: {}", e.getMessage());
}
```

## Testing

```java
import dev.fraiseql.testing.MockFraiseQLClient;

@Test
public void testGetUsers() throws FraiseQLException {
    MockFraiseQLClient mockClient = new MockFraiseQLClient();

    mockClient.mockQuery(
        "query { users { id name } }",
        new UserResponse(List.of(new User("1", "Alice", "alice@example.com")))
    );

    UserResponse response = mockClient.query("query { users { id name } }", UserResponse.class);
    assertEquals(1, response.getUsers().size());
}
```

## Troubleshooting

- **Connection Issues**: Verify URL and firewall settings
- **Authentication**: Check API key validity
- **Type Mapping**: Ensure Java classes match GraphQL schema

See also: [Spring Boot Integration](/deployment)