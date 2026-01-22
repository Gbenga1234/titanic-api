# Kustomize Deployment Guide for Titanic API

## Overview

This guide provides step-by-step instructions for deploying the Titanic API to Kubernetes using Kustomize with environment-specific configurations (dev and prod).

### Structure

```
k8s/
├── base/                    # Base configuration (production defaults)
│   ├── kustomization.yaml   # Base kustomization
│   ├── deployment-app.yaml
│   ├── statefulset-postgres.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── service-*.yaml
│   ├── hpa.yaml             # 2-10 replicas, 70% CPU threshold
│   ├── pdb.yaml             # minAvailable: 1
│   ├── networkpolicy-db.yaml
│   └── ... (other resources)
│
└── overlays/
    ├── dev/                 # Development environment
    │   ├── kustomization.yaml
    │   ├── deployment-patch.yaml    # 1 replica, 64/128Mi
    │   ├── configmap-patch.yaml     # debug=true, 2 workers
    │   └── hpa-patch.yaml           # 1-3 replicas, 80% threshold
    │
    └── prod/                # Production environment
        ├── kustomization.yaml
        ├── deployment-patch.yaml    # 3 replicas, 256/512Mi
        ├── configmap-patch.yaml     # production settings, 4 workers
        ├── hpa-patch.yaml           # 3-10 replicas, 65% threshold
        └── pdb-patch.yaml           # minAvailable: 2
```

## Prerequisites

1. **Kustomize** (v3.8+)
   ```bash
   # Install via kubectl (built-in)
   kubectl kustomize --version
   
   # Or install standalone
   curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
   sudo mv kustomize /usr/local/bin/
   ```

2. **kubectl** (v1.20+)
   ```bash
   kubectl version --client
   ```

3. **Kubernetes Cluster** (AKS 1.27+ recommended)
   ```bash
   kubectl cluster-info
   ```

4. **Database Secret** (pre-created)
   ```bash
   kubectl create secret generic titanic-api-secret \
     --from-literal=DATABASE_URL="postgresql://user:password@postgres-service:5432/titanic" \
     -n titanic-api
   ```

## Deployment Instructions

### 1. Preview Changes (Dry-Run)

Before deploying, preview all resources that will be created:

```bash
# Dev environment preview
kubectl kustomize k8s/overlays/dev | kubectl apply -f - --dry-run=client

# Prod environment preview
kubectl kustomize k8s/overlays/prod | kubectl apply -f - --dry-run=client
```

### 2. Validate Configuration

Validate the kustomization files for syntax errors:

```bash
# Validate base
kustomize build k8s/base > /tmp/base.yaml
kubectl apply -f /tmp/base.yaml --dry-run=client

# Validate dev overlay
kustomize build k8s/overlays/dev > /tmp/dev.yaml
kubectl apply -f /tmp/dev.yaml --dry-run=client

# Validate prod overlay
kustomize build k8s/overlays/prod > /tmp/prod.yaml
kubectl apply -f /tmp/prod.yaml --dry-run=client
```

### 3. Deploy Development Environment

Deploy to dev with cost optimizations (1 replica, lower resources):

```bash
# Create namespace (if not exists)
kubectl create namespace titanic-api

# Deploy dev environment
kustomize build k8s/overlays/dev | kubectl apply -f -

# Verify deployment
kubectl rollout status deployment/titanic-api -n titanic-api
kubectl get pods -n titanic-api -l app=titanic-api

# Check logs
kubectl logs -n titanic-api -f deployment/titanic-api
```

### 4. Deploy Production Environment

Deploy to prod with HA configuration (3 replicas, higher resources):

```bash
# Deploy prod environment (assumes separate cluster or namespace)
kustomize build k8s/overlays/prod | kubectl apply -f -

# Verify deployment
kubectl rollout status deployment/titanic-api -n titanic-api
kubectl get pods -n titanic-api -l app=titanic-api -o wide

# Check pod distribution (should be spread across nodes)
kubectl get pods -n titanic-api -l app=titanic-api -o wide

# Monitor HPA
kubectl get hpa -n titanic-api
kubectl describe hpa titanic-api -n titanic-api
```

### 5. Post-Deployment Validation

After deployment, verify the application is healthy:

```bash
# Check pod readiness
kubectl get pods -n titanic-api -l app=titanic-api

# Test health endpoints
kubectl port-forward -n titanic-api svc/titanic-api 5000:5000 &
curl http://localhost:5000/health/live
curl http://localhost:5000/health/ready

# Check database connectivity
kubectl exec -it deployment/titanic-api -n titanic-api -- \
  python -c "from src.app import create_app; app = create_app(); print('Database connected')"

# View metrics (if Prometheus installed)
kubectl get --raw /apis/metrics.k8s.io/v1beta1/namespaces/titanic-api/pods
```

## Configuration Differences

### Dev vs Base vs Prod

| Aspect | Base | Dev | Prod |
|--------|------|-----|------|
| Replicas (App) | 2 | 1 | 3 |
| Memory (App) | 256Mi req / 512Mi limit | 128Mi req / 256Mi limit | 256Mi req / 512Mi limit |
| HPA Min | 2 | 1 | 3 |
| HPA Max | 10 | 3 | 10 |
| CPU Threshold | 70% | 80% | 65% |
| Flask Debug | false | true | false |
| Gunicorn Workers | 4 | 2 | 4 |
| PDB MinAvailable | 1 | (none) | 2 |
| Pod Anti-Affinity | soft | (none) | strong |
| Topology Spread | (none) | (none) | enabled |

