---
title: Security
description: Field-level authorization, scopes, and RBAC in FraiseQL
---

FraiseQL provides comprehensive security features including field-level authorization, scopes, and role-based access control (RBAC).

## Authentication

### JWT Configuration

```toml
[auth]
enabled = true
provider = "jwt"

[auth.jwt]
secret = "${JWT_SECRET}"
algorithm = "HS256"
issuer = "my-api"
audience = "my-app"
expiry = 3600
```

### Token Structure

```json
{
    "sub": "user-123",
    "email": "user@example.com",
    "roles": ["user", "admin"],
    "scope": "read:User write:Post",
    "iat": 1704067200,
    "exp": 1704070800
}
```

### Request Headers

```bash
curl -X POST http://localhost:8080/graphql \
    -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIs..." \
    -H "Content-Type: application/json" \
    -d '{"query": "{ me { email } }"}'
```

## Field-Level Authorization

### Requiring Scopes

Use `Annotated` to require scopes for fields:

```python
from typing import Annotated
import fraiseql

@fraiseql.type
class User:
    id: ID
    name: str
    email: str

    # Protected field - requires scope
    salary: Annotated[Decimal, fraiseql.field(requires_scope="hr:read_salary")]

    # Multiple required scopes (all must be present)
    ssn: Annotated[str, fraiseql.field(requires_scope="hr:read_pii admin:view")]
```

### Scope Format

```
resource:action
resource:action:field
```

Examples:
- `read:User` — Read any User field
- `read:User.email` — Read User.email specifically
- `write:Post` — Create/update Posts
- `admin:*` — All admin actions

### Checking Scopes

FraiseQL checks scopes at query resolution:

```graphql
# User has scope "read:User"
query {
    user(id: "...") {
        name   # ✓ Allowed
        email  # ✓ Allowed
        salary # ✗ Forbidden (needs hr:read_salary)
    }
}
```

Response:

```json
{
    "data": {
        "user": {
            "name": "John",
            "email": "john@example.com",
            "salary": null
        }
    },
    "errors": [
        {
            "message": "Forbidden: missing scope hr:read_salary",
            "path": ["user", "salary"]
        }
    ]
}
```

## Role-Based Access Control

### Defining Roles

```python
@fraiseql.role("admin")
class AdminRole:
    """Full system access."""
    scopes = [
        "read:*",
        "write:*",
        "delete:*",
        "admin:*"
    ]

@fraiseql.role("user")
class UserRole:
    """Standard user access."""
    scopes = [
        "read:User",
        "read:Post",
        "write:Post",
        "write:Comment"
    ]

@fraiseql.role("analyst")
class AnalystRole:
    """Read-only analytics access."""
    scopes = [
        "read:Analytics",
        "read:Report"
    ]
```

### Role Hierarchy

```python
@fraiseql.role("super_admin")
class SuperAdminRole:
    """Inherits from admin with additional privileges."""
    inherits = ["admin"]
    scopes = [
        "admin:manage_users",
        "admin:system_config"
    ]
```

### Query-Level Authorization

```python
@fraiseql.query(
    sql_source="v_user",
    requires_role="admin"
)
def all_users() -> list[User]:
    """Only admins can list all users."""
    pass

@fraiseql.query(sql_source="v_user")
def me() -> User:
    """Any authenticated user can query themselves."""
    pass
```

### Mutation Authorization

```python
@fraiseql.mutation(
    sql_source="fn_delete_user",
    operation="DELETE",
    requires_scope="admin:delete_user"
)
def delete_user(id: ID) -> bool:
    """Delete a user. Requires admin:delete_user scope."""
    pass
```

## Row-Level Security

### Owner-Based Access

```python
@fraiseql.type
class Post:
    id: ID
    title: str
    content: str
    author_id: ID

@fraiseql.query(
    sql_source="v_post",
    row_filter="author_id = {current_user_id}"
)
def my_posts() -> list[Post]:
    """User can only see their own posts."""
    pass
```

### SQL Implementation

```sql
-- Row-level security in PostgreSQL
ALTER TABLE tb_post ENABLE ROW LEVEL SECURITY;

-- Users can only see their own posts
CREATE POLICY post_owner_policy ON tb_post
    FOR ALL
    USING (fk_user = current_user_pk());

-- Function to get current user's pk
CREATE FUNCTION current_user_pk() RETURNS INTEGER AS $$
BEGIN
    RETURN current_setting('app.current_user_pk')::INTEGER;
END;
$$ LANGUAGE plpgsql;
```

