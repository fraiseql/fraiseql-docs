---
title: Elixir SDK
description: FraiseQL client for Elixir with Phoenix framework and distributed systems support
---

# Elixir SDK

The FraiseQL Elixir SDK provides functional GraphQL client support, built-in Phoenix integration, and pattern matching for elegant error handling and data transformation.

## Installation

### Mix Dependencies

```elixir
# mix.exs
def deps do
  [
    {:fraiseql, "~> 1.0"},
    {:httpoison, "~> 2.0"}
  ]
end
```

## Quick Start

```elixir
defmodule User do
  defstruct id: "", name: "", email: ""
end

client = FraiseQL.Client.new(
  url: "https://your-api.fraiseql.dev/graphql",
  api_key: "your-api-key"
)

query = """
  query {
    users(limit: 10) {
      id
      name
      email
    }
  }
"""

case FraiseQL.query(client, query, User) do
  {:ok, users} ->
    Enum.each(users, fn user ->
      IO.puts("#{user.name} (#{user.email})")
    end)

  {:error, reason} ->
    IO.puts("Error: #{reason}")
end
```

## Phoenix Integration

```elixir
# config/config.exs
config :fraiseql,
  url: System.get_env("FRAISEQL_URL"),
  api_key: System.get_env("FRAISEQL_API_KEY")

# lib/my_app_web/controllers/user_controller.ex
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller

  def index(conn, _params) do
    case FraiseQL.query(
      FraiseQL.Client.default(),
      "query { users { id name email } }",
      User
    ) do
      {:ok, users} -> json(conn, users)
      {:error, error} -> json(conn, %{"error" => error})
    end
  end
end
```

## Pattern Matching

```elixir
def get_users do
  case FraiseQL.query(client, query, User) do
    {:ok, [head | tail]} ->
      IO.puts("First user: #{head.name}")
      IO.puts("Others: #{length(tail)}")

    {:ok, []} ->
      IO.puts("No users found")

    {:error, :unauthorized} ->
      IO.puts("Check your API key")

    {:error, reason} ->
      IO.puts("Failed: #{reason}")
  end
end
```

## Pipe Operations

```elixir
def process_users do
  FraiseQL.query(client, query, User)
  |> case do
    {:ok, users} -> users
    {:error, _} -> []
  end
  |> Enum.filter(&(&1.email != nil))
  |> Enum.map(&%{name: &1.name, email: &1.email})
end
```

## Concurrent Queries

```elixir
def get_dashboard_data do
  Task.await_many([
    Task.async(fn -> FraiseQL.query(client, users_query, User) end),
    Task.async(fn -> FraiseQL.query(client, posts_query, Post) end),
    Task.async(fn -> FraiseQL.query(client, comments_query, Comment) end)
  ], timeout: 5000)
end
```

## Error Handling

```elixir
def safe_query(query, module) do
  FraiseQL.query(client, query, module)
  |> case do
    {:ok, result} ->
      {:ok, result}

    {:error, %{code: "VALIDATION_ERROR"} = error} ->
      Logger.error("Invalid query: #{error.message}")
      {:error, :invalid_query}

    {:error, %{code: "UNAUTHORIZED"}} ->
      Logger.error("Authentication failed")
      {:error, :unauthorized}

    {:error, reason} ->
      Logger.error("Query failed: #{inspect(reason)}")
      {:error, :query_failed}
  end
end
```

## Testing

```elixir
defmodule FraiseQLTest do
  use ExUnit.Case

  describe "query" do
    test "fetches users" do
      mock_client = FraiseQL.Testing.MockClient.new()

      FraiseQL.Testing.MockClient.mock(
        mock_client,
        "query { users { id } }",
        {:ok, [%User{id: "1"}]}
      )

      assert {:ok, users} = FraiseQL.query(mock_client, "query { users { id } }", User)
      assert length(users) == 1
    end
  end
end
```

## Performance

```elixir
# Connection pooling
{:ok, _} = FraiseQL.Client.start_link(
  url: "https://api.fraiseql.dev/graphql",
  max_connections: 10
)

# Batch queries with Task
results = Task.await_many([
  Task.async(&query_batch_1/0),
  Task.async(&query_batch_2/0)
])
```

## Troubleshooting

- **Atom vs String Keys**: Use atoms with pattern matching
- **Type Parsing**: Define proper struct modules for deserialization
- **Supervision**: Wrap client in GenServer for production

See also: [Phoenix Integration](/deployment)
`3
`3