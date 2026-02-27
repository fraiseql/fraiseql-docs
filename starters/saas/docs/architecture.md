# SaaS Starter Architecture

This document explains how the FraiseQL SaaS starter achieves hard multi-tenant isolation without any application-layer filtering logic.

## The Core Guarantee

Every SQL query that touches tenant-scoped data runs through PostgreSQL Row-Level Security. The application cannot accidentally bypass isolation by omitting a WHERE clause or passing the wrong tenant context — the database enforces it unconditionally.

## Data Model

```
tb_tenant
    pk_tenant  BIGINT  (identity PK)
    id         UUID    (public surrogate key)
    name       TEXT
    slug       TEXT    UNIQUE
    plan       TEXT    (free | pro | enterprise)
    created_at TIMESTAMPTZ

        |
        | 1 : N
        v

tb_tenant_user                   tb_feature                    tb_subscription
    pk_tenant_user BIGINT             pk_feature BIGINT             pk_subscription BIGINT
    id             UUID               id         UUID               id              UUID
    fk_tenant      BIGINT  ------>    fk_tenant  BIGINT  ------>    fk_tenant       BIGINT
    name           TEXT               name       TEXT               plan            TEXT
    email          TEXT               enabled    BOOLEAN            status          TEXT
    role           TEXT               ...                           current_period_end TIMESTAMPTZ
    created_at     TIMESTAMPTZ
```

`tb_tenant` holds all tenants. The three child tables each carry a `fk_tenant` foreign key and have Row-Level Security enabled.

## How Tenant Isolation Works

### Step 1 — JWT carries a tenant_id claim

Every API client authenticates with a JWT signed using `JWT_SECRET`. The token payload must include a `tenant_id` field containing the tenant's UUID:

```json
{
  "sub": "550e8400-e29b-41d4-a716-446655440001",
  "tenant_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "role": "admin",
  "exp": 1893456000
}
```

### Step 2 — Middleware sets the session variable

FraiseQL middleware runs before every GraphQL operation. It verifies the token and writes the `tenant_id` into the PostgreSQL session using `SET LOCAL`:

```python
import os
import fraiseql
import jwt  # PyJWT

JWT_SECRET = os.environ["JWT_SECRET"]


def verify_jwt(token: str) -> dict:
    return jwt.decode(token, JWT_SECRET, algorithms=["HS256"])


@fraiseql.middleware
async def tenant_middleware(request, next):
    authorization = request.headers.get("Authorization", "")
    token = authorization.removeprefix("Bearer ")
    claims = verify_jwt(token)
    tenant_id = claims["tenant_id"]
    await request.db.execute(
        "SET LOCAL app.tenant_id = $1", tenant_id
    )
    return await next(request)
```

`SET LOCAL` scopes the variable to the current transaction. When the transaction ends — whether it commits, rolls back, or the connection is returned to a pool — the variable is automatically cleared. There is no possibility of a stale tenant ID leaking to the next request.

### Step 3 — RLS policies filter every query

A helper function resolves the UUID to an integer PK (the column type used in foreign keys):

```sql
CREATE OR REPLACE FUNCTION get_current_tenant_pk()
RETURNS BIGINT
LANGUAGE sql
STABLE
AS $$
    SELECT pk_tenant
    FROM   tb_tenant
    WHERE  id = current_setting('app.tenant_id', true)::uuid
$$;
```

Each child table has a single policy attached:

```sql
ALTER TABLE tb_tenant_user ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tb_tenant_user
    USING (fk_tenant = get_current_tenant_pk());
```

PostgreSQL evaluates this predicate for every row before returning it. If `app.tenant_id` is not set (the `true` argument to `current_setting` makes it return NULL rather than raising an error), `get_current_tenant_pk()` returns NULL, and NULL = anything is NULL (false), so no rows are returned. The absence of a session variable is as safe as an explicit block.

### Step 4 — Views expose the RLS-filtered data as JSONB

Views such as `v_tenant_user` select from the RLS-protected table without any WHERE clause. The policy is already applied:

```sql
CREATE OR REPLACE VIEW v_tenant_user AS
SELECT
    u.id,
    jsonb_build_object(
        'id',         u.id::text,
        'name',       u.name,
        'email',      u.email,
        'role',       u.role,
        'created_at', u.created_at
    ) AS data
FROM tb_tenant_user u;
```

FraiseQL maps these views directly to GraphQL types. Each row in the view becomes one object in the response.

## Request Lifecycle

```
Client
  |
  | HTTP POST /graphql
  | Authorization: Bearer <jwt>
  v
FraiseQL HTTP layer
  |
  | verify_jwt(token)  →  claims = { tenant_id: "...", ... }
  | SET LOCAL app.tenant_id = '<tenant_uuid>'
  v
PostgreSQL (inside a transaction)
  |
  | RLS policy evaluated for every row in every scanned table
  | get_current_tenant_pk()  →  looks up pk_tenant from session UUID
  v
v_tenant / v_tenant_user / v_feature / v_subscription
  |
  | JSONB rows returned, filtered to authenticated tenant only
  v
FraiseQL GraphQL serializer
  |
  v
Client receives only its own data
```

## Why Use Integer PKs Internally with UUID Surrogate Keys

PostgreSQL foreign keys and join indexes work best with integers. `BIGINT GENERATED ALWAYS AS IDENTITY` provides compact, fast, sequentially scanned keys for all internal joins and foreign key constraints.

UUIDs (`gen_random_uuid()`) are exposed publicly as the `id` field in every type. This means:

- Clients never learn the internal row order.
- IDs cannot be enumerated or predicted.
- A UUID in a URL or GraphQL argument uniquely identifies a row globally, not just within a table.

The RLS policies use `fk_tenant` (the integer) for the equality check, keeping the hot path fast.

## Extending the Starter

### Adding a new tenant-scoped table

1. Create `db/01_tables/006_tb_<entity>.sql` with `fk_tenant BIGINT NOT NULL REFERENCES tb_tenant(pk_tenant) ON DELETE CASCADE`.
2. Add RLS in `db/02_rls/` following the same pattern.
3. Create a view in `db/03_views/` using `jsonb_build_object`.
4. Add the type to `schema.py`.

### Cross-tenant admin access

Super-admin operations bypass RLS by connecting as the database owner role or using `SET LOCAL app.tenant_id` to a sentinel value combined with a separate `BYPASSRLS` role. Never expose a bypass path through the public API.

### Tenant provisioning webhook

Call `fn_create_tenant` from a mutation secured by an internal service token (not a user JWT). Follow up by calling `fn_invite_user` to create the first admin user for the new tenant.

## Further Reading

- [Multi-tenancy guide](/guides/multi-tenancy) — advanced patterns, cross-tenant admin, and provisioning workflows
- [PostgreSQL RLS documentation](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
- [FraiseQL JWT middleware reference](/reference/decorators)
