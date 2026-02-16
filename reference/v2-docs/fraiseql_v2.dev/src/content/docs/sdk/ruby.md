---
title: Ruby SDK
description: FraiseQL client for Ruby with Rails, Sinatra, and RubyGems support
---

# Ruby SDK

The FraiseQL Ruby SDK provides intuitive DSL support, first-class Rails integration with initializers, and ActiveRecord-compatible patterns for GraphQL queries.

## Installation

### Bundler

```bash
bundle add fraiseql
```

### Gemfile

```ruby
gem 'fraiseql', '~> 1.0'
```

## Quick Start

```ruby
require 'fraiseql'

class User
  attr_accessor :id, :name, :email

  def initialize(id:, name:, email:)
    @id = id
    @name = name
    @email = email
  end
end

client = FraiseQL::Client.new(
  url: 'https://your-api.fraiseql.dev/graphql',
  api_key: 'your-api-key'
)

query = <<~QUERY
  query {
    users(limit: 10) {
      id
      name
      email
    }
  }
QUERY

users = client.query(query, User)

users.each do |user|
  puts "#{user.name} (#{user.email})"
end
```

## Type Safety

```ruby
# Define response types
class UserResponse
  attr_reader :users

  def initialize(data)
    @users = data['users'].map { |u| User.new(**u.symbolize_keys) }
  end
end

response = client.query(query, UserResponse)
response.users.each { |u| puts u.name }
```

## Rails Integration

```ruby
# config/initializers/fraiseql.rb
FraiseQL.configure do |config|
  config.url = ENV['FRAISEQL_URL']
  config.api_key = ENV['FRAISEQL_API_KEY']
end

# app/models/user.rb
class User
  include FraiseQL::Model

  graphql_query <<~QUERY
    query GetUsers($limit: Int) {
      users(limit: $limit) {
        id
        name
        email
      }
    }
  QUERY
end

# Usage
users = User.all  # Executes FraiseQL query

# app/controllers/api/users_controller.rb
class Api::UsersController < ApplicationController
  def index
    render json: User.all
  end
end
```

## Query DSL

```ruby
users = client.query do
  users(limit: 10) do
    id
    name
    email
  end
end
```

## Error Handling

```ruby
begin
  users = client.query(query, User)
rescue FraiseQL::ValidationError => e
  Rails.logger.error("Invalid query: #{e.message}")
rescue FraiseQL::NetworkError => e
  Rails.logger.error("Network error: #{e.message}")
end
```

## Testing

```ruby
describe FraiseQL::Client do
  let(:mock_client) { FraiseQL::Testing::MockClient.new }

  it 'fetches users' do
    mock_client.mock(
      'query { users { id name } }',
      [{ id: '1', name: 'Alice' }]
    )

    users = mock_client.query('query { users { id name } }', User)
    expect(users.count).to eq(1)
  end
end
```

## Performance

```ruby
# Connection pooling
client = FraiseQL::Client.new(
  url: 'https://api.fraiseql.dev/graphql',
  max_connections: 10,
  timeout: 30
)

# Query result caching
users = client.query(query, User, cache: 300)

# Concurrent queries
require 'concurrent'

results = Concurrent::Promise.all(
  Concurrent::Promise.execute { client.query(query1, User) },
  Concurrent::Promise.execute { client.query(query2, Post) }
).value!
```

## Troubleshooting

- **Type Errors**: Use `symbolize_keys` for attribute mapping
- **Encoding**: Ensure UTF-8 in Gemfile and files
- **Dependencies**: Check `bundler` version compatibility

See also: [Rails Integration](/deployment)
`3
`3