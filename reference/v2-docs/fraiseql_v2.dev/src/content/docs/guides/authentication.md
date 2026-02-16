---
title: Authentication
description: Implement authentication in your FraiseQL API
---

Learn how to add authentication to your FraiseQL GraphQL API.

## Overview

FraiseQL supports multiple authentication strategies:

- **JWT tokens** — For web and mobile apps
- **API keys** — For service-to-service and client apps
- **OAuth 2.0** — For third-party authentication
- **SAML** — For enterprise single sign-on
- **Custom authentication** — For specialized requirements

Each strategy integrates seamlessly with FraiseQL's authorization system.

---

## JWT Authentication

The most common approach for web applications. Tokens contain user claims and can be validated without database lookups.

### Configuration

```toml title="fraiseql.toml"
[auth]
type = "jwt"
secret = "${JWT_SECRET}"
issuer = "your-app"
audience = "your-api"
algorithm = "HS256"  # HS256, RS256, ES256
expiration = 3600   # seconds (1 hour)
```

### Creating Tokens

```python title="auth.py"
from datetime import datetime, timedelta
import jwt

def create_token(user_id: str, scopes: list[str]) -> str:
    """Create a JWT token for a user."""
    payload = {
        'user_id': user_id,
        'scopes': scopes,
        'iat': datetime.utcnow(),
        'exp': datetime.utcnow() + timedelta(hours=1),
        'iss': 'your-app',
        'aud': 'your-api',
    }
    return jwt.encode(payload, os.getenv('JWT_SECRET'), algorithm='HS256')
```

### Protected Queries and Mutations

```python title="schema.py"
import fraiseql
from fraiseql.auth import authenticated, requires_scope, get_current_user

@fraiseql.query
@authenticated
async def me(info) -> "User":
    """Get current user (requires authentication)."""
    user_id = get_current_user(info)
    return await info.context.db.find_one("users", id=user_id)

@fraiseql.mutation
@authenticated
@requires_scope("write:posts")
async def create_post(info, title: str, content: str) -> "Post":
    """Create post (requires write:posts scope)."""
    user_id = get_current_user(info)
    return await info.context.db.create("posts",
        title=title, content=content, user_id=user_id)
```

### Token Refresh Pattern

```python title="schema.py"
@fraiseql.mutation
async def refresh_token(refresh_token: str) -> dict:
    """Exchange refresh token for new access token."""
    try:
        payload = jwt.decode(refresh_token, os.getenv('JWT_SECRET'),
                           algorithms=['HS256'])
        user_id = payload['user_id']
        scopes = payload.get('scopes', [])

        new_token = create_token(user_id, scopes)
        return {
            'access_token': new_token,
            'token_type': 'Bearer',
            'expires_in': 3600,
        }
    except jwt.ExpiredSignatureError:
        raise Exception("Refresh token expired")
```

---

## API Key Authentication

Simple authentication for service-to-service communication and client applications.

### Configuration

```toml title="fraiseql.toml"
[auth]
type = "api_key"
header = "X-API-Key"
key_prefix = "sk_"    # optional prefix for validation
```

### Protecting Endpoints

```python title="schema.py"
from fraiseql.auth import api_key_required

@fraiseql.query
@api_key_required
async def report_data(info) -> list["Report"]:
    """Public data accessible with API key."""
    return await info.context.db.find_all("reports")

@fraiseql.mutation
@api_key_required
@requires_scope("write:data")
async def update_report(info, id: str, data: dict) -> "Report":
    """Requires specific API key scope."""
    return await info.context.db.update("reports", id, data)
```

### Managing API Keys

```python title="schema.py"
@fraiseql.mutation
@authenticated
async def create_api_key(info, name: str, scopes: list[str]) -> dict:
    """Create API key for client."""
    user_id = get_current_user(info)
    key = generate_api_key()  # Use secure random generation

    await info.context.db.create("api_keys", {
        'key': key,
        'user_id': user_id,
        'name': name,
        'scopes': scopes,
        'created_at': datetime.utcnow(),
    })

    return {'key': key, 'message': 'Store this securely, you won\'t see it again'}
```

---

## OAuth 2.0 Integration

Delegate authentication to a trusted provider (Google, GitHub, Auth0, etc.).

### Configuration

```toml title="fraiseql.toml"
[auth]
type = "oauth2"

[auth.providers.google]
client_id = "${GOOGLE_CLIENT_ID}"
client_secret = "${GOOGLE_CLIENT_SECRET}"
authorization_url = "https://accounts.google.com/o/oauth2/v2/auth"
token_url = "https://oauth2.googleapis.com/token"
userinfo_url = "https://openidconnect.googleapis.com/v1/userinfo"
scopes = ["openid", "email", "profile"]

[auth.providers.github]
client_id = "${GITHUB_CLIENT_ID}"
client_secret = "${GITHUB_CLIENT_SECRET}"
```

