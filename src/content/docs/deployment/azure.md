---
title: Azure Deployment
description: Deploy FraiseQL to Azure App Service, Container Instances, and AKS
---

# Azure Deployment

Deploy FraiseQL on Azure using App Service, Container Instances, or Kubernetes Service (AKS).

## Quick Start with App Service (15 minutes)

### 1. Create Azure Container Registry

```bash
# Set variables
RESOURCE_GROUP=fraiseql-rg
REGION=eastus
REGISTRY_NAME=fraiseqlregistry

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $REGION

# Create container registry
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $REGISTRY_NAME \
  --sku Standard

# Build and push Docker image
az acr build \
  --registry $REGISTRY_NAME \
  --image fraiseql:latest .

# Get login credentials
az acr credential show \
  --name $REGISTRY_NAME
```

### 2. Create Azure Database for PostgreSQL

```bash
# Create PostgreSQL server
az postgres server create \
  --resource-group $RESOURCE_GROUP \
  --name fraiseql-prod \
  --location $REGION \
  --admin-user fraiseql \
  --admin-password "$(openssl rand -base64 32)" \
  --sku-name B_Gen5_1 \
  --storage-size 51200 \
  --backup-retention 30 \
  --geo-redundant-backup Enabled

# Create database
az postgres db create \
  --resource-group $RESOURCE_GROUP \
  --server-name fraiseql-prod \
  --name fraiseql

# Configure firewall to allow Azure services
az postgres server firewall-rule create \
  --resource-group $RESOURCE_GROUP \
  --server-name fraiseql-prod \
  --name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0

# Get connection string
az postgres server show-connection-string \
  --server-name fraiseql-prod \
  --admin-user fraiseql
```

### 3. Create App Service Plan

```bash
# Create App Service Plan
az appservice plan create \
  --name fraiseql-plan \
  --resource-group $RESOURCE_GROUP \
  --is-linux \
  --sku P1V2 \
  --number-of-workers 3
```

### 4. Create Web App

```bash
# Create web app
az webapp create \
  --resource-group $RESOURCE_GROUP \
  --plan fraiseql-plan \
  --name fraiseql-prod \
  --deployment-container-image-name \
    $REGISTRY_NAME.azurecr.io/fraiseql:latest

# Configure container registry
az webapp config container set \
  --name fraiseql-prod \
  --resource-group $RESOURCE_GROUP \
  --docker-custom-image-name $REGISTRY_NAME.azurecr.io/fraiseql:latest \
  --docker-registry-server-url https://$REGISTRY_NAME.azurecr.io \
  --docker-registry-server-user $(az acr credential show -n $REGISTRY_NAME --query username -o tsv) \
  --docker-registry-server-password $(az acr credential show -n $REGISTRY_NAME --query 'passwords[0].value' -o tsv)
```

### 5. Configure Environment Variables

```bash
# Set application settings
az webapp config appsettings set \
  --resource-group $RESOURCE_GROUP \
  --name fraiseql-prod \
  --settings \
    ENVIRONMENT=production \
    LOG_LEVEL=info \
    LOG_FORMAT=json \
    WEBSITES_ENABLE_APP_SERVICE_STORAGE=false \
    DOCKER_ENABLE_CI=true \
    DOCKER_REGISTRY_SERVER_URL=https://$REGISTRY_NAME.azurecr.io

# Set secrets (from Key Vault)
az keyvault secret set \
  --vault-name fraiseql-kv \
  --name DatabaseUrl \
  --value "postgresql://fraiseql:password@fraiseql-prod.postgres.database.azure.com:5432/fraiseql"

az keyvault secret set \
  --vault-name fraiseql-kv \
  --name JwtSecret \
  --value "$(openssl rand -base64 32)"
```

### 6. Configure Health Checks

```bash
# Enable health check
az webapp config set \
  --resource-group $RESOURCE_GROUP \
  --name fraiseql-prod \
  --generic-configurations '{"HealthCheckPath": "/health/ready"}'
```

