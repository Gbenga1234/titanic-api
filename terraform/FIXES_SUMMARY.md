# Terraform Production Fixes - Summary

This document summarizes all fixes applied to the Terraform configuration for production-ready deployment.

## Critical Issues Fixed

### ✅ 1. Database Password Management
**Issue**: Random password generation lost on each apply
**Fix**: 
- Added `db_admin_password` variable (sensitive)
- Password now provided externally via environment variable
- Stored securely in Key Vault
- **Action**: Export `TF_VAR_db_admin_password` before applying

**Files Changed**:
- `modules/database/variables.tf` - Added password variable with validation
- `modules/database/main.tf` - Uses var.db_admin_password instead of random_password

### ✅ 2. PostgreSQL Version Upgrade
**Issue**: PostgreSQL 11 is out of support (EOL Oct 2023)
**Fix**: Upgraded to version 14 (supported, receives security patches)

**Files Changed**:
- `modules/database/main.tf` - Changed version from "11" to "14"

### ✅ 3. Backup & Disaster Recovery
**Issue**: Only 7-day retention, no geo-redundancy
**Fix**:
- Production: 30-day retention + geo-redundant backups enabled
- Development: 7-day retention, no geo-redundancy (cost optimization)

**Files Changed**:
- `modules/database/main.tf` - Dynamic backup settings based on environment

### ✅ 4. Network Security
**Issue**: NSG created but no rules defined (default deny-all)
**Fix**: Added comprehensive inbound/outbound rules:
- Allow AKS → PostgreSQL (port 5432)
- Allow HTTP/HTTPS inbound (ports 80, 443)
- Allow outbound to internet

**Files Changed**:
- `modules/network/main.tf` - Added NSG rules with proper priorities

### ✅ 5. IAM Configuration
**Issue**: User-assigned identity created but not used by AKS
**Fix**: 
- Fixed role assignment to use actual AKS principal ID
- Added location variable (no hardcoding)
- Simplified IAM module to focus on Key Vault access

**Files Changed**:
- `modules/iam/main.tf` - Removed unused identity, focus on role assignment

### ✅ 6. AKS Kubernetes Version
**Issue**: No explicit version specified
**Fix**: Set kubernetes_version to 1.27 (recent, stable)

**Files Changed**:
- `modules/aks/main.tf` - Added kubernetes_version configuration

### ✅ 7. SSL/TLS Certificate Handling
**Issue**: HTTPS rule with no certificate configuration
**Fix**: Added documentation for SSL termination options
- Can use Application Gateway (recommended)
- Can use NGINX Ingress with Cert-Manager

**Files Changed**:
- `modules/load_balancer/main.tf` - Added comment about SSL/TLS setup

### ✅ 8. Monitoring & Observability
**Issue**: No logging, monitoring, or alerting configured
**Fix**: Created new `monitoring` module with:
- Log Analytics Workspace for centralized logging
- Application Insights for APM
- Diagnostic settings for AKS and PostgreSQL
- Metric alerts for high CPU and database issues

**Files Created**:
- `modules/monitoring/main.tf` - Log Analytics, App Insights, alerts
- `modules/monitoring/variables.tf` - Module variables
- `modules/monitoring/outputs.tf` - Module outputs

### ✅ 9. Output Values
**Issue**: Missing critical outputs for integration
**Fix**: Added comprehensive outputs:
- Public IP address and FQDN
- Database connection details
- Application Insights keys
- Log Analytics workspace info

**Files Changed**:
- `modules/aks/outputs.tf` - Added cluster_id
- `modules/database/outputs.tf` - Added server_id, updated connection_string guidance
- `modules/load_balancer/outputs.tf` - Added FQDN output

## New Files Created

### 1. `terraform/setup-backend.sh`
Automated script to prepare Terraform state backend:
- Creates resource group
- Creates storage account
- Creates blob container
- Enables versioning and soft delete

**Usage**:
```bash
bash terraform/setup-backend.sh "East US"
```

### 2. `terraform/PRODUCTION_DEPLOYMENT.md`
Complete step-by-step production deployment guide including:
- Pre-deployment checklist
- Backend setup
- Deployment steps
- Post-deployment configuration
- SSL/TLS setup instructions
- Disaster recovery procedures
- Troubleshooting guide
- Scaling operations
- Cost optimization tips
- Cleanup procedures