### Setting Context

FraiseQL sets the user context before queries:

```sql
-- Set by FraiseQL before each request
SET LOCAL app.current_user_pk = 123;
SET LOCAL app.current_user_scopes = 'read:User write:Post';
```

## Organization/Tenant Isolation

### Multi-Tenant Pattern

```python
@fraiseql.type
class Organization:
    id: ID
    name: str

@fraiseql.type
class User:
    id: ID
    organization_id: ID
    name: str

@fraiseql.query(
    sql_source="v_user",
    row_filter="organization_id = {current_org_id}"
)
def users() -> list[User]:
    """Users filtered to current organization."""
    pass
```

### Tenant Context

```python
@fraiseql.middleware
def set_tenant_context(request, next):
    """Extract and set tenant context from JWT."""
    org_id = request.auth.claims.get("org_id")
    request.context["current_org_id"] = org_id
    return next(request)
```

## Input Validation

### Built-in Validation

```python
@fraiseql.input
class CreateUserInput:
    email: Annotated[str, fraiseql.validate(
        pattern=r"^[^@]+@[^@]+\.[^@]+$",
        message="Invalid email format"
    )]
    name: Annotated[str, fraiseql.validate(
        min_length=2,
        max_length=100
    )]
    age: Annotated[int, fraiseql.validate(
        minimum=0,
        maximum=150
    )]
```

### Custom Validation

```python
@fraiseql.validator
def validate_password(value: str) -> str:
    if len(value) < 8:
        raise ValueError("Password must be at least 8 characters")
    if not any(c.isupper() for c in value):
        raise ValueError("Password must contain uppercase letter")
    if not any(c.isdigit() for c in value):
        raise ValueError("Password must contain a digit")
    return value

@fraiseql.input
class ChangePasswordInput:
    password: Annotated[str, fraiseql.validate(custom=validate_password)]
```

## Rate Limiting

### Configuration

```toml
[rate_limit]
enabled = true
window = 60  # seconds
max_requests = 100

[rate_limit.by_operation]
createUser = 10      # 10 per minute
resetPassword = 5    # 5 per minute
```

### Per-User Limits

```toml
[rate_limit.tiers]
free = { requests = 100, window = 60 }
pro = { requests = 1000, window = 60 }
enterprise = { requests = 10000, window = 60 }
```

## Audit Logging

### Automatic Audit

```toml
[audit]
enabled = true
log_queries = true
log_mutations = true
include_variables = true
redact_fields = ["password", "ssn", "credit_card"]
```

### Audit Table

```sql
CREATE TABLE ta_audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    user_id UUID,
    operation TEXT NOT NULL,
    query_name TEXT,
    variables JSONB,
    ip_address INET,
    user_agent TEXT,
    duration_ms INTEGER,
    success BOOLEAN,
    error_message TEXT
);
```

### Custom Audit

```python
@fraiseql.after_mutation("delete_user")
async def audit_user_deletion(result, context):
    await log_audit_event(
        event_type="user_deleted",
        actor_id=context.current_user_id,
        target_id=result.id,
        metadata={"reason": context.variables.get("reason")}
    )
```

## Security Headers

### Configuration

```toml
[security.headers]
x_frame_options = "DENY"
x_content_type_options = "nosniff"
x_xss_protection = "1; mode=block"
content_security_policy = "default-src 'self'"
strict_transport_security = "max-age=31536000; includeSubDomains"
```

## Query Complexity Limits

Prevent resource exhaustion:

```toml
[graphql.security]
max_depth = 10
max_complexity = 1000
max_aliases = 5
introspection = false  # Disable in production
```

## Secrets Management

### Environment Variables

```toml
[auth.jwt]
secret = "${JWT_SECRET}"  # Never hardcode

[database]
url = "${DATABASE_URL}"
```

### Secret Rotation

```python
@fraiseql.config
def get_jwt_secret():
    """Fetch secret from vault."""
    return vault_client.get_secret("jwt-secret")
```

## Security Checklist

### Authentication
- [ ] JWT secrets are 256+ bits
- [ ] Tokens expire appropriately
- [ ] Refresh token rotation enabled
- [ ] Failed login rate limiting

### Authorization
- [ ] All mutations require authentication
- [ ] Sensitive fields protected by scopes
- [ ] Row-level security where needed
- [ ] Admin actions require admin role

### Input
- [ ] All inputs validated
- [ ] SQL injection impossible (parameterized)
- [ ] File upload restrictions
- [ ] Request size limits

