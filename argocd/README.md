# ArgoCD Deployment for Titanic API

This directory contains ArgoCD configurations for deploying the Titanic API application using GitOps principles.

## 📁 Files Overview

- **`appproject.yaml`** - ArgoCD AppProject for organizing applications and access control
- **`argocd-application.yaml`** - ArgoCD Application manifest for the Titanic API

## 🚀 Deployment Steps

### Prerequisites

1. **ArgoCD installed** in your Kubernetes cluster
2. **Git repository** containing the Titanic API code
3. **ArgoCD CLI** (optional, for CLI operations)

### 1. Update Repository URL

Edit `argocd-application.yaml` and replace:
```yaml
repoURL: https://github.com/your-username/titanic-api
```
with your actual Git repository URL.

### 2. Deploy ArgoCD Resources

```bash
# Apply the AppProject first
kubectl apply -f argocd/appproject.yaml

# Apply the Application
kubectl apply -f argocd/argocd-application.yaml
```

### 3. Access ArgoCD UI

```bash
# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access at https://localhost:8080
```

## 🔧 Configuration Options

### Sync Policy

The application is configured with:
- **Automated sync**: ArgoCD automatically syncs when Git changes
- **Self-healing**: Automatically corrects drift
- **Pruning**: Removes resources not in Git
- **Retry logic**: 5 retries with exponential backoff

### Sync Options

- `CreateNamespace=true`: Creates the titanic-api namespace automatically
- `PrunePropagationPolicy=foreground`: Ensures dependent resources are cleaned up properly
- `PruneLast=true`: Prunes resources after all others are synced

## 📊 Monitoring Deployment

### Check Application Status

```bash
# Using ArgoCD CLI
argocd app get titanic-api

# Check sync status
argocd app list

# View application details
argocd app show titanic-api
```

### View in ArgoCD UI

1. Login to ArgoCD UI
2. Navigate to "Applications"
3. Click on "titanic-api"
4. View resource tree, sync status, and logs

## 🔄 GitOps Workflow

### Making Changes

1. **Modify manifests** in the `k8s/` directory
2. **Commit and push** changes to Git
3. **ArgoCD automatically syncs** the changes
4. **Monitor sync status** in ArgoCD UI or CLI

### Manual Sync (if needed)

```bash
# Force sync
argocd app sync titanic-api

# Sync with prune
argocd app sync titanic-api --prune

# Hard refresh (ignore cache)
argocd app sync titanic-api --hard-refresh
```

## 🛡️ Security Features

### AppProject Security

- **Source repository restrictions**: Only specified repos allowed
- **Destination restrictions**: Only titanic-api namespace allowed
- **RBAC roles**: Developer role with controlled permissions
- **Resource whitelisting**: All resources allowed (can be restricted further)

### Namespace Isolation

- Application deploys to dedicated `titanic-api` namespace
- RBAC controls access within the namespace
- Network policies restrict pod-to-pod communication

## 🚨 Troubleshooting

### Common Issues

1. **Repository not accessible**
   - Check repository URL and credentials
   - Ensure ArgoCD has access to the repository

2. **Sync failures**
   ```bash
   # Check application events
   argocd app get titanic-api --show-events

   # View detailed logs
   kubectl logs -n argocd deployment/argocd-application-controller
   ```

3. **Resource conflicts**
   - Check for existing resources in titanic-api namespace
   - Use `kubectl get all -n titanic-api` to inspect

4. **Permission issues**
   - Verify ArgoCD service account permissions
   - Check AppProject role assignments

### Health Checks

```bash
# Check ArgoCD components
kubectl get pods -n argocd

# Check application health
kubectl get applications -n argocd

# View application events
kubectl describe application titanic-api -n argocd
```

## 🔧 Advanced Configuration

### Custom Sync Windows

Add sync windows to `argocd-application.yaml`:
```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true
  automated:
    prune: true
    selfHeal: true
  syncWindows:
    - kind: allow
      schedule: '0 22 * * *'  # Daily at 10 PM
      duration: 1h
      applications:
        - 'titanic-api'
```

### Notifications

Configure notifications for sync events by adding notification configurations to ArgoCD.

## 📚 Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD CLI Reference](https://argo-cd.readthedocs.io/en/stable/cli_installation/)
- [GitOps Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)