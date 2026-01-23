# Prometheus Scrape Config (For Non-Operator Clusters)

If your Kubernetes cluster does NOT have Prometheus Operator installed, use this scrape configuration instead of the ServiceMonitor CRDs.

## Add to Prometheus Config

Add the following `scrape_configs` sections to your Prometheus `prometheus.yml` or config ConfigMap:

```yaml
global:
  scrape_interval: 30s
  evaluation_interval: 30s

scrape_configs:

  # Titanic API Application
  - job_name: 'titanic-api'
    honor_timestamps: true
    scrape_interval: 30s
    scrape_timeout: 10s
    metrics_path: '/metrics'
    scheme: http
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
            - titanic-api
    relabel_configs:
      # Keep only pods with prometheus.io/scrape annotation
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      
      # Get metrics path from annotation
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      
      # Get port from annotation
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
      
      # Add pod labels
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      
      # Add namespace label
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      
      # Add pod name label
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: kubernetes_pod_name

  # OTEL Collector Metrics
  - job_name: 'otel-collector'
    honor_timestamps: true
    scrape_interval: 30s
    scrape_timeout: 10s
    metrics_path: '/metrics'
    scheme: http
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
            - monitoring
    relabel_configs:
      # Keep only otel-collector pods
      - source_labels: [__meta_kubernetes_pod_label_app]
        action: keep
        regex: otel-collector
      
      # Set metrics path
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
        replacement: /metrics
      
      # Set port
      - source_labels: [__address__]
        action: replace
        replacement: otel-collector.monitoring.svc.cluster.local:8888
        target_label: __address__
      
      # Add labels
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace

  # Promtail Metrics
  - job_name: 'promtail'
    honor_timestamps: true
    scrape_interval: 30s
    scrape_timeout: 10s
    metrics_path: '/metrics'
    scheme: http
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
            - monitoring
    relabel_configs:
      # Keep only promtail pods
      - source_labels: [__meta_kubernetes_pod_label_app]
        action: keep
        regex: promtail
      
      # Set port
      - source_labels: [__address__]
        action: replace
        replacement: promtail:3101
        target_label: __address__
      
      # Add labels
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      
      - source_labels: [__meta_kubernetes_pod_node_name]
        action: replace
        target_label: node

  # Kubernetes API Server
  - job_name: 'kubernetes-apiservers'
    kubernetes_sd_configs:
      - role: endpoints
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
      - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
        action: keep
        regex: default;kubernetes;https

  # Kubelet
  - job_name: 'kubernetes-nodes'
    kubernetes_sd_configs:
      - role: node
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)

  # Pod Metrics (via kubelet)
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: kubernetes_pod_name
```

## Apply to Prometheus

### Option 1: Update ConfigMap

```bash
# If Prometheus is deployed with a ConfigMap:
kubectl edit configmap prometheus-config -n monitoring

# Paste the scrape_configs above, then reload:
kubectl rollout restart deployment/prometheus -n monitoring
```

### Option 2: Helm Values

```yaml
# values.yaml for prometheus-community/kube-prometheus-stack
prometheus:
  additionalScrapeConfigs:
    - job_name: 'titanic-api'
      # ... (paste scrape config above)
```

### Option 3: Prometheus Operator (but without ServiceMonitor)

```bash
# Apply as PrometheusSpec.additionalScrapeConfigs
kubectl patch prometheus prometheus -n monitoring --type merge -p '
{
  "spec": {
    "additionalScrapeConfigs": [
      {
        "job_name": "titanic-api",
        # ... (add scrape config)
      }
    ]
  }
}'
```

## Verify Scraping

After applying the config, verify that targets are discovered:

```bash
# Check if targets appear in Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &

# Open http://localhost:9090/targets
# Should see:
#   - titanic-api (UP)
#   - otel-collector (UP)
#   - promtail (UP)
#   - kubernetes-apiservers (UP)
#   - kubernetes-nodes (UP)
#   - kubernetes-pods (UP)
```

## Troubleshooting Scrape Configs

### Config not reloading
```bash
# Force Prometheus to reload
kubectl rollout restart deployment/prometheus -n monitoring

# Or send SIGHUP to Prometheus process
kubectl exec -it deployment/prometheus -n monitoring -- \
  kill -HUP 1
```

### Metrics not appearing
```bash
# Check Prometheus config syntax
kubectl exec -it deployment/prometheus -n monitoring -- \
  promtool check config /etc/prometheus/prometheus.yml

# View raw config as Prometheus sees it
kubectl get configmap prometheus-config -n monitoring -o yaml

# Check Prometheus logs
kubectl logs -n monitoring deployment/prometheus | grep "loading"
```

### High cardinality targets
```bash
# If too many targets discovered, add metric_relabeling to drop high-cardinality metrics:
scrape_configs:
  - job_name: 'titanic-api'
    # ... (other config)
    metric_relabel_configs:
      # Drop high-cardinality metrics
      - source_labels: [__name__]
        regex: 'container_network_.*'
        action: drop
      
      # Keep only low-cardinality labels
      - source_labels: [__name__]
        regex: 'api_requests_total'
        action: keep
        replacement: '${__name__}'
        target_label: __tmp_keep
```

## Quick Copy-Paste for Common Clusters

### EKS (Amazon)
```yaml
- job_name: 'titanic-api'
  kubernetes_sd_configs:
    - role: pod
      aws_sd_configs:
        - role: ec2
  # ... (rest of config)
```

### GKE (Google Cloud)
```yaml
- job_name: 'titanic-api'
  kubernetes_sd_configs:
    - role: pod
  # ... (rest of config, no special config needed)
```

### AKS (Azure)
```yaml
- job_name: 'titanic-api'
  kubernetes_sd_configs:
    - role: pod
  # ... (rest of config, no special config needed)
```