### Output
- [ ] Sensitive fields never leaked
- [ ] Error messages don't expose internals
- [ ] Introspection disabled in production

### Infrastructure
- [ ] TLS everywhere
- [ ] Security headers set
- [ ] CORS properly configured
- [ ] Rate limiting enabled

## Advanced RBAC Patterns

### Dynamic Role Assignment

```python
from fraiseql import middleware

@middleware
def assign_role_from_token(request, next):
    """Dynamically assign role based on claims."""
    token_claims = decode_token(request.headers.get("Authorization"))

    # Map custom claims to roles
    organization_tier = token_claims.get("org_tier")
    roles = ["user"]

    if organization_tier == "pro":
        roles.append("pro_user")
    if organization_tier == "enterprise":
        roles.append("enterprise_user")

    if token_claims.get("is_admin"):
        roles.append("admin")

    request.context["user_roles"] = roles
    return next(request)

@fraiseql.query(requires_role=["pro_user", "enterprise_user", "admin"])
def premium_analytics() -> Analytics:
    """Only premium tier users can access."""
    pass
```

### Conditional Field Authorization

```python
@fraiseql.type
class User:
    id: ID
    name: str
    email: str

    # Authorization logic in resolver
    @fraiseql.field
    async def email(self, context) -> str:
        """Email visible to self, admins, and HR."""
        user_id = context.current_user_id
        user_roles = context.user_roles

        if self.id == user_id:  # Can see own email
            return self.email

        if "admin" in user_roles:  # Admins can see all
            return self.email

        if "hr" in user_roles:  # HR staff can see all
            return self.email

        # Return masked email for others
        return f"{self.id}@hidden.example.com"

    @fraiseql.field
    async def salary(self, context) -> Decimal:
        """Salary only for self and HR."""
        user_id = context.current_user_id
        user_roles = context.user_roles

        if self.id == user_id or "hr" in user_roles:
            return self.salary

        raise PermissionError("Not authorized to view salary")
```

### Three-Tier RBAC System

                        ─      ─

```python
# Define roles with inheritance
@fraiseql.role("guest")
class GuestRole:
    """Unauthenticated user."""
    scopes = ["read:public"]

@fraiseql.role("user")
class UserRole:
    """Authenticated standard user."""
    inherits = ["guest"]
    scopes = [
        "read:user_profile",
        "write:user_profile",
        "read:posts",
        "write:posts",
        "read:comments",
        "write:comments"
    ]

@fraiseql.role("moderator")
class ModeratorRole:
    """User with moderation privileges."""
    inherits = ["user"]
    scopes = [
        "read:reports",
        "write:reports",
        "write:delete_posts",
        "write:delete_comments",
        "write:ban_user"
    ]

@fraiseql.role("admin")
class AdminRole:
    """Full system access."""
    inherits = ["moderator"]
    scopes = [
        "read:*",
        "write:*",
        "delete:*",
        "admin:user_management",
        "admin:system_settings",
        "admin:audit_logs"
    ]

# Use roles in queries
@fraiseql.type
class Post:
    id: ID
    title: str
    content: str
    author_id: ID
    deleted_at: Optional[str]

@fraiseql.query(sql_source="v_posts")
def posts(limit: int = 20) -> list[Post]:
    """Any authenticated user can see non-deleted posts."""
    pass

@fraiseql.query(
    sql_source="v_posts_including_deleted",
    requires_role=["moderator"]
)
def all_posts(limit: int = 20) -> list[Post]:
    """Moderators and admins can see all posts including deleted."""
    pass

@fraiseql.mutation(
    requires_role="admin"
)
def update_system_settings(setting: str, value: str) -> bool:
    """Only admins can change system settings."""
    pass
```

## Advanced Field Authorization

### Scope Inheritance

```python
# Scope patterns: resource:action:field
# resource:action - applies to all fields of that resource
# resource:action:field - applies to specific field

@fraiseql.type
class User:
    # read:User includes all user fields
    # read:User.email includes only email field
    id: ID
    name: str
    email: Annotated[str, fraiseql.field(requires_scope="read:User.email")]
    phone: Annotated[str, fraiseql.field(requires_scope="read:User.phone")]
    ssn: Annotated[str, fraiseql.field(requires_scope="read:User.ssn")]
```

### Wildcard Scopes

