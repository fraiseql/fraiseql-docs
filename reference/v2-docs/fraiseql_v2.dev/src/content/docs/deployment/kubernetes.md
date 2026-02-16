---
title: Kubernetes Deployment
description: Deploy FraiseQL to Kubernetes with auto-scaling and high availability
---

# Kubernetes Deployment

Deploy FraiseQL to Kubernetes for enterprise-grade scalability and reliability.

## Prerequisites

- Kubernetes cluster (1.24+)
- `kubectl` CLI configured
- Docker image pushed to registry
- PostgreSQL database (managed or deployed in cluster)

## Quick Start (Helm)

For fastest setup, use Helm:

```bash
# Add FraiseQL Helm repository
helm repo add fraiseql https://charts.fraiseql.io
helm repo update

# Install FraiseQL
helm install fraiseql fraiseql/fraiseql \
  --namespace fraiseql \
  --create-namespace \
  --set database.url=postgresql://user:pass@postgres:5432/db \
  --set jwt.secret=$(openssl rand -base64 32) \
  --set image.tag=1.0.0 \
  --set replicas=3

# Verify
kubectl get pods -n fraiseql
kubectl get svc -n fraiseql
```

## Manual Kubernetes Setup

### Step 1: Create Namespace

```
# fraiseql-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: fraiseql
  labels:
    name: fraiseql
```

Apply:

```bash
kubectl apply -f fraiseql-namespace.yaml
```

### Step 2: Configure Secrets

Store sensitive data in Kubernetes Secrets:

```bash
# Create from .env file
kubectl create secret generic fraiseql-secrets \
  --from-literal=database-url='postgresql://user:pass@postgres:5432/db' \
  --from-literal=jwt-secret=$(openssl rand -base64 32) \
  --from-literal=cors-origins='https://example.com' \
  -n fraiseql

# Or from file
kubectl create secret generic fraiseql-secrets \
  --from-file=.env \
  -n fraiseql
```

### Step 3: Create ConfigMap

Store non-sensitive configuration:

```
# fraiseql-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fraiseql-config
  namespace: fraiseql
data:
  ENVIRONMENT: "production"
  LOG_LEVEL: "info"
  LOG_FORMAT: "json"
  PGBOUNCER_MIN_POOL_SIZE: "5"
  PGBOUNCER_MAX_POOL_SIZE: "20"
  RATE_LIMIT_REQUESTS: "10000"
  RATE_LIMIT_WINDOW_SECONDS: "60"
```

Apply:

```bash
kubectl apply -f fraiseql-config.yaml
```

### Step 4: Create Deployment

```
# fraiseql-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fraiseql
  namespace: fraiseql
  labels:
    app: fraiseql
    version: v1
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0  # Zero downtime deployments
  selector:
    matchLabels:
      app: fraiseql
  template:
    metadata:
      labels:
        app: fraiseql
        version: v1
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9000"
        prometheus.io/path: "/metrics"
    spec:
      # Service account (for RBAC if needed)
      serviceAccountName: fraiseql

      # Init container: Run migrations before starting
      initContainers:
        - name: migrate
          image: your-registry/fraiseql:1.0.0
          imagePullPolicy: IfNotPresent
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: fraiseql-secrets
                  key: database-url
          command:
            - python
            - -m
            - fraiseql
            - migrate

      containers:
        - name: fraiseql
          image: your-registry/fraiseql:1.0.0
          imagePullPolicy: IfNotPresent

          # Ports
          ports:
            - name: http
              containerPort: 8000
              protocol: TCP
            - name: metrics
              containerPort: 9000
              protocol: TCP

          # Environment variables
          env:
            # From secrets
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
            - name: CORS_ORIGINS
              valueFrom:
                secretKeyRef:
                  name: fraiseql-secrets
                  key: cors-origins

            # From configmap
            - name: ENVIRONMENT
              valueFrom:
                configMapKeyRef:
                  name: fraiseql-config
                  key: ENVIRONMENT
            - name: LOG_LEVEL
              valueFrom:
                configMapKeyRef:
                  name: fraiseql-config
                  key: LOG_LEVEL
            - name: LOG_FORMAT
              valueFrom:
                configMapKeyRef:
                  name: fraiseql-config
                  key: LOG_FORMAT
            - name: PGBOUNCER_MIN_POOL_SIZE
              valueFrom:
                configMapKeyRef:
                  name: fraiseql-config
                  key: PGBOUNCER_MIN_POOL_SIZE
            - name: PGBOUNCER_MAX_POOL_SIZE
              valueFrom:
                configMapKeyRef:
                  name: fraiseql-config
                  key: PGBOUNCER_MAX_POOL_SIZE

          # Resource requests & limits
          resources:
            requests:
              cpu: 500m           # Minimum 0.5 CPU
              memory: 512Mi       # Minimum 512MB
              ephemeral-storage: 100Mi
            limits:
              cpu: 2000m          # Maximum 2 CPUs
              memory: 2Gi         # Maximum 2GB
              ephemeral-storage: 500Mi

          # Startup probe: Give container 60s to start
          startupProbe:
            httpGet:
              path: /health/live
              port: http
            failureThreshold: 30
            periodSeconds: 2

          # Liveness probe: Restart if unhealthy
          livenessProbe:
            httpGet:
              path: /health/live
              port: http
            initialDelaySeconds: 10
            periodSeconds: 30
            timeoutSeconds: 10
            failureThreshold: 3

          # Readiness probe: Remove from service if not ready
          readinessProbe:
            httpGet:
              path: /health/ready
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 2

          # Graceful shutdown
          lifecycle:
            preStop:
              exec:
                command:
                  - sh
                  - -c
                  - sleep 15 && kill -TERM 1

          # Security context
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL

          # Volume mounts
          volumeMounts:
            - name: tmp
              mountPath: /tmp
            - name: var-tmp
              mountPath: /var/tmp

      # Pod disruption budget: Keep at least 2 replicas during disruptions
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                    - key: app
                      operator: In
                      values:
                        - fraiseql
                topologyKey: kubernetes.io/hostname

      # Volumes
      volumes:
        - name: tmp
          emptyDir: {}
        - name: var-tmp
          emptyDir: {}

      # Termination grace period: Allow 40s for graceful shutdown
      terminationGracePeriodSeconds: 40

      # DNS policy
      dnsPolicy: ClusterFirst

      # Security policy
      securityContext:
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
```

