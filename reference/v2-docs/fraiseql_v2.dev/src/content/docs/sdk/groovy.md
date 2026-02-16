---
title: Groovy SDK
description: FraiseQL client for Groovy with JVM integration and dynamic typing
---

# Groovy SDK

The FraiseQL Groovy SDK provides a dynamic, fluent API for building GraphQL queries on the JVM with full metaprogramming support.

## Installation

### Gradle

```groovy
dependencies {
    implementation 'com.fraiseql:fraiseql-groovy:latest'
}
```

### Maven

```xml
<dependency>
    <groupId>com.fraiseql</groupId>
    <artifactId>fraiseql-groovy</artifactId>
    <version>latest</version>
</dependency>
```

## Quick Start

```groovy
import com.fraiseql.FraiseQL

// Create client
def client = FraiseQL.client('https://api.example.com/graphql')

// Build and execute query
def result = client.query {
    posts(first: 10) {
        id
        title
        author {
            name
            email
        }
    }
}.execute()

result.data.posts.each { post ->
    println "${post.title} by ${post.author.name}"
}
```

## Type Safety with Groovy

While Groovy is dynamically typed, you can use type hints with the SDK:

```groovy
@Grab('com.fraiseql:fraiseql-groovy:latest')
import com.fraiseql.FraiseQL
import com.fraiseql.types.Post
import com.fraiseql.types.User

FraiseQL client = FraiseQL.client('https://api.example.com/graphql')

List<Post> posts = client.query {
    posts(first: 20) {
        id
        title
        published
    }
}.execute().data.posts

posts.each { Post post ->
    println post.title
}
```

## Query Builder API

### Simple Queries

```groovy
def query = client.query {
    user(id: 'user123') {
        id
        name
        email
        createdAt
    }
}

def user = query.execute().data.user
```

### Mutations

```groovy
def result = client.mutation {
    createPost(
        title: 'Hello World',
        content: 'First post!'
    ) {
        id
        title
        createdAt
    }
}.execute()

def newPost = result.data.createPost
```

### Subscriptions (WebSocket)

```groovy
client.subscription {
    postCreated {
        id
        title
        author { name }
    }
}.subscribe { event ->
    println "New post: ${event.data.postCreated.title}"
}
```

## Error Handling

```groovy
try {
    def result = client.query {
        users {
            id
            name
        }
    }.execute()

    if (result.errors) {
        result.errors.each { error ->
            println "Error: ${error.message}"
        }
    } else {
        result.data.users.each { println it.name }
    }
} catch (Exception e) {
    println "Request failed: ${e.message}"
}
```

## Authentication

### JWT Token

```groovy
def client = FraiseQL.client('https://api.example.com/graphql') {
    auth = "Bearer ${jwtToken}"
}

def result = client.query {
    me {
        id
        name
        email
    }
}.execute()
```

### API Key

```groovy
def client = FraiseQL.client('https://api.example.com/graphql') {
    headers = ['X-API-Key': apiKey]
}
```

## Variables & Parameters

```groovy
def userId = 'user123'
def limit = 20

def result = client.query {
    user(id: userId) {
        posts(first: limit) {
            id
            title
        }
    }
}.execute()
```

## Caching & Performance

```groovy
// Cache query results for 1 hour
def query = client.query {
    popularPosts(first: 10) {
        id
        title
        views
    }
}.cache(duration: 3600)

def posts = query.execute().data.popularPosts
```

## Testing

```groovy
import spock.lang.Specification

class PostServiceSpec extends Specification {
    FraiseQL client = FraiseQL.mockClient()

    def "should fetch posts"() {
        given:
        client.mockResponse('posts', [
            [id: '1', title: 'Post 1'],
            [id: '2', title: 'Post 2']
        ])

        when:
        def posts = client.query {
            posts(first: 2) { id; title }
        }.execute().data.posts

        then:
        posts.size() == 2
        posts[0].title == 'Post 1'
    }
}
```

## Advanced Features

### Dynamic Field Selection

```groovy
def fields = ['id', 'name', 'email', 'createdAt']

def query = client.query {
    users {
        fields.each { field -> delegate."$field"() }
    }
}
```

### Meta-Programming

```groovy
class QueryBuilder {
    def client
    def queryMap = [:]

    def methodMissing(String name, args) {
        queryMap[name] = args
        this
    }

    def execute() {
        client.query(queryMap).execute()
    }
}
```

### Batch Operations

```groovy
def userIds = ['user1', 'user2', 'user3']

def queries = userIds.collect { id ->
    client.query {
        user(id: id) {
            id
            name
            email
        }
    }
}

def results = queries.collect { it.execute() }
```

## Common Patterns

### Pagination

```groovy
def allPosts = []
def cursor = null

while (true) {
    def result = client.query {
        posts(first: 20, after: cursor) {
            edges {
                node { id; title }
                cursor
            }
            pageInfo { hasNextPage; endCursor }
        }
    }.execute()

    result.data.posts.edges.each { edge ->
        allPosts << edge.node
    }

    if (!result.data.posts.pageInfo.hasNextPage) break
    cursor = result.data.posts.pageInfo.endCursor
}
```

### Error Recovery

```groovy
def executeWithRetry(closure, int maxRetries = 3) {
    int retries = 0
    while (retries < maxRetries) {
        try {
            return closure.call()
        } catch (Exception e) {
            retries++
            if (retries >= maxRetries) throw e
            Thread.sleep(1000 * retries)
        }
    }
}

def result = executeWithRetry {
    client.query {
        users { id; name }
    }.execute()
}
```

## Resources

- [Groovy Documentation](https://groovy-lang.org/)
- [JVM Integration](/deployment/kubernetes)
- [Error Handling](/guides/error-handling)
- [Query Optimization](/guides/advanced-patterns)

## See Also

- [Java SDK](/sdk/java)
- [Kotlin SDK](/sdk/kotlin)
- [Scala SDK](/sdk/scala)