## Module Updates

### Database Module (`modules/database/`)
- ✅ Added `db_admin_password` variable
- ✅ Added `location` variable
- ✅ Upgraded PostgreSQL to version 14
- ✅ Dynamic backup settings (prod vs dev)
- ✅ Removed random password generation
- ✅ Updated outputs

### Network Module (`modules/network/`)
- ✅ Added NSG rules for AKS ↔ PostgreSQL communication
- ✅ Added HTTP/HTTPS inbound rules
- ✅ Added outbound internet rule

### IAM Module (`modules/iam/`)
- ✅ Fixed principal ID reference
- ✅ Added location variable
- ✅ Removed unused identity resource

### AKS Module (`modules/aks/`)
- ✅ Added kubernetes_version specification
- ✅ Added cluster_id output

### Load Balancer Module (`modules/load_balancer/`)
- ✅ Added SSL/TLS documentation
- ✅ Added FQDN output
- ✅ Improved output descriptions

### Monitoring Module (NEW)
- ✅ Log Analytics Workspace
- ✅ Application Insights
- ✅ Diagnostic settings for AKS and PostgreSQL
- ✅ Metric alerts for CPU and database
- ✅ Action groups for notifications

## Production Environment Configuration

### `environments/prod/main.tf`
- ✅ Added monitoring module
- ✅ Passes AKS and PostgreSQL IDs to monitoring

### `environments/prod/terraform.tfvars`
- ✅ 3 AKS nodes (for HA)
- ✅ GP_Gen5_4 database SKU
- ✅ 10GB database storage

## Deployment Instructions

### Pre-Deployment
```bash
# 1. Generate secure password
export TF_VAR_db_admin_password="$(openssl rand -base64 32)"

# 2. Setup backend
cd terraform
bash setup-backend.sh "East US"

# 3. Initialize Terraform
terraform init \
  -backend-config="resource_group_name=terraform-state-rg" \
  -backend-config="storage_account_name=titanicapistate" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=prod.terraform.tfstate"
```

### Deployment
```bash
# 4. Plan deployment
terraform plan \
  -var-file="environments/prod/terraform.tfvars" \
  -out=tfplan

# 5. Apply
terraform apply tfplan
```

### Post-Deployment
```bash
# 6. Configure kubectl
terraform output -raw aks_kube_config > ~/.kube/titanic-prod
export KUBECONFIG=~/.kube/titanic-prod

# 7. Deploy K8s manifests
kubectl apply -f ../k8s/

# 8. Deploy ArgoCD
kubectl apply -f ../argocd/
```

## Testing Changes

Before production deployment, test in development:
```bash
# In environments/dev
terraform plan -var-file="environments/dev/terraform.tfvars"
```

## Cost Impact

### Before Fixes
- Only 7-day backups (unsafe)
- No monitoring (invisible failures)
- No disaster recovery strategy

### After Fixes
- **Production**: +~$50-100/month for 30-day backups, Log Analytics, Application Insights
- **Development**: No additional cost (free tier monitoring)

## Security Improvements

1. ✅ Passwords no longer in code or terraform.tfvars
2. ✅ PostgreSQL enforced SSL connections
3. ✅ Network segmentation with NSG rules
4. ✅ Secrets stored in Key Vault
5. ✅ RBAC configured for AKS
6. ✅ Monitoring for security events

## Next Steps

1. Review `PRODUCTION_DEPLOYMENT.md` for complete deployment process
2. Generate and securely store database password
3. Run `setup-backend.sh` to prepare state storage
4. Test in dev environment first
5. Run full production deployment with `terraform apply`
6. Configure SSL/TLS certificates
7. Deploy application via ArgoCD

## Breaking Changes

⚠️ **Note**: These changes are breaking - you cannot apply them to existing production infrastructure without:
1. Exporting database password from existing deployment
2. Running `terraform state mv` to handle password management changes
3. Coordinating with team for simultaneous deployment

If you have existing infrastructure, contact your DevOps team for safe migration strategy.
