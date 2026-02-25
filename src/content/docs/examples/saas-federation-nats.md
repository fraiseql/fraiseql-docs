---
title: Multi-Tenant SaaS with Federation & NATS
description: Complete real-world example combining federation, NATS events, and custom resolvers
---

A complete multi-tenant SaaS application combining federation, NATS messaging, and custom resolvers for a production-ready system.

## Architecture Overview

```d2
direction: down

clients: {
  shape: frame
  label: "👥 Tenants"

  tenant_a: "Tenant A\n(Acme Corp)"
  tenant_b: "Tenant B\n(TechCo)"
}

api_layer: {
  shape: frame
  label: "🔐 API Gateway"

  router: "Tenant Router"
  auth: "Auth & RBAC"
}

tenant_dbs: {
  shape: frame
  label: "🗄️ Tenant Databases"

  db_a: "PostgreSQL\n(Tenant A)"
  db_b: "PostgreSQL\n(Tenant B)"
}

shared_services: {
  shape: frame
  label: "🔗 Shared Services"

  master: "Master DB"
  analytics: "Analytics DB"
}

messaging: {
  shape: frame
  label: "📡 NATS"

  events: "Event Streams"
  observers: "Observers"
}

clients.tenant_a -> api_layer.router
clients.tenant_b -> api_layer.router

api_layer.router -> api_layer.auth
api_layer.auth -> tenant_dbs.db_a
api_layer.auth -> tenant_dbs.db_b

tenant_dbs.db_a -> shared_services.analytics: "Publish events"
tenant_dbs.db_b -> shared_services.analytics

messaging.observers -> tenant_dbs.db_a: "React to events"
messaging.observers -> tenant_dbs.db_b

shared_services.master <- api_layer.auth: "Validate tenant"
```

## Configuration

### fraiseql.toml

```toml
[multi_tenancy]
enabled = true
strategy = "database_per_tenant"
auth_header = "X-Tenant-ID"

# Tenant database pool
[databases.tenant]
type = "postgresql"
pool_max = 20

# Shared services
[databases.shared]
type = "postgresql"
url = "${SHARED_DB_URL}"
pool_max = 10

[nats]
enabled = true
servers = ["nats://localhost:4222"]
jetstream_enabled = true

[nats.publishing]
auto_publish = true
batch_size = 50
batch_timeout = 1000
```

### schema.py

```python
import fraiseql
from fraiseql import TenantContext, ID
from datetime import datetime
from decimal import Decimal

@fraiseql.type(database="tenant")
class Organization:
    """Tenant-specific organization."""
    id: ID
    tenant_id: ID
    name: str
    created_at: datetime
    subscription_tier: str

    @fraiseql.field_resolver
    async def member_count(self, ctx: TenantContext) -> int:
        """Count organization members."""
        result = await ctx.db.query_one(
            "SELECT COUNT(*) as count FROM tb_member WHERE org_id = $1",
            [self.id]
        )
        return result.get("count", 0)

@fraiseql.type(database="tenant")
class Project:
    """Tenant-specific project."""
    id: ID
    tenant_id: ID
    org_id: ID
    name: str
    created_at: datetime

    # Multi-database federation
    organization: Organization = fraiseql.federated(
        database="tenant",
        lookup="org_id"
    )

    @fraiseql.field_resolver
    async def task_count(self, ctx: TenantContext) -> int:
        """Count tasks in project."""
        result = await ctx.db.query_one(
            "SELECT COUNT(*) FROM tb_task WHERE project_id = $1",
            [self.id]
        )
        return result["count"]

# Root queries
@fraiseql.query
async def organizations(ctx: TenantContext, limit: int = 50) -> list[Organization]:
    """
    Get all organizations for tenant.
    Automatically filtered by tenant_id from context.
    """
    orgs = await ctx.db.query(
        """SELECT * FROM tb_organization
           WHERE tenant_id = $1
           ORDER BY created_at DESC
           LIMIT $2""",
        [ctx.tenant_id, limit]
    )
    return [Organization(**org) for org in orgs]

@fraiseql.query
async def projects_by_org(
    ctx: TenantContext,
    org_id: ID
) -> list[Project]:
    """Get projects for organization (with RLS)."""
    # Row-level security: verify user can access this org
    org = await ctx.db.query_one(
        "SELECT * FROM tb_organization WHERE id = $1 AND tenant_id = $2",
        [org_id, ctx.tenant_id]
    )
    if not org:
        raise Exception("Organization not found")

    projects = await ctx.db.query(
        "SELECT * FROM tb_project WHERE org_id = $1",
        [org_id]
    )
    return [Project(**p) for p in projects]

# Mutations
@fraiseql.mutation(operation="CREATE")
async def create_project(
    ctx: TenantContext,
    org_id: ID,
    name: str
) -> Project:
    """
    Create project and emit event.
    """
    # Verify ownership
    org = await ctx.db.query_one(
        "SELECT * FROM tb_organization WHERE id = $1 AND tenant_id = $2",
        [org_id, ctx.tenant_id]
    )
    if not org:
        raise Exception("Organization not found")

    # Create project
    project = await ctx.db.insert("tb_project", {
        "tenant_id": ctx.tenant_id,
        "org_id": org_id,
        "name": name,
        "created_at": datetime.now()
    })

    return Project(**project)

# Lifecycle hooks
@fraiseql.type(database="tenant")
class Project:
    @Hook.AFTER_CREATE
    async def on_project_created(self, ctx: TenantContext):
        """Initialize project data after creation."""
        # Create default board
        await ctx.db.insert("tb_board", {
            "project_id": self.id,
            "name": "Backlog"
        })

        # Publish event
        await fraiseql.nats.publish(
            subject=f"tenant.{ctx.tenant_id}.projects.created",
            data={
                "project_id": str(self.id),
                "org_id": str(self.org_id),
                "timestamp": datetime.now().isoformat()
            }
        )

# Observers for event-driven features
@fraiseql.observer(
    entity="Project",
    event="CREATE",
    database="tenant"
)
async def on_project_created_event(project: Project, ctx: TenantContext):
    """
    React to project creation:
    - Notify shared analytics
    - Update usage metrics
    """
    await fraiseql.nats.publish(
        subject=f"analytics.project_created",
        data={
            "tenant_id": str(ctx.tenant_id),
            "project_id": str(project.id),
            "timestamp": datetime.now().isoformat()
        }
    )

@fraiseql.nats.subscribe(
    subject="analytics.>",
    consumer_group="analytics_sync"
)
async def sync_analytics(message):
    """Sync analytics events to shared database."""
    data = message.data
    await ctx.db.insert(
        "tb_analytics_event",
        {
            "event_type": data["event_type"],
            "tenant_id": data["tenant_id"],
            "data": json.dumps(data),
            "recorded_at": datetime.now()
        }
    )
    await message.ack()
```

