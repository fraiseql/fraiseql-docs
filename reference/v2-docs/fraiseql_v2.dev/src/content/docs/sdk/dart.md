---
title: Dart SDK
description: FraiseQL client for Dart with Flutter and pub.dev package management support
---

# Dart SDK

The FraiseQL Dart SDK provides null-safe GraphQL client with built-in Flutter support, code generation, and reactive streams for real-time subscriptions.

## Installation

### pubspec.yaml

```
dependencies:
  fraiseql: ^1.0.0
  dio: ^5.0.0

dev_dependencies:
  fraiseql_generator: ^1.0.0
  build_runner: ^2.0.0
```

## Quick Start

```dart
import 'package:fraiseql/fraiseql.dart';

class User {
  final String id;
  final String name;
  final String email;

  User({
    required this.id,
    required this.name,
    required this.email,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    email: json['email'] ?? '',
  );
}

void main() async {
  final client = FraiseQLClient(
    url: 'https://your-api.fraiseql.dev/graphql',
    apiKey: 'your-api-key',
  );

  const query = '''
    query {
      users(limit: 10) {
        id
        name
        email
      }
    }
  ''';

  try {
    final users = await client.query<List<User>>(
      query,
      (json) => (json['users'] as List)
        .map((e) => User.fromJson(e as Map<String, dynamic>))
        .toList(),
    );

    for (final user in users) {
      print('${user.name} (${user.email})');
    }
  } catch (e) {
    print('Error: $e');
  }
}
```

## Flutter Integration

```dart
import 'package:flutter/material.dart';
import 'package:fraiseql/fraiseql.dart';

class UserListScreen extends StatefulWidget {
  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  late Future<List<User>> futureUsers;

  @override
  void initState() {
    super.initState();
    final client = FraiseQLClient(
      url: 'https://api.fraiseql.dev/graphql',
    );

    futureUsers = client.query<List<User>>(
      'query { users { id name email } }',
      (json) => // ... parsing logic
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Users')),
      body: FutureBuilder<List<User>>(
        future: futureUsers,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final user = snapshot.data![index];
                return ListTile(
                  title: Text(user.name),
                  subtitle: Text(user.email),
                );
              },
            );
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          return Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
```

## Code Generation

```bash
# Generate types from schema
dart run build_runner build

# Outputs generated types in lib/generated/
```

```dart
// Use generated types (auto-generated)
import 'generated/fraiseql_types.dart';

final users = await client.query<GetUsersQuery>(query);
```

## Null Safety

```dart
class SafeUser {
  final String id;
  final String? name;  // Nullable
  final String email;

  const SafeUser({
    required this.id,
    this.name,
    required this.email,
  });
}
```

## Error Handling

```dart
try {
  final users = await client.query(query, _parseUsers);
} on FraiseQLValidationException catch (e) {
  print('Validation error: ${e.message}');
} on FraiseQLNetworkException catch (e) {
  print('Network error: ${e.message}');
} catch (e) {
  print('Unexpected error: $e');
}
```

## Testing

```dart
import 'package:test/test.dart';
import 'package:fraiseql/testing.dart';

void main() {
  group('FraiseQL Client', () {
    test('fetches users', () async {
      final mock = MockFraiseQLClient();

      mock.mock(
        'query { users { id } }',
        {'users': [{'id': '1', 'name': 'Alice'}]},
      );

      final users = await mock.query(
        'query { users { id } }',
        (json) => User.fromJson(json),
      );

      expect(users, isNotEmpty);
    });
  });
}
```

## Reactive Streams

```dart
// Subscribe to real-time updates
final subscription = client
    .subscribe(subscriptionQuery)
    .listen(
      (data) => setState(() => _users = data),
      onError: (error) => print('Error: $error'),
      onDone: () => print('Subscription closed'),
    );

// Cleanup
@override
void dispose() {
  subscription.cancel();
  super.dispose();
}
```

## Performance

```dart
// Connection pooling
final client = FraiseQLClient(
  url: 'https://api.fraiseql.dev/graphql',
  maxConnections: 10,
  timeout: Duration(seconds: 30),
);

// Batch queries
final results = await Future.wait([
  client.query(query1, _parse1),
  client.query(query2, _parse2),
  client.query(query3, _parse3),
]);
```

## Troubleshooting

- **Type Errors**: Use proper generic type parameters
- **Async Issues**: Use `FutureBuilder` or `StreamBuilder`
- **Serialization**: Ensure `fromJson` factory methods

See also: [Flutter Integration](/deployment)
`3
`3