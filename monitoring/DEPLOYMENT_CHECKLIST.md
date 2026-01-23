# Monitoring Stack - Deployment Checklist

Step-by-step checklist for deploying the complete monitoring and instrumentation stack.

## Pre-Deployment

### Prerequisites
- [ ] Kubernetes cluster (1.20+) running
- [ ] `kubectl` configured and authenticated
- [ ] Prometheus Operator installed (optional, but recommended)
- [ ] Jaeger/Tempo available at endpoint (or localhost:4317)
- [ ] Loki available at endpoint (or localhost:3100)
- [ ] Grafana 9+ available (or localhost:3000)
- [ ] Docker registry access for pulling images

### Verify Prerequisites
```bash
# Cluster access
kubectl cluster-info

# Prometheus Operator (optional)
kubectl get crd servicemonitor.monitoring.coreos.com

# Container runtime
docker --version || podman --version
```

## Installation

### Step 1: Clone/Copy Monitoring Manifests

```bash
# Navigate to project root
cd /path/to/titanic-api

# Copy monitoring manifests
cp -r monitoring/ k8s/monitoring/

# Or apply directly from current directory
cd monitoring/
```

### Step 2: Review and Customize Manifests

```bash
# Review all manifests
for f in *.yaml; do
  echo "=== $f ==="
  head -5 "$f"
done

# Check for placeholders
grep -r "YOUR_" . --include="*.yaml"
grep -r "{{" . --include="*.yaml"
grep -r "TODO" . --include="*.yaml"

# Update container image in 03-deployment.yaml
sed -i 's/YOUR_DOCKERHUB_USERNAME/your-registry-username/g' 03-deployment.yaml

# Update OTEL collector endpoint if needed
sed -i 's/otel-collector.monitoring.svc.cluster.local:4317/YOUR_OTEL_ENDPOINT/g' \
  04-otel-collector-configmap.yaml

# Update Loki endpoint if needed
sed -i 's/loki.monitoring.svc.cluster.local:3100/YOUR_LOKI_ENDPOINT/g' \
  06-promtail-configmap.yaml
```

### Step 3: Create Namespaces

```bash
# Apply namespace manifest first
kubectl apply -f 00-namespace.yaml

# Verify namespaces created
kubectl get namespaces | grep -E "titanic-api|monitoring"

# Expected output:
# monitoring      Active   30s
# titanic-api     Active   30s
```

### Step 4: Create RBAC

```bash
# Apply service accounts, roles, and role bindings
kubectl apply -f 01-serviceaccount-role-rolebinding.yaml

# Verify RBAC
kubectl get serviceaccount -n titanic-api
kubectl get serviceaccount -n monitoring
kubectl get role -n titanic-api
kubectl get clusterrole | grep otel
kubectl get rolebinding -n titanic-api
kubectl get clusterrolebinding | grep otel
```

### Step 5: Create Services

```bash
# Apply services
kubectl apply -f 02-service.yaml

# Verify services
kubectl get svc -n titanic-api
kubectl get svc -n monitoring

# Expected output (eventually):
# titanic-api        ClusterIP   10.x.x.x   <none>   5000/TCP
# otel-collector     ClusterIP   10.x.x.x   <none>   4317/TCP,4318/TCP,8888/TCP
# promtail           ClusterIP   None       <none>   3101/TCP
```

### Step 6: Deploy OTEL Collector

```bash
# Apply OTEL configuration and deployment
kubectl apply -f 04-otel-collector-configmap.yaml
kubectl apply -f 05-otel-collector-deployment.yaml

# Wait for deployment
kubectl rollout status deployment/otel-collector -n monitoring

# Verify pods running
kubectl get pods -n monitoring -l app=otel-collector

# Check logs
kubectl logs -n monitoring -f deployment/otel-collector

# Expected logs:
# ... Starting otel-collector...
# ... receiver/otlpreceiver starting...
# ... exporter/jaegerexporter starting...
# ... Listening on 0.0.0.0:4317 ...
```

### Step 7: Deploy Promtail