## Deployment Considerations

### Database Isolation

```sql
-- For each tenant, create isolated database
CREATE DATABASE tenant_acme_corp;
CREATE USER tenant_acme_corp WITH PASSWORD '...';
GRANT CONNECT ON DATABASE tenant_acme_corp TO tenant_acme_corp;

-- Enable RLS for extra safety
ALTER TABLE tb_organization ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_project ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tb_organization
USING (tenant_id = current_setting('app.tenant_id')::uuid);
```

### Performance Optimization

```python
# Cache tenant configurations
@fraiseql.query(cache_ttl=3600)  # Cache for 1 hour
async def tenant_config(ctx: TenantContext) -> dict:
    """Frequently accessed configuration."""
    config = await ctx.db.query_one(
        "SELECT * FROM tb_tenant_config WHERE tenant_id = $1",
        [ctx.tenant_id]
    )
    return config

# Batch operations for multi-tenant deployments
@fraiseql.mutation(operation="CREATE")
async def bulk_create_projects(
    ctx: TenantContext,
    org_id: ID,
    names: list[str]
) -> list[Project]:
    """Batch create projects efficiently."""
    # Use single batch insert
    projects = await ctx.db.insert_batch(
        "tb_project",
        [
            {
                "tenant_id": ctx.tenant_id,
                "org_id": org_id,
                "name": name,
                "created_at": datetime.now()
            }
            for name in names
        ]
    )
    return [Project(**p) for p in projects]
```

## Testing

```python
import pytest
from fraiseql.testing import FraiseQLTestClient

@pytest.fixture
async def client():
    return await FraiseQLTestClient.create(
        config="fraiseql.test.toml"
    )

@pytest.mark.asyncio
async def test_tenant_isolation(client):
    """Verify tenants cannot access each other's data."""
    # Create as tenant A
    client.set_tenant("tenant-a")
    org_a = await client.execute("""
        mutation {
            createOrganization(name: "Org A") { id }
        }
    """)

    # Try to access as tenant B
    client.set_tenant("tenant-b")
    result = await client.execute(f"""
        query {{
            organization(id: "{org_a['data']['createOrganization']['id']}") {{
                name
            }}
        }}
    """)

    # Should return null or error
    assert result["data"]["organization"] is None

@pytest.mark.asyncio
async def test_nats_event_publishing(client):
    """Verify events are published on mutations."""
    client.set_tenant("tenant-a")

    project = await client.execute("""
        mutation {
            createProject(orgId: "org-1", name: "Test") { id }
        }
    """)

    # Give NATS time to process
    await asyncio.sleep(0.5)

    # Verify event was published
    events = await get_published_events("analytics.project_created")
    assert len(events) >= 1
```

## Monitoring

```python
# Track per-tenant metrics
fraiseql_tenant_requests_total{tenant_id="acme_corp", endpoint="/graphql"}
fraiseql_tenant_latency_seconds{tenant_id="acme_corp", operation="query"}
fraiseql_tenant_errors_total{tenant_id="acme_corp", error_type="validation"}

# Monitor event processing
fraiseql_nats_events_processed{tenant_id="acme_corp", event_type="project_created"}
fraiseql_nats_consumer_lag{consumer="analytics_sync"}
```

## Production Checklist

- [ ] Database per tenant created and configured
- [ ] RLS policies enabled on all tables
- [ ] NATS cluster deployed and replicated
- [ ] Consumer groups configured for reliability
- [ ] Monitoring and alerting configured
- [ ] Backup strategy for each tenant DB
- [ ] Failover procedures documented
- [ ] Load testing completed
- [ ] Security audit passed
- [ ] Documentation updated

## Next Steps

- [Advanced Federation](/guides/advanced-federation) — Deep dive on federation patterns
- [Advanced NATS](/guides/advanced-nats) — Event streaming advanced patterns
- [Custom Resolvers](/guides/custom-resolvers) — Business logic integration