### Environment Variables

**Dev:**
```
FLASK_ENV=development
FLASK_DEBUG=true
GUNICORN_WORKERS=2
LOG_LEVEL=DEBUG
```

**Prod:**
```
FLASK_ENV=production
FLASK_DEBUG=false
GUNICORN_WORKERS=4
GUNICORN_TIMEOUT=60
DATABASE_POOL_SIZE=20
LOG_LEVEL=INFO
```

## Integration with ArgoCD

If using ArgoCD for GitOps-based deployments:

### 1. Create ArgoCD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: titanic-api-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-repo/titanic-api.git
    targetRevision: HEAD
    path: k8s/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: titanic-api
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

### 2. Deploy via ArgoCD

```bash
# Create ArgoCD application
kubectl apply -f argocd-application.yaml

# Sync application
argocd app sync titanic-api-dev

# Monitor deployment
argocd app wait titanic-api-dev --sync
```

## Secret Management

### Option 1: Sealed Secrets (Recommended for GitOps)

```bash
# Install sealed-secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.18.0/controller.yaml

# Create and seal secret
echo -n 'postgresql://user:pass@postgres:5432/titanic' | \
  kubectl create secret generic titanic-api-secret \
  --dry-run=client --from-file=DATABASE_URL=/dev/stdin -o yaml | \
  kubeseal -f - > k8s/overlays/prod/sealed-secret.yaml

# Update overlay to use sealed secret
# Then deploy as normal - sealed-secrets will decrypt
```

### Option 2: External Secrets Operator

```bash
# Use External Secrets Operator with Azure Key Vault
# See terraform/modules/monitoring/main.tf for Key Vault integration
```

### Option 3: Terraform Secrets (Current Setup)

Secrets are managed by Terraform and created before K8s deployment:

```bash
# Create namespace
kubectl create namespace titanic-api

# Create secret from Terraform outputs
kubectl create secret generic titanic-api-secret \
  -n titanic-api \
  --from-literal=DATABASE_URL="postgresql://user:pass@postgres:5432/titanic"
```

## Troubleshooting

### Pods not starting

```bash
# Check pod status
kubectl describe pod -n titanic-api <pod-name>

# Check resource availability
kubectl top nodes
kubectl top pods -n titanic-api

# Check events
kubectl get events -n titanic-api --sort-by='.lastTimestamp'
```

### Database connection failing

```bash
# Verify secret exists
kubectl get secret titanic-api-secret -n titanic-api -o yaml

# Test database connectivity from pod
kubectl exec -it deployment/titanic-api -n titanic-api -- bash
psql $DATABASE_URL -c "SELECT 1"
```

### HPA not scaling

```bash
# Check HPA status
kubectl get hpa -n titanic-api
kubectl describe hpa titanic-api -n titanic-api

# Check metrics server
kubectl get deployment metrics-server -n kube-system

# Check pod metrics
kubectl top pods -n titanic-api
```

### Image pull failures

```bash
# Verify image exists in registry
docker pull <registry>/<image>:<tag>

# Check imagePullSecrets in deployment
kubectl get deployment titanic-api -n titanic-api -o yaml | grep -A 5 imagePull
```

## Scaling & Performance

### Manual Scaling

```bash
# Scale deployment manually
kubectl scale deployment titanic-api -n titanic-api --replicas=5

# Or patch
kubectl patch deployment titanic-api -n titanic-api -p '{"spec":{"replicas":5}}'
```

### Monitoring Resource Usage

```bash
# Install metrics-server (if not present)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Monitor resource usage
kubectl top pods -n titanic-api --containers
kubectl top nodes

# Watch HPA
kubectl get hpa -n titanic-api -w
```

## Cleanup

### Remove all resources

```bash
# Delete dev environment
kubectl delete -f <(kustomize build k8s/overlays/dev)

# Delete prod environment
kubectl delete -f <(kustomize build k8s/overlays/prod)

# Delete namespace (if needed)
kubectl delete namespace titanic-api
```

## Best Practices

1. **Always validate before deploying**
   ```bash
   kustomize build k8s/overlays/prod > /tmp/manifest.yaml
   kubectl apply -f /tmp/manifest.yaml --dry-run=client -o yaml
   ```

2. **Use GitOps for consistency**
   - Commit all changes to git
   - Let ArgoCD sync from git source
   - Never manually kubectl apply to prod

3. **Monitor deployments**
   - Watch rollout status: `kubectl rollout status deployment/titanic-api -n titanic-api`
   - Check pod logs: `kubectl logs -n titanic-api -f deployment/titanic-api`
   - Monitor metrics: `kubectl top pods -n titanic-api`

4. **Backup secrets before updating**
   ```bash
   kubectl get secret titanic-api-secret -n titanic-api -o yaml > secret-backup.yaml
   ```

5. **Test in dev first**
   - Always deploy to dev environment first
   - Verify all endpoints work
   - Then promote to prod

## References

- [Kustomize Documentation](https://kustomize.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)

## Support

For issues or questions:
1. Check logs: `kubectl logs -n titanic-api deployment/titanic-api`
2. Check events: `kubectl get events -n titanic-api`
3. Review kustomization: `kustomize build k8s/overlays/dev | less`
4. Validate manifests: `kubectl apply -f <(kustomize build k8s/overlays/dev) --dry-run=client`
