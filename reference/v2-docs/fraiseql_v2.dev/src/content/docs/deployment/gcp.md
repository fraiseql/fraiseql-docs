---
title: Google Cloud Platform Deployment
description: Deploy FraiseQL to Google Cloud Run, Cloud SQL, and GKE
---

# Google Cloud Platform Deployment

Deploy FraiseQL on Google Cloud Platform using serverless Cloud Run or Kubernetes Engine (GKE).

## Quick Start with Cloud Run (Fastest - 10 minutes)

### 1. Build and Push Docker Image to Artifact Registry

```bash
# Set project
export PROJECT_ID=$(gcloud config get-value project)
export REGION=us-central1

# Create Artifact Registry
gcloud artifacts repositories create fraiseql \
  --repository-format=docker \
  --location=$REGION

# Configure Docker auth
gcloud auth configure-docker $REGION-docker.pkg.dev

# Build and push
docker build -t fraiseql:latest .
docker tag fraiseql:latest \
  $REGION-docker.pkg.dev/$PROJECT_ID/fraiseql/fraiseql:latest
docker push $REGION-docker.pkg.dev/$PROJECT_ID/fraiseql/fraiseql:latest
```

### 2. Create Cloud SQL PostgreSQL Instance

```bash
# Create database instance
gcloud sql instances create fraiseql-prod \
  --database-version=POSTGRES_16 \
  --tier=db-f1-micro \
  --region=$REGION \
  --availability-type=REGIONAL \
  --backup-start-time=02:00 \
  --retained-backups-count=30 \
  --transaction-log-retention-days=7

# Create database
gcloud sql databases create fraiseql \
  --instance=fraiseql-prod

# Create database user
gcloud sql users create fraiseql \
  --instance=fraiseql-prod \
  --password="$(openssl rand -base64 32)"

# Get connection string
gcloud sql instances describe fraiseql-prod \
  --format='value(connectionName)'
```

### 3. Store Secrets in Secret Manager

```bash
# Create secrets
echo "postgresql://fraiseql:PASSWORD@/fraiseql?host=/cloudsql/PROJECT:REGION:fraiseql-prod" | \
  gcloud secrets create fraiseql-database-url --data-file=-

echo "$(openssl rand -base64 32)" | \
  gcloud secrets create fraiseql-jwt-secret --data-file=-

echo "https://app.example.com" | \
  gcloud secrets create fraiseql-cors-origins --data-file=-
```

### 4. Deploy to Cloud Run

```bash
# Deploy service
gcloud run deploy fraiseql \
  --image=$REGION-docker.pkg.dev/$PROJECT_ID/fraiseql/fraiseql:latest \
  --region=$REGION \
  --platform=managed \
  --memory=1Gi \
  --cpu=1 \
  --timeout=60 \
  --max-instances=100 \
  --min-instances=1 \
  --set-env-vars="ENVIRONMENT=production,LOG_LEVEL=info,LOG_FORMAT=json" \
  --set-secrets="DATABASE_URL=fraiseql-database-url:latest,JWT_SECRET=fraiseql-jwt-secret:latest,CORS_ORIGINS=fraiseql-cors-origins:latest" \
  --add-cloudsql-instances=$PROJECT_ID:$REGION:fraiseql-prod \
  --allow-unauthenticated

# Get service URL
gcloud run services describe fraiseql \
  --region=$REGION \
  --format='value(status.url)'
```

### 5. Configure Custom Domain

```bash
# Map custom domain
gcloud run domain-mappings create \
  --service=fraiseql \
  --domain=api.example.com \
  --region=$REGION

# Update DNS records (output from above command)
# Add CNAME record pointing to ghs.googleusercontent.com
```

## Full GCP Setup with Cloud Run + Cloud SQL

### Architecture

```
Cloud Load Balancer (optional, for multiple regions)
         ↓
Cloud Run (Serverless, auto-scaling)
         ↓
Cloud SQL PostgreSQL (Managed database)
```

### 1. Create VPC Network (for Cloud SQL private IP)

```bash
# Create VPC
gcloud compute networks create fraiseql-vpc \
  --subnet-mode=custom \
  --bgp-routing-mode=regional

# Create subnet
gcloud compute networks subnets create fraiseql-subnet \
  --network=fraiseql-vpc \
  --region=$REGION \
  --range=10.0.0.0/20

# Create Private Service Connection
gcloud compute addresses create fraiseql-db-range \
  --global \
  --purpose=VPC_PEERING \
  --prefix-length=16 \
  --network=fraiseql-vpc

gcloud services vpc-peerings connect \
  --service=servicenetworking.googleapis.com \
  --ranges=fraiseql-db-range \
  --network=fraiseql-vpc
```

### 2. Create Cloud SQL with Private IP

