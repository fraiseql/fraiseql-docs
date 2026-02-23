---
title: Introduction
description: What is FraiseQL and why should you use it?
---

FraiseQL is a **database-first GraphQL framework**. You write SQL views, FraiseQL maps them to GraphQL types, and every query resolves to a single SQL statement. No resolvers. No N+1. No magic.

## The Problem with Traditional GraphQL

Traditional GraphQL frameworks require you to:

1. **Write resolvers** for every field and relationship
2. **Handle N+1 queries** manually with DataLoaders
3. **Tune performance** at runtime
4. **Manage complex configurations** in YAML or JSON

This leads to boilerplate code, runtime surprises, and hours spent debugging performance issues.

## The FraiseQL Approach

FraiseQL takes a fundamentally different approach:

| Traditional GraphQL | FraiseQL |
|---------------------|----------|
| Write resolvers | Write SQL views |
| Handle N+1 manually | N+1 eliminated by design |
| Tune performance | Performance compiled in |
| Runtime complexity | Compile-time mapping |
| YAML/JSON config | TOML you can read |

### How It Works

1. **Write** SQL views following the `.data` JSONB pattern
2. **Define** your GraphQL types in your preferred language (Python, TypeScript, Go, etc.)
3. **Configure** in a simple TOML file
4. **Compile** the mapping between GraphQL types and SQL views
5. **Serve** GraphQL queries at database speed

The result: a GraphQL API backed by SQL you wrote, reviewed, and own. Database-first means you see the exact query that runs — and you get the full power of your database (PostgreSQL, SQL Server, MySQL, SQLite).

## Key Features

### Any Database

FraiseQL supports multiple databases:

- PostgreSQL
- MySQL
- SQLite
- SQL Server

*(Oracle is explicitly not supported)*

### Any Language

Define your schema in the language you're most comfortable with:

- Python
- TypeScript
- Go
- Java
- Rust
- And 12+ more

All compile to the same optimized output.

### TOML Configuration

Your entire configuration fits in one readable file:

```toml
[project]
name = "my-api"

[database]
type = "postgresql"
url = "${DATABASE_URL}"

[server]
port = 8080
```

No YAML complexity. No JSON verbosity. Just TOML you can actually read.

### Compile-Time Input Validation

13 built-in validators ensure data quality before any database execution. One fewer thing to debug in production.

- ✅ **Standard validation** — required, pattern, length, range, enum, checksum
- ✅ **Cross-field validation** — date ranges, numeric comparisons, string matching
- ✅ **Mutual exclusivity** — OneOf, AnyOf, ConditionalRequired, RequiredIfAbsent
- ✅ **All enforced at compile time** — invalid input structures impossible at runtime

Unlike traditional GraphQL frameworks that validate at runtime, FraiseQL catches validation errors during schema compilation. Your API can never deploy an invalid schema.

                             ─

### 15 Type-Safe SDKs

Define your GraphQL schema in 15 languages with full type safety.

## When to Use FraiseQL

FraiseQL is ideal when you need:

- **High performance** — sub-millisecond query latency
- **Simplicity** — no resolver code to write or maintain
- **Predictability** — deterministic, compiled behavior
- **Flexibility** — multiple databases and languages

## When NOT to Use FraiseQL

Be honest: FraiseQL isn't for every use case.

Consider alternatives if you need:

- **Custom business logic in resolvers** — FraiseQL is database-first; complex business logic may need a different approach
- **Real-time subscriptions with complex filtering** — basic subscriptions are supported, but complex filtering may be limited
- **Oracle database** — explicitly not supported

## Next Steps

Ready to get started?

- [Quick Start](/getting-started/quickstart) — 5 minutes to your first API
- [Installation](/getting-started/installation) — Detailed setup guide
- [How It Works](/concepts/how-it-works) — Understand the architecture
`3
`3