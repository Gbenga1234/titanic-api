# Cost Estimation

## Azure Pricing Calculator

Use the [Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/) with the following components:

## Development Environment

### Compute (AKS)
- **Service**: Azure Kubernetes Service
- **Region**: East US
- **Nodes**: 2 × Standard_DS2_v2
- **Uptime**: 744 hours/month (24/7)
- **Cost**: ~$100/month

### Database (PostgreSQL)
- **Service**: Azure Database for PostgreSQL
- **Tier**: General Purpose Gen 5
- **vCores**: 2
- **Storage**: 5 GB
- **Backup**: 7 days
- **Cost**: ~$50/month

### Storage
- **Service**: Azure Storage Account
- **Type**: Standard LRS
- **Operations**: Minimal
- **Cost**: ~$5/month

### Security (Key Vault)
- **Service**: Azure Key Vault
- **Operations**: 10,000/month
- **Cost**: ~$1/month

### Networking
- **Service**: Azure Virtual Network
- **Data Transfer**: Minimal
- **Cost**: ~$0/month

**Total Dev Cost**: ~$156/month

## Production Environment

### Compute (AKS)
- **Service**: Azure Kubernetes Service
- **Region**: East US
- **Nodes**: 3 × Standard_DS2_v2
- **Uptime**: 744 hours/month (24/7)
- **Cost**: ~$150/month

### Database (PostgreSQL)
- **Service**: Azure Database for PostgreSQL
- **Tier**: General Purpose Gen 5
- **vCores**: 4
- **Storage**: 10 GB
- **Backup**: 7 days
- **Cost**: ~$150/month

### Storage
- **Service**: Azure Storage Account
- **Type**: Standard LRS
- **Operations**: Moderate
- **Cost**: ~$5/month

### Security (Key Vault)
- **Service**: Azure Key Vault
- **Operations**: 100,000/month
- **Cost**: ~$1/month

### Networking
- **Service**: Azure Load Balancer
- **Data Transfer**: Moderate
- **Cost**: ~$0/month

**Total Prod Cost**: ~$306/month

## Cost Optimization Strategies

### Reserved Instances
- **AKS**: 1-year reservation saves ~20%
- **Database**: 1-year reservation saves ~30%

### Auto-scaling
- Configure HPA for pods
- Enable cluster autoscaling
- Use spot instances for non-critical workloads

### Storage Optimization
- Use Azure Files for persistent volumes
- Implement backup retention policies
- Archive old logs to cool storage

### Monitoring Costs
- Set up cost alerts
- Use Azure Cost Management
- Review resource utilization monthly

## Budget Alerts

Set up budget alerts in Azure:
1. Go to Cost Management > Budgets
2. Create budget for resource group
3. Set alert threshold (e.g., 80% of budget)
4. Configure email notifications

## Cost Monitoring

```bash
# View costs by resource group
az costmanagement query \
  --type ActualCost \
  --dataset-granularity Daily \
  --dataset-grouping name=ResourceGroup \
  --timeframe MonthToDate
```

## Reserved Instance Planning

For production workloads:
- Calculate average usage over 3 months
- Purchase 1-year reservations for stable workloads
- Use Azure Advisor recommendations

## Scaling Cost Impact

| Configuration | Monthly Cost | Notes |
|---------------|--------------|-------|
| 1 node AKS | $50 | Minimum viable |
| 2 nodes AKS | $100 | Development |
| 3 nodes AKS | $150 | Production |
| 5 nodes AKS | $250 | High availability |

## Disaster Recovery Costs

- **Geo-redundant storage**: +20% cost
- **Cross-region replication**: Additional region costs
- **Backup retention**: 30 days = +50% storage cost

## Total Cost of Ownership (TCO)

Beyond Azure costs:
- **Development time**: 40 hours × $100/hour = $4,000
- **Maintenance**: 8 hours/month × $100/hour = $800/month
- **Training**: $500 initial + $200/month
- **Monitoring tools**: $50/month

**3-year TCO**: ~$15,000 (infrastructure) + ~$30,000 (operations)