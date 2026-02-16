---
title: Swift SDK
description: FraiseQL client for Swift with iOS, macOS, and Server Swift support
---

# Swift SDK

The FraiseQL Swift SDK provides native Swift support for iOS, macOS, and server-side Swift with Codable integration, async/await, and first-class networking support.

## Installation

### Swift Package Manager

```swift
// Package.swift
let package = Package(
    name: "MyApp",
    dependencies: [
        .package(url: "https://github.com/fraiseql/swift-client.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "MyApp",
            dependencies: [.product(name: "FraiseQL", package: "swift-client")]
        )
    ]
)
```

### CocoaPods

```ruby
pod 'FraiseQL', '~> 1.0'
```

## Quick Start

```swift
import FraiseQL

struct User: Codable {
    let id: String
    let name: String
    let email: String
}

let client = FraiseQLClient(
    url: URL(string: "https://your-api.fraiseql.dev/graphql")!,
    apiKey: "your-api-key"
)

let query = """
    query {
        users(limit: 10) {
            id
            name
            email
        }
    }
    """

let users: [User] = try await client.query(query)
users.forEach { user in
    print("\(user.name) (\(user.email))")
}
```

## Type-Safe Queries

```swift
struct GetUsersResponse: Codable {
    let users: [User]
}

// Strongly typed response
let response: GetUsersResponse = try await client.query(query)
```

## iOS Integration

```swift
import SwiftUI

@main
struct ContentView: View {
    @State private var users: [User] = []
    @State private var isLoading = false

    var body: some View {
        List {
            ForEach(users, id: \.id) { user in
                VStack(alignment: .leading) {
                    Text(user.name).font(.headline)
                    Text(user.email).font(.caption)
                }
            }
        }
        .onAppear {
            Task {
                await fetchUsers()
            }
        }
    }

    private func fetchUsers() async {
        isLoading = true
        do {
            users = try await client.query(getusersQuery)
        } catch {
            print("Error: \(error)")
        }
        isLoading = false
    }
}
```

## Server-Side Swift

```swift
import Vapor

app.get("api", "users") { req -> EventLoopFuture<[User]> in
    let client = req.application.fraiseql
    return client.query(query)
}
```

## Error Handling

```swift
do {
    let users: [User] = try await client.query(query)
} catch let error as FraiseQLError {
    switch error {
    case .validationError(let message):
        print("Validation error: \(message)")
    case .networkError(let underlyingError):
        print("Network error: \(underlyingError)")
    case .decodingError(let underlyingError):
        print("Decoding error: \(underlyingError)")
    }
}
```

## Testing

```swift
import XCTest

class FraiseQLTests: XCTestCase {
    var client: FraiseQLClient!

    override func setUp() {
        super.setUp()
        client = FraiseQLClient(url: URL(string: "http://localhost:4000/graphql")!)
    }

    func testGetUsers() async throws {
        let users: [User] = try await client.query(getUsersQuery)
        XCTAssertGreaterThan(users.count, 0)
    }
}
```

## Performance

```swift
// Connection pooling
let client = FraiseQLClient(
    url: url,
    maxConnections: 10,
    timeout: 30
)

// Batch queries
async let users = client.query(usersQuery)
async let posts = client.query(postsQuery)
let (userList, postList) = try await (users, posts)
```

## Troubleshooting

- **Decoding Issues**: Ensure property names match GraphQL field names
- **Async/await**: Requires iOS 13+ or macOS 10.15+
- **SSL Errors**: Check certificate pinning configuration

See also: [iOS Integration Guide](/deployment)
`3
`3