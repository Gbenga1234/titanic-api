# Kustomize Quick Start Guide

## One-Liner Deployments

### Deploy Dev Environment (1 replica, cost-optimized)
```bash
kustomize build k8s/overlays/dev | kubectl apply -f -
```

### Deploy Prod Environment (3 replicas, HA-enabled)
```bash
kustomize build k8s/overlays/prod | kubectl apply -f -
```

### Preview Changes (Dry-Run)
```bash
# Dev preview
kustomize build k8s/overlays/dev | kubectl apply -f - --dry-run=client

# Prod preview
kustomize build k8s/overlays/prod | kubectl apply -f - --dry-run=client
```

## Configuration Overview

### Base (Production-Safe Defaults)
- **App Replicas:** 2
- **App Memory:** 256Mi request / 512Mi limit
- **Flask Debug:** false
- **Gunicorn Workers:** 4
- **HPA Range:** 2-10 replicas (70% CPU, 80% memory)
- **PDB MinAvailable:** 1

### Dev Overlay (Cost-Optimized)
- **App Replicas:** 1
- **App Memory:** 64Mi request / 128Mi limit (50% reduction)
- **Flask Debug:** true
- **Gunicorn Workers:** 2
- **HPA Range:** 1-3 replicas (80% CPU threshold)
- **Cost Savings:** ~60% vs prod

### Prod Overlay (High-Availability)
- **App Replicas:** 3
- **App Memory:** 256Mi request / 512Mi limit (full production)
- **Flask Debug:** false
- **Gunicorn Workers:** 4
- **HPA Range:** 3-10 replicas (65% CPU threshold)
- **PDB MinAvailable:** 2 (at least 2 pods must stay up)
- **Pod Anti-Affinity:** Spread across nodes
- **Topology Spread:** Spread across availability zones

## Validation

### Validate Before Deploying
```bash
# Run validation script
bash k8s/validate-kustomize.sh

# Or manual validation
kustomize build k8s/overlays/prod > /tmp/manifest.yaml
kubectl apply -f /tmp/manifest.yaml --dry-run=client
```

## Post-Deployment Checks

```bash
# Check pod status
kubectl get pods -n titanic-api -l app=titanic-api

# Check deployment
kubectl rollout status deployment/titanic-api -n titanic-api

# Check health endpoints
kubectl port-forward -n titanic-api svc/titanic-api 5000:5000 &
curl http://localhost:5000/health/live
curl http://localhost:5000/health/ready

# Check HPA
kubectl get hpa -n titanic-api
```

## Troubleshooting

### Pods not starting?
```bash
kubectl describe pod -n titanic-api <pod-name>
kubectl logs -n titanic-api -f deployment/titanic-api
```

### Database connection failing?
```bash
# Verify secret exists
kubectl get secret titanic-api-secret -n titanic-api

# Check DATABASE_URL
kubectl get secret titanic-api-secret -n titanic-api -o jsonpath='{.data.DATABASE_URL}' | base64 -d
```

### Stuck in ImagePullBackOff?
```bash
# Verify image in registry
docker pull <registry>/titanic-api:latest

# Check image pull errors
kubectl describe pod -n titanic-api <pod-name> | grep -A 5 "Image"
```

## Integration with ArgoCD

### Deploy via ArgoCD
```bash
# Create ArgoCD application for dev
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: titanic-api-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-repo/titanic-api.git
    path: k8s/overlays/dev
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: titanic-api
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# Sync
argocd app sync titanic-api-dev
```

## File Structure Reference

```
k8s/
├── base/                         # Production-safe defaults
│   ├── kustomization.yaml        # Base configuration
│   ├── deployment-app.yaml       # Flask deployment (2 replicas)
│   ├── statefulset-postgres.yaml # PostgreSQL (v14)
│   ├── configmap.yaml            # Config (FLASK_ENV=production)
│   ├── secret.yaml               # Secrets template
│   ├── hpa.yaml                  # HPA (2-10 replicas, 70% CPU)
│   ├── pdb.yaml                  # PodDisruptionBudget
│   ├── networkpolicy-db.yaml     # Network policies
│   └── ... (11 more resources)
│
└── overlays/
    ├── dev/                      # Development environment
    │   ├── kustomization.yaml    # Dev config (1 replica, debug)
    │   ├── deployment-patch.yaml # 1 replica, 64/128Mi
    │   ├── configmap-patch.yaml  # Debug enabled
    │   └── hpa-patch.yaml        # 1-3 replicas
    │
    └── prod/                     # Production environment
        ├── kustomization.yaml    # Prod config (3 replicas)
        ├── deployment-patch.yaml # 3 replicas, 256/512Mi, affinity
        ├── configmap-patch.yaml  # Production settings
        ├── hpa-patch.yaml        # 3-10 replicas, 65% CPU
        └── pdb-patch.yaml        # minAvailable: 2
```

## Key Kustomize Features Used

1. **bases:** Reuse of base configuration in overlays
2. **patchesStrategicMerge:** Non-destructive patches for deployment, configmap, hpa
3. **patchesJson6902:** Precise field modifications for HPA metrics
4. **commonLabels:** Consistent labeling across all resources
5. **replicas:** Easy replica count customization per environment
6. **images:** Image tag management per environment
7. **namespace:** Environment-specific namespaces
8. **nameSuffix:** (Dev only) Resource name isolation

## Environment Variables by Overlay

### Dev Overlay
```
FLASK_ENV=development
FLASK_DEBUG=true
GUNICORN_WORKERS=2
LOG_LEVEL=DEBUG
```

### Prod Overlay
```
FLASK_ENV=production
FLASK_DEBUG=false
GUNICORN_WORKERS=4
GUNICORN_TIMEOUT=60
DATABASE_POOL_SIZE=20
LOG_LEVEL=INFO
```

## Scaling Guide

### Manual scaling (emergency only)
```bash
kubectl scale deployment titanic-api -n titanic-api --replicas=5
```

### HPA will automatically scale based on:
- **CPU:** 65% (prod) / 80% (dev) threshold
- **Memory:** 75% (prod) / (none set for dev)
- **Response Time:** Check logs for slow requests

## Best Practices

✅ **Do:**
- Always validate before deploying: `kustomize build k8s/overlays/prod | kubectl apply -f - --dry-run=client`
- Test in dev first, then promote to prod
- Monitor with: `kubectl top pods -n titanic-api`
- Use GitOps: commit configs, let ArgoCD sync
- Backup secrets: `kubectl get secret titanic-api-secret -n titanic-api -o yaml > backup.yaml`

❌ **Don't:**
- Manually edit resources in cluster (use overlays instead)
- Commit secrets in plaintext (use sealed-secrets or external operators)
- Deploy directly with `kubectl apply -f` (use kustomize build pipe)
- Ignore HPA warnings (scale node pool if pod limits exceeded)

## References

- Full guide: [KUSTOMIZE_DEPLOYMENT_GUIDE.md](KUSTOMIZE_DEPLOYMENT_GUIDE.md)
- Kustomize docs: https://kustomize.io/
- Kubernetes docs: https://kubernetes.io/docs/
- ArgoCD docs: https://argo-cd.readthedocs.io/