```python
# In token scopes:
# admin:* - All admin actions
# read:* - All read actions
# *:* - All actions

@fraiseql.type
class SystemLog:
    id: ID
    message: str
    # Requires admin:logs or admin:* or *:*
    details: Annotated[dict, fraiseql.field(requires_scope="admin:logs")]
```

## Token Validation Strategies

### JWT Validation

```python
from datetime import datetime
import jwt

async def validate_jwt_token(token: str) -> dict:
    """Validate JWT token with security checks."""
    try:
        # Verify signature and expiration
        payload = jwt.decode(
            token,
            key=JWT_SECRET,
            algorithms=["HS256"],
            audience=JWT_AUDIENCE,
            issuer=JWT_ISSUER
        )

        # Verify token hasn't been revoked
        if await is_token_revoked(payload["jti"]):
            raise ValueError("Token has been revoked")

        # Check claim requirements
        if "sub" not in payload or "scopes" not in payload:
            raise ValueError("Missing required claims")

        return payload

    except jwt.ExpiredSignatureError:
        raise ValueError("Token has expired")
    except jwt.InvalidSignatureError:
        raise ValueError("Invalid token signature")
    except jwt.InvalidTokenError as e:
        raise ValueError(f"Invalid token: {e}")

@middleware
async def jwt_auth_middleware(request, next):
    """Extract and validate JWT from Authorization header."""
    auth_header = request.headers.get("Authorization", "")

    if not auth_header.startswith("Bearer "):
        raise UnauthorizedError("Missing or invalid Authorization header")

    token = auth_header.replace("Bearer ", "")

    try:
        payload = await validate_jwt_token(token)
        request.context["user_id"] = payload["sub"]
        request.context["user_scopes"] = payload.get("scopes", []).split()
        request.context["user_roles"] = payload.get("roles", [])
    except ValueError as e:
        raise UnauthorizedError(str(e))

    return next(request)
```

### Token Revocation (Blacklist)

```python
from redis import Redis

redis_client = Redis()

async def revoke_token(jti: str, exp: int):
    """Add token to revocation list."""
    ttl = max(0, exp - int(datetime.utcnow().timestamp()))
    redis_client.setex(f"revoked_token:{jti}", ttl, "true")

async def is_token_revoked(jti: str) -> bool:
    """Check if token has been revoked."""
    return redis_client.exists(f"revoked_token:{jti}") > 0

@fraiseql.mutation
async def logout(context) -> bool:
    """Log out user by revoking token."""
    # Extract JTI from current token
    jti = context.token_claims.get("jti")
    exp = context.token_claims.get("exp")

    if not jti:
        raise ValueError("Token doesn't have JTI claim")

    await revoke_token(jti, exp)
    return True
```

## OAuth2 & OIDC Integration

### OAuth2 Bearer Token Validation

```python
from aiohttp import ClientSession

class OAuth2Validator:
    def __init__(self, introspection_endpoint: str):
        self.introspection_endpoint = introspection_endpoint

    async def validate_token(self, token: str) -> dict:
        """Validate token via OAuth2 introspection endpoint."""
        async with ClientSession() as session:
            response = await session.post(
                self.introspection_endpoint,
                data={
                    "token": token,
                    "client_id": OAUTH2_CLIENT_ID,
                    "client_secret": OAUTH2_CLIENT_SECRET
                }
            )

            introspection_result = await response.json()

            if not introspection_result.get("active"):
                raise UnauthorizedError("Token is inactive")

            return introspection_result

@middleware
async def oauth2_auth_middleware(request, next):
    """OAuth2 token validation middleware."""
    auth_header = request.headers.get("Authorization", "")

    if not auth_header.startswith("Bearer "):
        raise UnauthorizedError("Missing Bearer token")

    token = auth_header.replace("Bearer ", "")
    validator = OAuth2Validator(OAUTH2_INTROSPECTION_ENDPOINT)

    try:
        token_info = await validator.validate_token(token)
        request.context["user_id"] = token_info["sub"]
        request.context["user_scopes"] = token_info.get("scope", "").split()
    except Exception as e:
        raise UnauthorizedError(f"Token validation failed: {e}")

    return next(request)
```

### OpenID Connect (OIDC)

