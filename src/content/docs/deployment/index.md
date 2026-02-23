---
title: Deployment Guides
description: Deploy FraiseQL to production on Docker, Kubernetes, AWS, GCP, or Azure
---

# Deployment Guides

Choose your deployment target based on your infrastructure preferences and scalability needs.

## Quick Comparison

| Platform | Best For | Setup Time | Scaling | Cost |
|----------|----------|-----------|---------|------|
| **Docker** | Development, small teams | 30 min | Manual | Low |
| **Kubernetes** | Enterprise, high traffic | 2-4 hours | Automatic | Medium |
| **AWS (ECS/Fargate)** | AWS-native, managed | 1-2 hours | Auto-scaling | Medium-High |
| **Google Cloud Run** | Serverless, event-driven | 30 min | Automatic | Pay-per-use |
| **Azure App Service** | Microsoft ecosystem | 1-2 hours | Auto-scaling | Medium |

## Deployment Checklist (All Platforms)

Before deploying to production:

- [ ] Environment variables configured (DATABASE_URL, JWT_SECRET, etc.)
- [ ] Database migrations completed
- [ ] Database connection pooling configured
- [ ] Health check endpoints enabled
- [ ] Logging configured (structured JSON logs)
- [ ] Monitoring/alerting setup (errors, latency, CPU)
- [ ] CORS configured properly
- [ ] Rate limiting enabled
- [ ] SSL/TLS certificates valid
- [ ] API keys/secrets stored in secrets manager (not .env)
- [ ] Database backups configured
- [ ] Rollback plan documented

## Environment Configuration

### Required Variables

```bash
# Database connection
DATABASE_URL=postgresql://user:pass@host:5432/dbname
# or for other databases:
# DATABASE_URL=mysql://user:pass@host:3306/dbname
# DATABASE_URL=sqlite:///./data/fraiseql.db
# DATABASE_URL=mssql://user:pass@host:1433/dbname

# Authentication
JWT_SECRET=your-secret-key-min-32-chars
CORS_ORIGINS=https://example.com,https://api.example.com

# Deployment
ENVIRONMENT=production
FRAISEQL_HOST=0.0.0.0
FRAISEQL_PORT=8000

# Optional: Logging
LOG_LEVEL=info
LOG_FORMAT=json

# Optional: Rate limiting
RATE_LIMIT_REQUESTS=1000
RATE_LIMIT_WINDOW_MINUTES=1

# Optional: NATS (if using events/subscriptions)
NATS_URL=nats://nats-server:4222
NATS_SUBJECT_PREFIX=fraiseql.events
```

### Secrets Management Best Practice

**NEVER commit secrets to version control.** Use:

- **Docker/Docker Compose**: Use `.env` file (in `.gitignore`), or secrets manager
- **Kubernetes**: Use Secrets or external secrets operator
- **AWS**: AWS Secrets Manager or Parameter Store
- **GCP**: Google Secret Manager
- **Azure**: Azure Key Vault

Example with AWS Secrets Manager:

```python
import boto3
import json

def get_secrets(secret_name: str) -> dict:
    client = boto3.client('secretsmanager')
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response['SecretString'])

# In your main.py:
secrets = get_secrets('fraiseql/prod')
app.config.jwt_secret = secrets['JWT_SECRET']
app.config.database_url = secrets['DATABASE_URL']
```

## Network Configuration

### Port Binding

FraiseQL listens on:
- **Port 8000** (default): GraphQL endpoint
- **Port 9000** (optional): Health check/metrics endpoint

### Health Checks

FraiseQL provides health check endpoints:

```bash
# Liveness check (is the service running?)
GET /health/live
# Response: 200 OK

# Readiness check (is it ready to serve traffic?)
GET /health/ready
# Response: 200 OK if database connected, else 503 Service Unavailable
```

Configure your orchestrator to use these endpoints for health checks.

### Graceful Shutdown

FraiseQL responds to SIGTERM signal and:
1. Stops accepting new requests
2. Waits up to 30 seconds for in-flight requests to complete
3. Closes database connections
4. Exits