```bash
gcloud sql instances create fraiseql-prod \
  --database-version=POSTGRES_16 \
  --tier=db-custom-2-8192 \
  --region=$REGION \
  --network=fraiseql-vpc \
  --no-assign-ip \
  --availability-type=REGIONAL \
  --backup-start-time=02:00 \
  --retained-backups-count=30 \
  --transaction-log-retention-days=7 \
  --database-flags=cloudsql_iam_authentication=on
```

### 3. Enable Cloud SQL Proxy for Cloud Run

```bash
# Add Cloud Run service to IAM policy
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:$PROJECT_ID@appspot.gserviceaccount.com \
  --role=roles/cloudsql.client

# In Cloud Run, use unix socket connection:
# DATABASE_URL=postgresql://fraiseql:pass@/fraiseql?host=/cloudsql/PROJECT:REGION:instance-name
```

### 4. Configure Auto-Scaling

Cloud Run auto-scales automatically based on request count.

To customize:

```
# cloud-run-config.yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: fraiseql
  namespace: default
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: "1"
        autoscaling.knative.dev/maxScale: "100"
        autoscaling.knative.dev/targetUtilization: "0.7"
    spec:
      containerConcurrency: 80
      containers:
        - image: us-central1-docker.pkg.dev/PROJECT/fraiseql/fraiseql:latest
```

Apply:

```bash
gcloud run services replace cloud-run-config.yaml --region=$REGION
```

## Kubernetes Engine (GKE) Deployment

For more control and complex workloads:

### 1. Create GKE Cluster

```bash
# Create cluster
gcloud container clusters create fraiseql-cluster \
  --region=$REGION \
  --num-nodes=3 \
  --machine-type=n2-standard-2 \
  --enable-autoscaling \
  --min-nodes=3 \
  --max-nodes=10 \
  --enable-autorepair \
  --enable-autoupgrade \
  --enable-stackdriver-kubernetes \
  --addons=HttpLoadBalancing,HttpsLoadBalancing \
  --workload-pool=$PROJECT_ID.svc.id.goog \
  --enable-network-policy

# Get credentials
gcloud container clusters get-credentials fraiseql-cluster --region=$REGION
```

### 2. Deploy to GKE

Follow the [Kubernetes deployment guide](/deployment/kubernetes) with GCP-specific configuration:

```
# fraiseql-gke-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fraiseql
  namespace: default
spec:
  replicas: 3
  template:
    spec:
      serviceAccountName: fraiseql
      containers:
        - name: fraiseql
          image: us-central1-docker.pkg.dev/PROJECT/fraiseql/fraiseql:latest
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: fraiseql-secrets
                  key: database-url

---
apiVersion: v1
kind: Service
metadata:
  name: fraiseql
spec:
  type: LoadBalancer
  selector:
    app: fraiseql
  ports:
    - port: 80
      targetPort: 8000
```

Deploy:

```bash
# Store secrets
kubectl create secret generic fraiseql-secrets \
  --from-literal=database-url=$DATABASE_URL \
  --from-literal=jwt-secret=$JWT_SECRET

# Deploy
kubectl apply -f fraiseql-gke-deployment.yaml

# Check status
kubectl get services fraiseql
kubectl get pods
```python

## Monitoring & Logging

### Cloud Logging

Logs are automatically collected from Cloud Run and GKE.

View logs:

```bash
# Cloud Run logs
gcloud run logs read fraiseql --region=$REGION --limit=100

# GKE logs
kubectl logs deployment/fraiseql --all-containers --follow
```

### Cloud Monitoring (Stackdriver)

```bash
# Create alert policy (high error rate)
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="FraiseQL High Error Rate" \
  --condition-display-name="Error rate > 5%" \
  --condition-threshold-value=0.05 \
  --condition-threshold-filter='resource.type="cloud_run_revision" AND metric.type="run.googleapis.com/request_count" AND resource.label.service_name="fraiseql"'
```

### Cloud Trace

Enable distributed tracing:

```bash
# In your FraiseQL code, initialize tracer
from google.cloud import trace_v2

client = trace_v2.TraceServiceClient()
```

## Backup & Disaster Recovery

### Cloud SQL Automated Backups

```bash
# Configure backups (already set in creation)
gcloud sql instances patch fraiseql-prod \
  --backup-start-time=02:00 \
  --retained-backups-count=30

# Create on-demand backup
gcloud sql backups create \
  --instance=fraiseql-prod \
  --description="Manual backup"

# List backups
gcloud sql backups list --instance=fraiseql-prod

# Restore from backup
gcloud sql backups restore BACKUP_ID \
  --backup-instance=fraiseql-prod \
  --backup-id=BACKUP_ID
```

### Regional Database for High Availability

