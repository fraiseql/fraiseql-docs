"""
src/auth.py — JWT validation dependency for FastAPI.

This module provides a FastAPI dependency that decodes and validates a Bearer
JWT from the Authorization header. It is used by the thin forwarding wrapper
in src/main.py and can be reused in any additional FastAPI routes you add.

Local development: JWTs are verified with HS256 using settings.jwt_secret.
Production: Replace the jose.jwt.decode call below with a JWKS-backed verifier.
See the comment in get_current_user() for the recommended production approach.
"""

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import ExpiredSignatureError, JWTError, jwt

from src.config import settings

# OAuth2 scheme — extracts the Bearer token from the Authorization header.
# The tokenUrl is a placeholder; this example does not implement a token
# endpoint itself (the OIDC provider is the token issuer).
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")


def get_current_user(token: str = Depends(oauth2_scheme)) -> dict:
    """
    FastAPI dependency: decode and validate a JWT Bearer token.

    Validates:
    - Signature (HS256 with jwt_secret in dev; see production note below)
    - ``iss`` claim matches settings.oidc_issuer
    - ``exp`` claim (token not expired)
    - ``sub`` claim present (identifies the user)

    Returns a dict containing at minimum:
        {
            "sub": "<user UUID>",
            "tenant_id": "<tenant UUID>",
            "email": "<user email>",
        }

    Raises:
        HTTPException(401): If the token is missing, expired, or invalid.

    Production note:
    ---------------
    In production you should NOT use HS256 with a shared secret. Instead:
    1. Fetch the OIDC provider's JWKS from:
           {oidc_issuer}/.well-known/openid-configuration -> jwks_uri
    2. Use python-jose's RSAAlgorithm.from_jwk() to build public keys.
    3. Pass algorithms=["RS256"] (or ["ES256"]) to jwt.decode().
    4. Cache the JWKS and refresh periodically (the provider may rotate keys).
    Libraries such as ``python-jose`` and ``joserfc`` both support JWKS natively.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        # In local development we verify with HS256 + shared secret.
        # Swap this block with a JWKS-backed call for production deployments.
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=["HS256"],
            options={
                # Issuer validation: the token's iss must match oidc_issuer.
                "verify_iss": True,
            },
            issuer=settings.oidc_issuer,
        )
    except ExpiredSignatureError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc
    except JWTError as exc:
        raise credentials_exception from exc

    sub: str | None = payload.get("sub")
    if sub is None:
        raise credentials_exception

    return {
        "sub": sub,
        "tenant_id": payload.get("tenant_id", ""),
        "email": payload.get("email", ""),
        # Forward the raw token so the forwarding wrapper can re-attach it.
        "_raw_token": token,
    }


# Alias for use as a named dependency in route definitions.
# Usage:
#   @app.post("/graphql")
#   async def graphql(user: dict = Depends(require_auth)):
#       ...
require_auth = get_current_user
