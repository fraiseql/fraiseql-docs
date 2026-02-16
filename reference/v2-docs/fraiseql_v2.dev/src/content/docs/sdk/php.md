---
title: PHP SDK
description: FraiseQL client for PHP with Laravel, Symfony, and Composer support
---

# PHP SDK

The FraiseQL PHP SDK provides type-hinted support for PHP 8.0+, built-in Laravel integration, and async/concurrent query support via ReactPHP.

## Installation

### Composer

```bash
composer require fraiseql/client
```

## Quick Start

```php
<?php

require_once 'vendor/autoload.php';

use FraiseQL\Client;

class User {
    public function __construct(
        public string $id,
        public string $name,
        public string $email
    ) {}
}

$client = new Client(
    url: 'https://your-api.fraiseql.dev/graphql',
    apiKey: 'your-api-key'
);

$query = <<<'QUERY'
    query {
        users(limit: 10) {
            id
            name
            email
        }
    }
QUERY;

$users = $client->query($query, User::class);

foreach ($users as $user) {
    echo "{$user->name} ({$user->email})\n";
}
```

## Type Safety

```php
use FraiseQL\Attributes\Query;

#[Query('GetUsers')]
class GetUsersResponse {
    /** @var User[] */
    public array $users;
}

$response = $client->query($query, GetUsersResponse::class);
```

## Laravel Integration

```php
// config/fraiseql.php
return [
    'url' => env('FRAISEQL_URL', 'https://api.fraiseql.dev/graphql'),
    'api_key' => env('FRAISEQL_API_KEY'),
];

// routes/api.php
Route::get('/users', function () {
    return app('fraiseql')
        ->query('query { users { id name email } }', User::class);
});

// Or use in controller
class UserController extends Controller {
    public function index(FraiseQLClient $client) {
        return $client->query(
            'query { users { id name email } }',
            User::class
        );
    }
}
```

## Symfony Integration

```php
// config/services.yaml
services:
    fraiseql.client:
        class: FraiseQL\Client
        arguments:
            - '%env(FRAISEQL_URL)%'
            - '%env(FRAISEQL_API_KEY)%'

// Controller
class UserController extends AbstractController {
    public function index(Client $fraiseql): Response {
        $users = $fraiseql->query(
            'query { users { id name email } }',
            User::class
        );
        return $this->json($users);
    }
}
```

## Async Queries

```php
use React\EventLoop\Loop;
use React\Promise\Promise;

$promises = [
    $client->queryAsync('query { users { id } }', User::class),
    $client->queryAsync('query { posts { id } }', Post::class),
    $client->queryAsync('query { comments { id } }', Comment::class),
];

Promise\all($promises)->then(function($results) {
    [$users, $posts, $comments] = $results;
    // Process results
});
```

## Error Handling

```php
use FraiseQL\Exceptions\GraphQLException;
use FraiseQL\Exceptions\ValidationException;

try {
    $users = $client->query($query, User::class);
} catch (ValidationException $e) {
    echo "Invalid query: " . $e->getMessage();
} catch (GraphQLException $e) {
    echo "Query failed: " . $e->getMessage();
    if ($e->hasExtensions()) {
        print_r($e->getExtensions());
    }
}
```

## Testing

```php
use PHPUnit\Framework\TestCase;
use FraiseQL\Testing\MockClient;

class UserServiceTest extends TestCase {
    private MockClient $client;

    protected function setUp(): void {
        $this->client = new MockClient();
    }

    public function testGetUsers(): void {
        $this->client->mock(
            'query { users { id name } }',
            [new User('1', 'Alice', 'alice@example.com')]
        );

        $users = $this->client->query(
            'query { users { id name } }',
            User::class
        );

        $this->assertCount(1, $users);
        $this->assertEquals('Alice', $users[0]->name);
    }
}
```

## Performance

```php
// Connection pooling with cURL options
$client = new Client(
    url: 'https://api.fraiseql.dev/graphql',
    options: [
        'max_connections' => 10,
        'timeout' => 30,
        'pool_size' => 50,
    ]
);

// Query result caching
$users = $client->query($query, User::class, cache: 300); // 5 min cache
```

## Troubleshooting

- **Type Mapping**: Use PHP 8 named properties for type safety
- **Encoding**: Ensure UTF-8 encoding for special characters
- **Memory**: Use streaming for large result sets

See also: [Laravel Integration](/deployment), [Symfony Integration](/deployment)
`3
`3