# Monitoring Installation & Setup Guide

## Overview

This guide provides complete instructions for installing and configuring Prometheus and Grafana for Kubernetes cluster monitoring and observability.

## Files Structure

```
k8s/monitoring/
├── namespace.yaml                 # Monitoring namespace
├── prometheus-rbac.yaml           # ServiceAccount, ClusterRole, ClusterRoleBinding
├── prometheus-configmap.yaml      # Prometheus scrape configuration
├── prometheus-rules.yaml          # Alert rules and recording rules
├── prometheus-deployment.yaml     # Prometheus Deployment and PVC
├── grafana-deployment.yaml        # Grafana Deployment, PVC, ConfigMap, Secret
├── ingress.yaml                   # Ingress for external access
└── kustomization.yaml             # Kustomize manifest list

helm/monitoring-chart/
├── Chart.yaml                     # Helm chart metadata
├── values.yaml                    # Default configuration values
└── templates/monitoring.yaml      # Helm templates
```

## Installation

### Method 1: Using Kustomize

Apply all manifests using Kustomize:

```bash
kubectl apply -k k8s/monitoring/
```

Verify installation:

```bash
kubectl get pods -n monitoring
kubectl get services -n monitoring
kubectl get pvc -n monitoring
```

### Method 2: Using Helm

Create a custom values file (optional):

```bash
cp helm/monitoring-chart/values.yaml values-custom.yaml
# Edit values-custom.yaml with your settings
```

Install the Helm chart:

```bash
helm install monitoring ./helm/monitoring-chart -n monitoring --create-namespace -f values-custom.yaml
```

Check installation:

```bash
helm list -n monitoring
helm status monitoring -n monitoring
```

### Method 3: Using kubectl

Apply individual manifests:

```bash
kubectl apply -f k8s/monitoring/namespace.yaml
kubectl apply -f k8s/monitoring/prometheus-rbac.yaml
kubectl apply -f k8s/monitoring/prometheus-configmap.yaml
kubectl apply -f k8s/monitoring/prometheus-rules.yaml
kubectl apply -f k8s/monitoring/prometheus-deployment.yaml
kubectl apply -f k8s/monitoring/grafana-deployment.yaml
kubectl apply -f k8s/monitoring/ingress.yaml
```

## Configuration

### Prometheus Configuration

Key settings in `prometheus-configmap.yaml`:

- **scrape_interval**: How often to scrape targets (default: 15s)
- **evaluation_interval**: How often to evaluate rules (default: 15s)
- **retention**: How long to keep data (default: 30d)
- **scrape_configs**: Define what to monitor

#### Add Custom Scrape Target

Edit `prometheus-configmap.yaml` and add under `scrape_configs`:

```yaml
- job_name: 'my-custom-app'
  static_configs:
    - targets: ['my-app:8080']
```

Apply changes:

```bash
kubectl apply -f k8s/monitoring/prometheus-configmap.yaml
curl -X POST http://localhost:9090/-/reload  # Reload Prometheus config
```

### Grafana Configuration

Grafana default credentials:
- **Username**: admin
- **Password**: admin123 (change in `grafana-deployment.yaml`)

#### Access Grafana

```bash
# Port-forward to access locally
kubectl port-forward svc/grafana 3000:3000 -n monitoring

# Then visit http://localhost:3000
```

#### Configure Data Source

1. Login to Grafana
2. Go to **Configuration** > **Data Sources**
3. Click **Add data source**
4. Select **Prometheus**
5. Set URL to `http://prometheus:9090`
6. Click **Save & Test**

#### Import Pre-built Dashboards

**Popular Dashboard IDs:**
- 1860: Node Exporter for Prometheus
- 6417: Kubernetes Cluster Monitoring
- 8588: Kubernetes Deployment Statefulset Daemonset
- 10256: Prometheus Stats

Import steps:
1. In Grafana, go to **Dashboards** > **Import**
2. Enter dashboard ID (e.g., 1860)
3. Select Prometheus as data source
4. Click **Import**

#### Create Custom Dashboard

1. Click **Create** > **Dashboard**
2. Click **Add new panel**
3. Select **Prometheus** query type
4. Write PromQL query (examples below)
5. Customize visualization
6. Save dashboard

## Monitoring Pods & Applications

### Configure App for Prometheus Scraping

Add annotations to your Pod or Deployment:

```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
```

Example for myapp in pipeops namespace:

```yaml
# deployment-app.yaml
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "5000"
        prometheus.io/path: "/metrics"
```

Reload Prometheus:

```bash
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
curl -X POST http://localhost:9090/-/reload
```

### Verify Metrics Collection

Access Prometheus UI:

```bash
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
# Visit http://localhost:9090
```

