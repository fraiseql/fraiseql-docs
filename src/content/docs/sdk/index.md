---
title: Schema Authoring SDKs
description: Define GraphQL schemas in your favorite language with 6 supported SDKs
---

# Schema Authoring SDKs

FraiseQL provides **6 schema authoring SDKs** across different programming languages. Each SDK lets you define your GraphQL schema using native language constructs, which compile to optimized SQL queries at build time.

## How It Works

You write your schema in your preferred language using type definitions and decorators, then the FraiseQL CLI compiles it to JSON that the Rust runtime executes.

## Available SDKs

| Language | Type System | Package Manager | Status |
|----------|-------------|-----------------|--------|
| **Python** | Type hints | PyPI / uv | Stable |
| **TypeScript** | Native types | npm / yarn / pnpm | Stable |
| **Go** | Struct tags + builders | Go modules 1.22+ | Stable |
| **Java** | Annotations | Maven, Gradle | Stable |
| **Rust** | Traits | Cargo | Stable |
| **PHP** | Attributes | Composer | Stable |

:::note[JVM Interop]
Kotlin, Scala, Groovy, and Clojure projects can use the **Java SDK** directly via JVM interop. Annotations and builder patterns work seamlessly across JVM languages.
:::

## Quick Start by Language

### Compiled, Typed Languages

- **[Go](/sdk/go)** — Fast, concurrent, cloud-native applications
- **[Rust](/sdk/rust)** — Maximum performance and memory safety
- **[Java](/sdk/java)** — Enterprise-grade backend development (also works with Kotlin, Scala, Groovy, Clojure via JVM interop)

### Dynamically Typed Languages

- **[Python](/sdk/python)** — Primary authoring language, data science friendly
- **[TypeScript](/sdk/typescript)** — Type-safe Node.js and frontend backends
- **[PHP](/sdk/php)** — Web development with Composer, Laravel

## Key Features of All SDKs

Each SDK provides:

- **Type-Safe Schema Definition** — Use your language's native type system
- **Decorators/Attributes** — Metadata for GraphQL behavior (queries, mutations, authorization)
- **Schema Compilation** — Generate schema.json for the FraiseQL compiler
- **Builder Patterns** — Fluent APIs for complex type definitions
- **Full Feature Parity** — All SDKs support all 30 core features

## Typical Workflow

### 1. Define Your Schema

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

## See Also

- [How FraiseQL Works](/concepts/how-it-works) — Compilation and runtime
- [Schema Definition](/concepts/schema) — Schema concepts and patterns
- [Type System](/concepts/type-system) — Type definitions and mappings
- [Deployment](/deployment) — Deploy your compiled schema
