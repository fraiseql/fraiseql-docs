"""
src/config.py — Application configuration loaded from environment variables.

Pydantic Settings reads values from the process environment and, when present,
from a .env file in the working directory. Rename .env.example to .env and
fill in the values before running locally.
"""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Centralised configuration for the FraiseQL auth example.

    All fields map to environment variables of the same name (uppercased).
    For example, ``database_url`` is read from the ``DATABASE_URL`` env var.
    """

    # PostgreSQL connection string. In docker-compose this points to the
    # compose service; in production use a managed database with SSL.
    database_url: str

    # Base URL of the OIDC provider used for JWT issuer validation.
    # Example: "https://accounts.google.com" or "https://your-tenant.auth0.com"
    oidc_issuer: str = "https://accounts.example.com"

    # OAuth2 client ID registered with the OIDC provider.
    oidc_client_id: str = "your-client-id"

    # OAuth2 client secret — read from OIDC_CLIENT_SECRET env var.
    # Never hard-code this value; always inject it via the environment.
    oidc_client_secret: str = ""

    # HS256 signing secret used to verify JWTs during local development and
    # automated tests. This MUST NOT be used in production deployments.
    # Production should validate RS256/ES256 JWTs against the JWKS endpoint.
    jwt_secret: str = "dev-jwt-secret-replace-in-production"

    # Controls logging verbosity and error detail. Set to "production" before
    # deploying; this prevents stack traces from appearing in HTTP responses.
    app_env: str = "development"

    model_config = SettingsConfigDict(
        # Load from a .env file if present in the working directory.
        # Variables already present in the process environment take precedence.
        env_file=".env",
        # Allow extra fields so future env vars do not cause startup errors.
        extra="ignore",
    )


# Module-level singleton — import this in other modules:
#   from src.config import settings
settings = Settings()
