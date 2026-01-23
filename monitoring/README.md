# Titanic API - Production Monitoring & Instrumentation Stack

Complete production-ready Kubernetes manifests for application instrumentation, Prometheus scraping, OpenTelemetry tracing, and centralized logging for the Titanic API service.

## 📋 Overview

This monitoring stack provides:

- **Application Metrics**: Prometheus scraping with custom metrics (request rate, latency, errors)
- **Distributed Tracing**: OpenTelemetry collector with trace sampling and Jaeger/Tempo export
- **Centralized Logging**: Promtail DaemonSet for aggregating container logs to Loki
- **Alerting**: PrometheusRule with 8+ alert conditions for high error rate, latency, crashes, resource usage
- **Dashboards**: Grafana dashboard with 8 panels covering request rate, latency, error rate, resource utilization
- **Production-Ready**: RBAC, security policies, resource limits, health checks, sampling configuration

## 🏗️ Architecture

```
Titanic API Pod
    ├─ Prometheus metrics: /metrics (port 5000)
    ├─ OTEL SDK: exports to OTEL Collector
    ├─ Structured JSON logs: sent to Promtail
    └─ Health checks: /health/live, /health/ready

OTEL Collector (Deployment)
    ├─ Receives OTLP traces (grpc 4317, http 4318)
    ├─ Tail sampling: error spans, high latency, 10% success sampling
    ├─ Batching + Resource + Attributes processors
    └─ Exports to: Jaeger/Tempo (traces), Prometheus (metrics)

Promtail DaemonSet
    ├─ Collects pod logs from /var/log/pods
    ├─ Adds labels: namespace, pod, container, app, version, trace_id, request_id
    └─ Sends to Loki

Prometheus
    ├─ Scrapes: Titanic API, OTEL Collector, Promtail (via ServiceMonitor)
    └─ Alert Rules: HighErrorRate, HighLatencyP95, PodRestartBurst, etc.

Grafana
    └─ Dashboard: 8 panels with request rate, latency, errors, resource usage
```

## 📦 Files

| File | Purpose |
|------|---------|
| `00-namespace.yaml` | Create `titanic-api` and `monitoring` namespaces |
| `01-serviceaccount-role-rolebinding.yaml` | RBAC for titanic-api, otel-collector, promtail |
| `02-service.yaml` | ClusterIP service for titanic-api on port 5000 |
| `03-deployment.yaml` | Titanic API deployment with OTEL env vars, Prometheus annotations |
| `04-otel-collector-configmap.yaml` | OTEL Collector config: OTLP receiver, tail sampling, exporters |
| `05-otel-collector-deployment.yaml` | OTEL Collector deployment (1 replica, 256-512Mi memory) |
| `06-promtail-configmap.yaml` | Promtail scrape config for pod log collection |
| `07-promtail-daemonset.yaml` | Promtail DaemonSet (runs on all nodes) |
| `08-servicemonitor.yaml` | ServiceMonitor CRDs for Prometheus Operator |
| `09-prometheusrule.yaml` | PrometheusRule with 10+ alerting rules (severity: warning/critical) |
| `10-grafana-dashboard-titanic-api.json` | Grafana dashboard JSON (8 panels, ready to import) |

## 🚀 Quick Start

### Prerequisites

- Kubernetes 1.20+ cluster (AKS, EKS, GKE, on-prem)
- `kubectl` configured to access your cluster
- Prometheus Operator installed (for ServiceMonitor/PrometheusRule CRDs) OR manual Prometheus config
- Jaeger, Tempo, or OTLP backend running (or use `localhost:4317` for testing)
- Loki running (or use `localhost:3100` for testing)
- Grafana 9+ for dashboard import

### Option 1: Apply All Manifests at Once

