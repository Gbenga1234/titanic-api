# Monitoring Stack - Files & Quick Reference

Complete production-ready monitoring and instrumentation for Titanic API.

## 📦 Files Overview

### Core Kubernetes Manifests

| File | Type | Purpose | Key Resources |
|------|------|---------|---------------|
| `00-namespace.yaml` | Manifest | Create titanic-api and monitoring namespaces | Namespace |
| `01-serviceaccount-role-rolebinding.yaml` | RBAC | Service accounts and roles for all components | ServiceAccount, Role, RoleBinding, ClusterRole |
| `02-service.yaml` | Service | ClusterIP service for titanic-api on port 5000 | Service |
| `03-deployment.yaml` | Deployment | Titanic API with OTEL env vars, Prometheus annotations, health checks | Deployment |
| `04-otel-collector-configmap.yaml` | ConfigMap | OTEL Collector pipeline configuration | ConfigMap |
| `05-otel-collector-deployment.yaml` | Deployment | OpenTelemetry Collector for trace/metric aggregation | Service, Deployment |
| `06-promtail-configmap.yaml` | ConfigMap | Promtail scrape configuration for log collection | ConfigMap |
| `07-promtail-daemonset.yaml` | DaemonSet | Log collector running on all nodes | Service, DaemonSet |
| `08-servicemonitor.yaml` | CRD | Prometheus Operator ServiceMonitor for scraping | ServiceMonitor (3x) |
| `09-prometheusrule.yaml` | CRD | Alert rules for Prometheus | PrometheusRule (2x) |
| `10-grafana-dashboard-titanic-api.json` | Dashboard | Grafana dashboard with 8 monitoring panels | (JSON export) |

### Documentation Files

| File | Purpose | Audience |
|------|---------|----------|
| `README.md` | Main documentation with installation, verification, configuration | DevOps/SRE |
| `SCRAPE_CONFIGS_NO_OPERATOR.md` | Prometheus scrape configs for non-Operator clusters | DevOps without Prometheus Operator |
| `APP_INSTRUMENTATION_GUIDE.md` | How to add metrics/tracing/logging to Flask app | Developers |
| `INDEX.md` (this file) | Quick reference and file listing | All |

## 🚀 Quick Start

### 1. Apply All Manifests
```bash
cd monitoring/
kubectl apply -f .
```

### 2. Verify Deployment
```bash
kubectl get pods -n titanic-api
kubectl get pods -n monitoring
```

### 3. Check Metrics
```bash
kubectl port-forward -n titanic-api svc/titanic-api 5000:5000 &
curl -s http://localhost:5000/metrics | grep api_requests
```

### 4. Import Grafana Dashboard
1. Port-forward to Grafana: `kubectl port-forward svc/grafana 3000:3000`
2. Open http://localhost:3000
3. Go to Dashboards > Import
4. Paste contents of `10-grafana-dashboard-titanic-api.json`
5. Select Prometheus data source

## 🔍 Manifest Details

### 00-namespace.yaml
```yaml
Namespaces:
  - titanic-api (app namespace, label: monitoring=true)
  - monitoring (observability namespace)
```

### 01-serviceaccount-role-rolebinding.yaml
```yaml
ServiceAccounts:
  - titanic-api-sa (titanic-api namespace)
  - otel-collector-sa (monitoring namespace)
  - promtail-sa (monitoring namespace)

Roles:
  - titanic-api-role: read pods/services (for OTEL resource attributes)
  
ClusterRoles:
  - otel-collector-role: read all K8s resources (for service discovery, Prometheus scraping)
  - promtail-role: read nodes/pods (for log discovery)

RoleBindings:
  - titanic-api-rolebinding: bind titanic-api-sa to titanic-api-role
  
ClusterRoleBindings:
  - otel-collector-rolebinding: bind otel-collector-sa to otel-collector-role
  - promtail-rolebinding: bind promtail-sa to promtail-role
```

### 02-service.yaml
```yaml
Service: titanic-api
  - Type: ClusterIP
  - Port: 5000 (http)
  - Selector: app=titanic-api
```