### 7. Configure Auto-Scaling

```bash
# Create auto-scale settings
az monitor autoscale create \
  --resource-group $RESOURCE_GROUP \
  --resource fraiseql-prod \
  --resource-type "Microsoft.Web/sites" \
  --name fraiseql-autoscale \
  --min-count 3 \
  --max-count 10 \
  --count 3

# Add scale-up rule (CPU > 70%)
az monitor autoscale rule create \
  --resource-group $RESOURCE_GROUP \
  --autoscale-name fraiseql-autoscale \
  --condition "Percentage CPU > 70 avg 5m" \
  --scale out 1

# Add scale-down rule (CPU < 30%)
az monitor autoscale rule create \
  --resource-group $RESOURCE_GROUP \
  --autoscale-name fraiseql-autoscale \
  --condition "Percentage CPU < 30 avg 5m" \
  --scale in 1
```

## Advanced Azure Setup with Key Vault

### 1. Create Azure Key Vault

```bash
# Create Key Vault
az keyvault create \
  --resource-group $RESOURCE_GROUP \
  --name fraiseql-kv \
  --location $REGION

# Create secrets
az keyvault secret set \
  --vault-name fraiseql-kv \
  --name database-url \
  --value "postgresql://user:pass@host/db"

az keyvault secret set \
  --vault-name fraiseql-kv \
  --name jwt-secret \
  --value "$(openssl rand -base64 32)"

az keyvault secret set \
  --vault-name fraiseql-kv \
  --name cors-origins \
  --value "https://app.example.com"
```

### 2. Create Managed Identity

```bash
# Create managed identity
az identity create \
  --resource-group $RESOURCE_GROUP \
  --name fraiseql-identity

# Get identity ID
IDENTITY_ID=$(az identity show \
  --resource-group $RESOURCE_GROUP \
  --name fraiseql-identity \
  --query id -o tsv)

# Assign to App Service
az webapp identity assign \
  --resource-group $RESOURCE_GROUP \
  --name fraiseql-prod \
  --identities $IDENTITY_ID

# Grant Key Vault access
az keyvault set-policy \
  --name fraiseql-kv \
  --object-id $(az identity show \
    --resource-group $RESOURCE_GROUP \
    --name fraiseql-identity \
    --query principalId -o tsv) \
  --secret-permissions get
```

### 3. Reference Secrets in App Service

In your FraiseQL code, use managed identity:

```python
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

credential = DefaultAzureCredential()
client = SecretClient(
    vault_url="https://fraiseql-kv.vault.azure.net/",
    credential=credential
)

database_url = client.get_secret("database-url").value
jwt_secret = client.get_secret("jwt-secret").value
```

Or set App Service app settings to reference Key Vault:

```bash
az webapp config appsettings set \
  --resource-group $RESOURCE_GROUP \
  --name fraiseql-prod \
  --settings \
    DATABASE_URL="@Microsoft.KeyVault(SecretUri=https://fraiseql-kv.vault.azure.net/secrets/database-url/)" \
    JWT_SECRET="@Microsoft.KeyVault(SecretUri=https://fraiseql-kv.vault.azure.net/secrets/jwt-secret/)"
```

## Kubernetes Service (AKS) Deployment

For complex workloads requiring Kubernetes:

### 1. Create AKS Cluster

```bash
# Create AKS cluster
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name fraiseql-aks \
  --node-count 3 \
  --vm-set-type VirtualMachineScaleSets \
  --load-balancer-sku standard \
  --enable-managed-identity \
  --network-plugin azure \
  --enable-addons monitoring,azure-policy \
  --enable-app-routing \
  --docker-bridge-address 172.17.0.1/16 \
  --service-principal ... \
  --client-secret ...

# Get credentials
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name fraiseql-aks \
  --overwrite-existing
```