1. Go to **Status** > **Targets**
2. Check if your app appears with status "UP"
3. Go to **Graph** tab
4. Query metrics (e.g., `up{job="kubernetes-pods"}`)

## PromQL Query Examples

### Pod Metrics

```promql
# Container CPU usage
sum(rate(container_cpu_usage_seconds_total[5m])) by (pod_name, namespace)

# Container memory usage
sum(container_memory_working_set_bytes) by (pod_name, namespace)

# Pod restart count
kube_pod_container_status_restarts_total

# Pods by status
sum(kube_pod_status_phase) by (phase, namespace)
```

### Node Metrics

```promql
# Node CPU usage
(1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) by (instance)) * 100

# Node memory available percentage
(node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100

# Disk usage percentage
(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100
```

### Application Metrics

```promql
# HTTP request rate
rate(http_requests_total[5m])

# HTTP request errors
rate(http_requests_total{status=~"5.."}[5m])

# API latency (95th percentile)
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

## Alerting Setup

### Configure Alert Rules

Edit `prometheus-rules.yaml` to customize alert conditions:

```yaml
- alert: HighErrorRate
  expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "High error rate detected"
```

### View Active Alerts

```bash
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
# Visit http://localhost:9090/alerts
```

### Configure AlertManager (Optional)

For sending alerts to Slack, email, etc., configure AlertManager separately.

## Observability Checklist

- [ ] Prometheus is running and scraping targets
- [ ] Grafana is accessible and data source configured
- [ ] Dashboards imported or created
- [ ] Pod metrics are being collected
- [ ] Alert rules are defined
- [ ] Logs are being aggregated (if using ELK/Loki)
- [ ] Metrics are retained for sufficient period
- [ ] Storage is sized appropriately

## Common Tasks

### Increase Prometheus Storage

```bash
kubectl patch pvc prometheus-storage -n monitoring -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'
```

### Update Prometheus Config

```bash
# Edit the ConfigMap
kubectl edit cm prometheus-config -n monitoring

# Reload Prometheus
kubectl port-forward svc/prometheus 9090:9090 -n monitoring &
curl -X POST http://localhost:9090/-/reload
```

### Reset Grafana Password

```bash
kubectl exec -it deployment/grafana -n monitoring -- grafana-cli admin reset-admin-password newpassword
```

### Backup Grafana Dashboards

```bash
kubectl exec -it deployment/grafana -n monitoring -- grafana-cli admin export-dashboard > dashboards.json
```

### View Logs

```bash
# Prometheus logs
kubectl logs -n monitoring deployment/prometheus

# Grafana logs
kubectl logs -n monitoring deployment/grafana
```

## Troubleshooting

### Prometheus Targets Down

1. Check pod status:
   ```bash
   kubectl get pods -n monitoring
   ```

2. Check logs:
   ```bash
   kubectl logs -n monitoring deployment/prometheus
   ```

3. Verify scrape config:
   ```bash
   kubectl describe cm prometheus-config -n monitoring
   ```

### Grafana Can't Connect to Prometheus

1. Check network connectivity:
   ```bash
   kubectl exec -it deployment/grafana -n monitoring -- nc -zv prometheus 9090
   ```

2. Verify service:
   ```bash
   kubectl get svc prometheus -n monitoring
   ```

### High Memory Usage

1. Reduce retention:
   ```bash
   # Edit prometheus-deployment.yaml and change --storage.tsdb.retention.time
   ```

2. Lower scrape interval:
   ```bash
   # Edit prometheus-configmap.yaml
   ```

## Security Hardening

### Add Authentication to Prometheus

Use nginx reverse proxy or configure BasicAuth:

```yaml
# In ingress.yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
```

### Restrict RBAC

The provided RBAC config uses least privilege principle. Review `prometheus-rbac.yaml`.

### Enable TLS for Ingress

Update `ingress.yaml` with cert-manager:

```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

## Performance Tuning

### Optimize Query Performance

1. Use recording rules (pre-computed metrics)
2. Increase scrape interval for less critical metrics
3. Use relabel configs to drop unnecessary metrics
4. Implement query rate limits

### Scale Prometheus

For large clusters:

```yaml
prometheus:
  replicas: 3  # In values.yaml
```

Use federation or remote storage for long-term retention.

## Cleanup

### Remove Monitoring Stack

Using Kustomize:
```bash
kubectl delete -k k8s/monitoring/
```

Using Helm:
```bash
helm uninstall monitoring -n monitoring
kubectl delete namespace monitoring
```

## Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Kubernetes Monitoring Best Practices](https://kubernetes.io/docs/tasks/debug-application-cluster/resource-metrics-pipeline/)
- [PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet/)
