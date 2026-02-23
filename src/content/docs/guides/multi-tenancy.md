---
title: Multi-Tenancy Architecture
description: Implement multi-tenant SaaS applications with FraiseQL using row-level security and data isolation
---

# Multi-Tenancy Architecture

This guide covers implementing secure multi-tenant SaaS applications with FraiseQL, including data isolation strategies, row-level security, and best practices for all supported databases.

## Multi-Tenancy Models

FraiseQL supports three primary multi-tenancy models:

| Model | Pros | Cons | Best For |
|-------|------|------|----------|
| **Database-per-Tenant** | Complete isolation, simple backups | Operational complexity, high cost | Enterprise, regulated industries |
| **Schema-per-Tenant** | Good isolation, shared infrastructure | Complex scaling, database limits | Mid-market SaaS |
| **Row-Level Isolation** | Most cost-effective, best scalability | Complex logic, performance tuning needed | High-volume SaaS |

## 1. Database-per-Tenant Model

In this model, each tenant has a dedicated PostgreSQL database.

### Architecture

```
fraiseql-api
├── tenant-a-db.fraiseql.dev
├── tenant-b-db.fraiseql.dev
└── tenant-c-db.fraiseql.dev
```

### Implementation

```python
from fraiseql import Client

class TenantRouter:
    def __init__(self, master_config):
        self.master_config = master_config
        self.clients = {}

    def get_client(self, tenant_id: str) -> Client:
        if tenant_id not in self.clients:
            # Resolve tenant to database URL
            db_url = self.resolve_tenant_db(tenant_id)
            self.clients[tenant_id] = Client(
                url=f"{db_url}/graphql",
                auth=self.get_tenant_auth(tenant_id)
            )
        return self.clients[tenant_id]

    def resolve_tenant_db(self, tenant_id: str) -> str:
        # Query metadata service
        tenant_config = self.master_config.get_tenant(tenant_id)
        return tenant_config['database_url']

    async def query(self, tenant_id: str, query: str):
        client = self.get_client(tenant_id)
        return await client.query(query)

# Usage
router = TenantRouter(master_config)
result = await router.query("tenant-123", "query { users { id name } }")
```

### Provisioning New Tenants

```python
async def provision_tenant(tenant_config):
    # 1. Create new database
    db_name = f"fraiseql_tenant_{tenant_config['id']}"
    await create_database(db_name)

    # 2. Run migrations
    await run_migrations(db_name)

    # 3. Register in metadata service
    await metadata_service.register_tenant({
        'id': tenant_config['id'],
        'database_url': f"postgres://user:pass@host/{db_name}",
        'created_at': datetime.utcnow()
    })

    # 4. Initialize schema
    client = Client(url=f"postgres://host/{db_name}/graphql")
    await client.mutate("""
        mutation InitializeTenant {
            createTenantMetadata(input: {
                name: "{name}"
                plan: "{plan}"
            }) {
                id
                createdAt
            }
        }
    """.format(
        name=tenant_config['name'],
        plan=tenant_config['plan']
    ))
```

## 2. Schema-per-Tenant Model

Multiple tenants share one PostgreSQL database but have separate schemas.

### Architecture

```
shared-database
├── tenant_a (schema)
├── tenant_b (schema)
└── tenant_c (schema)
```

### PostgreSQL Implementation

```sql
-- Create schema for tenant
CREATE SCHEMA tenant_123;

-- Create table in tenant schema
CREATE TABLE tenant_123.users (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    tenant_id UUID NOT NULL
);

-- Grant permissions to tenant role
CREATE ROLE tenant_123_user LOGIN PASSWORD 'secure_password';
GRANT USAGE ON SCHEMA tenant_123 TO tenant_123_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA tenant_123 TO tenant_123_user;
```

### FraiseQL Schema-per-Tenant

```python
from fraiseql import Client

class SchemaPerTenantRouter:
    def __init__(self, database_url):
        self.database_url = database_url
        self.clients = {}

    def get_client(self, tenant_id: str) -> Client:
        if tenant_id not in self.clients:
            # Connect with tenant-specific role
            self.clients[tenant_id] = Client(
                url=self.database_url,
                auth={
                    'user': f'tenant_{tenant_id}_user',
                    'password': self.get_tenant_password(tenant_id),
                    'search_path': f'tenant_{tenant_id}'  # Set schema
                }
            )
        return self.clients[tenant_id]

    async def query(self, tenant_id: str, query: str):
        client = self.get_client(tenant_id)
        # Query automatically scoped to tenant schema
        return await client.query(query)

# Usage
router = SchemaPerTenantRouter("postgresql://host/fraiseql_db")
result = await router.query("tenant-123", "query { users { id name } }")
```

### Provisioning New Schema