Apply:

```bash
kubectl apply -f fraiseql-deployment.yaml
```

### Step 5: Create Service

```
# fraiseql-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: fraiseql
  namespace: fraiseql
  labels:
    app: fraiseql
spec:
  type: ClusterIP
  selector:
    app: fraiseql
  ports:
    - name: http
      port: 8000
      targetPort: 8000
      protocol: TCP
    - name: metrics
      port: 9000
      targetPort: 9000
      protocol: TCP
  sessionAffinity: None
```

Apply:

```bash
kubectl apply -f fraiseql-service.yaml
```

### Step 6: Create Ingress

For external access with TLS:

```
# fraiseql-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: fraiseql
  namespace: fraiseql
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/rate-limit: "1000"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
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
                name: fraiseql
                port:
                  number: 8000
```

Apply:

```bash
kubectl apply -f fraiseql-ingress.yaml
```

## Auto-Scaling

### Horizontal Pod Autoscaler (HPA)

```
# fraiseql-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: fraiseql
  namespace: fraiseql
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: fraiseql
  minReplicas: 3
  maxReplicas: 10
  metrics:
    # Scale based on CPU usage
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    # Scale based on memory usage
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
    # Scale based on custom metric (requests per second)
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: "1000"
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 30
        - type: Pods
          value: 2
          periodSeconds: 30
```

Apply:

```bash
kubectl apply -f fraiseql-hpa.yaml

# View HPA status
kubectl get hpa -n fraiseql --watch
```

## Pod Disruption Budget

Ensure minimum availability during maintenance:

```
# fraiseql-pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: fraiseql
  namespace: fraiseql
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: fraiseql
```

Apply:

```bash
kubectl apply -f fraiseql-pdb.yaml
```

## Database in Kubernetes

### PostgreSQL StatefulSet (For testing only)

For production, use managed database (AWS RDS, Cloud SQL, Azure Database).

```
# postgres-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: fraiseql
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRES_DB
              value: fraiseql
            - name: POSTGRES_USER
              value: fraiseql
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: password
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
              subPath: postgres
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 50Gi
```

**Better approach: Use managed database**

```bash
# Update fraiseql-config with managed database URL
kubectl set env deployment/fraiseql \
  DATABASE_URL="postgresql://user:pass@managed-rds.amazonaws.com:5432/fraiseql" \
  -n fraiseql
```

## Monitoring

### Prometheus ServiceMonitor

```
# fraiseql-servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: fraiseql
  namespace: fraiseql
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app: fraiseql
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
```

## Logging

### Fluent Bit DaemonSet

```
# fluent-bit-daemonset.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit
  namespace: fraiseql
spec:
  selector:
    matchLabels:
      app: fluent-bit
  template:
    metadata:
      labels:
        app: fluent-bit
    spec:
      containers:
        - name: fluent-bit
          image: fluent/fluent-bit:latest
          volumeMounts:
            - name: varlog
              mountPath: /var/log
            - name: varlibdockercontainers
              mountPath: /var/lib/docker/containers
              readOnly: true
            - name: fluent-bit-config
              mountPath: /fluent-bit/etc/
      volumes:
        - name: varlog
          hostPath:
            path: /var/log
        - name: varlibdockercontainers
          hostPath:
            path: /var/lib/docker/containers
        - name: fluent-bit-config
          configMap:
            name: fluent-bit-config
```

