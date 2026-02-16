---
title: Kotlin SDK
description: FraiseQL client for Kotlin with Spring Boot and Ktor framework support
---

# Kotlin SDK

The FraiseQL Kotlin SDK provides coroutines support, data class integration, and seamless Spring Boot and Ktor framework support with full null safety.

## Installation

### Gradle

```groovy
dependencies {
    implementation 'dev.fraiseql:fraiseql-client:1.0.0'
    implementation 'org.jetbrains.kotlinx:kotlinx-coroutines-core:1.6.0'
}
```

## Quick Start

```kotlin
import dev.fraiseql.client.FraiseQLClient
import dev.fraiseql.client.auth.ApiKeyAuth

data class User(
    val id: String,
    val name: String,
    val email: String
)

suspend fun main() {
    val client = FraiseQLClient(
        "https://your-api.fraiseql.dev/graphql",
        ApiKeyAuth("your-api-key")
    )

    val query = """
        query {
            users(limit: 10) {
                id
                name
                email
            }
        }
    """

    val users = client.query<List<User>>(query)
    users.forEach { user ->
        println("${user.name} (${user.email})")
    }
}
```

## Type Safety with Data Classes

```kotlin
data class GetUsersResponse(val users: List<User>)

val response = client.query<GetUsersResponse>(query)
response.users.forEach { println(it.name) }
```

## Spring Boot Integration

```kotlin
import org.springframework.stereotype.Service
import org.springframework.boot.autoconfigure.EnableAutoConfiguration

@Service
class UserService(private val client: FraiseQLClient) {
    suspend fun getAllUsers(): List<User> =
        client.query("""
            query { users { id name email } }
        """)
}

@EnableAutoConfiguration
class Application

fun main(args: Array<String>) {
    runApplication<Application>(*args)
}
```

## Ktor Integration

```kotlin
import io.ktor.server.routing.*
import io.ktor.server.application.*

fun Application.configureRouting(client: FraiseQLClient) {
    routing {
        get("/api/users") {
            val users = client.query<List<User>>(
                "query { users { id name email } }"
            )
            call.respond(users)
        }
    }
}
```

## Coroutines & Async

```kotlin
suspend fun getDashboardData(client: FraiseQLClient) {
    val (users, posts) = coroutineScope {
        val usersDeferred = async { client.query<List<User>>("query { users }") }
        val postsDeferred = async { client.query<List<Post>>("query { posts }") }

        usersDeferred.await() to postsDeferred.await()
    }
}
```

## Error Handling

```kotlin
try {
    val users = client.query<List<User>>(query)
} catch (e: FraiseQLException) {
    when (e) {
        is ValidationException -> println("Invalid query: ${e.message}")
        is NetworkException -> println("Network error: ${e.message}")
        else -> throw e
    }
}
```

## Testing

```kotlin
import org.junit.jupiter.api.Test
import org.mockito.Mockito.*

class UserServiceTest {
    private val mockClient = mock<FraiseQLClient>()
    private val service = UserService(mockClient)

    @Test
    suspend fun testGetUsers() {
        val expectedUsers = listOf(
            User("1", "Alice", "alice@example.com")
        )

        `when`(mockClient.query<List<User>>(any())).thenReturn(expectedUsers)

        val users = service.getAllUsers()
        assert(users.isNotEmpty())
    }
}
```

## Performance

```kotlin
// Connection pooling
val client = FraiseQLClient(
    url = "https://api.fraiseql.dev/graphql",
    maxConnections = 50
)

// Batch queries efficiently
val results = listOf(
    async { client.query<List<User>>("query { users }") },
    async { client.query<List<Post>>("query { posts }") }
).awaitAll()
```

## Troubleshooting

- **Null Safety**: Use `?` or Elvis operator for nullable fields
- **Coroutines**: Ensure using suspend functions
- **Type Errors**: Verify data class matches GraphQL schema

See also: [Spring Boot Integration](/deployment)
`3
`3