```bash
# Apply Promtail configuration and daemonset
kubectl apply -f 06-promtail-configmap.yaml
kubectl apply -f 07-promtail-daemonset.yaml

# Wait for daemonset
kubectl rollout status daemonset/promtail -n monitoring

# Verify pods on all nodes
kubectl get pods -n monitoring -l app=promtail

# Expected: One pod per node

# Check logs
kubectl logs -n monitoring -l app=promtail | head -20

# Expected logs:
# ... Starting Promtail...
# ... Scrape config loaded: kubernetes-pods...
# ... clients=["http://loki..."]
```

### Step 8: Deploy Titanic API with Monitoring

```bash
# Apply updated Titanic API deployment
kubectl apply -f 03-deployment.yaml

# Wait for deployment
kubectl rollout status deployment/titanic-api -n titanic-api

# Verify pods running
kubectl get pods -n titanic-api -l app=titanic-api

# Expected: 2 replicas running

# Check logs
kubectl logs -n titanic-api -f deployment/titanic-api

# Expected logs:
# ... Flask app created...
# ... OTEL SDK configured...
# ... Prometheus metrics registered...
```

### Step 9: Deploy Prometheus ServiceMonitor (Operator Only)

```bash
# Check if Prometheus Operator is installed
kubectl get crd servicemonitor.monitoring.coreos.com 2>/dev/null

# If installed, apply ServiceMonitor
if [ $? -eq 0 ]; then
  kubectl apply -f 08-servicemonitor.yaml
  
  # Verify ServiceMonitor created
  kubectl get servicemonitor -n titanic-api
  kubectl get servicemonitor -n monitoring
else
  echo "Prometheus Operator not found, skipping ServiceMonitor"
  echo "Use SCRAPE_CONFIGS_NO_OPERATOR.md for manual config"
fi
```

### Step 10: Deploy Prometheus Rules (Operator Only)

```bash
# Check if Prometheus Operator is installed
kubectl get crd prometheusrule.monitoring.coreos.com 2>/dev/null

# If installed, apply PrometheusRule
if [ $? -eq 0 ]; then
  kubectl apply -f 09-prometheusrule.yaml
  
  # Verify PrometheusRule created
  kubectl get prometheusrule -n titanic-api
  kubectl get prometheusrule -n monitoring
else
  echo "Prometheus Operator not found, skipping PrometheusRule"
fi
```

### Step 11: Verify All Components

```bash
# Check all pods
kubectl get pods -n titanic-api
kubectl get pods -n monitoring

# Expected output:
# NAMESPACE       NAME                                  READY   STATUS    RESTARTS   AGE
# titanic-api     titanic-api-abc123-def45              1/1     Running   0          2m
# titanic-api     titanic-api-abc123-ghi67              1/1     Running   0          2m
# monitoring      otel-collector-jkl89-mno01            1/1     Running   0          2m
# monitoring      promtail-pqr23                        1/1     Running   0          2m
# monitoring      promtail-stu45                        1/1     Running   0          2m

# Check services
kubectl get svc -n titanic-api
kubectl get svc -n monitoring

# Check ConfigMaps
kubectl get cm -n monitoring

# Check ServiceMonitor
kubectl get servicemonitor -n titanic-api
kubectl get servicemonitor -n monitoring

# Check PrometheusRule
kubectl get prometheusrule -n titanic-api
```

## Post-Deployment Verification

### 1. Metrics Endpoint

```bash
# Port-forward to titanic-api
kubectl port-forward -n titanic-api svc/titanic-api 5000:5000 &

# Fetch metrics
curl -s http://localhost:5000/metrics | head -20

# Expected output:
# # HELP api_requests_total Total API requests
# # TYPE api_requests_total counter
# api_requests_total{...} x.0

# Kill port-forward
pkill -f "port-forward.*5000"
```

### 2. OTEL Collector

```bash
# Check OTEL Collector logs
kubectl logs -n monitoring deployment/otel-collector | tail -10

# Expected: No errors, listening on 4317 and 4318

# Port-forward and test
kubectl port-forward -n monitoring svc/otel-collector 4317:4317 &

# Test with grpcurl (if installed)
grpcurl -plaintext localhost:4317 list

# Or just check it's listening
nc -zv localhost 4317

# Kill port-forward
pkill -f "port-forward.*4317"
```

### 3. Promtail