Configure container/orchestrator shutdown timeout to at least 35 seconds.

## Database Connection Pooling

For production, FraiseQL automatically configures connection pooling:

```python
# Configuration via environment variables
PGBOUNCER_MIN_POOL_SIZE=5      # Minimum connections per database
PGBOUNCER_MAX_POOL_SIZE=20     # Maximum connections per database
PGBOUNCER_CONNECTION_TIMEOUT=30 # Seconds
```

### Recommended Pool Sizes

| Database | Min | Max | Per Server |
|----------|-----|-----|-----------|
| PostgreSQL | 5 | 20 | 100-200 |
| MySQL | 5 | 20 | 100-200 |
| SQLite | 1 | 5 | 10 |
| SQL Server | 5 | 20 | 100-200 |

For high-traffic applications (10k+ RPS), use external connection pooler:
- **PostgreSQL**: PgBouncer
- **MySQL**: ProxySQL or MaxScale
- **SQL Server**: SQL Server connection pooling (built-in)

## Logging Configuration

### Structured Logging

FraiseQL outputs JSON logs (enabled by default in production):

```json
{
  "timestamp": "2024-01-15T10:30:45Z",
  "level": "INFO",
  "message": "Request processed",
  "request_id": "abc123def456",
  "method": "POST",
  "path": "/graphql",
  "duration_ms": 145,
  "status": 200,
  "user_id": "user_123"
}
```

### Log Levels

```bash
# Environment: FRAISEQL_LOG_LEVEL
DEBUG   # Verbose: all database queries, middleware decisions
INFO    # Default: requests, errors, important events
WARN    # Warnings: slow queries, connection issues
ERROR   # Errors only: failures, exceptions
FATAL   # Critical issues only
```

### Log Aggregation Setup

**CloudWatch (AWS)**:
```bash
# In Docker: Use awslogs driver
# In Kubernetes: Use CloudWatch agent
```

**Stackdriver (GCP)**:
```bash
# Automatic if running on Cloud Run
# Manual setup for VMs
```

**Azure Monitor**:
```bash
# Automatic if running on App Service
# Container Insights for Kubernetes
```

## Monitoring & Observability

### Key Metrics to Monitor

```
GraphQL Queries (requests/sec)
├── Success rate
├── Error rate
├── p50, p95, p99 latency
└── Query complexity distribution

Database
├── Connection pool utilization
├── Query execution time
├── Transaction time
└── Slow queries (>500ms)

System
├── CPU usage
├── Memory usage
├── Disk space
└── Network I/O

NATS (if enabled)
├── Messages published/sec
├── Messages consumed/sec
├── Delivery errors
└── Consumer lag
```

### Prometheus Metrics

FraiseQL exports Prometheus metrics on `/metrics`:

```python
# Example scrape configuration
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'fraiseql'
    static_configs:
      - targets: ['localhost:9000']
```

### Alerting Rules

```
# Alert on high error rate
- alert: HighErrorRate
  expr: rate(fraiseql_errors_total[5m]) > 0.05
  for: 5m
  annotations:
    summary: "FraiseQL error rate above 5%"

# Alert on high latency
- alert: HighLatency
  expr: fraiseql_request_duration_seconds{quantile="0.95"} > 1
  for: 5m
  annotations:
    summary: "p95 latency above 1 second"

# Alert on database connection pool exhaustion
- alert: ConnectionPoolExhausted
  expr: fraiseql_db_connections_used / fraiseql_db_connections_max > 0.9
  for: 2m
  annotations:
    summary: "Database connection pool >90% full"
```

## Security in Production

### TLS/SSL Configuration

All external traffic must use HTTPS:

```bash
# Option 1: Reverse proxy (recommended)
# Use nginx, Caddy, or cloud load balancer with SSL termination

# Option 2: Application-level TLS
FRAISEQL_TLS_CERT=/etc/tls/cert.pem
FRAISEQL_TLS_KEY=/etc/tls/key.pem
FRAISEQL_TLS_PORT=8443
```

### CORS Configuration

