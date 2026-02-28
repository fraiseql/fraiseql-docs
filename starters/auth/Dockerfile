# Dockerfile — Multi-stage build for the FraiseQL server binary.
#
# ============================================================================
# IMPORTANT: This Dockerfile is illustrative.
#
# A real FraiseQL project does not build the server binary from source inside
# this directory — the fraiseql-server crate lives in the main FraiseQL
# repository and is published as a pre-built release artifact and Docker image.
#
# For production use, pull the official image instead:
#   docker pull ghcr.io/fraiseql/fraiseql-server:latest
#
# If you need to build from source, clone the FraiseQL repository and run:
#   cargo build --release -p fraiseql-server
# then copy the resulting binary here.
#
# The stages below show the intended pattern; the actual binary copy is
# replaced with placeholder commands and explanatory comments.
# ============================================================================

# ============================================================================
# Stage 1: builder
#
# Compiles the FraiseQL server binary from source.
# In a real project this stage would build fraiseql-server from the workspace.
# ============================================================================
FROM rust:1.80-slim AS builder

# Install C toolchain dependencies required by some Rust crates (e.g., openssl-sys).
RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# NOTE: In a real project you would copy the Cargo workspace here and build:
#
#   COPY Cargo.toml Cargo.lock ./
#   COPY crates/ ./crates/
#   RUN cargo build --release -p fraiseql-server
#
# This example does not bundle the FraiseQL source, so we emit a placeholder
# that makes the stage succeed. Replace this with the real build command above.
RUN echo "Placeholder builder stage — replace with: cargo build --release -p fraiseql-server"

# The compiled schema is generated outside of Docker before building the image:
#   python schema.py                                    -> schema.json
#   fraiseql compile fraiseql.toml --types schema.json  -> schema.compiled.json
# The image reads schema.compiled.json at runtime (mounted or COPY'd below).
COPY schema.compiled.json* ./

# ============================================================================
# Stage 2: runtime
#
# Minimal Debian image containing only the server binary and its shared libs.
# ============================================================================
FROM debian:bookworm-slim

# Install runtime dependencies: CA certificates for TLS, and libssl for
# connections to the database and OIDC provider.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libssl3 \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the compiled server binary from the builder stage.
# In a real project:
#   COPY --from=builder /app/target/release/fraiseql-server /usr/local/bin/fraiseql-server
#
# Placeholder: create a stub so the image builds for demonstration purposes.
RUN echo '#!/bin/sh\necho "FraiseQL server placeholder — replace with real binary"\nexec sleep infinity' \
    > /usr/local/bin/fraiseql-server && chmod +x /usr/local/bin/fraiseql-server

# Copy the compiled schema. Mount this as a volume or bake it in at build time.
COPY --from=builder /app/schema.compiled.json* ./

EXPOSE 8080

# The server reads schema.compiled.json at startup and binds to 0.0.0.0:8080.
CMD ["fraiseql-server", "serve", "schema.compiled.json"]
