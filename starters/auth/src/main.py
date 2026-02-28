"""
src/main.py — Thin FastAPI wrapper that forwards authenticated requests to FraiseQL.

IMPORTANT: This wrapper is illustrative only.

In production, FraiseQL handles JWT authentication natively via its built-in
security layer (configured in fraiseql.toml). The compiled Rust server validates
tokens, rejects unauthenticated requests (default_policy = "authenticated"), and
injects JWT claims into queries via the inject= parameter on each @fraiseql.query /
@fraiseql.mutation decorator.

This wrapper exists to demonstrate how a FastAPI gateway could sit in front of
FraiseQL for teams that already have a Python API layer, or that want to add
custom middleware (e.g., request logging, custom auth logic) before the request
reaches FraiseQL. It is NOT required for FraiseQL to function.
"""

import httpx
from fastapi import Depends, FastAPI, Request, Response
from fastapi.responses import JSONResponse

from src.auth import require_auth

# ---------------------------------------------------------------------------
# Application
# ---------------------------------------------------------------------------

app = FastAPI(
    title="FraiseQL Auth Example",
    description=(
        "Illustrative FastAPI wrapper that validates JWTs and forwards GraphQL "
        "requests to the FraiseQL compiled server."
    ),
    version="1.0.0",
)

# The FraiseQL server address. In production this might be an internal service
# URL (e.g., http://fraiseql:8080 inside a Docker network).
FRAISEQL_UPSTREAM = "http://localhost:8080"


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


@app.get("/health")
async def health() -> dict:
    """Health check endpoint. Returns 200 when the wrapper is running."""
    return {"status": "ok"}


@app.post("/graphql")
async def graphql_proxy(
    request: Request,
    current_user: dict = Depends(require_auth),
) -> Response:
    """
    Validate the JWT and forward the GraphQL request to FraiseQL.

    Steps:
    1. require_auth decodes and validates the Bearer token (raises 401 on failure).
    2. Extract sub and tenant_id from the validated token payload.
    3. Forward the raw request body to the FraiseQL server, attaching the
       original Authorization header so FraiseQL can also validate the token
       and perform its own inject parameter resolution.
    4. Return FraiseQL's response to the client verbatim.

    Note: FraiseQL re-validates the token independently using its own JWT
    verification logic. This double-validation is intentional — the wrapper
    provides an early-rejection layer so malformed requests never reach the
    Rust server.
    """
    # Read the original request body (GraphQL JSON payload).
    body = await request.body()

    # Forward the Authorization header so FraiseQL can verify the token and
    # resolve inject parameters (jwt:sub, jwt:tenant_id) from it.
    raw_token: str = current_user["_raw_token"]
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {raw_token}",
        # Propagate the client's Accept header if present.
        "Accept": request.headers.get("Accept", "application/json"),
    }

    async with httpx.AsyncClient(timeout=30.0) as client:
        upstream_response = await client.post(
            f"{FRAISEQL_UPSTREAM}/graphql",
            content=body,
            headers=headers,
        )

    # Return the FraiseQL response to the caller with the original status code
    # and Content-Type header.
    return Response(
        content=upstream_response.content,
        status_code=upstream_response.status_code,
        media_type=upstream_response.headers.get("content-type", "application/json"),
    )


# ---------------------------------------------------------------------------
# Error handlers
# ---------------------------------------------------------------------------


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """
    Catch-all for unexpected errors. Returns a generic 500 without leaking
    internal details. Enable detailed errors by setting APP_ENV=development.
    """
    from src.config import settings  # import here to avoid circular at module level

    if settings.app_env == "development":
        detail = str(exc)
    else:
        detail = "An unexpected error occurred."

    return JSONResponse(
        status_code=500,
        content={"error": detail},
    )
