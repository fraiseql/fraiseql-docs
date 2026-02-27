# FraiseQL Blog Starter

A production-shaped blog API built with FraiseQL and PostgreSQL. Covers users, posts, comments, and tags with proper relational views and mutation functions — ready to extend into a real application.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) with Compose v2

## Quick Start

```bash
docker compose up
```

PostgreSQL initialises, migrations run, seed data loads, and FraiseQL starts — all automatically. Open the GraphQL playground at:

```
http://localhost:8080/graphql
```

## Example Queries

### List published posts with tags

```graphql
{
  posts {
    id
    title
    author {
      name
    }
    tags {
      name
      slug
    }
  }
}
```

### Get a single post with comments

```graphql
{
  post(id: "00000000-0000-0000-0000-000000000001") {
    title
    content
    comments {
      body
      author {
        name
      }
    }
  }
}
```

### Create a new post

```graphql
mutation {
  createPost(
    title:    "My First Post"
    content:  "Hello, FraiseQL!"
    authorId: "00000000-0000-0000-0000-000000000002"
  ) {
    id
    title
  }
}
```

## Project Layout

```
blog/
├── docker-compose.yml         # Orchestrates Postgres + FraiseQL
├── fraiseql.toml              # FraiseQL project configuration
├── schema.py                  # GraphQL type definitions
├── Makefile                   # Developer convenience targets
├── .env.example               # Environment variable reference
└── db/
    ├── 01_tables/             # DDL — tables run first
    │   ├── 001_extensions.sql
    │   ├── 002_tb_user.sql
    │   ├── 003_tb_post.sql
    │   ├── 004_tb_comment.sql
    │   ├── 005_tb_tag.sql
    │   └── 006_tb_post_tag.sql
    ├── 02_views/              # GraphQL-facing views run second
    │   ├── 001_v_tag.sql
    │   ├── 002_v_user.sql
    │   ├── 003_v_comment.sql
    │   └── 004_v_post.sql
    ├── 03_functions/          # Mutation functions run third
    │   ├── fn_create_post.sql
    │   └── fn_create_comment.sql
    └── 04_seed/               # Seed data runs last
        └── 001_seed.sql
```

## Architecture Notes

**Tables** (`tb_*`) use `BIGINT GENERATED ALWAYS AS IDENTITY` integer primary keys for join performance and `UUID` surrogate keys for all external-facing identifiers. Foreign keys always reference the integer PK, never the UUID.

**Views** (`v_*`) each produce two columns: `id UUID` and `data JSONB`. FraiseQL reads `data` and deserialises it directly into your Python types. Nested objects and arrays are assembled here in SQL — GraphQL resolvers never touch the database.

**Functions** (`fn_*`) accept UUIDs as their public interface, resolve to integer PKs internally, and return the new row's UUID.

## Makefile Targets

| Target        | Description                              |
|---------------|------------------------------------------|
| `make up`     | Start all services in the foreground     |
| `make down`   | Stop and remove containers               |
| `make reset`  | Tear down volumes and restart fresh      |
| `make shell`  | Open a psql shell inside the db service  |
| `make seed`   | Re-run the seed file against a live db   |

## Full Documentation

https://fraiseql.dev/docs