```bash
# Allow specific origins only
CORS_ORIGINS=https://example.com,https://app.example.com

# Or: Allow any subdomain of example.com
# (set via code, not env var)
```

### Rate Limiting

Protect against abuse:

```bash
# Global rate limit
RATE_LIMIT_REQUESTS=10000
RATE_LIMIT_WINDOW_SECONDS=60

# Per-user rate limit (requires auth)
PER_USER_RATE_LIMIT=100
PER_USER_RATE_LIMIT_WINDOW_SECONDS=60

# Per-IP rate limit (unauthenticated)
PER_IP_RATE_LIMIT=50
PER_IP_RATE_LIMIT_WINDOW_SECONDS=60
```

### API Key Rotation

Implement key rotation schedule:

```
1. Generate new API key
2. Update client configuration (staged rollout)
3. Wait for all clients to switch
4. Revoke old key
```

## Scaling Strategies

### Horizontal Scaling (Multiple Instances)

For stateless FraiseQL deployment:

```
1. Deploy multiple instances
2. Use load balancer (distribute traffic)
3. All instances connect to same database
4. Share NATS connection for events
```

**Example with 3 instances**:
```
               Load Balancer
              /    |    \
          Pod1  Pod2  Pod3
             \    |    /
         Shared PostgreSQL
         (read replicas optional)
```

### Vertical Scaling (Bigger Instances)

Recommended when:
- Single instance can handle load (< 1000 RPS)
- Simplifies deployment
- Reduces operational overhead

**Limits**:
- Database connection pool limits
- Memory limits for request batching
- Network bandwidth

### Auto-Scaling Configuration

Most platforms support auto-scaling based on:
- **CPU usage** (target: 50-70%)
- **Memory usage** (target: 60-80%)
- **Request count** (scale on RPS threshold)
- **Custom metrics** (database connection pool, query latency)

## Backup & Disaster Recovery

### Database Backups

**PostgreSQL**:
```bash
# Automated backups with WAL archiving
pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME > backup.sql
# Or: Use managed PostgreSQL (AWS RDS, Google Cloud SQL) for automated backups
```

**MySQL**:
```bash
# Binary log backups
mysqldump -h $DB_HOST -u $DB_USER -p $DB_PASS $DB_NAME > backup.sql
# Or: Use managed MySQL (AWS RDS, Google Cloud SQL)
```

**SQLite**:
```bash
# File-based backup
cp /data/fraiseql.db /backups/fraiseql-$(date +%Y%m%d).db
# Keep 7-30 days of rolling backups
```

### Recovery Time Objectives (RTO)

| Strategy | RTO | RPO | Cost |
|----------|-----|-----|------|
| Manual backups | 4 hours | 1 day | Low |
| Automated daily | 2 hours | 1 day | Low |
| Continuous replication | 5 min | 1 min | High |
| Read replicas | 5 min | 0 min | High |

### Testing Backups

**Critical**: Test restore procedures regularly:

```bash
# Monthly: Restore backup to test environment
# Verify: All data present, no corruption
# Measure: Actual restore time
```

## Deployment Paths

Choose your deployment guide:


─


─


─


─


─


─

## Common Issues & Troubleshooting

### Connection Pool Exhaustion
**Symptom**: "Too many connections" errors
**Solution**: Increase `PGBOUNCER_MAX_POOL_SIZE`, verify clients closing connections properly

### Slow Queries
**Symptom**: p99 latency > 5 seconds
**Solution**: Check query complexity, add database indexes, analyze slow query logs

### Memory Leaks
**Symptom**: Memory usage grows over time
**Solution**: Check for unclosed connections, verify no circular references in schema

### Database Connection Lost
**Symptom**: Random "connection refused" errors
**Solution**: Configure connection retry logic, check database availability, verify network connectivity

See [Troubleshooting](/troubleshooting) for more common issues.

## Next Steps

1. Choose your deployment platform above
2. Follow the step-by-step guide
3. Test in staging environment first
4. Deploy to production with confidence
5. Monitor metrics and logs continuously
`3
`3