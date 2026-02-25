---
title: Deployment
description: Deploy FraiseQL to production with Docker, cloud platforms, and best practices
---

This guide covers deploying FraiseQL to production environments, including Docker, cloud platforms, and operational best practices.

## Production Configuration

### fraiseql.toml for Production

```toml
[project]
name = "my-api"
version = "1.0.0"

[database]
type = "postgresql"
url = "${DATABASE_URL}"
pool_min = 10
pool_max = 100
statement_timeout = 30000

[database.replica]
url = "${DATABASE_REPLICA_URL}"
pool_min = 20
pool_max = 200

[server]
host = "0.0.0.0"
port = 8080
workers = 0  # 0 = use all CPU cores

[server.cors]
origins = ["https://app.example.com"]
credentials = true

[graphql]
playground = false
introspection = false
max_depth = 8
max_complexity = 500

[graphql.apq]
enabled = true
cache_size = 10000

[auth]
enabled = true
provider = "jwt"

[auth.jwt]
secret = "${JWT_SECRET}"
algorithm = "HS256"
issuer = "my-api"

[logging]
level = "info"
format = "json"

[metrics]
enabled = true

[tracing]
enabled = true
provider = "otlp"
endpoint = "${OTLP_ENDPOINT}"
sample_rate = 0.1
```

### Environment Variables

Required environment variables for production:

```bash
# Database
DATABASE_URL=postgresql://user:pass@host:5432/dbname?sslmode=require
DATABASE_REPLICA_URL=postgresql://user:pass@replica:5432/dbname?sslmode=require

# Authentication
JWT_SECRET=your-256-bit-secret-key

# Caching (if enabled)
REDIS_URL=redis://host:6379/0

# Observability
OTLP_ENDPOINT=https://otlp.example.com:4317
```

## Docker Deployment

### Dockerfile

```dockerfile
# Build stage
FROM rust:1.75-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache musl-dev openssl-dev

# Copy source
COPY . .

# Build release binary
RUN fraiseql build --target release

# Runtime stage
FROM alpine:3.19

WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache ca-certificates libgcc

# Copy binary and config
COPY --from=builder /app/target/release/fraiseql-server /app/
COPY fraiseql.toml /app/

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
    CMD wget -qO- http://localhost:8080/health || exit 1

# Run
EXPOSE 8080
CMD ["./fraiseql-server"]
```

### docker-compose.yml

```
version: "3.8"

services:
  api:
    build: .
    ports:
      - "8080:8080"
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - JWT_SECRET=${JWT_SECRET}
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - postgres
      - redis
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: "2"
          memory: 1G
        reservations:
          cpus: "0.5"
          memory: 256M
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:8080/health"]
      interval: 30s
      timeout: 3s
      retries: 3

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: mydb
      POSTGRES_USER: user
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d mydb"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
  redis_data:
```

## Kubernetes Deployment

### deployment.yaml

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fraiseql-api
  labels:
    app: fraiseql-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: fraiseql-api
  template:
    metadata:
      labels:
        app: fraiseql-api
    spec:
      containers:
        - name: api
          image: your-registry/fraiseql-api:latest
          ports:
            - containerPort: 8080
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: fraiseql-secrets
                  key: database-url
            - name: JWT_SECRET
              valueFrom:
                secretKeyRef:
                  name: fraiseql-secrets
                  key: jwt-secret
          resources:
            requests:
              cpu: "500m"
              memory: "256Mi"
            limits:
              cpu: "2000m"
              memory: "1Gi"
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: fraiseql-api
spec:
  selector:
    app: fraiseql-api
  ports:
    - port: 80
      targetPort: 8080
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: fraiseql-api
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
    - hosts:
        - api.example.com
      secretName: fraiseql-tls
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: fraiseql-api
                port:
                  number: 80
```

### Secrets

```
apiVersion: v1
kind: Secret
metadata:
  name: fraiseql-secrets
type: Opaque
stringData:
  database-url: postgresql://user:pass@postgres:5432/mydb
  jwt-secret: your-256-bit-secret
