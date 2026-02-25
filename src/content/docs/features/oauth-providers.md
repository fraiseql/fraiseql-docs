---
title: OAuth Providers
description: Configure OAuth2 and OIDC authentication with multiple providers
---

FraiseQL supports multiple OAuth2/OIDC providers for authentication, with built-in support for popular identity platforms.

## Supported Providers

| Provider | Protocol | Features |
|----------|----------|----------|
| Google | OIDC | Email verification, profile |
| GitHub | OAuth2 | Org membership, teams |
| Microsoft Azure AD | OIDC | Tenant isolation, groups |
| Okta | OIDC | Custom claims, MFA |
| Auth0 | OIDC | Rules, roles, permissions |
| Keycloak | OIDC | Self-hosted, realm support |
| Generic OIDC | OIDC | Any compliant provider |

## Configuration

### Google

```toml
[auth]
provider = "google"

[auth.google]
client_id = "${GOOGLE_CLIENT_ID}"
client_secret = "${GOOGLE_CLIENT_SECRET}"
redirect_uri = "https://api.example.com/auth/callback"

# Optional: restrict to specific domains
allowed_domains = ["example.com", "company.org"]

# Optional: require email verification
require_verified_email = true
```

### GitHub

```toml
[auth]
provider = "github"

[auth.github]
client_id = "${GITHUB_CLIENT_ID}"
client_secret = "${GITHUB_CLIENT_SECRET}"
redirect_uri = "https://api.example.com/auth/callback"

# Optional: require org membership
required_org = "my-company"

# Optional: map teams to roles
[auth.github.team_roles]
"my-company/admins" = "admin"
"my-company/developers" = "developer"
```

### Microsoft Azure AD

```toml
[auth]
provider = "azure"

[auth.azure]
client_id = "${AZURE_CLIENT_ID}"
client_secret = "${AZURE_CLIENT_SECRET}"
tenant_id = "${AZURE_TENANT_ID}"
redirect_uri = "https://api.example.com/auth/callback"

# Optional: map Azure AD groups to roles
[auth.azure.group_roles]
"00000000-0000-0000-0000-000000000001" = "admin"
"00000000-0000-0000-0000-000000000002" = "user"
```

### Okta

```toml
[auth]
provider = "okta"

[auth.okta]
domain = "your-domain.okta.com"
client_id = "${OKTA_CLIENT_ID}"
client_secret = "${OKTA_CLIENT_SECRET}"
redirect_uri = "https://api.example.com/auth/callback"

# Optional: authorization server
authorization_server = "default"

# Optional: custom claims for roles
role_claim = "groups"
```

### Auth0

```toml
[auth]
provider = "auth0"

[auth.auth0]
domain = "your-tenant.auth0.com"
client_id = "${AUTH0_CLIENT_ID}"
client_secret = "${AUTH0_CLIENT_SECRET}"
redirect_uri = "https://api.example.com/auth/callback"
audience = "https://api.example.com"

# Optional: namespace for custom claims
namespace = "https://example.com/"
role_claim = "roles"
```

### Keycloak

```toml
[auth]
provider = "keycloak"

[auth.keycloak]
server_url = "https://keycloak.example.com"
realm = "my-realm"
client_id = "${KEYCLOAK_CLIENT_ID}"
client_secret = "${KEYCLOAK_CLIENT_SECRET}"
redirect_uri = "https://api.example.com/auth/callback"

# Optional: role mapping
[auth.keycloak.role_mapping]
"realm-admin" = "admin"
"realm-user" = "user"
```

### Generic OIDC

For any OIDC-compliant provider:

```toml
[auth]
provider = "oidc"

[auth.oidc]
issuer = "https://identity.example.com"
client_id = "${OIDC_CLIENT_ID}"
client_secret = "${OIDC_CLIENT_SECRET}"
redirect_uri = "https://api.example.com/auth/callback"

# Discovery endpoint (usually auto-detected from issuer)
discovery_url = "https://identity.example.com/.well-known/openid-configuration"

# Claims mapping
subject_claim = "sub"
email_claim = "email"
name_claim = "name"
role_claim = "roles"

# Scopes to request
scopes = ["openid", "profile", "email"]
```

## Authentication Flow

### Authorization Code Flow