```bash
# Check Promtail logs
kubectl logs -n monitoring -l app=promtail | grep -i "scrape config\|clients" | head -5

# Expected: Scrape config loaded, clients connected to Loki

# Check one Promtail pod in detail
POD=$(kubectl get pods -n monitoring -l app=promtail -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n monitoring "$POD" | tail -10
```

### 4. Prometheus Scraping

```bash
# Port-forward to Prometheus (if using Prometheus Operator)
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &

# Open http://localhost:9090/targets
# Verify targets are UP:
# - titanic-api (should be green/UP)
# - otel-collector (should be green/UP)
# - promtail (should be green/UP)

# Or check via API
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, state: .health}'

# Expected output:
# {"job":"titanic-api","state":"up"}
# {"job":"otel-collector","state":"up"}
# {"job":"promtail","state":"up"}

# Kill port-forward
pkill -f "port-forward.*9090"
```

### 5. Query Prometheus

```bash
# Query metrics
curl -s 'http://localhost:9090/api/v1/query?query=api_requests_total' | jq '.data'

# Expected: Non-empty result with api_requests_total samples

# Or with longer query
curl -s 'http://localhost:9090/api/v1/query?query=rate(api_requests_total%5B5m%5D)' | jq '.data'
```

### 6. Traces in Jaeger

```bash
# Port-forward to Jaeger
kubectl port-forward -n monitoring svc/jaeger 16686:16686 &

# Open http://localhost:16686
# In "Service" dropdown, select "titanic-api"
# Should see traces appearing

# Or query Jaeger API
curl -s 'http://localhost:16686/api/traces?service=titanic-api' | jq '.data | length'

# Expected: Positive number (traces found)

# Kill port-forward
pkill -f "port-forward.*16686"
```

### 7. Logs in Loki

```bash
# Port-forward to Loki
kubectl port-forward -n monitoring svc/loki 3100:3100 &

# Query logs by service
curl -s 'http://localhost:3100/loki/api/v1/query?query={app="titanic-api"}' | jq '.data.result | length'

# Expected: Positive number (logs found)

# Or query by trace_id
curl -s 'http://localhost:3100/loki/api/v1/query?query={app="titanic-api",trace_id=~".+"}' | jq '.data'

# Kill port-forward
pkill -f "port-forward.*3100"
```

### 8. Grafana Dashboard

```bash
# Port-forward to Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000 &

# Open http://localhost:3000
# Login (default: admin/admin)
# Go to Dashboards > Import
# Click "Paste JSON"
# Paste contents of 10-grafana-dashboard-titanic-api.json
# Select Prometheus data source
# Click Import

# Expected: Dashboard imported, panels show data

# Kill port-forward
pkill -f "port-forward.*3000"
```

## Generate Test Data

To verify everything is working, generate some test traffic:

```bash
# Port-forward to titanic-api
kubectl port-forward -n titanic-api svc/titanic-api 5000:5000 &

# Generate requests
for i in {1..100}; do
  curl -X GET http://localhost:5000/people &
  curl -X GET http://localhost:5000/health/live &
done

wait

# Generate some errors
for i in {1..10}; do
  curl -X GET http://localhost:5000/nonexistent || true &
done

wait

# Kill port-forward
pkill -f "port-forward.*5000"

# Wait for data to propagate (30 seconds)
sleep 30

# Verify metrics generated
kubectl port-forward -n titanic-api svc/titanic-api 5000:5000 &
curl -s http://localhost:5000/metrics | grep api_requests_total | head -5

# Should see non-zero counters
```

## Verification Checklist

After deployment, verify each component:

### Namespaces
- [ ] `kubectl get ns | grep titanic-api`
- [ ] `kubectl get ns | grep monitoring`

### ServiceAccounts
- [ ] `kubectl get sa -n titanic-api titanic-api-sa`
- [ ] `kubectl get sa -n monitoring otel-collector-sa`
- [ ] `kubectl get sa -n monitoring promtail-sa`

### Deployments
- [ ] `kubectl get deployment -n titanic-api titanic-api`
- [ ] `kubectl get deployment -n monitoring otel-collector`

### DaemonSets
- [ ] `kubectl get daemonset -n monitoring promtail` (pods on all nodes)

### Services
- [ ] `kubectl get svc -n titanic-api titanic-api`
- [ ] `kubectl get svc -n monitoring otel-collector`
- [ ] `kubectl get svc -n monitoring promtail`

