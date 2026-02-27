import fraiseql
from fraiseql.scalars import ID, DateTime


@fraiseql.type
class Feature:
    id: ID
    name: str
    enabled: bool


@fraiseql.type
class TenantUser:
    id: ID
    name: str
    email: str
    role: str  # admin | member | viewer
    created_at: str


@fraiseql.type
class Subscription:
    id: ID
    plan: str
    status: str  # active | cancelled | past_due
    current_period_end: str


@fraiseql.type
class Tenant:
    id: ID
    name: str
    slug: str
    plan: str  # free | pro | enterprise
    created_at: str
    users: list[TenantUser]
    features: list[Feature]