```

## Cloud Platforms

### AWS (ECS/Fargate)

**Task Definition:**

```json
{
  "family": "fraiseql-api",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "2048",
  "containerDefinitions": [
    {
      "name": "api",
      "image": "your-ecr/fraiseql-api:latest",
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "RUST_LOG",
          "value": "info"
        }
      ],
      "secrets": [
        {
          "name": "DATABASE_URL",
          "valueFrom": "arn:aws:secretsmanager:region:account:secret:fraiseql/database-url"
        },
        {
          "name": "JWT_SECRET",
          "valueFrom": "arn:aws:secretsmanager:region:account:secret:fraiseql/jwt-secret"
        }
      ],
      "healthCheck": {
        "command": ["CMD-SHELL", "wget -qO- http://localhost:8080/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3
      },
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/fraiseql-api",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

### Google Cloud Run

```
# service.yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: fraiseql-api
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: "1"
        autoscaling.knative.dev/maxScale: "10"
    spec:
      containerConcurrency: 100
      containers:
        - image: gcr.io/your-project/fraiseql-api:latest
          ports:
            - containerPort: 8080
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: fraiseql-secrets
                  key: database-url
          resources:
            limits:
              cpu: "2"
              memory: 1Gi
```

Deploy:

```bash
gcloud run services replace service.yaml --region=us-central1
```

### Fly.io

```toml
# fly.toml
app = "fraiseql-api"
primary_region = "iad"

[build]
dockerfile = "Dockerfile"

[http_service]
internal_port = 8080
force_https = true
auto_stop_machines = false
auto_start_machines = true
min_machines_running = 2

[http_service.concurrency]
type = "requests"
soft_limit = 200
hard_limit = 250

[[services.http_checks]]
interval = "30s"
timeout = "5s"
path = "/health"

[[vm]]
cpu_kind = "shared"
cpus = 2
memory_mb = 1024
```

Deploy:

```bash
fly secrets set DATABASE_URL="..." JWT_SECRET="..."
fly deploy
```

## Database Migrations

### Production Migration Strategy

1. **Test migrations locally** against a copy of production data
2. **Create a backup** before migrating
3. **Run migrations** during low-traffic periods
4. **Monitor** for errors after migration

```bash
# Create backup
pg_dump $DATABASE_URL > backup-$(date +%Y%m%d).sql

# Run migrations
fraiseql migrate --env production

# Verify
fraiseql migrate status
```

### Zero-Downtime Migrations

For zero-downtime deployments:

1. **Add columns as nullable** first
2. **Deploy code** that handles both old and new schema
3. **Backfill data** for new columns
4. **Add constraints** after data is backfilled
5. **Remove old code paths**

## Health Checks

FraiseQL exposes health endpoints:

| Endpoint | Description |
|----------|-------------|
| `/health` | Overall health status |
| `/health/live` | Liveness probe (is process running) |
| `/health/ready` | Readiness probe (can accept traffic) |

```bash
curl http://localhost:8080/health
# {"status": "healthy", "database": "connected", "version": "1.0.0"}
```

## Scaling

### Horizontal Scaling

FraiseQL is stateless and scales horizontally:

```
# Kubernetes HPA
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: fraiseql-api
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: fraiseql-api
  minReplicas: 3
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

### Connection Pooling

For high-scale deployments, use external connection pooling:

```
# PgBouncer sidecar
- name: pgbouncer
  image: edoburu/pgbouncer:1.21.0
  env:
    - name: DATABASE_URL
      valueFrom:
        secretKeyRef:
          name: fraiseql-secrets
          key: database-url
    - name: POOL_MODE
      value: transaction
    - name: MAX_CLIENT_CONN
      value: "1000"
    - name: DEFAULT_POOL_SIZE
      value: "20"
```

## Security Checklist

- [ ] **TLS enabled** for all traffic
- [ ] **JWT secrets** are strong (256+ bits)
- [ ] **Database credentials** use secrets management
- [ ] **Network policies** restrict pod-to-pod traffic
- [ ] **Rate limiting** enabled at load balancer
- [ ] **Introspection disabled** in production
- [ ] **Playground disabled** in production
- [ ] **CORS origins** explicitly listed
- [ ] **SQL injection** prevented (parameterized queries)
- [ ] **Audit logging** enabled

## Monitoring

### Prometheus Metrics

```
# ServiceMonitor for Prometheus Operator
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: fraiseql-api
spec:
  selector:
    matchLabels:
      app: fraiseql-api
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
```

### Key Metrics

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `fraiseql_requests_total` | Total requests | - |
| `fraiseql_request_duration_seconds` | Request latency | p99 > 500ms |
| `fraiseql_db_pool_size` | Connection pool size | > 80% of max |
| `fraiseql_errors_total` | Error count | > 10/min |

## Next Steps

- [Performance](/guides/performance) — Optimize for production load
- [Troubleshooting](/guides/troubleshooting) — Debug production issues
- [Security](/features/security) — Production security hardening