### OAuth Login Flow

```python title="schema.py"
@fraiseql.mutation
async def oauth_callback(info, code: str, provider: str) -> dict:
    """Handle OAuth callback and create/update user."""
    # Exchange code for token
    token = await exchange_oauth_code(code, provider)
    user_info = await fetch_user_info(token, provider)

    # Find or create user
    user = await info.context.db.find_one("users",
        email=user_info['email'])

    if not user:
        user = await info.context.db.create("users", {
            'email': user_info['email'],
            'name': user_info.get('name'),
            'oauth_provider': provider,
            'oauth_id': user_info['sub'],
        })

    # Create access token
    access_token = create_token(user['id'], ['read:*', 'write:own'])

    return {
        'access_token': access_token,
        'user': user,
    }
```

---

## SAML Integration

Enterprise single sign-on with SAML identity providers.

### Configuration

```toml title="fraiseql.toml"
[auth]
type = "saml"
metadata_url = "${SAML_METADATA_URL}"  # From IdP
entity_id = "urn:your-app:entity"
assertion_consumer_url = "https://api.example.com/auth/saml/acs"
```

### SAML Assertion Handling

```python title="schema.py"
@fraiseql.mutation
async def saml_acs(info, saml_response: str) -> dict:
    """Process SAML assertion from IdP."""
    # Validate and parse SAML response
    assertion = validate_saml_response(saml_response)

    # Extract user attributes
    email = assertion.get_attribute('email')[0]
    name = assertion.get_attribute('name')[0]
    groups = assertion.get_attribute('groups', [])

    # Find or create user with group mapping
    user = await info.context.db.find_one("users", email=email)
    if not user:
        user = await info.context.db.create("users", {
            'email': email,
            'name': name,
            'sso_provider': 'saml',
            'groups': groups,
        })

    # Map SAML groups to scopes
    scopes = map_groups_to_scopes(groups)
    token = create_token(user['id'], scopes)

    return {'access_token': token}
```

---

## Custom Authentication

For specialized requirements or legacy systems.

```python title="schema.py"
from fraiseql.auth import custom_auth_handler

@custom_auth_handler
async def authenticate_request(request) -> dict:
    """Custom authentication logic."""
    # Example: validate custom header
    auth_header = request.headers.get('X-Custom-Auth')

    if not auth_header:
        raise Exception("Missing authentication")

    # Your custom validation logic
    user = await validate_custom_token(auth_header)

    return {
        'user_id': user['id'],
        'scopes': user['scopes'],
    }
```

---

## Multi-Factor Authentication (MFA)

Add TOTP or SMS-based MFA on top of any authentication method.

```python title="schema.py"
@fraiseql.mutation
async def verify_mfa_code(info, code: str) -> dict:
    """Verify MFA code and complete authentication."""
    session = get_mfa_session(info)
    user_id = session['pending_user_id']

    if verify_totp(code, user_id):
        token = create_token(user_id, user['scopes'])
        clear_mfa_session(info)
        return {'success': True, 'access_token': token}

    raise Exception("Invalid MFA code")
```

---

## Token Validation

FraiseQL automatically validates tokens in every request. Customize validation behavior:

```python title="schema.py"
@fraiseql.middleware
async def validate_token(request, next):
    """Custom token validation middleware."""
    token = extract_token_from_header(request)

    if token:
        try:
            payload = jwt.decode(token, os.getenv('JWT_SECRET'),
                               algorithms=['HS256'])

            # Additional custom validation
            if payload.get('revoked'):
                raise Exception("Token has been revoked")

            request.user = payload
        except jwt.ExpiredSignatureError:
            raise Exception("Token has expired")

    return await next(request)
```

---

## Security Best Practices

1. **Use HTTPS everywhere** — Never transmit tokens over unencrypted connections
2. **Store secrets securely** — Use environment variables or secret managers (not in code)
3. **Use strong secrets** — At least 32 bytes for JWT_SECRET
4. **Implement token expiration** — Short-lived tokens (1 hour) with refresh token rotation
5. **Validate token signature** — Every token must be cryptographically validated
6. **Set proper CORS** — Restrict `Access-Control-Allow-Origin` to trusted domains
7. **Use secure cookies** — For web apps, store tokens in `HttpOnly` cookies
8. **Implement rate limiting** — Prevent brute force authentication attempts
9. **Audit authentication events** — Log all login/logout events
10. **Rotate secrets regularly** — Monthly or quarterly secret rotation

---

## Next Steps

- [Authorization & RBAC](/guides/advanced-patterns#rbac-patterns) — Role-based access control
- [Security Best Practices](/features/security) — Production security
- [Troubleshooting Auth Issues](/troubleshooting/security-issues) — Common authentication problems