```bash
# Clone or download monitoring manifests
cd monitoring/

# Apply all resources
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-serviceaccount-role-rolebinding.yaml
kubectl apply -f 02-service.yaml
kubectl apply -f 03-deployment.yaml
kubectl apply -f 04-otel-collector-configmap.yaml
kubectl apply -f 05-otel-collector-deployment.yaml
kubectl apply -f 06-promtail-configmap.yaml
kubectl apply -f 07-promtail-daemonset.yaml

# If using Prometheus Operator:
kubectl apply -f 08-servicemonitor.yaml
kubectl apply -f 09-prometheusrule.yaml
```

Or apply all at once:
```bash
kubectl apply -f monitoring/
```

### Option 2: Using Kustomize

Create a `kustomization.yaml` in the monitoring folder:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - 00-namespace.yaml
  - 01-serviceaccount-role-rolebinding.yaml
  - 02-service.yaml
  - 03-deployment.yaml
  - 04-otel-collector-configmap.yaml
  - 05-otel-collector-deployment.yaml
  - 06-promtail-configmap.yaml
  - 07-promtail-daemonset.yaml
  - 08-servicemonitor.yaml
  - 09-prometheusrule.yaml

commonLabels:
  app.kubernetes.io/part-of: titanic-api
```

Then:
```bash
kubectl apply -k monitoring/
```

## ⚙️ Configuration

### OpenTelemetry Sampling

By default, **10% of successful traces** are sampled (production-friendly):

```yaml
OTEL_TRACES_SAMPLER: "parentbased_traceidratio"
OTEL_TRACES_SAMPLER_ARG: "0.1"  # 10%
```

To change sampling:

```bash
# 100% sampling (development)
kubectl set env deployment/titanic-api \
  OTEL_TRACES_SAMPLER_ARG=1.0 \
  -n titanic-api

# 1% sampling (high-volume production)
kubectl set env deployment/titanic-api \
  OTEL_TRACES_SAMPLER_ARG=0.01 \
  -n titanic-api
```

### OTEL Collector Tail Sampling Policies

Edit `04-otel-collector-configmap.yaml` to adjust tail sampling rules:

```yaml
tail_sampling:
  policies:
    # Always sample error spans
    - name: error_spans
      type: status_code
      status_code:
        status_codes: [ERROR]
    
    # Sample latency > 500ms
    - name: high_latency
      type: latency
      latency:
        threshold_ms: 500  # Adjust as needed
    
    # Sample 5% of successful traces
    - name: sample_successful
      type: probabilistic
      probabilistic:
        sampling_percentage: 5  # Adjust as needed
```

After editing, restart the collector:
```bash
kubectl rollout restart deployment/otel-collector -n monitoring
```

### Loki Endpoint

Update Promtail log destination (default: `loki.monitoring.svc.cluster.local:3100`):

```bash
# Edit ConfigMap
kubectl edit cm promtail-config -n monitoring

# Find: clients:
#   - url: http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push
# Change to your Loki URL, e.g.:
#   - url: http://loki.prod.example.com:3100/loki/api/v1/push

# Restart Promtail
kubectl rollout restart daemonset/promtail -n monitoring
```

### Jaeger/Tempo Endpoint

Update OTEL Collector export destination (default: `jaeger.monitoring.svc.cluster.local:4317`):

```bash
# Edit ConfigMap
kubectl edit cm otel-collector-config -n monitoring

# Find: exporters:
#   otlp:
#     endpoint: jaeger.monitoring.svc.cluster.local:4317
# Change to your Jaeger/Tempo URL, e.g.:
#     endpoint: jaeger.prod.example.com:4317

# Restart OTEL Collector
kubectl rollout restart deployment/otel-collector -n monitoring
```

## ✅ Verification Steps

### 1. Verify Deployments

```bash
# Check all pods are running
kubectl get pods -n titanic-api
kubectl get pods -n monitoring