### 2. Deploy to AKS

Follow the [Kubernetes deployment guide](/deployment/kubernetes) with Azure-specific steps:

```
# fraiseql-aks-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fraiseql
spec:
  replicas: 3
  template:
    spec:
      serviceAccountName: fraiseql
      containers:
        - name: fraiseql
          image: fraiseqlregistry.azurecr.io/fraiseql:latest
          resources:
            requests:
              cpu: 500m
              memory: 512Mi
            limits:
              cpu: 2000m
              memory: 2Gi
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

---
apiVersion: v1
kind: Service
metadata:
  name: fraiseql
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 8000
  selector:
    app: fraiseql
```

Deploy:

```bash
# Create secrets
kubectl create secret generic fraiseql-secrets \
  --from-literal=database-url="postgresql://user:pass@host/db" \
  --from-literal=jwt-secret="$(openssl rand -base64 32)"

# Deploy
kubectl apply -f fraiseql-aks-deployment.yaml

# Check status
kubectl get services
kubectl get pods
```

### 3. Enable HTTPS with Application Gateway

```bash
# Create Application Gateway
az network application-gateway create \
  --name fraiseql-gateway \
  --location $REGION \
  --resource-group $RESOURCE_GROUP \
  --vnet-name fraiseql-vnet \
  --subnet gateway-subnet \
  --capacity 2 \
  --sku Standard_v2 \
  --http-settings-cookie-based-affinity Disabled \
  --frontend-port 443 \
  --http-settings-port 8000 \
  --http-settings-protocol Http
```

## App Service Deployment Slots

For zero-downtime deployments:

```bash
# Create staging slot
az webapp deployment slot create \
  --resource-group $RESOURCE_GROUP \
  --name fraiseql-prod \
  --slot staging

# Deploy to staging
az webapp config container set \
  --name fraiseql-prod \
  --resource-group $RESOURCE_GROUP \
  --slot staging \
  --docker-custom-image-name $REGISTRY_NAME.azurecr.io/fraiseql:staging

# Swap to production (when ready)
az webapp deployment slot swap \
  --resource-group $RESOURCE_GROUP \
  --name fraiseql-prod \
  --slot staging
```

## Azure DevOps CI/CD

### Create Build Pipeline

```
# azure-pipelines.yml
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

stages:
  - stage: Build
    jobs:
      - job: BuildAndPush
        steps:
          - task: Docker@2
            inputs:
              containerRegistry: 'fraiseql-acr'
              repository: 'fraiseql'
              command: 'buildAndPush'
              Dockerfile: 'Dockerfile'
              tags: '$(Build.BuildId)'

  - stage: Deploy
    dependsOn: Build
    jobs:
      - deployment: DeployToAppService
        environment: production
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureAppServiceSettings@1
                  inputs:
                    azureSubscription: 'Azure Subscription'
                    appName: 'fraiseql-prod'
                    resourceGroupName: $RESOURCE_GROUP

                - task: AzureRmWebAppDeployment@4
                  inputs:
                    azureSubscription: 'Azure Subscription'
                    appType: 'webAppContainer'
                    WebAppName: 'fraiseql-prod'
```

## Monitoring & Logging

### Azure Monitor

```bash
# Create action group for alerts
az monitor action-group create \
  --name fraiseql-alerts \
  --resource-group $RESOURCE_GROUP

# Create metric alert (high CPU)
az monitor metrics alert create \
  --name fraiseql-high-cpu \
  --resource-group $RESOURCE_GROUP \
  --scopes /subscriptions/{subid}/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/fraiseql-prod \
  --description "Alert when CPU > 70%" \
  --condition "avg Percentage CPU > 70" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action fraiseql-alerts
```

### Application Insights

