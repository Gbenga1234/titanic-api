# Deployment Runbook

## Pre-deployment Checklist

- [ ] Azure CLI installed and authenticated
- [ ] Terraform 1.0+ installed
- [ ] Access to target subscription
- [ ] Remote state storage account created
- [ ] Required permissions (Contributor role)

## Deployment Steps

### 1. Environment Setup

```bash
# Clone repository
git clone <repository-url>
cd titanic-api/terraform

# Authenticate with Azure
az login
az account set --subscription <subscription-id>
```

### 2. Remote State Configuration

```bash
# Create resource group for state
az group create --name terraform-state-rg --location eastus

# Create storage account
az storage account create \
  --name titanicapistate \
  --resource-group terraform-state-rg \
  --location eastus \
  --sku Standard_LRS

# Create container
az storage container create \
  --name tfstate \
  --account-name titanicapistate
```

### 3. Development Deployment

```bash
cd environments/dev

# Initialize Terraform
terraform init

# Review changes
terraform plan

# Apply changes
terraform apply
```

### 4. Production Deployment

```bash
cd ../prod

# Initialize Terraform
terraform init

# Review changes
terraform plan

# Apply changes
terraform apply
```

### 5. Kubernetes Configuration

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group $(terraform output resource_group_name) \
  --name $(terraform output aks_cluster_name)

# Verify connection
kubectl get nodes
```

### 6. Application Deployment

```bash
# Deploy to Kubernetes
kubectl apply -f k8s/

# Check deployment
kubectl get pods
kubectl get services
```

## Post-deployment Verification

### Infrastructure Checks
- [ ] Resource group created
- [ ] VNet and subnets configured
- [ ] AKS cluster running
- [ ] Database server accessible
- [ ] Key Vault created

### Application Checks
- [ ] Kubernetes pods running
- [ ] Services exposed
- [ ] Load balancer configured
- [ ] Application accessible

### Security Checks
- [ ] Network security groups applied
- [ ] RBAC permissions configured
- [ ] Secrets stored in Key Vault

## Monitoring Setup

```bash
# Enable Azure Monitor for containers
az monitor diagnostic-settings create \
  --name diagnostics \
  --resource /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.ContainerService/managedClusters/<aks> \
  --logs '[{"category": "kube-apiserver", "enabled": true}]' \
  --metrics '[{"category": "AllMetrics", "enabled": true}]' \
  --workspace /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.OperationalInsights/workspaces/<workspace>
```

## Rollback Procedure

### Emergency Rollback
```bash
# Destroy infrastructure
terraform destroy

# Or rollback to previous version
terraform plan -var-file=previous.tfvars
terraform apply -var-file=previous.tfvars
```

### Application Rollback
```bash
# Rollback Kubernetes deployment
kubectl rollout undo deployment/titanic-api
```


### Backups
- Terraform state automatically backed up
- Database backups configured (7 days)
- Manual snapshots for critical updates

### Scaling
```bash
# Scale AKS nodes
az aks scale --resource-group <rg> --name <aks> --node-count 5

# Scale database
az postgres server update --resource-group <rg> --name <db> --sku-name GP_Gen5_8
```

## Security Considerations

- Rotate database passwords quarterly
- Review RBAC permissions regularly
- Monitor for security vulnerabilities
- Keep infrastructure code updated

## Support Contacts

- DevOps Team: devops@company.com
- Security Team: security@company.com
- Infrastructure Team: infra@company.com