# Expected output:
# NAME                            READY   STATUS    RESTARTS   AGE
# titanic-api-5d4c7f8d9f-abc12    1/1     Running   0          2m
# titanic-api-5d4c7f8d9f-def45    1/1     Running   0          2m
# otel-collector-8f7c3d5-ghi67    1/1     Running   0          2m
# promtail-abc12                  1/1     Running   0          2m
# promtail-def45                  1/1     Running   0          2m
```

### 2. Verify Metrics Endpoint

```bash
# Port-forward to titanic-api
kubectl port-forward -n titanic-api svc/titanic-api 5000:5000 &

# Fetch metrics
curl -s http://localhost:5000/metrics | head -20

# Expected output:
# # HELP api_requests_total Total API requests
# # TYPE api_requests_total counter
# api_requests_total{endpoint="/health/live",method="GET",status="200"} 42.0
# api_requests_total{endpoint="/health/ready",method="GET",status="200"} 41.0
# # HELP api_response_latency_seconds API response latency in seconds
# # TYPE api_response_latency_seconds histogram
# api_response_latency_seconds_bucket{endpoint="/people",le="0.005",...} 5.0
```

### 3. Verify OTEL Collector

```bash
# Check logs
kubectl logs -n monitoring -f deployment/otel-collector

# Expected output:
# ... receiver/otlpreceiver starting...
# ... exporter/jaegerexporter starting...
# ... Listening on 0.0.0.0:4317 ...

# Port-forward to collector
kubectl port-forward -n monitoring svc/otel-collector 4317:4317 &

# Send a test trace (from application or via curl)
# Application should auto-export traces to localhost:4317
```

### 4. Verify Promtail

```bash
# Check Promtail logs
kubectl logs -n monitoring -l app=promtail | head -20

# Expected output:
# ... promtail, version=... ...
# ... Scrape config loaded: kubernetes-pods ...
# ... clients=["http://loki..."]

# Query logs from Loki
kubectl port-forward -n monitoring svc/loki 3100:3100 &
curl -s 'http://localhost:3100/loki/api/v1/query?query={app="titanic-api"}' | jq .
```

### 5. Verify Prometheus Scraping

```bash
# Port-forward to Prometheus (if installed)
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &

# Open http://localhost:9090 in browser
# Go to Targets tab, verify:
#   - titanic-api (green, UP)
#   - otel-collector (green, UP)
#   - promtail (green, UP)

# Query metrics in Prometheus:
# curl 'http://localhost:9090/api/v1/query?query=api_requests_total'
```

### 6. Verify Traces in Jaeger/Tempo

```bash
# Port-forward to Jaeger (if installed)
kubectl port-forward -n monitoring svc/jaeger 16686:16686 &

# Open http://localhost:16686 in browser
# Select "titanic-api" service in dropdown
# Should see traces with latency, status, span count

# Make a test request to generate traces:
kubectl exec -it deployment/titanic-api -n titanic-api -- \
  curl -X GET http://localhost:5000/people

# Traces should appear in Jaeger within 10 seconds
```

### 7. Verify Logs in Loki

```bash
# Port-forward to Loki
kubectl port-forward -n monitoring svc/loki 3100:3100 &

# Query logs by service
curl -s 'http://localhost:3100/loki/api/v1/query?query={app="titanic-api"}' | jq .

# Query logs by trace_id (if application logs include it)
curl -s 'http://localhost:3100/loki/api/v1/query?query={app="titanic-api",trace_id="xyz123"}' | jq .

# Expected log format (JSON):
# {
#   "timestamp": "2024-01-22T10:15:30.123Z",
#   "level": "INFO",
#   "service": "titanic-api",
#   "version": "1.0",
#   "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
#   "span_id": "00f067aa0ba902b7",
#   "request_id": "req-12345",
#   "message": "GET /people completed",
#   "http_method": "GET",
#   "http_path": "/people",
#   "http_status": 200,
#   "duration_ms": 45
# }
```

### 8. Verify Grafana Dashboard

```bash
# Port-forward to Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000 &

