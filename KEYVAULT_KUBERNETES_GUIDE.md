# Using Azure Key Vault Secrets in Kubernetes

Complete guide for managing and using Azure Key Vault secrets in your Titanic API Kubernetes deployment.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Setup & Configuration](#setup--configuration)
4. [Methods to Use Secrets](#methods-to-use-secrets)
5. [Deployment Examples](#deployment-examples)
6. [Best Practices](#best-practices)
7. [Troubleshooting](#troubleshooting)
8. [Security Considerations](#security-considerations)

---

## Overview

### What's Stored in Key Vault

The Terraform configuration automatically stores these secrets:

```
titanic-kv-prod/
├─ db-password              → PostgreSQL admin password
├─ db-connection-string     → Full connection string
├─ flask-secret-key        → Flask session encryption key
└─ (Extensible for API keys, JWT tokens, etc.)
```

### Access Control

- ✅ **Terraform**: Full admin access (create/update/delete secrets)
- ✅ **AKS Cluster**: Read-only access (get/list secrets only)
- ✅ **Pod Identity**: Automatic authentication via managed identity

### Three Methods to Use Secrets

```
1. Azure Key Vault Provider for Kubernetes Secrets (Recommended)
   └─ Syncs Key Vault → Kubernetes Secrets automatically
   
2. Pod Identity (Workload Identity)
   └─ Pods authenticate directly to Key Vault
   
3. Environment Variables
   └─ Explicit secret injection from Key Vault
```

---

## Architecture

### How Secrets Flow to Pods

```
┌──────────────────────────────┐
│   Azure Key Vault (prod)     │
│                              │
│  ├─ db-password             │
│  ├─ db-connection-string    │
│  └─ flask-secret-key        │
└────────────┬─────────────────┘
             │
             ▼
┌──────────────────────────────────────────┐
│  Kubernetes Cluster (AKS)                │
│                                          │
│  ┌─────────────────────────────────┐   │
│  │  Key Vault Provider DaemonSet   │   │
│  │  (CSI Driver)                   │   │
│  │                                 │   │
│  │  Every 15min:                   │   │
│  │  1. Fetch from Key Vault        │   │
│  │  2. Create K8s Secrets          │   │
│  │  3. Sync changes                │   │
│  └────────────┬────────────────────┘   │
│               │                         │
│               ▼                         │
│  ┌──────────────────────────────┐     │
│  │  Kubernetes Secrets          │     │
│  │                              │     │
│  │  ├─ kv-db-password           │     │
│  │  ├─ kv-db-connection-string  │     │
│  │  └─ kv-flask-secret-key      │     │
│  └────────────┬─────────────────┘     │
│               │                         │
│               ▼                         │
│  ┌──────────────────────────────┐     │
│  │  Titanic API Pod             │     │
│  │                              │     │
│  │  Environment Variables:      │     │
│  │  ├─ DATABASE_URL             │     │
│  │  ├─ FLASK_SECRET_KEY         │     │
│  │  └─ DB_PASSWORD              │     │
│  └──────────────────────────────┘     │
│                                        │
└────────────────────────────────────────┘
```

### Authentication Flow

```
Pod Request:
1. Pod starts with Workload Identity enabled
2. Pod requests token from local metadata server
3. Metadata server contacts Azure AD
4. Azure AD returns token for Key Vault
5. Pod authenticates to Key Vault
6. Pod receives secret

Note: No explicit credentials stored in pod or config!
```

---

## Setup & Configuration

### Prerequisites

1. **Azure Key Vault** (created by Terraform)
   ```bash
   # Verify Key Vault exists
   az keyvault list --resource-group <rg-name>
   ```

2. **AKS Cluster with managed identity enabled** (default)
   ```bash
   # Check cluster identity
   az aks show --resource-group <rg-name> --name <cluster-name> \
     --query identity.principalId
   ```

3. **Key Vault Provider for Secrets CSI Driver** (optional, recommended)
   ```bash
   # Check if installed
   kubectl get deployment -n kube-system | grep csi
   ```

---

### Method 1: Key Vault Provider for Kubernetes (CSI Driver) ⭐ Recommended

#### Step 1: Install the CSI Driver

```bash
# Add Helm repo
helm repo add csi-secrets-store-provider-azure https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/master/charts
helm repo update

# Install CSI driver
helm install csi-secrets-store-provider-azure/csi-secrets-store-provider-azure \
  --namespace kube-system \
  --set secrets-store-csi-driver.syncSecret.enabled=true

# Verify installation
kubectl get pods -n kube-system | grep csi
```

#### Step 2: Create SecretProviderClass

```yaml
# k8s/secretproviderclass.yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: titanic-kv-secrets
  namespace: titanic-api
spec:
  provider: azure
  parameters:
    usePodIdentity: "true"                    # Use workload identity
    keyvaultName: titanic-kv-prod             # Your Key Vault name
    cloudName: AzurePublicCloud
    objects: |
      array:
        - |
          objectName: db-password
          objectType: secret
          objectAlias: DB_PASSWORD
        - |
          objectName: db-connection-string
          objectType: secret
          objectAlias: DATABASE_URL
        - |
          objectName: flask-secret-key
          objectType: secret
          objectAlias: FLASK_SECRET_KEY
  
  # Optional: Sync to Kubernetes Secrets
  secretObjects:
  - secretKey: db-password
    objectName: db-password
    data: true
  - secretKey: database-url
    objectName: db-connection-string
    data: true
  - secretKey: flask-secret-key
    objectName: flask-secret-key
    data: true
```

#### Step 3: Update Deployment to Mount Secrets

```yaml
# k8s/deployment-app.yaml (snippet)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: titanic-api
  namespace: titanic-api
spec:
  template:
    spec:
      serviceAccountName: titanic-api-sa
      containers:
      - name: app
        image: titanic-api:latest
        
        # Mount secrets as volume
        volumeMounts:
        - name: secrets-store
          mountPath: /mnt/secrets
          readOnly: true
        
        # Read from mounted files
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: titanic-api-secrets  # K8s secret (synced from KV)
              key: database-url
        - name: FLASK_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: titanic-api-secrets
              key: flask-secret-key
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: titanic-api-secrets
              key: db-password
      
      volumes:
      - name: secrets-store
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: "titanic-kv-secrets"
```

#### Step 4: Deploy

```bash
# Apply SecretProviderClass
kubectl apply -f k8s/secretproviderclass.yaml

# Deploy application (will auto-sync secrets)
kubectl apply -f k8s/deployment-app.yaml

# Verify secrets are created
kubectl get secrets -n titanic-api
kubectl describe secret titanic-api-secrets -n titanic-api
```

---

### Method 2: Workload Identity (Direct Authentication)

#### Step 1: Create Workload Identity

```bash
# Get AKS details
RESOURCE_GROUP=<your-rg>
AKS_NAME=<your-aks-cluster>
NAMESPACE=titanic-api
SERVICE_ACCOUNT=titanic-api-sa

# Get tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)

# Create service account with workload identity
kubectl annotate serviceaccount $SERVICE_ACCOUNT \
  azure.workload.identity/client-id=$CLIENT_ID \
  -n $NAMESPACE

# Create Azure AD app identity
az ad app create --display-name "titanic-api-workload"
CLIENT_ID=$(az ad app list --query "[?displayName=='titanic-api-workload'].appId" -o tsv)

# Create federated credential
az identity federated-credential create \
  --identity-name titanic-api-identity \
  --issuer https://oidc.prod.workload.azure.com/$TENANT_ID/service-accounts/$NAMESPACE/$SERVICE_ACCOUNT/ \
  --subject system:serviceaccount:$NAMESPACE:$SERVICE_ACCOUNT \
  --resource-group $RESOURCE_GROUP
```

#### Step 2: Update Pod Spec

```yaml
# k8s/deployment-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: titanic-api
  namespace: titanic-api
spec:
  template:
    metadata:
      labels:
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: titanic-api-sa
      containers:
      - name: app
        image: titanic-api:latest
        env:
        - name: AZURE_CLIENT_ID
          value: <CLIENT_ID>
        - name: AZURE_TENANT_ID
          value: <TENANT_ID>
        - name: AZURE_AUTHORITY_HOST
          value: https://login.microsoftonline.com
```

---

### Method 3: Environment Variables (Manual)

#### Step 1: Create Kubernetes Secrets Manually

```bash
# Get secrets from Key Vault
DB_PASSWORD=$(az keyvault secret show --name db-password \
  --vault-name titanic-kv-prod --query value -o tsv)
DB_CONN_STR=$(az keyvault secret show --name db-connection-string \
  --vault-name titanic-kv-prod --query value -o tsv)
FLASK_KEY=$(az keyvault secret show --name flask-secret-key \
  --vault-name titanic-kv-prod --query value -o tsv)

# Create Kubernetes Secret
kubectl create secret generic titanic-api-secrets \
  --from-literal=db-password="$DB_PASSWORD" \
  --from-literal=database-url="$DB_CONN_STR" \
  --from-literal=flask-secret-key="$FLASK_KEY" \
  -n titanic-api
```

#### Step 2: Use in Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: titanic-api
spec:
  template:
    spec:
      containers:
      - name: app
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: titanic-api-secrets
              key: database-url
        - name: FLASK_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: titanic-api-secrets
              key: flask-secret-key
```

---

## Methods to Use Secrets

### In Deployment Specifications

#### As Environment Variables

```yaml
env:
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: titanic-api-secrets
      key: database-url

- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: titanic-api-secrets
      key: db-password

- name: FLASK_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: titanic-api-secrets
      key: flask-secret-key
```

#### As Volume Mounts

```yaml
volumeMounts:
- name: secrets-store
  mountPath: /mnt/secrets
  readOnly: true

volumes:
- name: secrets-store
  secret:
    secretName: titanic-api-secrets
    items:
    - key: database-url
      path: database-url.txt
    - key: db-password
      path: db-password.txt
    - key: flask-secret-key
      path: flask-secret-key.txt
```

#### From CSI Driver (Recommended)

```yaml
volumeMounts:
- name: secrets-store
  mountPath: /mnt/secrets
  readOnly: true

volumes:
- name: secrets-store
  csi:
    driver: secrets-store.csi.k8s.io
    readOnly: true
    volumeAttributes:
      secretProviderClass: "titanic-kv-secrets"
```

### In Application Code

#### Python (Flask)

```python
# src/app.py
import os
from pathlib import Path

# Read from environment variable
database_url = os.environ.get('DATABASE_URL')
flask_secret = os.environ.get('FLASK_SECRET_KEY')

# Or read from mounted file (CSI Driver)
def read_secret(path):
    try:
        with open(f'/mnt/secrets/{path}', 'r') as f:
            return f.read().strip()
    except FileNotFoundError:
        return os.environ.get(path.upper().replace('-', '_'))

db_password = read_secret('db-password')
database_url = read_secret('db-connection-string')
```

#### With Flask Config

```python
# src/config.py
import os

class ProductionConfig:
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL')
    SECRET_KEY = os.environ.get('FLASK_SECRET_KEY')
    
    # Or from file
    if not SECRET_KEY:
        try:
            with open('/mnt/secrets/flask-secret-key', 'r') as f:
                SECRET_KEY = f.read().strip()
        except FileNotFoundError:
            SECRET_KEY = 'default-insecure-key'  # Should never happen in prod
```

---

## Deployment Examples

### Complete Example: CSI Driver Method (Recommended)

#### 1. Create SecretProviderClass

```bash
cat > k8s/secretproviderclass.yaml <<'EOF'
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: titanic-kv-secrets
  namespace: titanic-api
spec:
  provider: azure
  parameters:
    usePodIdentity: "true"
    keyvaultName: titanic-kv-prod
    cloudName: AzurePublicCloud
    objects: |
      array:
        - |
          objectName: db-password
          objectType: secret
          objectAlias: DB_PASSWORD
        - |
          objectName: db-connection-string
          objectType: secret
          objectAlias: DATABASE_URL
        - |
          objectName: flask-secret-key
          objectType: secret
          objectAlias: FLASK_SECRET_KEY
  secretObjects:
  - secretKey: db-password
    objectName: db-password
  - secretKey: database-url
    objectName: db-connection-string
  - secretKey: flask-secret-key
    objectName: flask-secret-key
EOF
```

#### 2. Update Deployment

```bash
cat >> k8s/deployment-app.yaml <<'EOF'

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: titanic-api
  namespace: titanic-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: titanic-api
  template:
    metadata:
      labels:
        app: titanic-api
    spec:
      serviceAccountName: titanic-api-sa
      containers:
      - name: app
        image: titanic-api:latest
        ports:
        - containerPort: 5000
          name: http
        
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: titanic-api-secrets
              key: database-url
        - name: FLASK_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: titanic-api-secrets
              key: flask-secret-key
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: titanic-api-secrets
              key: db-password
        
        volumeMounts:
        - name: secrets-store
          mountPath: /mnt/secrets
          readOnly: true
        
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        
        livenessProbe:
          httpGet:
            path: /health/live
            port: 5000
          initialDelaySeconds: 30
          periodSeconds: 10
        
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 5000
          initialDelaySeconds: 10
          periodSeconds: 5
      
      volumes:
      - name: secrets-store
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: "titanic-kv-secrets"
EOF
```

#### 3. Deploy Everything

```bash
# 1. Apply SecretProviderClass
kubectl apply -f k8s/secretproviderclass.yaml

# 2. Apply Deployment (secrets auto-synced)
kubectl apply -f k8s/deployment-app.yaml

# 3. Verify pod is running
kubectl get pods -n titanic-api
kubectl logs <pod-name> -n titanic-api

# 4. Verify secrets are mounted
kubectl exec <pod-name> -n titanic-api -- \
  cat /mnt/secrets/db-password
```

---

## Best Practices

### ✅ Security

1. **Always use workload identity or managed identity**
   ```yaml
   azure.workload.identity/use: "true"
   ```

2. **Never log secrets**
   ```python
   # BAD
   print(f"Connecting to {database_url}")
   
   # GOOD
   print(f"Connecting to database at {os.environ.get('DB_HOST', 'unknown')}")
   ```

3. **Use read-only file systems**
   ```yaml
   securityContext:
     readOnlyRootFilesystem: true
   ```

4. **Enable audit logging in Key Vault**
   ```bash
   az monitor diagnostic-settings create \
     --name KeyVaultDiags \
     --resource /subscriptions/.../vaults/titanic-kv-prod \
     --logs '[{"category":"AuditEvent","enabled":true}]' \
     --workspace $(az monitor log-analytics workspace show \
       --resource-group <rg> --name <workspace> --query id -o tsv)
   ```

5. **Rotate secrets regularly**
   ```bash
   # Update password in Key Vault
   az keyvault secret set \
     --name db-password \
     --vault-name titanic-kv-prod \
     --value <new-password>
   
   # CSI driver syncs automatically within 15 minutes
   # Redeploy to get new secret
   kubectl rollout restart deployment/titanic-api -n titanic-api
   ```

### ✅ Operational

1. **Use namespace isolation**
   ```yaml
   namespace: titanic-api  # Separate from monitoring, etc.
   ```

2. **Implement secret refresh policies**
   ```yaml
   # In SecretProviderClass
   secretRotationPeriod: "15m"
   refreshInterval: "5m"
   ```

3. **Monitor secret access**
   ```bash
   # Query Key Vault audit logs
   az monitor activity-log list \
     --resource-group <rg> \
     --namespace Microsoft.KeyVault \
     --max-items 10
   ```

4. **Tag secrets appropriately**
   ```bash
   # In Terraform
   tags = {
     application = "titanic-api"
     environment = "production"
     sensitivity = "high"
     rotation    = "90days"
   }
   ```

---

## Troubleshooting

### Secret Not Syncing to Kubernetes

**Symptoms**: Kubernetes Secret not created after pod starts

**Diagnosis**:
```bash
# Check CSI driver pods
kubectl get pods -n kube-system | grep csi

# Check SecretProviderClass
kubectl describe secretproviderclass titanic-kv-secrets -n titanic-api

# Check pod logs
kubectl logs <pod-name> -n titanic-api
```

**Solutions**:
1. Verify workload identity is enabled:
   ```bash
   kubectl describe sa titanic-api-sa -n titanic-api
   ```

2. Check Key Vault access policy:
   ```bash
   az keyvault show --name titanic-kv-prod \
     --query properties.accessPolicies
   ```

3. Reinstall CSI driver:
   ```bash
   helm uninstall csi-secrets-store-provider-azure -n kube-system
   helm install csi-secrets-store-provider-azure/csi-secrets-store-provider-azure \
     --namespace kube-system
   ```

### Pod Can't Access Key Vault

**Symptoms**: "Access denied" errors in pod logs

**Diagnosis**:
```bash
# Check pod identity annotations
kubectl get pod <pod-name> -n titanic-api -o yaml | grep azure.workload

# Check OIDC endpoint
kubectl get pods -n kube-system -l component=oidc

# Test Key Vault connectivity
kubectl exec <pod-name> -n titanic-api -- curl -s \
  http://169.254.169.254/metadata/identity/oauth2/token?api-version=2021-02-01&resource=https://vault.azure.net
```

**Solutions**:
1. Verify Workload Identity is enabled:
   ```bash
   az aks show --resource-group <rg> --name <cluster> \
     --query oidcIssuerProfile.enabled
   ```

2. Check OIDC issuer:
   ```bash
   az aks show --resource-group <rg> --name <cluster> \
     --query oidcIssuerProfile.issuerUrl
   ```

3. Verify Key Vault access policy exists:
   ```bash
   az keyvault access-policy list --name titanic-kv-prod
   ```

### Stale Secrets (Not Updating)

**Symptoms**: Secret changed in Key Vault but pod still has old value

**Solution**: Restart pod to reload secrets
```bash
kubectl rollout restart deployment/titanic-api -n titanic-api

# Or for immediate effect
kubectl delete pods -l app=titanic-api -n titanic-api
```

### Performance Issues (Slow Pod Startup)

**Cause**: CSI driver waiting for Key Vault responses

**Solutions**:
1. Add tolerations for vault latency:
   ```yaml
   volumeMounts:
   - name: secrets-store
     mountPath: /mnt/secrets
     readOnly: true
   ```

2. Use init container to cache secrets:
   ```yaml
   initContainers:
   - name: secrets-init
     image: secrets-store-csi-driver-init
     volumeMounts:
     - name: secrets-store
       mountPath: /mnt/secrets
   ```

---

## Security Considerations

### Encryption

✅ **In Transit**
- All secrets transmitted over HTTPS/TLS to Key Vault
- Pod-to-Key Vault communication encrypted

✅ **At Rest**
- Secrets encrypted in Key Vault (AES-256)
- Kubernetes ETCD encryption enabled (should be)

### Access Control

✅ **RBAC**
- AKS kubelet: "Key Vault Secrets User" role (read-only)
- Terraform: Full admin (full lifecycle)
- Pods: Only via workload identity

✅ **Network**
- Key Vault network ACLs (deny by default)
- AzureServices bypass for AKS

### Audit

✅ **Logging**
- All Key Vault operations logged to Azure Monitor
- Pod access attempts logged
- Secret rotation tracked

### Secrets Rotation

#### Automated (Recommended)

```bash
# Using Azure Key Vault Rotation Function
az functionapp create --resource-group <rg> \
  --consumption-plan-location eastus \
  --runtime python --runtime-version 3.9 \
  --functions-version 4 \
  --name titanic-keyvault-rotation
```

#### Manual

```bash
# Update secret
az keyvault secret set \
  --vault-name titanic-kv-prod \
  --name db-password \
  --value <new-password>

# Update database
mysql -h <host> -u admin -p<old-password> \
  -e "ALTER USER 'postgresadmin'@'localhost' IDENTIFIED BY '<new-password>';"

# Restart pods
kubectl rollout restart deployment/titanic-api -n titanic-api
```

---

## Summary

### Recommended Setup

1. **Install CSI Driver** (one-time)
   ```bash
   helm install csi-secrets-store-provider-azure/csi-secrets-store-provider-azure \
     --namespace kube-system
   ```

2. **Create SecretProviderClass** (per app)
   ```bash
   kubectl apply -f k8s/secretproviderclass.yaml
   ```

3. **Update Deployment** (reference secrets)
   ```bash
   kubectl apply -f k8s/deployment-app.yaml
   ```

4. **Verify Secrets Mount** (validation)
   ```bash
   kubectl exec <pod> -n titanic-api -- cat /mnt/secrets/db-password
   ```

### Benefits

✅ Secrets never in code or config files
✅ Automatic rotation and updates
✅ Audit trail of all access
✅ Encryption at rest and in transit
✅ No credential sprawl

---

**File**: [KEYVAULT_KUBERNETES_GUIDE.md](KEYVAULT_KUBERNETES_GUIDE.md)
**Status**: Production Ready
**Last Updated**: January 2026