```
┌────────┐     1. Login Request      ┌──────────┐
│ Client │ ─────────────────────────→│ FraiseQL │
└────────┘                           └──────────┘
                                           │
                                           │ 2. Redirect to Provider
                                           ↓
                                     ┌──────────┐
                                     │ Provider │
                                     └──────────┘
                                           │
          3. Auth Code + State             │
┌────────┐ ←───────────────────────────────┘
│ Client │
└────────┘
     │
     │ 4. Code → FraiseQL
     ↓
┌──────────┐     5. Exchange Code    ┌──────────┐
│ FraiseQL │ ───────────────────────→│ Provider │
└──────────┘ ←───────────────────────└──────────┘
                 6. Tokens
     │
     │ 7. Session Token
     ↓
┌────────┐
│ Client │
└────────┘
```

### Endpoints

| Endpoint | Purpose |
|----------|---------|
| `/auth/login` | Initiate OAuth flow |
| `/auth/callback` | OAuth callback handler |
| `/auth/logout` | End session |
| `/auth/refresh` | Refresh access token |
| `/auth/userinfo` | Get current user info |

## Session Management

### Session Storage

```toml
[auth.session]
# Storage backend
storage = "postgres"  # or "redis", "memory"

# Session lifetime
ttl_seconds = 86400  # 24 hours

# Refresh token lifetime
refresh_ttl_seconds = 604800  # 7 days

# Secure cookies
cookie_secure = true
cookie_same_site = "lax"
```

### PostgreSQL Session Storage

```toml
[auth.session]
storage = "postgres"

[auth.session.postgres]
table_name = "tb_session"
cleanup_interval_seconds = 3600
```

### Redis Session Storage

```toml
[auth.session]
storage = "redis"

[auth.session.redis]
url = "${REDIS_URL}"
key_prefix = "session:"
```

## Security Features

### PKCE Support

PKCE (Proof Key for Code Exchange) is enabled by default:

```toml
[auth.security]
pkce_enabled = true
pkce_method = "S256"  # SHA-256
```

### State Parameter

State is encrypted with ChaCha20-Poly1305:

```toml
[auth.security]
state_encryption_key = "${STATE_ENCRYPTION_KEY}"
state_ttl_seconds = 300  # 5 minutes
```

### Nonce Validation

For OIDC providers:

```toml
[auth.security]
nonce_validation = true
nonce_ttl_seconds = 300
```

## Role Mapping

### From Token Claims

```toml
[auth.roles]
# Claim containing roles
claim = "roles"

# Default role if none specified
default = "user"

# Mapping from provider roles to app roles
[auth.roles.mapping]
"admin" = "admin"
"editor" = "editor"
"viewer" = "user"
```

### From Provider Groups

```toml
[auth.roles]
source = "groups"  # Use group membership

[auth.roles.group_mapping]
"admins" = "admin"
"developers" = "developer"
"*" = "user"  # Default for any group
```

## Multi-Provider Setup

Enable multiple providers:

```toml
[auth]
providers = ["google", "github", "azure"]
default_provider = "google"

[auth.google]
client_id = "${GOOGLE_CLIENT_ID}"
# ...

[auth.github]
client_id = "${GITHUB_CLIENT_ID}"
# ...

[auth.azure]
client_id = "${AZURE_CLIENT_ID}"
# ...
```

Login endpoint accepts provider parameter:

```
/auth/login?provider=github
/auth/login?provider=google
```

## Token Handling

### Access Token in Context

```python
# In resolvers, access the authenticated user
@fraiseql.query(sql_source="v_user")
def me(context: Context) -> User:
    user_id = context.user_id  # From token
    roles = context.roles      # Mapped roles
    email = context.email      # From claims
```

### Custom Claims

```toml
[auth.claims]
# Extract custom claims from token
tenant_id = "https://example.com/tenant_id"
org_id = "https://example.com/org_id"
```

Access in context:

```python
tenant_id = context.claims.get("tenant_id")
```

## Metrics

| Metric | Description |
|--------|-------------|
| `fraiseql_auth_logins_total` | Login attempts |
| `fraiseql_auth_login_success_total` | Successful logins |
| `fraiseql_auth_login_failure_total` | Failed logins |
| `fraiseql_auth_token_refresh_total` | Token refreshes |
| `fraiseql_auth_session_active` | Active sessions |

## Troubleshooting

### Redirect URI Mismatch

Ensure redirect URI matches exactly in:
1. FraiseQL config
2. Provider app settings
3. Actual callback URL

### Token Validation Errors

1. Check clock sync between servers
2. Verify issuer URL is correct
3. Check token hasn't expired

### Missing Claims

1. Verify scopes include required claims
2. Check provider-specific claim names
3. Review claim mapping configuration

## Next Steps

- [Security](/features/security) - RBAC and field-level authorization
- [Rate Limiting](/features/rate-limiting) - Protect auth endpoints
- [Deployment](/guides/deployment) - Production OAuth setup