### 03-deployment.yaml
```yaml
Deployment: titanic-api
  - Replicas: 2
  - Image: YOUR_DOCKERHUB_USERNAME/titanic-api:latest
  - Port: 5000
  
  Annotations:
    - prometheus.io/scrape: "true"
    - prometheus.io/port: "5000"
    - prometheus.io/path: "/metrics"
  
  Environment:
    - OTEL_EXPORTER_OTLP_ENDPOINT: "http://otel-collector.monitoring.svc.cluster.local:4317"
    - OTEL_TRACES_SAMPLER: "parentbased_traceidratio"
    - OTEL_TRACES_SAMPLER_ARG: "0.1" (10% sampling)
    - LOG_LEVEL: "INFO"
    - LOG_FORMAT: "json"
  
  Probes:
    - Liveness: GET /health/live (30s delay)
    - Readiness: GET /health/ready (10s delay)
  
  Security:
    - runAsNonRoot: true
    - allowPrivilegeEscalation: false
    - Pod anti-affinity for spreading
```

### 04-otel-collector-configmap.yaml
```yaml
Config: otel-collector-config

Receivers:
  - otlp: GRPC (4317) + HTTP (4318)
  - prometheus: scrapes K8s pods with prometheus.io annotations

Processors:
  - batch: batches spans
  - resource: adds service.name attribute
  - attributes: extracts HTTP method, scheme
  - memory_limiter: prevents OOM
  - tail_sampling: 4 policies
    * error_spans: sample all errors
    * high_latency: sample traces with latency > 1s
    * sample_successful: 10% probabilistic
    * service_spans: sample by attribute

Exporters:
  - otlp: to jaeger.monitoring.svc.cluster.local:4317
  - prometheus: 0.0.0.0:8888 (for scraping)
  - logging: debug output

Service:
  - traces: otlp → processors → otlp, logging
  - metrics: otlp, prometheus → processors → prometheus, logging
  - logs: otlp → processors → logging
```

### 05-otel-collector-deployment.yaml
```yaml
Deployment: otel-collector
  - Replicas: 1
  - Image: otel/opentelemetry-collector-k8s:0.88.0
  - Ports: 4317, 4318, 8888, 13133, 1777
  
  Environment:
    - GOGC: "80"
  
  Args:
    - --config=/etc/otel-collector-config/config.yaml
  
  Resources:
    - Request: 100m CPU, 256Mi memory
    - Limit: 500m CPU, 512Mi memory
  
  Health Checks:
    - Liveness/Readiness: GET /health (port 13133)
  
  Security:
    - readOnlyRootFilesystem: true
    - runAsNonRoot: true
```

### 06-promtail-configmap.yaml
```yaml
Config: promtail.yaml

Server:
  - http_listen_port: 3101

Clients:
  - url: http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push

Scrape Configs:
  - kubernetes-pods: discovers pods via K8s API
    Relabels:
    - Add namespace, pod, container, app, version labels
    - Extract trace_id, request_id from labels (optional)
    - Set log path: /var/log/pods/*/{pod_id}/{container}/*.log
  
  - kubernetes-pods-systemd: kubelet system logs
```

### 07-promtail-daemonset.yaml
```yaml
DaemonSet: promtail
  - Image: grafana/promtail:2.9.3
  - Port: 3101 (metrics)
  
  VolumeMounts:
    - /etc/promtail: config (read-only)
    - /var/log: pod logs (read-only)
    - /var/lib/docker/containers: container logs (read-only)
    - /var/log/journal: systemd logs (read-only)
    - /tmp: positions file
  
  Environment:
    - HOSTNAME: from spec.nodeName
  
  Resources:
    - Request: 50m CPU, 64Mi memory
    - Limit: 200m CPU, 128Mi memory
  
  Tolerations:
    - tolerates all node taints (NoSchedule, NoExecute)
```