```bash
# Create read replica
gcloud sql instances create fraiseql-replica \
  --master-instance-name=fraiseql-prod \
  --tier=db-f1-micro \
  --region=us-west1  # Different region

# Promote replica to standalone
gcloud sql instances promote-replica fraiseql-replica
```

## Scaling & Performance

### Cloud Run Scaling

Cloud Run automatically scales based on request count.

For higher throughput:

```bash
# Increase maximum instances
gcloud run services update fraiseql \
  --max-instances=500 \
  --region=$REGION

# Set minimum instances (keeps instances warm)
gcloud run services update fraiseql \
  --min-instances=10 \
  --region=$REGION
```

### Cloud SQL Performance Insights

```bash
# Enable insights
gcloud sql instances patch fraiseql-prod \
  --enable-database-flags=cloudsql_insights_enabled=on

# View insights
gcloud sql operations list --instance=fraiseql-prod
```

## CI/CD Integration

### Cloud Build

Create build pipeline:

```
# cloudbuild.yaml
steps:
  # Build Docker image
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-t'
      - '$_IMAGE_NAME'
      - '.'

  # Push to Artifact Registry
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'push'
      - '$_IMAGE_NAME'

  # Deploy to Cloud Run
  - name: 'gcr.io/cloud-builders/gke-deploy'
    args:
      - 'run'
      - '--service='
      - 'fraiseql'
      - '--region=$_REGION'
      - '--image=$_IMAGE_NAME'

substitutions:
  _IMAGE_NAME: 'us-central1-docker.pkg.dev/$PROJECT_ID/fraiseql/fraiseql:$SHORT_SHA'
  _REGION: 'us-central1'

images:
  - '$_IMAGE_NAME'
```

Trigger from GitHub:

```bash
gcloud builds connect --repository-name=fraiseql \
  --repository-owner=your-github-org \
  --region=$REGION
```bash

## Cost Optimization

### Cloud Run Pricing

- **Invocations**: $0.40 per 1 million requests
- **Compute time**: $0.00001667 per CPU-second
- **Memory**: $0.0000025 per GB-second

Examples:

```bash
1 request at 1 CPU for 1 second = $0.00001667
100,000 requests/month = $0.04
```bash

**Optimization**:
- Use `min-instances=0` to save on idle time
- Lower CPU allocation for I/O-bound apps
- Cache responses at load balancer

### Cloud SQL Pricing

- Shared core: $8/month (dev only)
- db-f1-micro: $28/month (small production)
- db-custom-2-8192: $150+/month (medium workloads)

**Optimization**:
- Use shared-core for development
- Enable automated backups (cheaper than manual)
- Use preemptible VMs if availability not critical

## Troubleshooting

### Cloud Run Deployment Issues

```bash
# Check service status
gcloud run services describe fraiseql --region=$REGION

# View recent deployments
gcloud run revisions list --service=fraiseql --region=$REGION

# View logs during deployment
gcloud builds log $(gcloud builds list --limit=1 --format='value(id)')
```

### Connection to Cloud SQL

```bash
# Test connection from Cloud Run
gcloud run exec --service=fraiseql \
  --region=$REGION \
  -- psql $DATABASE_URL
```

### Memory Issues

```bash
# Increase memory
gcloud run services update fraiseql \
  --memory=2Gi \
  --region=$REGION
```

## Production Checklist

- [ ] Cloud SQL automated backups enabled
- [ ] Secrets stored in Secret Manager
- [ ] IAM roles configured (least privilege)
- [ ] Cloud Monitoring alerts configured
- [ ] Cloud Logging retention set
- [ ] Read replica in different region
- [ ] VPC network configured (if using private SQL)
- [ ] Cloud Armor security policies (if needed)
- [ ] Cloud CDN enabled (for static content)
- [ ] Load testing completed
- [ ] Disaster recovery plan documented

## Comparison: Cloud Run vs GKE

| Feature | Cloud Run | GKE |
|---------|-----------|-----|
| Setup time | 5 minutes | 30 minutes |
| Scaling | Automatic | Manual/Automatic |
| Price (low traffic) | $0.04/month | $200+/month |
| Price (high traffic) | $0.40/M requests | Better for sustained load |
| Latency | 100-500ms cold start | Low (warm) |
| Customization | Limited | Full control |
| Multi-region | Easy | More complex |

**Recommendation**:
- **Cloud Run**: Best for most applications, especially if traffic is variable
- **GKE**: Best for predictable high traffic, complex deployments, multi-region

## Next Steps

- **CI/CD**: Set up Cloud Build triggers for automatic deployments
- **Monitoring**: Configure Cloud Monitoring dashboards
- **Security**: Set up Cloud Armor for DDoS protection
- **Multi-region**: Deploy to multiple regions with Cloud Load Balancing