# FraiseQL Minimal Starter

The fastest way to get a GraphQL API running with FraiseQL. No Docker, no cloud account, no configuration ceremony — just a SQLite database and two commands.

## Prerequisites

- [FraiseQL](https://fraiseql.dev/docs/installation) installed (`curl -fsSL https://fraiseql.dev/install.sh | sh`)
- Python 3.10 or later with [uv](https://docs.astral.sh/uv/)

## Quick Start

```bash
fraiseql compile && fraiseql run
```

That's it. Your GraphQL API is live at http://127.0.0.1:8080/graphql.

## Try Your First Query

Open the GraphQL playground at http://127.0.0.1:8080/graphql and run:

```graphql
{
  users {
    id
    name
    email
  }
}
```

You should see the three seed users (Alice, Bob, and Carol) returned immediately.

## What's in This Starter

```
minimal/
├── fraiseql.toml          # Project configuration
├── schema.py              # GraphQL type definitions
├── .env.example           # Environment variable reference
└── db/
    ├── 01_tables/
    │   └── tb_user.sql    # User table
    ├── 02_views/
    │   └── v_user.sql     # GraphQL-facing view
    └── 03_seed/
        └── seed.sql       # Three example users
```

FraiseQL follows a strict layered convention:

- **Tables** (`tb_*`) hold your data with integer primary keys and UUID surrogate keys.
- **Views** (`v_*`) expose exactly the shape your GraphQL types consume — each row is an `id` plus a `data` JSONB column.
- **Schema** (`schema.py`) maps Python dataclasses to your views with zero glue code.

## Next Steps

- Add a mutation by creating `db/03_functions/fn_create_user.sql`
- Switch to PostgreSQL by changing `[database]` in `fraiseql.toml`
- Explore relationships by adding a `Post` type

## Full Documentation

https://fraiseql.dev/docs