```python
async def provision_tenant_schema(tenant_id: str):
    # Connect as admin
    admin_client = Client(
        url=database_url,
        auth=admin_auth
    )

    # Create schema
    await admin_client.mutate(f"""
        mutation {{
            executeRawSQL(sql: "CREATE SCHEMA tenant_{tenant_id}")
        }}
    """)

    # Create tables
    await admin_client.mutate(f"""
        mutation {{
            executeRawSQL(sql: "CREATE TABLE tenant_{tenant_id}.users (...)")
        }}
    """)

    # Create role
    await admin_client.mutate(f"""
        mutation {{
            executeRawSQL(sql: "CREATE ROLE tenant_{tenant_id}_user")
        }}
    """)
```

## 3. Row-Level Security Model (Most Cost-Effective)

All tenants share one database and schema. Data isolation is enforced at the row level using policies.

### PostgreSQL Row-Level Security

```sql
-- Create tenant identifier column
ALTER TABLE users ADD COLUMN tenant_id UUID NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000';

-- Create RLS policy
CREATE POLICY users_isolation ON users
    USING (tenant_id = current_setting('app.tenant_id')::uuid)
    WITH CHECK (tenant_id = current_setting('app.tenant_id')::uuid);

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Set tenant context before query
SET app.tenant_id = 'tenant-123-uuid';
SELECT * FROM users;  -- Only returns rows for tenant-123
```

### FraiseQL Row-Level Security Implementation

```python
from fraiseql import Client
from functools import wraps

class RowLevelSecurityRouter:
    def __init__(self, database_url):
        self.database_url = database_url
        self.client = Client(url=database_url)

    async def set_tenant_context(self, tenant_id: str):
        """Set tenant context for session"""
        await self.client.execute_raw(
            f"SET app.tenant_id = '{tenant_id}'::uuid"
        )

    async def query(self, tenant_id: str, query: str):
        """Execute query with tenant context"""
        await self.set_tenant_context(tenant_id)
        return await self.client.query(query)

    async def mutate(self, tenant_id: str, mutation: str, variables=None):
        """Execute mutation with tenant context"""
        await self.set_tenant_context(tenant_id)
        return await self.client.mutate(mutation, variables)

# Usage
router = RowLevelSecurityRouter("postgresql://host/fraiseql_db")
users = await router.query("tenant-123", "query { users { id name } }")
```

### MySQL Row-Level Security

```sql
-- MySQL doesn't have native RLS, use views
CREATE VIEW tenant_123_users AS
SELECT * FROM users WHERE tenant_id = 'tenant-123';

-- Or use stored procedures with tenant context
DELIMITER $$
CREATE PROCEDURE get_tenant_users(IN p_tenant_id VARCHAR(36))
BEGIN
    SELECT * FROM users WHERE tenant_id = p_tenant_id;
END$$
DELIMITER ;
```

### SQLite Row-Level Security

```sql
-- SQLite doesn't support RLS, implement in application
-- Create TRIGGER to prevent cross-tenant access
CREATE TRIGGER prevent_cross_tenant_insert
BEFORE INSERT ON users
FOR EACH ROW
WHEN NEW.tenant_id != (SELECT current_tenant_id FROM app_context)
BEGIN
    SELECT RAISE(ABORT, 'Cross-tenant access denied');
END;
```

### SQL Server Row-Level Security

```sql
-- Create security predicate
CREATE FUNCTION fn_tenantAccessPredicate(@tenant_id NVARCHAR(MAX))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN SELECT 1 as fn_result
WHERE @tenant_id = CAST(SESSION_CONTEXT(N'tenant_id') AS NVARCHAR(MAX));

-- Apply to table
CREATE SECURITY POLICY tenant_isolation
    ADD FILTER PREDICATE fn_tenantAccessPredicate(tenant_id)
    ON dbo.users;

-- Set tenant context
EXEC sp_set_session_context @key = N'tenant_id', @value = N'tenant-123';
```

## Complete Multi-Tenant SaaS Example

### Schema Definition

```python
from fraiseql import FraiseQL, Type, Query, Mutation

@FraiseQL.type
class Organization:
    id: str
    name: str
    tenant_id: str
    created_at: str

@FraiseQL.type
class User:
    id: str
    name: str
    email: str
    organization_id: str
    tenant_id: str
    created_at: str

@FraiseQL.type
class Post:
    id: str
    title: str
    content: str
    user_id: str
    organization_id: str
    tenant_id: str
    created_at: str

# Queries automatically filtered by RLS
@FraiseQL.query(sql_source="v_users")
def users(limit: int = 20) -> list[User]:
    """Get all users in current tenant"""
    pass

@FraiseQL.query(sql_source="v_organization")
def organization() -> Organization:
    """Get current tenant's organization"""
    pass

# Mutations automatically enforce tenant_id
@FraiseQL.mutation
def create_user(
    name: str,
    email: str,
    organization_id: str
) -> User:
    """Create user in current tenant"""
    pass

@FraiseQL.mutation
def create_post(
    title: str,
    content: str
) -> Post:
    """Create post in current tenant"""
    pass
```