# Open http://localhost:3000
# Login (default: admin/admin)
# Go to Dashboards > Import
# Paste JSON from 10-grafana-dashboard-titanic-api.json
# Select Prometheus data source
# Click Import

# Dashboard should display:
#   - Request rate (graph)
#   - Response latency P50/P95/P99 (graph)
#   - Error rate by status (graph)
#   - CPU/Memory usage (graph)
#   - Current request rate (stat)
#   - Current error rate (stat)
#   - P95 latency (stat)
#   - Running pods (stat)
```

### 9. Verify Alerts

```bash
# Check PrometheusRule
kubectl get prometheusrule -n titanic-api
kubectl describe prometheusrule titanic-api-alerts -n titanic-api

# Trigger a test alert (simulate high error rate)
kubectl exec -it deployment/titanic-api -n titanic-api -- bash
# Inside pod:
# for i in {1..100}; do curl http://localhost:5000/nonexistent; done

# Wait 5 minutes, check Prometheus Alerts tab:
# http://localhost:9090/alerts
# Should see "TitanicAPIHighErrorRate" in FIRING state

# Rollback by stopping the loop
```

## 📊 Dashboard Panels

The Grafana dashboard includes:

1. **Request Rate by Method** (timeseries)
   - Query: `sum(rate(api_requests_total[1m])) by (method)`
   - Shows: GET, POST, PUT, DELETE, etc.

2. **Response Latency Percentiles** (timeseries)
   - Queries: P50, P95, P99 latency
   - Threshold: P95 > 2s (yellow), > 5s (red)

3. **Error Rate by Status Code** (timeseries)
   - Queries: 5xx and 4xx error rate (%)
   - Threshold: > 1% (yellow), > 5% (red)

4. **Resource Utilization** (timeseries)
   - CPU and memory usage as % of limits
   - Threshold: > 75% (yellow), > 90% (red)

5. **Current Request Rate** (stat)
   - Single value: requests/sec

6. **Current Error Rate (5xx)** (stat)
   - Single value: % of requests

7. **P95 Latency** (stat)
   - Single value: seconds

8. **Running Pods** (stat)
   - Count of running titanic-api pods

## 🚨 Alerting Rules

PrometheusRule includes:

| Alert | Condition | Duration | Severity |
|-------|-----------|----------|----------|
| **HighErrorRate** | 5xx error rate > 5% | 5m | Critical |
| **HighLatencyP95** | P95 latency > 2s | 5m | Warning |
| **PodRestartBurst** | >3 restarts in 15m | 1m | Critical |
| **HighMemoryUsage** | Memory > 85% of limit | 5m | Warning |
| **HighCPUUsage** | CPU > 80% of limit | 5m | Warning |
| **DBConnectionPoolLow** | < 10% available | 2m | Warning |
| **PodCrashLoop** | Restart rate > 0.1/min | 5m | Critical |
| **DeploymentReplicasMismatch** | Replicas != available | 5m | Warning |

To test alerts:
```bash
# Generate high error rate
kubectl exec -it deployment/titanic-api -n titanic-api -- bash
for i in {1..1000}; do curl http://localhost:5000/bad_endpoint & done

# Wait 5+ minutes, check Prometheus alerts
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
# http://localhost:9090/alerts -> TitanicAPIHighErrorRate should be FIRING
```

## 🔐 Security Notes

### Secrets Handling

**Do NOT log PII or secrets:**

```python
# ✅ Good - redact sensitive data
logger.info(f"User login from {user_id[:4]}...") 

# ❌ Bad - logs entire user ID
logger.info(f"User login: {user_id}")

# ✅ Good - environment variables
DATABASE_URL = os.getenv("DATABASE_URL")  # Never logged