### ConfigMaps
- [ ] `kubectl get cm -n monitoring otel-collector-config`
- [ ] `kubectl get cm -n monitoring promtail-config`

### ServiceMonitor (if Operator installed)
- [ ] `kubectl get servicemonitor -n titanic-api`
- [ ] `kubectl get servicemonitor -n monitoring`

### PrometheusRule (if Operator installed)
- [ ] `kubectl get prometheusrule -n titanic-api`

### Metrics Endpoint
- [ ] `curl http://localhost:5000/metrics` returns 200
- [ ] Response includes `api_requests_total`

### OTEL Collector
- [ ] Logs show no errors
- [ ] Listening on 4317, 4318, 8888, 13133
- [ ] Connected to Jaeger/Tempo endpoint

### Promtail
- [ ] One pod per node
- [ ] Logs show "scrape config loaded"
- [ ] Connected to Loki

### Prometheus
- [ ] Targets are UP (green)
- [ ] Metrics queryable
- [ ] PrometheusRule rules loaded

### Jaeger
- [ ] titanic-api service visible
- [ ] Traces appearing

### Loki
- [ ] Logs appearing for app=titanic-api
- [ ] Fields parsed correctly

### Grafana
- [ ] Dashboard imported
- [ ] Panels show data
- [ ] No "No data" messages

## Rollback Plan

If something goes wrong, rollback with:

```bash
# Delete monitoring namespace (all components)
kubectl delete namespace monitoring

# Delete titanic-api ServiceMonitor/PrometheusRule
kubectl delete servicemonitor titanic-api-monitor -n titanic-api
kubectl delete prometheusrule titanic-api-alerts -n titanic-api

# Redeploy just the app (original deployment)
kubectl apply -f k8s/base/deployment-app.yaml

# Verify app still works
kubectl get pods -n titanic-api
kubectl port-forward svc/titanic-api 5000:5000
curl http://localhost:5000/health/live
```

## Troubleshooting During Deployment

### Namespace creation fails
```bash
# Verify kubectl access
kubectl auth can-i create namespace

# Check for quota issues
kubectl describe resourcequota -A
```

### Pod creation fails (ImagePullBackOff)
```bash
# Verify image exists
docker pull otel/opentelemetry-collector-k8s:0.88.0
docker pull grafana/promtail:2.9.3
docker pull YOUR_DOCKERHUB_USERNAME/titanic-api:latest

# Update imagePullSecrets if private registry
kubectl create secret docker-registry regcred \
  --docker-server=your-registry \
  --docker-username=username \
  --docker-password=password

# Add to deployment:
# imagePullSecrets:
# - name: regcred
```

### Pod fails to start (CrashLoopBackOff)
```bash
# Check logs
kubectl logs -n monitoring deployment/otel-collector

# Check for config errors
kubectl logs -n monitoring deployment/otel-collector | grep -i error

# Validate manifests
kubectl apply -f . --dry-run=client

# Check resource limits
kubectl top pod -n monitoring
```

### ServiceMonitor not discovering targets
```bash
# Verify ServiceMonitor labels match Prometheus selector
kubectl get servicemonitor -n titanic-api -o yaml | grep labels

# Check Prometheus config
kubectl get prometheus -n monitoring -o yaml | grep serviceMonitorSelector

# Verify pods have correct annotations
kubectl get pods -n titanic-api -o yaml | grep prometheus
```

## Next Steps

1. **Instrument Application**: Follow [APP_INSTRUMENTATION_GUIDE.md](APP_INSTRUMENTATION_GUIDE.md)
2. **Configure Alerts**: Edit PrometheusRule for your thresholds
3. **Setup Retention**: Configure Prometheus, Loki, Jaeger data retention
4. **Enable Sampling**: Adjust OTEL_TRACES_SAMPLER_ARG for production
5. **Monitor Health**: Set up status dashboard and alerting

## Support

For detailed information, see:
- [README.md](README.md) - Full documentation
- [SCRAPE_CONFIGS_NO_OPERATOR.md](SCRAPE_CONFIGS_NO_OPERATOR.md) - Non-Operator setup
- [INDEX.md](INDEX.md) - File reference