### Middleware to Set Tenant Context

```python
from fastapi import FastAPI, Request, HTTPException
from fraiseql import Client

app = FastAPI()

# Middleware to extract and set tenant
@app.middleware("http")
async def set_tenant_context(request: Request, call_next):
    # Extract tenant from subdomain, path, or header
    tenant_id = extract_tenant_id(request)

    if not tenant_id:
        raise HTTPException(status_code=400, detail="Missing tenant context")

    # Store in request state
    request.state.tenant_id = tenant_id

    # Set in database session
    await client.execute_raw(
        f"SET app.tenant_id = '{tenant_id}'::uuid"
    )

    response = await call_next(request)
    return response

def extract_tenant_id(request: Request) -> str:
    """Extract tenant from request"""
    # Option 1: Subdomain
    if request.url.hostname:
        subdomain = request.url.hostname.split('.')[0]
        if subdomain != 'api':
            return subdomain

    # Option 2: Authorization token
    auth_header = request.headers.get('Authorization')
    if auth_header:
        token = auth_header.replace('Bearer ', '')
        tenant_id = decode_and_get_tenant(token)
        if tenant_id:
            return tenant_id

    # Option 3: X-Tenant-ID header
    return request.headers.get('X-Tenant-ID')

@app.get("/api/organization")
async def get_organization(request: Request):
    tenant_id = request.state.tenant_id
    result = await client.query("""
        query {
            organization {
                id
                name
                createdAt
            }
        }
    """)
    return result
```

### API Routes

```python
@app.post("/api/users")
async def create_user(request: Request, data: dict):
    tenant_id = request.state.tenant_id

    result = await client.mutate("""
        mutation CreateUser($name: String!, $email: String!) {
            createUser(name: $name, email: $email) {
                id
                name
                email
            }
        }
    """, variables=data)

    return result

@app.get("/api/users")
async def list_users(request: Request, limit: int = 20):
    tenant_id = request.state.tenant_id

    result = await client.query(f"""
        query {{
            users(limit: {limit}) {{
                id
                name
                email
                createdAt
            }}
        }}
    """)

    return result
```

## Security Best Practices

### 1. Tenant Context Validation

```python
async def validate_tenant_context(tenant_id: str):
    """Verify tenant context is valid"""
    if not tenant_id or len(tenant_id) == 0:
        raise ValueError("Missing tenant context")

    # Verify tenant exists
    tenant = await metadata_service.get_tenant(tenant_id)
    if not tenant:
        raise ValueError(f"Unknown tenant: {tenant_id}")

    # Verify user has access
    if not user_has_access_to_tenant(current_user, tenant_id):
        raise PermissionError(f"Access denied to tenant: {tenant_id}")
```

### 2. Prevent Tenant ID Injection

```python
# BAD: Vulnerable to injection
async def get_users_bad(tenant_id: str):
    return await client.query(f"""
        query {{ users(tenant: {tenant_id}) {{ id }} }}
    """)

# GOOD: Use variables
async def get_users_good(tenant_id: str):
    return await client.query(
        """
        query GetUsersByTenant($tenant: ID!) {
            users(tenant: $tenant) { id }
        }
        """,
        variables={"tenant": tenant_id}
    )
```

### 3. Audit Logging

```python
from datetime import datetime

async def log_tenant_action(
    tenant_id: str,
    user_id: str,
    action: str,
    resource: str,
    result: str
):
    """Log all tenant actions for compliance"""
    await audit_log.insert({
        'tenant_id': tenant_id,
        'user_id': user_id,
        'action': action,
        'resource': resource,
        'result': result,
        'timestamp': datetime.utcnow()
    })
```

## Performance Considerations

### Connection Pooling

```python
# Database-per-tenant: Use connection pool per database
router = TenantRouter(master_config)
router.pool_size = 20  # Connections per tenant database

# Schema-per-tenant: Shared pool with tenant-specific connections
client = Client(
    url=database_url,
    pool_size=100  # Shared across all tenants
)

# Row-level security: Single connection pool
rls_router = RowLevelSecurityRouter(database_url)
rls_router.pool_size = 100
```

### Query Optimization

```python
# Add indexes for tenant_id column
CREATE INDEX idx_users_tenant_id ON users(tenant_id);

# Add indexes for common queries
CREATE INDEX idx_posts_tenant_user ON posts(tenant_id, user_id);
```

## Related Guides

- [Authentication](/guides/authentication) - Tenant-aware auth
- [RBAC/Security](/features/security) - Role-based access control
- [Troubleshooting](/guides/troubleshooting) - Common multi-tenant issues
- [Performance](/guides/performance) - Query optimization