# ❌ Bad - hardcoded or logged
DATABASE_URL = "postgresql://user:password@host/db"
```

### RBAC & NetworkPolicy

- ServiceAccounts have minimal permissions (read pods/services only)
- OTEL Collector and Promtail use separate ServiceAccounts
- NetworkPolicy restricts traffic to/from monitoring namespace (if enabled)

To enforce NetworkPolicy:
```bash
kubectl label namespace titanic-api monitoring=true
# Then apply network policies to restrict traffic
```

### Pod Security Standards

Deployments run with:
- `runAsNonRoot: true` (security contexts)
- `allowPrivilegeEscalation: false`
- `readOnlyRootFilesystem: true` (where applicable)
- Minimal capabilities (drop ALL, add only DAC_READ_SEARCH for Promtail)

## 📈 Metrics Collection

### Application Metrics

Application must expose metrics at `/metrics` in Prometheus text format:

```
# HELP api_requests_total Total API requests
# TYPE api_requests_total counter
api_requests_total{endpoint="/people",method="GET",status="200"} 1234.0
api_requests_total{endpoint="/people",method="POST",status="201"} 56.0
api_requests_total{endpoint="/health/live",method="GET",status="200"} 5678.0

# HELP api_response_latency_seconds API response latency in seconds
# TYPE api_response_latency_seconds histogram
api_response_latency_seconds_bucket{endpoint="/people",le="0.001"} 100.0
api_response_latency_seconds_bucket{endpoint="/people",le="0.01"} 500.0
api_response_latency_seconds_bucket{endpoint="/people",le="0.1"} 900.0
api_response_latency_seconds_bucket{endpoint="/people",le="+Inf"} 1000.0
api_response_latency_seconds_count{endpoint="/people"} 1000.0
api_response_latency_seconds_sum{endpoint="/people"} 450.0
```

### Custom Metrics Recommended

Add to your Flask application:

```python
from prometheus_client import Counter, Histogram, Gauge, start_http_server
import time

# Request counter
api_requests_total = Counter(
    'api_requests_total',
    'Total API requests',
    ['endpoint', 'method', 'status']
)

# Latency histogram
api_response_latency = Histogram(
    'api_response_latency_seconds',
    'API response latency in seconds',
    ['endpoint', 'method'],
    buckets=[0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0, 2.0, 5.0]
)

# Database pool gauge
db_pool_available = Gauge(
    'db_pool_available_connections',
    'Available database connections',
    ['service']
)

# Usage in Flask route
@app.route('/people', methods=['GET'])
def get_people():
    start = time.time()
    try:
        people = Person.get_all()
        status = '200'
        api_requests_total.labels(
            endpoint='/people',
            method='GET',
            status=status
        ).inc()
        return jsonify(people), 200
    except Exception as e:
        status = '500'
        api_requests_total.labels(
            endpoint='/people',
            method='GET',
            status=status
        ).inc()
        raise
    finally:
        duration = time.time() - start
        api_response_latency.labels(
            endpoint='/people',
            method='GET'
        ).observe(duration)
```

## 📝 Structured Logging Format

Application logs must include JSON with required fields:

```json
{
  "timestamp": "2024-01-22T10:15:30.123Z",
  "level": "INFO",
  "service": "titanic-api",
  "version": "1.0",
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7",
  "request_id": "req-12345abc",
  "message": "GET /people completed successfully",
  "http": {
    "method": "GET",
    "path": "/people",
    "status": 200,
    "duration_ms": 45
  },
  "attributes": {
    "user_id": "user_123",
    "query_count": 2,
    "db_rows": 150
  }
}
```

Python example:
```python
import logging
import json
from pythonjsonlogger import jsonlogger
import uuid
from opentelemetry import trace

# Setup JSON logging
handler = logging.StreamHandler()
formatter = jsonlogger.JsonFormatter(
    '%(timestamp)s %(level)s %(service)s %(version)s %(trace_id)s %(span_id)s %(request_id)s %(message)s %(http_method)s %(http_path)s %(http_status)s %(duration_ms)s'
)
handler.setFormatter(formatter)
logger = logging.getLogger()
logger.addHandler(handler)
logger.setLevel(logging.INFO)

