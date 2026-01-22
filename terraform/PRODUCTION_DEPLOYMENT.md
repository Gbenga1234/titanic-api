# Production Deployment Guide - Titanic API

## Pre-Deployment Checklist

### 1. Azure Prerequisites
- [ ] Azure subscription created
- [ ] Azure CLI installed and authenticated: `az login`
- [ ] Terraform installed (v1.0+)
- [ ] Sufficient quota in target region (East US)

### 2. Secret Management
**CRITICAL**: Generate secure passwords BEFORE deployment:

```bash
# Generate 16+ character password
openssl rand -base64 32

# Export as environment variable (do not commit to git)
export TF_VAR_db_admin_password="your-secure-password"
```

**Never commit passwords to git!** Use:
- GitHub Secrets for CI/CD
- Azure Key Vault for retrieval
- Environment variables locally

### 3. Backend Setup
```bash
# 1. Run setup script to create state storage
cd terraform
bash setup-backend.sh "East US"

# 2. Initialize Terraform with backend config
terraform init \
  -backend-config="resource_group_name=terraform-state-rg" \
  -backend-config="storage_account_name=titanicapistate" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=prod.terraform.tfstate"
```

## Deployment Steps

### Step 1: Validate Configuration
```bash
# Format check
terraform fmt -recursive

# Syntax validation
terraform validate

# Security scanning (optional, requires Checkov)
checkov -d . --framework terraform
```

### Step 2: Plan Deployment
```bash
# Generate execution plan
terraform plan \
  -var-file="environments/prod/terraform.tfvars" \
  -var="db_admin_password=$TF_VAR_db_admin_password" \
  -out=tfplan

# Review plan (check resource creation/modification)
terraform show tfplan
```

### Step 3: Deploy Infrastructure
```bash
# Apply the plan
terraform apply tfplan

# Capture outputs
terraform output -json > deployment-outputs.json
```

### Step 4: Configure AKS Access
```bash
# Get kubeconfig
terraform output -raw aks_kube_config > ~/.kube/titanic-prod

# Set kubectl context
export KUBECONFIG=~/.kube/titanic-prod
kubectl config current-context

# Verify cluster access
kubectl get nodes
```

### Step 5: Verify Deployments
```bash
# Check all resources created
terraform output

# Verify database connectivity
POSTGRES_HOST=$(terraform output -raw database_server_name).postgres.database.azure.com
psql -h $POSTGRES_HOST -U postgresadmin -d titanic -c "SELECT version();"

# Check Load Balancer
LB_IP=$(terraform output -raw load_balancer_public_ip)
curl -I http://$LB_IP/health/ready
```

## Post-Deployment Configuration

### 1. Deploy Kubernetes Manifests
```bash
# Create namespace
kubectl create namespace titanic-api

# Deploy ArgoCD Application
kubectl apply -f ../argocd/appproject.yaml
kubectl apply -f ../argocd/argocd-application.yaml

# Verify deployment
kubectl rollout status deployment/titanic-api -n titanic-api
```

### 2. Configure SSL/TLS (Production)

**Option A: Application Gateway (Recommended)**
```bash
# Create Application Gateway for SSL termination
# Requires certificate from Key Vault or Azure Key Vault

# Update load balancer to use Application Gateway
terraform apply -var="enable_application_gateway=true"
```

**Option B: NGINX Ingress with Cert-Manager**
```bash
# Install cert-manager
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace

# Configure Let's Encrypt issuer
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@titanic-api.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

### 3. Enable Monitoring
```bash
# Verify Log Analytics Workspace
LAW_ID=$(terraform output -raw log_analytics_workspace_id)
az monitor log-analytics workspace show --ids "$LAW_ID"

# Configure application insights
AI_KEY=$(terraform output -raw application_insights_key)
# Use this key in Flask app configuration
```

### 4. Database Initialization
```bash
# Connect to database
POSTGRES_PASSWORD=$TF_VAR_db_admin_password
POSTGRES_HOST=$(terraform output -raw database_server_name).postgres.database.azure.com

# Load schema
psql -h $POSTGRES_HOST -U postgresadmin -d titanic < ../init.sql
```

## Disaster Recovery

### Backup Configuration
```bash
# Verify backup settings
az postgres server show \
  -g titanic-api-prod-rg \
  -n titanic-postgres-prod \
  --query "{backup_retention_days: backup_retention_days, geo_redundant: geo_redundant_backup_enabled}"

# Backup is automatic (30 days in production)
```

### Point-in-Time Restore
```bash
# Restore database to specific timestamp
az postgres server restore \
  -g titanic-api-prod-rg \
  -n titanic-postgres-prod-restored \
  --source-server titanic-postgres-prod \
  --restore-point-in-time "2026-01-22T10:00:00Z"
```

## Troubleshooting

### Network Connectivity Issues
```bash
# Check NSG rules
az network nsg rule list -g titanic-api-prod-rg -n titanic-nsg --output table

# Test connectivity to database
nc -zv titanic-postgres-prod.postgres.database.azure.com 5432
```

### AKS Cluster Issues
```bash
# Check cluster status
az aks show -g titanic-api-prod-rg -n titanic-aks-prod

# View node pool status
az aks nodepool list -g titanic-api-prod-rg --cluster-name titanic-aks-prod

# Check pod logs
kubectl logs -n titanic-api deployment/titanic-api
```

### Terraform State Issues
```bash
# List all resources in state
terraform state list

# Inspect specific resource
terraform state show azurerm_kubernetes_cluster.this

# Recover from corrupted state
# Use Azure portal to backup storage account first!
terraform state pull > backup.tfstate
```

## Scaling Operations

### Scale AKS Nodes
```bash
# Update node count
terraform apply \
  -var="aks_node_count=5" \
  -var-file="environments/prod/terraform.tfvars"
```

### Scale Database
```bash
# Update SKU to larger size
terraform apply \
  -var="db_sku_name=GP_Gen5_8" \
  -var-file="environments/prod/terraform.tfvars"
```

## Cost Optimization

### View Current Costs
```bash
# Calculate estimated monthly cost
terraform plan -json | jq '.resource_changes[] | select(.change.actions[] | contains("create")) | .address' | wc -l
```

### Cost Reduction Options
1. **Development**: Use smaller VM sizes (`Standard_B2s`)
2. **Database**: Use single-region backup instead of geo-redundant
3. **Monitoring**: Use Free tier for non-production Log Analytics

## Cleanup

### Destroy All Resources
```bash
# WARNING: This destroys all infrastructure!
terraform destroy \
  -var-file="environments/prod/terraform.tfvars" \
  -var="db_admin_password=$TF_VAR_db_admin_password"

# Verify resource group is empty
az group list -o table | grep titanic
```

## Support & References

- [Terraform Azure Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure AKS Best Practices](https://docs.microsoft.com/azure/aks/best-practices)
- [Azure Database for PostgreSQL](https://docs.microsoft.com/azure/postgresql/)