### 08-servicemonitor.yaml
```yaml
ServiceMonitors (3):
  1. titanic-api-monitor (namespace: titanic-api)
     - Selector: app=titanic-api
     - Endpoint: port=http, path=/metrics, interval=30s
  
  2. otel-collector-monitor (namespace: monitoring)
     - Selector: app=otel-collector
     - Endpoint: port=prometheus, path=/metrics, interval=30s
  
  3. promtail-monitor (namespace: monitoring)
     - Selector: app=promtail
     - Endpoint: port=http, path=/metrics, interval=30s

Relabelings: add pod name, namespace to labels

Note: These require Prometheus Operator to be installed
Alternative: Use SCRAPE_CONFIGS_NO_OPERATOR.md for manual config
```

### 09-prometheusrule.yaml
```yaml
PrometheusRules (2):

1. titanic-api-alerts (namespace: titanic-api)
   - HighErrorRate: 5xx > 5% for 5m (Critical)
   - HighLatencyP95: P95 > 2s for 5m (Warning)
   - HighMemoryUsage: > 85% for 5m (Warning)
   - HighCPUUsage: > 80% for 5m (Warning)
   - DBConnectionPoolLow: < 10% available for 2m (Warning)
   - PodCrashLoop: restarts > 0.1/min for 5m (Critical)
   - DeploymentReplicasMismatch: replicas != available for 5m (Warning)
   - PodRestartBurst: > 3 restarts in 15m (Critical)

2. otel-collector-alerts (namespace: monitoring)
   - HighErrorRate: exporter errors > 10% for 5m (Warning)
   - QueueFull: queue at capacity (Critical)

All rules include:
  - severity label (critical/warning)
  - summary and description annotations
  - runbook_url for resolution steps
```

### 10-grafana-dashboard-titanic-api.json
```json
Dashboard: Titanic API - Application Monitoring

Panels (8):
  1. Request Rate by Method (timeseries)
     - Query: sum(rate(api_requests_total[1m])) by (method)
     - Shows: GET, POST, PUT, DELETE rates

  2. Response Latency Percentiles (timeseries)
     - Queries: P50, P95, P99
     - Thresholds: P95 > 2s (red)

  3. Error Rate by Status Code (timeseries)
     - 5xx and 4xx error rates (%)
     - Thresholds: > 1% (yellow), > 5% (red)

  4. Resource Utilization (timeseries)
     - CPU and memory % of limits
     - Thresholds: > 75% (yellow), > 90% (red)

  5. Current Request Rate (stat)
     - Single value: requests/sec

  6. Current Error Rate (stat)
     - Single value: % of 5xx responses

  7. P95 Latency (stat)
     - Single value: seconds

  8. Running Pods (stat)
     - Count of running titanic-api pods

Time range: Last 1 hour (configurable)
Refresh: Auto (default 30s)
```

## 🔧 Configuration Reference

### OTEL Sampling Levels

| Config | Scenario | Sampling % |
|--------|----------|-----------|
| `OTEL_TRACES_SAMPLER_ARG=1.0` | Development | 100% |
| `OTEL_TRACES_SAMPLER_ARG=0.5` | Staging/Testing | 50% |
| `OTEL_TRACES_SAMPLER_ARG=0.1` | Production (default) | 10% |
| `OTEL_TRACES_SAMPLER_ARG=0.01` | High-volume production | 1% |

### Prometheus Scrape Intervals

| Component | Interval | Timeout |
|-----------|----------|---------|
| Titanic API | 30s | 10s |
| OTEL Collector | 30s | 10s |
| Promtail | 30s | 10s |
| Kubernetes API | 30s | 10s |

### Resource Limits

| Component | Request | Limit |
|-----------|---------|-------|
| Titanic API | 100m / 128Mi | 200m / 256Mi |
| OTEL Collector | 100m / 256Mi | 500m / 512Mi |
| Promtail | 50m / 64Mi | 200m / 128Mi |

## 📊 Metrics Exposed

### Application Metrics (titanic-api)