```python
from authlib.integrations.starlette_client import OAuth

oauth = OAuth()

oauth.register(
    name='oidc_provider',
    client_id=OIDC_CLIENT_ID,
    client_secret=OIDC_CLIENT_SECRET,
    server_metadata_url=OIDC_DISCOVERY_URL,
    client_kwargs={'scope': 'openid profile email'}
)

@middleware
async def oidc_auth_middleware(request, next):
    """OIDC ID token validation."""
    auth_header = request.headers.get("Authorization", "")

    if not auth_header.startswith("Bearer "):
        raise UnauthorizedError("Missing Bearer token")

    id_token = auth_header.replace("Bearer ", "")

    try:
        # Validate and decode ID token
        claims = await oauth.oidc_provider.parse_id_token(
            request,
            id_token
        )

        request.context["user_id"] = claims["sub"]
        request.context["user_email"] = claims.get("email")
        request.context["user_name"] = claims.get("name")

    except Exception as e:
        raise UnauthorizedError(f"Invalid ID token: {e}")

    return next(request)
```

## Session Management

### Session-Based Auth

```python
from datetime import datetime, timedelta

class SessionManager:
    async def create_session(
        self,
        user_id: str,
        ip_address: str,
        user_agent: str
    ) -> str:
        """Create new session for user."""
        session_id = generate_secure_token()
        expires_at = datetime.utcnow() + timedelta(days=7)

        await session_store.set(
            f"session:{session_id}",
            {
                "user_id": user_id,
                "ip_address": ip_address,
                "user_agent": user_agent,
                "created_at": datetime.utcnow().isoformat(),
                "expires_at": expires_at.isoformat()
            },
            ttl=7 * 24 * 3600  # 7 days
        )

        return session_id

    async def validate_session(self, session_id: str, ip_address: str):
        """Validate session and IP address match."""
        session = await session_store.get(f"session:{session_id}")

        if not session:
            raise UnauthorizedError("Invalid session")

        if session["ip_address"] != ip_address:
            # IP changed - potential security issue
            await session_store.delete(f"session:{session_id}")
            raise UnauthorizedError("Session IP mismatch")

        return session["user_id"]

@middleware
async def session_auth_middleware(request, next):
    """Session-based authentication."""
    session_id = request.cookies.get("session_id")

    if not session_id:
        raise UnauthorizedError("Missing session")

    ip_address = request.client.host
    user_id = await session_manager.validate_session(session_id, ip_address)

    request.context["user_id"] = user_id
    return next(request)
```

## CORS Configuration

### CORS for GraphQL APIs

```toml
[security.cors]
enabled = true
allowed_origins = [
    "https://app.example.com",
    "https://admin.example.com"
]
allowed_methods = ["GET", "POST", "OPTIONS"]
allowed_headers = ["Content-Type", "Authorization"]
allow_credentials = true
max_age = 3600

# Never use wildcard in production
# allowed_origins = ["*"]  # DANGEROUS!
```

### Python Implementation

```python
from starlette.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://app.example.com",
        "https://admin.example.com"
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Authorization"],
    max_age=3600
)
```

## Security Checklist (Expanded)

### Authentication
- [ ] JWT secrets are 256+ bits (use `openssl rand -hex 32`)
- [ ] Tokens expire appropriately (30 min - 1 hour)
- [ ] Refresh token rotation enabled
- [ ] Failed login rate limiting (5 attempts / 15 min)
- [ ] Session timeout configured
- [ ] Password hashing uses bcrypt/argon2
- [ ] MFA enabled for admin accounts

### Authorization
- [ ] All mutations require authentication
- [ ] Sensitive fields protected by scopes
- [ ] Row-level security where needed
- [ ] Admin actions require admin role
- [ ] Scope inheritance properly configured
- [ ] No default "grant all" permissions

### Token Security
- [ ] JWT signature verified
- [ ] Token claims validated
- [ ] Expired tokens rejected
- [ ] Token revocation implemented
- [ ] Token JTI claim present
- [ ] Token issuer/audience verified

### Input Security
- [ ] All inputs validated on server
- [ ] Query complexity limits enforced
- [ ] SQL injection prevented (parameterized)
- [ ] File upload restrictions in place
- [ ] Request size limits configured
- [ ] Rate limiting per user/IP

### Secrets Management
- [ ] Secrets in environment variables
- [ ] Secrets rotated regularly
- [ ] No secrets in logs
- [ ] No secrets in version control
- [ ] Vault used for secret storage
- [ ] Audit logging of secret access

## Next Steps

- [Authentication](/guides/authentication) — Auth implementation guide
- [Deployment](/guides/deployment) — Production security
- [Troubleshooting](/guides/troubleshooting) — Security debugging
- [Multi-Tenancy](/guides/multi-tenancy) — Tenant isolation patterns