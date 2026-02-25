---
title: Docker Deployment
description: Deploy FraiseQL using Docker and Docker Compose
---

# Docker Deployment

Deploy FraiseQL in Docker containers for development and production use.

## Quick Start (5 Minutes)

### 1. Create `Dockerfile`

```dockerfile
FROM python:3.12-slim

WORKDIR /app

# Install dependencies
COPY pyproject.toml uv.lock ./
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
RUN pip install uv && uv sync --frozen --no-dev

# Copy application code
COPY . .

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health/live || exit 1

# Start FraiseQL
CMD ["uv", "run", "python", "-m", "fraiseql", "serve"]
```

### 2. Create `docker-compose.yml`

```
version: '3.8'

services:
  # PostgreSQL database
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: fraiseql
      POSTGRES_PASSWORD: dev-password
      POSTGRES_DB: fraiseql_dev
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U fraiseql"]
      interval: 10s
      timeout: 5s
      retries: 5

  # FraiseQL API
  fraiseql:
    build: .
    environment:
      DATABASE_URL: postgresql://fraiseql:dev-password@postgres:5432/fraiseql_dev
      JWT_SECRET: dev-secret-key-change-in-production
      ENVIRONMENT: development
      LOG_LEVEL: debug
    ports:
      - "8000:8000"
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - .:/app  # For development: hot-reload
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health/live"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  postgres_data:
```

### 3. Start Containers

```bash
# Build and start
docker-compose up -d

# View logs
docker-compose logs -f fraiseql

# Stop
docker-compose down
```

### 4. Test

```bash
# Check if API is running
curl http://localhost:8000/health/live
# Response: 200 OK

# Run a test query
curl -X POST http://localhost:8000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ users { id name } }"}'
```

## Production Dockerfile

For production deployments, use a multi-stage build for smaller image size:

```dockerfile
# Stage 1: Build dependencies
FROM python:3.12-slim AS builder

WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
RUN pip install uv && uv sync --frozen

# Stage 2: Runtime
FROM python:3.12-slim

WORKDIR /app

# Install runtime dependencies only
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Copy virtual environment from builder
COPY --from=builder /app/.venv /app/.venv

# Copy application code
COPY . .

# Set Python path
ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8000/health/live || exit 1

# Run with gunicorn for better concurrency
CMD ["gunicorn", "--workers=4", "--worker-class=uvicorn.workers.UvicornWorker", \
     "--bind=0.0.0.0:8000", "--access-logfile=-", "--error-logfile=-", \
     "app:app"]
```

## Production Docker Compose

For production with proper secrets management:

```
version: '3.8'

services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
    ports:
      - "${DB_PORT}:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups  # For automated backups
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  fraiseql:
    build:
      context: .
      dockerfile: Dockerfile.prod
    environment:
      DATABASE_URL: postgresql://${DB_USER}:${DB_PASSWORD}@postgres:5432/${DB_NAME}
      JWT_SECRET: ${JWT_SECRET}
      ENVIRONMENT: production
      LOG_LEVEL: ${LOG_LEVEL:-info}
      LOG_FORMAT: json
      CORS_ORIGINS: ${CORS_ORIGINS}
      RATE_LIMIT_REQUESTS: ${RATE_LIMIT_REQUESTS:-10000}
      RATE_LIMIT_WINDOW_SECONDS: ${RATE_LIMIT_WINDOW_SECONDS:-60}
      PGBOUNCER_MIN_POOL_SIZE: 5
      PGBOUNCER_MAX_POOL_SIZE: 20
    ports:
      - "${FRAISEQL_PORT}:8000"
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health/ready"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M

  # Optional: nginx reverse proxy with SSL
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certs:/etc/nginx/certs:ro
    depends_on:
      - fraiseql
    restart: unless-stopped

volumes:
  postgres_data:
```

## Environment Configuration

Create `.env.production` file (never commit to git):