# In Flask request
@app.before_request
def before_request():
    request.request_id = str(uuid.uuid4())[:8]
    request.trace_id = trace.get_current_span().get_span_context().trace_id

@app.route('/people', methods=['GET'])
def get_people():
    start = time.time()
    logger.info(
        'GET /people started',
        extra={
            'service': 'titanic-api',
            'version': '1.0',
            'trace_id': request.trace_id,
            'span_id': trace.get_current_span().get_span_context().span_id,
            'request_id': request.request_id,
            'http_method': 'GET',
            'http_path': '/people',
        }
    )
    try:
        people = Person.get_all()
        duration = int((time.time() - start) * 1000)
        logger.info(
            'GET /people completed',
            extra={
                'service': 'titanic-api',
                'version': '1.0',
                'trace_id': request.trace_id,
                'span_id': trace.get_current_span().get_span_context().span_id,
                'request_id': request.request_id,
                'http_method': 'GET',
                'http_path': '/people',
                'http_status': 200,
                'duration_ms': duration,
            }
        )
        return jsonify(people), 200
    except Exception as e:
        duration = int((time.time() - start) * 1000)
        logger.error(
            f'GET /people failed: {str(e)}',
            extra={
                'service': 'titanic-api',
                'version': '1.0',
                'trace_id': request.trace_id,
                'span_id': trace.get_current_span().get_span_context().span_id,
                'request_id': request.request_id,
                'http_method': 'GET',
                'http_path': '/people',
                'http_status': 500,
                'duration_ms': duration,
            }
        )
        return jsonify({'error': 'Internal server error'}), 500
```

## 🔄 Trace Propagation

Ensure W3C trace context propagates through HTTP headers:

```python
from opentelemetry import trace, propagate
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.propagators.jaeger_propagator import JaegerPropagator
from opentelemetry.propagators.b3_format import B3Format
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
import requests

# Configure tracer
resource = Resource.create({SERVICE_NAME: "titanic-api"})
tracer_provider = TracerProvider(resource=resource)
otlp_exporter = OTLPSpanExporter(
    otlp_endpoint="http://otel-collector.monitoring.svc.cluster.local:4317"
)
tracer_provider.add_span_processor(BatchSpanProcessor(otlp_exporter))
trace.set_tracer_provider(tracer_provider)

# Configure propagator (W3C traceparent)
propagate.set_global_textmap(propagate.DefaultTextMapPropagator())

# In Flask app
@app.before_request
def before_request():
    # Extract trace context from incoming request headers
    ctx = propagate.extract(request.headers)
    request.trace_context = ctx

@app.route('/people', methods=['GET'])
def get_people():
    # Current span automatically includes trace_id
    span = trace.get_current_span()
    trace_id = span.get_span_context().trace_id
    
    # Outbound requests will propagate trace_id
    headers = {}
    propagate.inject(headers)
    response = requests.get('http://other-service/api', headers=headers)
    
    return jsonify(people), 200
```

## 🔄 Rollback Instructions

### Rollback All Monitoring

```bash
# Delete all monitoring resources
kubectl delete namespace monitoring

# Delete titanic-api ServiceMonitor/PrometheusRule
kubectl delete servicemonitor titanic-api-monitor -n titanic-api
kubectl delete prometheusrule titanic-api-alerts -n titanic-api

# Redeploy titanic-api without monitoring (original deployment)
kubectl apply -f k8s/base/deployment-app.yaml
```

### Rollback Specific Component

```bash
# Rollback OTEL Collector
kubectl delete deployment otel-collector -n monitoring
kubectl delete service otel-collector -n monitoring
kubectl delete configmap otel-collector-config -n monitoring

