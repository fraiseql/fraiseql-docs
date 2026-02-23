---
title: Installation
description: Install FraiseQL and set up your development environment
---

FraiseQL is a Rust-based tool that supports schema definition in multiple languages. Choose the installation method that fits your workflow.

## Requirements

- **Database**: PostgreSQL, MySQL, SQLite, or SQL Server
- **Schema language** (optional): Python 3.10+, Node.js 18+, Go 1.21+, or others

## Quick Install

### Using Cargo (Recommended)

If you have Rust installed:

```bash
cargo install fraiseql
```

### Using the Install Script

For macOS and Linux:

```bash
curl -fsSL https://fraiseql.dev/install.sh | sh
```

### Using Homebrew (macOS)

```bash
brew install fraiseql
```python

### Pre-built Binaries

Download from [GitHub Releases](https://github.com/fraiseql/fraiseql/releases) for your platform.

### For Python Schema Development

If you're using Python for schema definition:

```bash
# Using uv (recommended)
uv tool install fraiseql

# Using pipx (isolated environment)
pipx install fraiseql

# Using pip
pip install fraiseql
```

## Verify Installation

```bash
fraiseql --version
# fraiseql 2.0.0
```

## Database Setup

### PostgreSQL

```bash
# Create a database
createdb myapp

# Set the connection string
export DATABASE_URL="postgresql://localhost:5432/myapp"
```

### MySQL

```bash
# Create a database
mysql -e "CREATE DATABASE myapp"

# Set the connection string
export DATABASE_URL="mysql://root@localhost:3306/myapp"
```

### SQLite

```bash
# SQLite creates the file automatically
export DATABASE_URL="sqlite:///./myapp.db"
```

### SQL Server

```bash
# Set the connection string
export DATABASE_URL="sqlserver://localhost:1433;database=myapp;user=sa;password=..."
```

## Project Initialization

```bash
# Create a new project
fraiseql init my-api

# Or initialize in current directory
fraiseql init .
```

This creates:

```
my-api/
├── fraiseql.toml      # Configuration
├── schema.py          # Schema definition
└── migrations/        # Database migrations
```

## IDE Setup

### VS Code

Install the recommended extensions:

```json title=".vscode/extensions.json"
{
  "recommendations": [
    "ms-python.python",
    "tamasfe.even-better-toml",
    "graphql.vscode-graphql"
  ]
}
```

### PyCharm

FraiseQL works out of the box with PyCharm's Python support.

## Docker Installation

```dockerfile title="Dockerfile"
FROM debian:bookworm-slim

# Install FraiseQL
RUN apt-get update && apt-get install -y curl && \
    curl -fsSL https://fraiseql.dev/install.sh | sh && \
    rm -rf /var/lib/apt/lists/*

# Copy your project
COPY . /app
WORKDIR /app

# Build and serve
RUN fraiseql build
CMD ["fraiseql", "serve", "--host", "0.0.0.0"]
```

For Python schema development:

```dockerfile title="Dockerfile"
FROM python:3.12-slim

# Install FraiseQL and Python dependencies
RUN pip install fraiseql

# Copy your project
COPY . /app
WORKDIR /app

# Build and serve
RUN fraiseql build
CMD ["fraiseql", "serve", "--host", "0.0.0.0"]
```

## Troubleshooting

### Database connection issues

Verify your connection string:

```bash
fraiseql db check
```

### Permission errors

On Linux, you may need to add your user to the docker group or use sudo for certain operations.

## Next Steps

- [Quick Start](/getting-started/quickstart) — Build your first API
- [Your First API](/getting-started/first-api) — Complete tutorial
- [Configuration](/concepts/configuration) — All TOML options
`3
`3