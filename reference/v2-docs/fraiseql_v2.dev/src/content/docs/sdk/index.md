---
title: Schema Authoring SDKs
description: Define GraphQL schemas in your favorite language - 15 SDK options for schema authoring
---

# Schema Authoring SDKs

FraiseQL provides **15 schema authoring SDKs** in different programming languages. Each SDK allows you to define your GraphQL schema using native language constructs, which compile to optimized SQL queries at build time.

## How It Works

```

        │

        │

        │

        │
```

You write your schema in your preferred language using type definitions and decorators, then the FraiseQL CLI compiles it to JSON that the Rust runtime executes.

## Available SDKs (15 Languages)

| Language | Type System | Package Manager | Status |
|----------|-------------|-----------------|--------|
| **Python** | Type hints | PyPI / uv | ✅ Stable |
| **TypeScript** | Native types | npm / yarn / pnpm | ✅ Stable |
| **Go** | Struct tags + builders | Go modules 1.22+ | ✅ Stable |
| **Java** | Annotations | Maven, Gradle | ✅ Stable |
| **Rust** | Traits | Cargo | ✅ Stable |
| **C#** | Attributes | NuGet | ✅ Stable |
| **Swift** | Protocols | SPM | ✅ Stable |
| **Kotlin** | Annotations | Maven, Gradle | ✅ Stable |
| **PHP** | Attributes | Composer | ✅ Stable |
| **Ruby** | DSL + Classes | RubyGems | ✅ Stable |
| **Elixir** | Macros | Mix | ✅ Stable |
| **Dart** | Annotations | pub.dev | ✅ Stable |
| **Clojure** | Maps + builders | Leiningen, deps.edn | ✅ Stable |
| **Groovy** | Dynamic classes | Gradle, Maven | ✅ Stable |
| **Scala** | Case classes | sbt, Maven | ✅ Stable |

## Quick Start by Language

### Compiled, Typed Languages

- **[Go](/sdk/go)** - Fast, concurrent, cloud-native applications
- **[Rust](/sdk/rust)** - Maximum performance and memory safety
- **[Java](/sdk/java)** - Enterprise-grade backend development
- **[C#](/sdk/csharp)** - .NET ecosystem integration
- **[Kotlin](/sdk/kotlin)** - Modern JVM language with conciseness

### Dynamically Typed Languages

- **[Python](/sdk/python)** - Primary authoring language, data science friendly
- **[Ruby](/sdk/ruby)** - Rails integration, rapid development
- **[PHP](/sdk/php)** - Web development with Composer, Laravel
- **[Groovy](/sdk/groovy)** - Dynamic JVM language, metaprogramming

### Functional & Niche Languages

- **[TypeScript](/sdk/typescript)** - Type-safe Node.js and frontend backends
- **[Elixir](/sdk/elixir)** - Distributed systems, Phoenix framework
- **[Swift](/sdk/swift)** - iOS, macOS, and server-side Swift
- **[Dart](/sdk/dart)** - Flutter mobile development
- **[Clojure](/sdk/clojure)** - Lisp on the JVM
- **[Scala](/sdk/scala)** - Scalable language, functional paradigms

## Key Features of All SDKs

Each SDK provides:

✅ **Type-Safe Schema Definition** - Use your language's native type system
✅ **Decorators/Attributes** - Metadata for GraphQL behavior (queries, mutations, authorization, etc.)
✅ **Schema Compilation** - Generate schema.json for the FraiseQL compiler
✅ **Builder Patterns** - Fluent APIs for complex type definitions
✅ **Full Feature Parity** - All SDKs support all 30 core features
✅ **Example Code** - Get started with working examples in your language

## Typical Workflow

### 1. Define Your Schema

Choose your language and define types:

```python
# Python example
from fraiseql import Type, Query

@Type
class User:
    id: int
    name: str
    email: str
    created_at: str
```

### 2. Compile the Schema

```bash
fraiseql-cli compile --input schema.json --output schema.compiled.json
```

### 3. Run the Server

```bash
fraiseql-server --schema schema.compiled.json --database postgres://...
```

### 4. Execute GraphQL Queries

Your schema automatically handles GraphQL queries against the database.

## Feature Coverage

All 15 SDKs implement 30 core features with 100% parity:

**Type System (6 features)**
- Object types, enumerations, interfaces, unions, input types, scalar types

**Operations (7 features)**
- Queries, mutations, subscriptions, parameters, auto-parameters, pagination, filtering

**Field Metadata (4 features)**
- Descriptions, deprecation, access control, scope requirements

**Analytics (5 features)**
- Fact tables, measures, dimensions, denormalized columns, aggregations

**Security (3 features)**
- JWT scope validation, field-level authorization, role-based access

**Observers (5 features)**
- Event observers, webhooks, notifications, retry logic, audit trails

## Getting Help

- **[Choose your language](/sdk/)** from the links above
- **[Core Concepts](/concepts/how-it-works)** - Understand FraiseQL architecture
- **[Troubleshooting](/troubleshooting)** - Common issues and solutions
- **[Examples](/examples)** - Real-world example applications

## See Also

- [How FraiseQL Works](/concepts/how-it-works) - Compilation and runtime
- [Schema Definition](/concepts/schema) - Schema concepts and patterns
- [Type System](/concepts/type-system) - Type definitions and mappings
- [Deployment](/deployment) - Deploy your compiled schema
`3
`3