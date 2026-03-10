# FraiseQL SaaS Starter

A production-ready multi-tenant SaaS backend built with FraiseQL, PostgreSQL Row-Level Security, JWT authentication, and role-based access control. One command to start.

## Quick Start

```bash
docker compose up
```

Your GraphQL API is live at http://localhost:8080/graphql.

## How It Works

### Multi-Tenant Isolation via PostgreSQL RLS

Every tenant's data is isolated at the database level using PostgreSQL Row-Level Security policies. No tenant can ever read or write another tenant's rows — not through a bug, not through a misconfigured query, not through any application-layer failure.

Each request carries a JWT containing a `tenant_id` claim. The FraiseQL Rust runtime extracts this claim and sets a PostgreSQL session variable before running any query:

```sql
SET LOCAL app.tenant_id = '<tenant_uuid>';
```

All RLS policies on `tb_tenant_user`, `tb_feature`, and `tb_subscription` use this session variable to filter rows:

```sql
USING (
    fk_tenant = (
        SELECT pk_tenant
        FROM tb_tenant
        WHERE id = current_setting('app.tenant_id', true)::uuid
    )
)
```

Because `SET LOCAL` is scoped to the current transaction, the variable is automatically cleared when the transaction ends. There is no risk of a tenant ID leaking across connections in a pool.

### Wiring tenant_id from the JWT

No application code is required. The FraiseQL schema definition uses `inject=` to tell the runtime which JWT claim maps to which SQL parameter:

```python
# FraiseQL Python handles tenant isolation automatically via JWT claims and
# PostgreSQL RLS — no middleware required.
@fraiseql.query(
    sql_source="v_tenant_user",
    inject={"tenant_id": "jwt:tenant_id"},  # "jwt:<claim_name>" syntax
)
def tenant_users(role: str | None = None) -> list[TenantUser]:
    """Return users scoped to the authenticated tenant."""
    pass
```

The Rust runtime verifies the JWT, injects `tenant_id` as a SQL parameter, and your RLS policies do the rest. Every GraphQL operation — query, mutation, or subscription — is automatically scoped to the authenticated tenant.

## What's Included

### Data Model

| Table | Purpose |
|---|---|
| `tb_tenant` | Top-level tenant records (name, slug, plan) |
| `tb_tenant_user` | Users belonging to a tenant with role assignments |
| `tb_feature` | Per-tenant feature flags |
| `tb_subscription` | Billing subscription records per tenant |

### Security

- **Row-Level Security** on `tb_tenant_user`, `tb_feature`, and `tb_subscription`
- **Role checks** enforced at the view and function layer (`admin`, `member`, `viewer`)
- **JWT verification** in middleware before any database access
- **`SET LOCAL`** scoping prevents session variable leakage across pooled connections

### GraphQL Schema

- `Tenant` — tenant record with nested users and active features
- `TenantUser` — user within a tenant with role
- `Feature` — named feature flag
- `Subscription` — billing subscription with plan and status

### Mutations

- `fn_create_tenant` — provision a new tenant
- `fn_invite_user` — add a user to an existing tenant

### Pre-Seeded Demo Tenants

Two tenants are seeded on first boot:

| Tenant | Slug | Plan | Admin Email |
|---|---|---|---|
| Acme Corp | `acme` | `pro` | `alice@acme.example` |
| BetaCo | `betaco` | `free` | `dana@betaco.example` |

Acme Corp has three users (one admin, two members) and three feature flags enabled: `analytics`, `api_access`, and `sso`.

BetaCo has two users (one admin, one member) and one feature flag: `analytics`.

## Directory Layout

```
saas/
├── docker-compose.yml          # Postgres + FraiseQL services
├── fraiseql.toml               # Project configuration
├── schema.py                   # GraphQL type definitions
├── .env.example                # Environment variable reference
├── Makefile                    # Common dev tasks
├── docs/
│   └── architecture.md         # Deep dive on the RLS + JWT design
└── db/
    ├── 01_tables/
    │   ├── 001_extensions.sql  # pgcrypto
    │   ├── 002_tb_tenant.sql
    │   ├── 003_tb_tenant_user.sql
    │   ├── 004_tb_feature.sql
    │   └── 005_tb_subscription.sql
    ├── 02_rls/
    │   └── 001_rls_policies.sql
    ├── 03_views/
    │   ├── 001_v_tenant_user.sql
    │   ├── 002_v_feature.sql
    │   ├── 003_v_subscription.sql
    │   └── 004_v_tenant.sql
    ├── 04_functions/
    │   ├── fn_create_tenant.sql
    │   └── fn_invite_user.sql
    └── 05_seed/
        └── 001_seed.sql
```

FraiseQL applies SQL files in directory and filename order. The numeric prefixes guarantee tables exist before views, views before functions, and functions before seed data.

## Next Steps

- Read the [multi-tenancy guide](/guides/multi-tenancy) for advanced patterns including cross-tenant admin roles and tenant provisioning workflows.
- Add a billing webhook handler with `fn_update_subscription`.
- Deploy to any platform that supports Docker Compose or a managed PostgreSQL service.
