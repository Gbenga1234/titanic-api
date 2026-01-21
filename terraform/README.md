# Titanic API Infrastructure as Code

This directory contains Terraform configurations for deploying the Titanic API to Azure using Infrastructure as Code practices.

## Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Azure Load    │    │   AKS Cluster   │    │ Azure Database  │
│   Balancer      │◄──►│                 │◄──►│ PostgreSQL      │
│                 │    │ ┌─────────────┐ │    │                 │
└─────────────────┘    │ │  App Pods   │ │    └─────────────────┘
                       │ │             │ │
                       │ └─────────────┘ │
                       │                 │
                       │ ┌─────────────┐ │
                       │ │  Ingress    │ │
                       │ │  Controller │ │
                       │ └─────────────┘ │
                       └─────────────────┘
                              ▲
                              │
                       ┌─────────────────┐
                       │   Azure VNet    │
                       │                 │
                       │ ┌─────────────┐ │
                       │ │  Subnets    │ │
                       │ └─────────────┘ │
                       └─────────────────┘
```

## Infrastructure Components

### Networking
- **Virtual Network (VNet)**: Isolated network environment
- **Subnets**: Separate subnets for AKS and database
- **Network Security Groups**: Security rules for traffic control

### Compute
- **AKS Cluster**: Managed Kubernetes service
- **Node Pools**: Configurable VM sizes and counts
- **Auto-scaling**: Horizontal pod autoscaling

### Database
- **Azure Database for PostgreSQL**: Managed PostgreSQL service
- **VNet Integration**: Private connectivity
- **High Availability**: Built-in replication

### Security
- **Azure Key Vault**: Secrets management
- **RBAC**: Role-based access control
- **Managed Identities**: Passwordless authentication

## Prerequisites

1. **Azure CLI**: Install and authenticate
   ```bash
   az login
   az account set --subscription <subscription-id>
   ```

2. **Terraform**: Version 1.0+
   ```bash
   terraform --version
   ```

3. **Azure Storage for State**: Create storage account for remote state
   ```bash
   az group create --name terraform-state-rg --location eastus
   az storage account create --name titanicapistate --resource-group terraform-state-rg --location eastus --sku Standard_LRS
   az storage container create --name tfstate --account-name titanicapistate
   ```

## Deployment

### Development Environment

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### Production Environment

```bash
cd terraform/environments/prod
terraform init
terraform plan
terraform apply
```

## Configuration

### Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `location` | Azure region | East US |
| `environment` | Environment name | dev |
| `aks_node_count` | Number of AKS nodes | 2 (dev), 3 (prod) |
| `aks_vm_size` | AKS node VM size | Standard_DS2_v2 |
| `db_sku_name` | Database SKU | GP_Gen5_2 (dev), GP_Gen5_4 (prod) |

### Secrets Management

Database passwords are automatically generated and stored in Azure Key Vault.

## Cost Estimation

### Development Environment (Monthly)
- AKS: ~$100 (2 nodes × Standard_DS2_v2)
- PostgreSQL: ~$50 (GP_Gen5_2)
- Storage: ~$5
- Key Vault: ~$1
- **Total**: ~$156/month

### Production Environment (Monthly)
- AKS: ~$150 (3 nodes × Standard_DS2_v2)
- PostgreSQL: ~$150 (GP_Gen5_4)
- Storage: ~$5
- Key Vault: ~$1
- **Total**: ~$306/month

*Note: Costs are estimates and may vary based on usage and region.*

## Security Controls

- **Network Isolation**: All resources in private VNet
- **Encryption**: Data encrypted at rest and in transit
- **Access Control**: RBAC and managed identities
- **Secrets Management**: Azure Key Vault integration
- **Monitoring**: Azure Monitor integration

## Disaster Recovery

- **Multi-zone**: Resources distributed across availability zones
- **Backups**: Automated database backups (7-day retention)
- **State Management**: Remote Terraform state in Azure Storage
- **Recovery Plan**: Infrastructure can be recreated from code

## Monitoring and Logging

- **Azure Monitor**: Container insights for AKS
- **Log Analytics**: Centralized logging
- **Application Insights**: Application performance monitoring

## Scaling

- **Horizontal Pod Autoscaling**: Automatic scaling based on CPU/memory
- **Cluster Autoscaling**: Node pool scaling
- **Database Scaling**: Vertical scaling options available

## Cleanup

```bash
terraform destroy
```

## Best Practices Implemented

- ✅ **Modular Code**: Reusable Terraform modules
- ✅ **Remote State**: Azure Storage backend
- ✅ **Environment Separation**: Separate workspaces/states
- ✅ **Secrets Management**: Azure Key Vault
- ✅ **Cost Optimization**: Right-sizing resources
- ✅ **Security**: Least privilege access
- ✅ **Documentation**: Comprehensive docs and diagrams