## Rolling Updates

### Update image with zero downtime

```bash
# Set new image
kubectl set image deployment/fraiseql \
  fraiseql=your-registry/fraiseql:2.0.0 \
  -n fraiseql

# Monitor rollout
kubectl rollout status deployment/fraiseql -n fraiseql

# View history
kubectl rollout history deployment/fraiseql -n fraiseql

# Rollback if needed
kubectl rollout undo deployment/fraiseql -n fraiseql
```

## Network Policies

Restrict traffic between pods:

```
# fraiseql-networkpolicy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: fraiseql
  namespace: fraiseql
spec:
  podSelector:
    matchLabels:
      app: fraiseql
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow from ingress controller
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
      ports:
        - protocol: TCP
          port: 8000
  egress:
    # Allow to DNS
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: UDP
          port: 53
    # Allow to database
    - to:
        - podSelector:
            matchLabels:
              app: postgres
      ports:
        - protocol: TCP
          port: 5432
    # Allow to external APIs
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 443
```

## RBAC (Role-Based Access Control)

Create service account with minimal permissions:

```
# fraiseql-rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fraiseql
  namespace: fraiseql

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: fraiseql
  namespace: fraiseql
rules:
  # (typically empty for basic deployments)
  # Add rules only if your app needs to access K8s API

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: fraiseql
  namespace: fraiseql
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: fraiseql
subjects:
  - kind: ServiceAccount
    name: fraiseql
    namespace: fraiseql
```

## Backup Strategy

### Automatic Database Backups

```
# backup-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: fraiseql-backup
  namespace: fraiseql
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: fraiseql
          containers:
            - name: backup
              image: postgres:16-alpine
              env:
                - name: DATABASE_URL
                  valueFrom:
                    secretKeyRef:
                      name: fraiseql-secrets
                      key: database-url
              command:
                - /bin/sh
                - -c
                - |
                  pg_dump $DATABASE_URL | \
                  gzip > /backups/fraiseql-$(date +%Y%m%d-%H%M%S).sql.gz
              volumeMounts:
                - name: backups
                  mountPath: /backups
          volumes:
            - name: backups
              persistentVolumeClaim:
                claimName: backups-pvc
          restartPolicy: OnFailure
```

## Troubleshooting

### View pod logs

```bash
# Current logs
kubectl logs deployment/fraiseql -n fraiseql

# Previous logs (if pod crashed)
kubectl logs deployment/fraiseql -n fraiseql --previous

# Follow logs
kubectl logs deployment/fraiseql -n fraiseql -f

# Logs from specific pod
kubectl logs fraiseql-abc123-def456 -n fraiseql

# Logs from all pods
kubectl logs -l app=fraiseql -n fraiseql --all-containers
```

### Debug pod

```bash
# Describe pod (events, status)
kubectl describe pod fraiseql-abc123-def456 -n fraiseql

# Execute command in pod
kubectl exec -it fraiseql-abc123-def456 -n fraiseql -- bash

# Check environment variables
kubectl exec fraiseql-abc123-def456 -n fraiseql -- env | grep DATABASE
```

### Common Issues

**CrashLoopBackOff**: Pod keeps crashing
```bash
kubectl describe pod <pod-name> -n fraiseql
kubectl logs <pod-name> -n fraiseql --previous
# Check database connectivity, environment variables
```

**ImagePullBackOff**: Can't pull Docker image
```bash
# Verify image exists and registry credentials
kubectl create secret docker-registry regcred \
  --docker-server=your-registry \
  --docker-username=user \
  --docker-password=pass
# Add imagePullSecrets to deployment
```

**Pending**: Pod can't be scheduled
```bash
# Check resource availability
kubectl top nodes
kubectl describe node <node-name>
# May need to increase resource requests in deployment
```

## Production Checklist

- [ ] Use managed database (RDS, Cloud SQL)
- [ ] Configure HPA with appropriate metrics
- [ ] Set resource requests and limits
- [ ] Configure readiness and liveness probes
- [ ] Use Pod Disruption Budget
- [ ] Configure Network Policies
- [ ] Set up monitoring (Prometheus)
- [ ] Set up logging (ELK, CloudWatch, etc.)
- [ ] Configure automatic backups
- [ ] Set up SSL/TLS with cert-manager
- [ ] Test rolling updates
- [ ] Document runbooks for common issues

## Next Steps

- [AWS EKS Deployment](/deployment/aws#eks)
- [Google Cloud GKE Deployment](/deployment/gcp#gke)
- [Azure AKS Deployment](/deployment/azure#aks)
- [Monitoring & Observability](/deployment)