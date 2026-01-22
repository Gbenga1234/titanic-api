# Titanic API Kubernetes Deployment

This directory contains comprehensive Kubernetes manifests for deploying the Titanic API application with production-ready features.

## Architecture Overview

The deployment includes:
- **Flask API** (port 5000) with Gunicorn
- **PostgreSQL database** with persistent storage
- **Load balancing** via LoadBalancer service and Ingress
- **Auto-scaling** with Horizontal Pod Autoscaler
- **Security** with Network Policies and RBAC
- **Resource management** with quotas and limits

## Deployment Strategy

### Rolling Updates
- Max unavailable: 1 pod
- Max surge: 1 pod
- Zero-downtime deployments with readiness probes

### Rollback Mechanism
```bash
# Check rollout status
kubectl rollout status deployment/titanic-api -n titanic-api

# Rollback to previous version
kubectl rollout undo deployment/titanic-api -n titanic-api

# Check rollout history
kubectl rollout history deployment/titanic-api -n titanic-api
```

## Prerequisites

1. Kubernetes cluster (v1.24+)
2. kubectl configured
3. NGINX Ingress Controller (for ingress functionality)
4. Storage class for persistent volumes

## Deployment

### Using kubectl

```bash
# Create namespace and deploy all resources
kubectl apply -f k8s/

# Or use kustomize
kubectl apply -k k8s/
```

### Verify Deployment

```bash
# Check all resources
kubectl get all -n titanic-api

# Check pod status
kubectl get pods -n titanic-api

# Check services
kubectl get svc -n titanic-api

# Check ingress
kubectl get ingress -n titanic-api
```

## Configuration

### Environment Variables
- Update `configmap.yaml` for non-sensitive config
- Update `secret.yaml` for sensitive data (base64 encoded)

### Resource Limits
- Adjust CPU/memory requests/limits in `deployment-app.yaml`
- Modify HPA thresholds in `hpa.yaml`

### Database
- PostgreSQL uses 10Gi PVC
- Credentials stored in secrets

## Monitoring & Scaling

### HPA Metrics
- CPU: 70% utilization
- Memory: 80% utilization
- Scales between 2-10 replicas

### Health Checks
- Liveness: `/health/live` (container restart if fails)
- Readiness: `/health/ready` (traffic routing)

## Security Features

- **Network Policies**: Database only accessible by app pods
- **RBAC**: Least-privilege service account
- **Secrets**: Sensitive data encrypted
- **Resource Quotas**: Namespace-level limits

## Troubleshooting

### Common Issues

1. **Pods not starting**: Check resource limits vs cluster capacity
2. **Database connection**: Verify secrets and network policies
3. **Ingress not working**: Ensure NGINX ingress controller is installed
4. **HPA not scaling**: Check metrics server installation

### Logs

```bash
# App logs
kubectl logs -f deployment/titanic-api -n titanic-api

# Database logs
kubectl logs -f statefulset/postgres -n titanic-api
```

## Cleanup

```bash
kubectl delete -f k8s/
# or
kubectl delete -k k8s/
```