```bash
# Database
DB_USER=fraiseql_prod
DB_PASSWORD=strong-password-min-32-chars
DB_NAME=fraiseql_production
DB_PORT=5432

# FraiseQL
JWT_SECRET=long-random-secret-min-32-chars
FRAISEQL_PORT=8000
CORS_ORIGINS=https://app.example.com,https://api.example.com
LOG_LEVEL=info

# Rate limiting
RATE_LIMIT_REQUESTS=10000
RATE_LIMIT_WINDOW_SECONDS=60

# Backup schedule (cron format)
BACKUP_SCHEDULE="0 2 * * *"  # Daily at 2 AM
```

Load with Docker Compose:

```bash
docker-compose --env-file .env.production up -d
```

## Reverse Proxy Configuration (nginx)

For production with SSL termination:

```nginx
upstream fraiseql {
    server fraiseql:8000;
}

server {
    listen 80;
    server_name api.example.com;

    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.example.com;

    # SSL certificates (use Let's Encrypt for free)
    ssl_certificate /etc/nginx/certs/cert.pem;
    ssl_certificate_key /etc/nginx/certs/key.pem;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Logging
    access_log /var/log/nginx/fraiseql-access.log;
    error_log /var/log/nginx/fraiseql-error.log;

    # Proxy to FraiseQL
    location / {
        proxy_pass http://fraiseql;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;

        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
    }

    # Health check endpoint (don't log)
    location /health/ {
        access_log off;
        proxy_pass http://fraiseql;
    }
}
```

## Database Initialization

Run migrations on container start:

```dockerfile
# In Dockerfile, add:
COPY scripts/init-db.sh /docker-entrypoint-initdb.d/
RUN chmod +x /docker-entrypoint-initdb.d/init-db.sh

# In docker-compose.yml postgres service:
volumes:
  - ./scripts/init-db.sh:/docker-entrypoint-initdb.d/init-db.sh
```

Example `scripts/init-db.sh`:

```bash
#!/bin/bash
set -e

echo "Running database migrations..."
python -m fraiseql migrate

echo "Seeding database (optional)..."
python -m fraiseql seed --data=seeds/initial-data.json

echo "Database initialization complete"
```

## Volume Management

### Development (Hot Reload)

```
fraiseql:
  volumes:
    - .:/app  # Mount entire project
    - /app/.venv  # Exclude venv from bind mount
```

### Production (No Volumes)

```
fraiseql:
  volumes: []
  # All data lives in the container (ephemeral)
  # Database state lives in PostgreSQL volume
```

### Data Persistence

```
fraiseql:
  volumes:
    # For SQLite or file-based uploads
    - fraiseql_data:/app/data
    - fraiseql_uploads:/app/uploads

volumes:
  fraiseql_data:
    driver: local
  fraiseql_uploads:
    driver: local
```

## Scaling: Docker Swarm

For multiple instances:

```
version: '3.8'

services:
  fraiseql:
    build: .
    environment:
      DATABASE_URL: postgresql://user:pass@postgres:5432/db
    deploy:
      replicas: 3  # Run 3 instances
      resources:
        limits:
          cpus: '1'
          memory: 1G
      restart_policy:
        condition: on-failure
      update_config:
        parallelism: 1  # Rolling update
        delay: 10s

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - fraiseql
```

Start with Docker Swarm:

```bash
docker swarm init
docker stack deploy -c docker-compose.yml fraiseql
docker stack services fraiseql  # View running services
```

## Logging

### View Logs

```bash
# All services
docker-compose logs

# Specific service
docker-compose logs fraiseql

# Follow logs
docker-compose logs -f fraiseql

# Last 100 lines
docker-compose logs --tail=100 fraiseql

# Timestamps
docker-compose logs --timestamps fraiseql
```

### Send Logs to External Service