```
api_requests_total{endpoint, method, status} - counter
api_response_latency_seconds{endpoint, method} - histogram
api_active_requests{endpoint, method} - gauge
exceptions_total{exception_type, endpoint} - counter
db_pool_available_connections{service} - gauge
db_pool_size{service} - gauge
db_query_latency_seconds{query_type} - histogram
```

### OTEL Collector Metrics (port 8888)

```
otelcontributor_exporter_send_spans{exporter} - counter
otelcontributor_exporter_send_failed_spans{exporter} - counter
otelcontributor_exporter_queue_size{exporter} - gauge
otelcontributor_exporter_queue_capacity{exporter} - gauge
otelcontributor_processor_batch_send_size{processor} - histogram
```

### Promtail Metrics (port 3101)

```
promtail_read_bytes_total - counter
promtail_lines_total{job} - counter
promtail_entries_dropped_total - counter
```

### Kubernetes Metrics (via kube-state-metrics)

```
kube_pod_container_status_restarts_total{pod, namespace}
kube_pod_container_resource_requests{pod, resource}
kube_pod_container_resource_limits{pod, resource}
kube_deployment_spec_replicas{deployment, namespace}
kube_deployment_status_replicas_available{deployment, namespace}
container_cpu_usage_seconds_total{pod, namespace}
container_memory_usage_bytes{pod, namespace}
```

## 🔌 Integration Points

### Receives Data From

- **Titanic API Pod**: 
  - Metrics: Prometheus `/metrics` endpoint
  - Traces: OTEL SDK via gRPC (4317)
  - Logs: stdout (collected by Promtail)

- **OTEL Collector**:
  - Traces: Application OTEL SDK
  - Metrics: Prometheus scraping of `/metrics` endpoints

### Sends Data To

- **Prometheus**:
  - From: Titanic API, OTEL Collector, Promtail
  - Protocol: HTTP polling (scrape config)

- **Jaeger/Tempo**:
  - From: OTEL Collector
  - Protocol: OTLP gRPC (4317)

- **Loki**:
  - From: Promtail
  - Protocol: HTTP (3100)

- **Grafana**:
  - From: Prometheus, Loki, Jaeger
  - Protocol: HTTP

## ✅ Verification Checklist

After applying manifests:

- [ ] All pods running: `kubectl get pods -n monitoring`
- [ ] Metrics endpoint works: `curl http://localhost:5000/metrics`
- [ ] ServiceMonitor created: `kubectl get servicemonitor -n titanic-api`
- [ ] PrometheusRule created: `kubectl get prometheusrule -n titanic-api`
- [ ] OTEL Collector logs: `kubectl logs deployment/otel-collector -n monitoring`
- [ ] Promtail logs: `kubectl logs -l app=promtail -n monitoring`
- [ ] Prometheus scraping: http://localhost:9090/targets
- [ ] Grafana dashboard imported: http://localhost:3000/dashboards
- [ ] Traces in Jaeger: http://localhost:16686 (select titanic-api)
- [ ] Logs in Loki: `curl http://localhost:3100/loki/api/v1/query?query={app="titanic-api"}`

## 🔗 Related Documentation

- **[README.md](README.md)** - Complete installation and operation guide
- **[APP_INSTRUMENTATION_GUIDE.md](APP_INSTRUMENTATION_GUIDE.md)** - How to add tracing/metrics/logs to Flask
- **[SCRAPE_CONFIGS_NO_OPERATOR.md](SCRAPE_CONFIGS_NO_OPERATOR.md)** - Manual Prometheus config (without Operator)

## 📞 Support

- **OTEL Collector Issues**: Check logs, verify endpoint, check memory
- **Missing Metrics**: Verify annotations on deployment, check Prometheus targets
- **No Traces**: Verify OTEL_EXPORTER_OTLP_ENDPOINT, check collector logs
- **Missing Logs**: Verify Promtail DaemonSet running, check loki endpoint
- **Dashboard No Data**: Verify Prometheus datasource, check metrics exist in Prometheus

See README.md Troubleshooting section for detailed steps.
