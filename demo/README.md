# FraiseQL Demo API

This is the hosted demo API that powers the interactive playground at [demo.fraiseql.dev](https://demo.fraiseql.dev).

It exposes a read-only GraphQL API over a PostgreSQL blog dataset: users, posts, comments, and tags.

## Schema

- **User** — name, email, role (`reader` | `author` | `admin`), posts
- **Post** — title, content, published flag, author, comments, tags
- **Comment** — body, author
- **Tag** — name, slug

## Running Locally

**Prerequisites:** Docker and Docker Compose.

```bash
git clone https://github.com/fraiseql/fraiseql
cd fraiseql/demo

docker compose up
```

The GraphQL endpoint will be available at `http://localhost:8080/graphql`.

The database is seeded automatically on first start via the SQL files in `db/`. To reset:

```bash
docker compose down -v
docker compose up
```

## Deploying to Fly.io

```bash
fly auth login
fly launch --no-deploy          # reads fly.toml, skip initial deploy
fly secrets set DATABASE_URL="postgres://..."   # set managed Postgres URL
fly deploy
```

The app is configured with `auto_stop_machines = true` and `min_machines_running = 0`
so it scales to zero when idle and costs nothing between playground sessions.

## CORS Configuration

Allowed origins are defined in `fraiseql.toml` under `[server.cors]`:

```toml
[server.cors]
origins = [
  "https://fraiseql.dev",
  "http://localhost:4321",
  "http://localhost:8080",
]
```

To allow additional origins (e.g. a staging environment), add them to this list and redeploy.

## Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Local development stack |
| `fly.toml` | Fly.io deployment configuration |
| `fraiseql.toml` | FraiseQL server configuration |
| `schema.py` | Python type definitions consumed by FraiseQL |
| `db/01_tables/` | Table DDL (runs in filename order) |
| `db/02_views/` | Composed JSONB views (FraiseQL query targets) |
| `db/04_seed/` | Seed data for the demo dataset |
| `versions.json` | Version manifest consumed by the playground UI |