```
fraiseql:
  logging:
    driver: "splunk"  # or awslogs, gcplogs, awsfirelens
    options:
      splunk-token: "${SPLUNK_HEC_TOKEN}"
      splunk-url: "${SPLUNK_HEC_URL}"
      splunk-insecureskipverify: "true"
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker-compose logs fraiseql

# Common issues:
# 1. PORT_ALREADY_IN_USE: Change ports in docker-compose.yml
# 2. DATABASE_NOT_RUNNING: Ensure postgres service started first
# 3. ENVIRONMENT_VARIABLES_MISSING: Check .env file exists
```

### Connection Refused

```bash
# Verify services are running
docker-compose ps

# Test database connection from fraiseql container
docker-compose exec fraiseql \
  python -c "import psycopg2; \
  conn = psycopg2.connect('postgresql://user:pass@postgres:5432/db'); \
  print('Connected!')"
```

### Out of Disk Space

```bash
# Check Docker disk usage
docker system df

# Clean up unused images/containers
docker system prune

# Clean up volumes (CAREFUL - deletes data!)
docker volume prune
```

### High Memory Usage

Increase memory limit in `docker-compose.yml`:

```
fraiseql:
  deploy:
    resources:
      limits:
        memory: 2G  # Increase from 1G
```

## Database Backups in Docker

### Automated Daily Backups

Create `scripts/backup.sh`:

```bash
#!/bin/bash
set -e

BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/fraiseql-backup-$TIMESTAMP.sql"

mkdir -p "$BACKUP_DIR"

echo "Starting backup..."

# Dump database
docker-compose exec -T postgres pg_dump \
  -U "${DB_USER}" \
  "${DB_NAME}" > "$BACKUP_FILE"

# Compress
gzip "$BACKUP_FILE"

# Keep only last 7 days
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +7 -delete

echo "Backup complete: $BACKUP_FILE.gz"
```

Schedule with cron:

```bash
# Add to crontab
0 2 * * * cd /home/user/fraiseql && ./scripts/backup.sh
```python

### Restore from Backup

```bash
# Decompress
gunzip backups/fraiseql-backup-20240115_020000.sql.gz

# Restore
docker-compose exec -T postgres psql \
  -U fraiseql_prod fraiseql_production < \
  backups/fraiseql-backup-20240115_020000.sql

echo "Restore complete"
```

## Security Best Practices

1. **Never hardcode secrets**: Use `.env` files (add to `.gitignore`)
2. **Use read-only root filesystem**:
   ```
   fraiseql:
     read_only: true
     tmpfs: ["/tmp", "/var/tmp"]
   ```

3. **Don't run as root**:
   ```dockerfile
   RUN useradd -m -u 1000 fraiseql
   USER fraiseql
   ```

4. **Network isolation**:
   ```
   networks:
     backend:  # Only for backend services
     frontend: # Only for frontend access
   fraiseql:
     networks:
       - backend
   ```

5. **Secrets in production** (use Docker Secrets):
   ```bash
   echo "${JWT_SECRET}" | docker secret create jwt_secret -

   # In docker-compose.yml:
   secrets:
     jwt_secret:
       external: true
   fraiseql:
     secrets:
       - jwt_secret
   ```

## Performance Tuning

### Resource Limits

Adjust based on expected load:

```
fraiseql:
  deploy:
    resources:
      limits:
        cpus: '2'        # 2 CPUs max
        memory: 2G       # 2GB max
      reservations:
        cpus: '1'        # Reserve 1 CPU
        memory: 1G       # Reserve 1GB
```

### Worker Configuration

For Gunicorn (multi-process):

```dockerfile
# Calculate workers: (2 * CPU_count) + 1
# With 4 CPUs: 9 workers
CMD ["gunicorn", "--workers=9", ...]
```

### Database Optimization

```
postgres:
  environment:
    POSTGRES_INITDB_ARGS: "-c max_connections=200 -c shared_buffers=256MB"
```

## Next Steps

1. **Kubernetes** - For production at scale
2. **CI/CD Integration** - Automate Docker builds
3. **Monitoring** - Add Prometheus/Grafana
4. **Load Testing** - Verify performance with multiple instances