# Rollback Promtail
kubectl delete daemonset promtail -n monitoring
kubectl delete service promtail -n monitoring
kubectl delete configmap promtail-config -n monitoring
```

### Disable Tracing (Keep Metrics/Logs)

```bash
# Set OTEL_SDK_DISABLED=true
kubectl set env deployment/titanic-api \
  OTEL_SDK_DISABLED=true \
  -n titanic-api
```

### Disable Logging (Keep Tracing/Metrics)

```bash
# Delete Promtail
kubectl delete daemonset promtail -n monitoring
```

## 🧪 Testing & Examples

### Generate Test Metrics

```bash
# Port-forward to titanic-api
kubectl port-forward -n titanic-api svc/titanic-api 5000:5000 &

# Make requests to generate metrics
for i in {1..100}; do
  curl -X GET http://localhost:5000/people
  curl -X POST http://localhost:5000/people \
    -H "Content-Type: application/json" \
    -d '{"name":"John Doe","age":30}'
done

# Check metrics
curl -s http://localhost:5000/metrics | grep api_requests_total
```

### Generate Test Traces

```bash
# Port-forward to Jaeger
kubectl port-forward -n monitoring svc/jaeger 16686:16686 &

# Make requests (should generate traces within 10s)
curl -X GET http://localhost:5000/people
curl -X GET http://localhost:5000/people/1

# Check Jaeger: http://localhost:16686
# Select "titanic-api" in dropdown, view traces
```

### Generate Test Logs

```bash
# Port-forward to Loki
kubectl port-forward -n monitoring svc/loki 3100:3100 &

# Make requests (logs should appear in Loki)
curl -X GET http://localhost:5000/people

# Query logs
curl -s 'http://localhost:3100/loki/api/v1/query?query={app="titanic-api"}' | jq .streams[].values
```

### Query Prometheus

```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &

# Query examples
curl 'http://localhost:9090/api/v1/query?query=api_requests_total'
curl 'http://localhost:9090/api/v1/query?query=rate(api_requests_total[5m])'
curl 'http://localhost:9090/api/v1/query?query=histogram_quantile(0.95,api_response_latency_seconds_bucket)'
curl 'http://localhost:9090/api/v1/query?query=kube_pod_container_status_restarts_total'
```

## 📚 Additional Resources

- [OpenTelemetry Docs](https://opentelemetry.io/docs/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/naming/)
- [Grafana Dashboard Documentation](https://grafana.com/docs/grafana/latest/dashboards/)
- [Loki Documentation](https://grafana.com/docs/loki/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [PrometheusRule Documentation](https://prometheus-operator.dev/)

## 🤝 Support & Troubleshooting

### Common Issues

**Q: Prometheus not scraping metrics**
- Verify ServiceMonitor labels match Prometheus selector
- Check Prometheus targets: http://localhost:9090/targets
- Ensure port name matches in ServiceMonitor: `name: http`

**Q: OTEL Collector not receiving traces**
- Verify OTEL_EXPORTER_OTLP_ENDPOINT is correct
- Check collector logs: `kubectl logs -n monitoring deployment/otel-collector`
- Test with `grpcurl`: `grpcurl -plaintext localhost:4317 list`

**Q: Logs not appearing in Loki**
- Verify Promtail can reach Loki: `kubectl logs -n monitoring -l app=promtail`
- Check Promtail scrape config: `kubectl get cm promtail-config -n monitoring -o yaml`
- Query Loki: `http://localhost:3100/loki/api/v1/labels`

**Q: Grafana dashboard shows no data**
- Verify Prometheus data source is connected
- Check Prometheus has scraped metrics: `http://localhost:9090/api/v1/series`
- Import dashboard again, select correct data source

**Q: High memory usage from OTEL Collector**
- Reduce sampling rate: adjust `OTEL_TRACES_SAMPLER_ARG` to 0.01
- Increase batch processor timeout: edit `04-otel-collector-configmap.yaml`
- Reduce collector replicas or increase resource limits

## 📄 License

Same as Titanic API project.