```bash
# Create Application Insights
az monitor app-insights component create \
  --app fraiseql-insights \
  --location $REGION \
  --resource-group $RESOURCE_GROUP

# Link to App Service
az webapp config appsettings set \
  --resource-group $RESOURCE_GROUP \
  --name fraiseql-prod \
  --settings APPINSIGHTS_INSTRUMENTATIONKEY=$(az monitor app-insights component show \
    --app fraiseql-insights \
    --resource-group $RESOURCE_GROUP \
    --query instrumentationKey -o tsv)
```

### Log Analytics

```bash
# Create Log Analytics workspace
az monitor log-analytics workspace create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name fraiseql-logs

# View logs
az monitor log-analytics query \
  --workspace fraiseql-logs \
  --analytics-query "ContainerLog | where time > ago(1h)"
```

## Backup & Disaster Recovery

### Database Backups

```bash
# View automatic backups
az postgres server backup show \
  --resource-group $RESOURCE_GROUP \
  --server-name fraiseql-prod

# Restore from backup
az postgres server restore \
  --resource-group $RESOURCE_GROUP \
  --name fraiseql-restored \
  --source-server fraiseql-prod \
  --restore-point-in-time "2024-01-15T12:00:00"

# Enable geo-redundant backups (already done in creation)
# Allows restore in different region if primary region fails
```

### Failover to Replica

```bash
# Create read replica in different region
az postgres server replica create \
  --name fraiseql-replica \
  --resource-group $RESOURCE_GROUP \
  --source-server fraiseql-prod \
  --location westus

# Promote replica to standalone (if primary fails)
az postgres server promote-replica \
  --name fraiseql-replica \
  --resource-group $RESOURCE_GROUP
```

## Cost Optimization

### Reserved Instances

```bash
# Purchase reserved instances (1-3 year commitment)
# Typical savings: 30-60%
az reservations reservation list
```

### Spot Instances (for non-critical workloads)

```bash
# Use spot instances in AKS
az aks nodepool add \
  --resource-group $RESOURCE_GROUP \
  --cluster-name fraiseql-aks \
  --name spotnodepool \
  --priority Spot \
  --eviction-policy Delete \
  --max-surge 33 \
  --max-unavailable 33
```

## Troubleshooting

### Check App Service Status

```bash
# View logs
az webapp log tail \
  --resource-group $RESOURCE_GROUP \
  --name fraiseql-prod

# View deployment logs
az webapp deployment log show \
  --resource-group $RESOURCE_GROUP \
  --name fraiseql-prod

# Restart app
az webapp restart \
  --resource-group $RESOURCE_GROUP \
  --name fraiseql-prod
```

### Database Connection Issues

```bash
# Test connection
psql "postgresql://fraiseql@fraiseql-prod:password@fraiseql-prod.postgres.database.azure.com:5432/fraiseql"

# Check firewall rules
az postgres server firewall-rule list \
  --resource-group $RESOURCE_GROUP \
  --server-name fraiseql-prod
```

### Container Image Issues

```bash
# Check image in registry
az acr repository list \
  --name $REGISTRY_NAME

# View image tags
az acr repository show-tags \
  --name $REGISTRY_NAME \
  --repository fraiseql
```

## Production Checklist

- [ ] Use Premium tier App Service Plan (for better SLA)
- [ ] Enable geographic redundancy for databases
- [ ] Configure Application Insights monitoring
- [ ] Set up Log Analytics for log aggregation
- [ ] Enable Key Vault for secrets management
- [ ] Configure auto-scaling based on metrics
- [ ] Set up deployment slots for zero-downtime deploys
- [ ] Enable Azure Backup for App Service
- [ ] Configure firewall rules appropriately
- [ ] Set up Azure DevOps CI/CD pipeline
- [ ] Test failover and recovery procedures

## Next Steps

- **CI/CD**: Set up Azure DevOps pipelines for automatic deployments
- **Monitoring**: Create custom dashboards in Azure Monitor
- **Security**: Configure Azure Security Center recommendations
- **Multi-region**: Set up traffic manager for global distribution
