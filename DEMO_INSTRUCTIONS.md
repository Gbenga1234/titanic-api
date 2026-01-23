# Titanic API - Demo Instructions

Complete walkthrough for deploying, testing, and monitoring the Titanic API.

**Estimated Time**: 60 minutes end-to-end

---

## Table of Contents

1. [Pre-Demo Setup](#pre-demo-setup)
2. [Demo 1: Deploy to Kubernetes](#demo-1-deploy-to-kubernetes)
3. [Demo 2: Trigger CI/CD Pipeline](#demo-2-trigger-cicd-pipeline)
4. [Demo 3: Access Monitoring Dashboards](#demo-3-access-monitoring-dashboards)
5. [Demo 4: End-to-End Workflow](#demo-4-end-to-end-workflow)
6. [Quick Reference](#quick-reference)

---

## Pre-Demo Setup

### Prerequisites Checklist

Before starting demos, verify you have:

```bash
# 1. Git repository cloned
cd ~/projects/titanic-api
git status

# 2. kubectl configured
kubectl config current-context
# Expected: Should show AKS cluster name

# 3. Docker installed and running
docker --version
docker ps

# 4. Azure CLI authenticated
az account show

# 5. kubectl available
kubectl version --client
```

### Demo Environment Options

**Option A: Local Kubernetes (Minikube)** ⚡ Fastest for demo
```bash
# Start minikube
minikube start --cpus=4 --memory=8192

# Set context
kubectl config use-context minikube

# Load image locally
eval $(minikube docker-env)
docker build -t titanic-api:latest .
```

**Option B: Azure AKS** 🏢 Production-like
```bash
# Get credentials
az aks get-credentials --resource-group <rg> --name <cluster>

# Verify connection
kubectl get nodes
```

---

## Demo 1: Deploy to Kubernetes

**Duration**: 15-20 minutes

### Step 1: Build and Push Docker Image

```bash
# 1. Build the Docker image
docker build -t titanic-api:v1.0.0 .

# Expected output:
# ✅ Successfully built abc123
# ✅ Successfully tagged titanic-api:v1.0.0

# 2. Tag for registry (if using ACR)
docker tag titanic-api:v1.0.0 <registry>.azurecr.io/titanic-api:v1.0.0

# 3. Login to registry
az acr login --name <registry>

# 4. Push image
docker push <registry>.azurecr.io/titanic-api:v1.0.0

# Expected output:
# The push refers to repository [<registry>.azurecr.io/titanic-api]
# v1.0.0: digest: sha256:abc123
```

### Step 2: Create Kubernetes Namespace

```bash
# Create namespace
kubectl create namespace titanic-api

# Verify
kubectl get namespaces | grep titanic-api

# Expected output:
# titanic-api          Active          30s
```

### Step 3: Deploy Application with Kustomize (Recommended)

#### Method A: Deploy to Staging

```bash
# Apply base configuration
kubectl apply -k k8s/overlays/staging

# Watch deployment
kubectl rollout status deployment/titanic-api -n titanic-api
# Expected: deployment "titanic-api" successfully rolled out

# Check pods
kubectl get pods -n titanic-api
# Expected output:
# NAME                           READY   STATUS    RESTARTS   AGE
# titanic-api-abc123-xyz789      1/1     Running   0          2m
# titanic-api-def456-uvw012      1/1     Running   0          2m
# postgres-0                     1/1     Running   0          2m
```

#### Method B: Deploy to Production

```bash
# Apply production configuration
kubectl apply -k k8s/overlays/prod

# Verify deployment
kubectl get all -n titanic-api
```

### Step 4: Verify Deployment

```bash
# 1. Check pod status
kubectl get pods -n titanic-api
kubectl describe pod <pod-name> -n titanic-api

# 2. View logs
kubectl logs <pod-name> -n titanic-api
kubectl logs -f <pod-name> -n titanic-api  # Follow logs

# Expected logs:
# WARNING: This is a development server. Do not use it in a production deployment.
# Running on http://0.0.0.0:5000

# 3. Port-forward to access locally
kubectl port-forward svc/titanic-api 5000:5000 -n titanic-api

# In another terminal, test API
curl http://localhost:5000/health/live
# Expected response:
# {"status": "healthy"}

# 4. Get all resources
kubectl get all -n titanic-api
```

### Step 5: Access the Application

```bash
# Method 1: Port-forward (simplest)
kubectl port-forward svc/titanic-api 5000:5000 -n titanic-api

# In browser: http://localhost:5000
# Or via curl:
curl -X GET http://localhost:5000/people

# Method 2: Load Balancer (if configured)
kubectl get svc -n titanic-api
# Get EXTERNAL-IP and visit: http://<EXTERNAL-IP>:5000

# Method 3: Ingress (production)
kubectl get ingress -n titanic-api
kubectl describe ingress titanic-api -n titanic-api
```

### Step 6: Test API Endpoints

```bash
# 1. Health check
curl http://localhost:5000/health/live
# Expected: {"status":"healthy"}

# 2. Get all passengers
curl http://localhost:5000/people
# Expected: [{"id":"...", "name":"...", ...}, ...]

# 3. Create new passenger
curl -X POST http://localhost:5000/people \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Demo",
    "age": 30,
    "passengerClass": 1,
    "survived": true
  }'
# Expected: {"id":"uuid", "name":"John Demo", ...}

# 4. Get specific passenger
curl http://localhost:5000/people/<id>
# Expected: {"id":"...", "name":"John Demo", ...}

# 5. Update passenger
curl -X PUT http://localhost:5000/people/<id> \
  -H "Content-Type: application/json" \
  -d '{"age": 31}'
# Expected: {"id":"...", "name":"John Demo", "age": 31, ...}

# 6. Delete passenger
curl -X DELETE http://localhost:5000/people/<id>
# Expected: {"message":"success"}
```

### Deployment Demo Summary

```
✅ Docker image built and pushed
✅ Kubernetes namespace created
✅ Application deployed with 2 replicas
✅ PostgreSQL database running
✅ Services configured
✅ API responding to requests
✅ Health checks passing
```

---

## Demo 2: Trigger CI/CD Pipeline

**Duration**: 10-15 minutes

### Understanding the CI/CD Pipeline

```
GitHub Actions Workflow:
1. Code Push → 2. Test/Lint → 3. Security Scan → 4. Build Image → 5. Push to Registry
```

### Step 1: View Existing Workflow

```bash
# 1. Navigate to GitHub
open https://github.com/PipeOpsHQ/titanic-api

# 2. Go to Actions tab
# Click: Actions → ci-cd.yml

# 3. View recent workflow runs
# You should see successful runs for previous commits
```

### Step 2: Make a Code Change and Push

```bash
# 1. Make a small change to trigger pipeline
echo "# Demo update $(date)" >> README.md

# 2. Commit and push
git add README.md
git commit -m "chore: demo CI/CD trigger"
git push origin main

# Expected:
# [main abc1234] chore: demo CI/CD trigger
#  1 file changed, 1 insertion(+)
```

### Step 3: Monitor Pipeline Execution

```bash
# Option 1: GitHub Web UI (fastest for demo)
open https://github.com/PipeOpsHQ/titanic-api/actions

# Watch status change:
# 🟠 Queued → 🔵 In Progress → ✅ Completed

# Click workflow to see details:
# - Build logs
# - Test results
# - Coverage report
# - Security scan results

# Option 2: GitHub CLI
gh run list --repo PipeOpsHQ/titanic-api

# Option 3: Terminal
git log --oneline -5
# Should show your commit
```

### Step 4: View Pipeline Details

#### Test Results
```bash
# In GitHub Actions UI:
# 1. Click "test" job
# 2. Expand "Run tests with coverage"
# 3. View:
#    - pytest output
#    - Coverage report
#    - Pass/fail ratio

# Expected:
# ✅ 15 passed in 2.34s
# Coverage: 85%
```

#### Linting Results
```bash
# In GitHub Actions UI:
# 1. Click "test" job
# 2. Expand "Lint with flake8"
# 3. View code quality issues

# Expected:
# ✅ 0 errors
# 0 violations found
```

#### Security Scan
```bash
# In GitHub Actions UI:
# 1. Click "security-scan" job
# 2. View:
#    - Docker image scan results
#    - Known vulnerabilities
#    - Security recommendations

# Expected:
# ✅ Docker build successful
# ⚠️  High: 0, Medium: 0, Low: 2
```

#### Docker Image
```bash
# In GitHub Actions UI:
# 1. Click "build" job
# 2. Expand "Build and push Docker image"
# 3. View:
#    - Image layers
#    - Size
#    - Registry push status

# Expected:
# ✅ Image pushed to <registry>.azurecr.io/titanic-api:main
```

### Step 5: Understand Workflow Stages

#### Stage 1: Trigger (Automatic)
```
Event: git push origin main
Time: Immediate
Status: Visible in GitHub Actions
```

#### Stage 2: Test (2-3 minutes)
```bash
# What runs:
1. Setup Python 3.11
2. Install dependencies (requirements.txt)
3. Run linting (flake8)
4. Run unit tests (pytest)
5. Check coverage (>75% required)

# Success indicators:
✅ All 15 tests pass
✅ Coverage above 75%
✅ No lint errors
```

#### Stage 3: Security (3-5 minutes)
```bash
# What runs:
1. Build Docker image
2. Scan image with Trivy
3. Check for vulnerabilities
4. Upload results to GitHub Security tab

# Success indicators:
✅ Image builds successfully
✅ No high/critical vulnerabilities
✅ Report uploaded
```

#### Stage 4: Deployment (Automatic if enabled)
```bash
# What runs:
1. Push image to container registry
2. Update Kubernetes deployment
3. Monitor rollout

# Success indicators:
✅ Image pushed with digest
✅ Deployment updated
✅ New pods running
```

### Step 6: View Detailed Logs

```bash
# GitHub CLI method:
gh run view <run-id> --log

# Or web UI:
# 1. Go to Actions → Latest Run
# 2. Click specific job
# 3. Click step to expand logs
# 4. Search logs with Ctrl+F

# Common sections to review:
- "Set up Python" → Verify Python 3.11
- "Install dependencies" → Check package versions
- "Run tests" → See test results
- "Build Docker image" → Check layer caching
- "Push image" → Verify registry push
```

### CI/CD Demo Summary

```
✅ Code change committed
✅ Pipeline automatically triggered
✅ Tests passed (coverage >75%)
✅ Linting clean
✅ Security scan completed
✅ Docker image built and pushed
✅ Workflow completed in ~5 minutes
```

---

## Demo 3: Access Monitoring Dashboards

**Duration**: 15-20 minutes

### Prerequisites for Monitoring

```bash
# Verify monitoring stack deployed
kubectl get pods -n monitoring
# Expected:
# prometheus-xxxx                  Running
# grafana-xxxx                     Running
# loki-xxxx                        Running
# tempo-xxxx                       Running
# otel-collector-xxxx              Running
# promtail-xxxx                    Running (one per node)

# If not deployed:
kubectl apply -f monitoring/
```

### Step 1: Access Grafana Dashboard

```bash
# Option 1: Port-forward (simplest for demo)
kubectl port-forward svc/grafana 3000:80 -n monitoring

# Expected output:
# Forwarding from 127.0.0.1:3000 -> 3000

# In browser: http://localhost:3000
# Login: admin / admin (default)
# Change password when prompted
```

#### First Time Setup

```
1. Login with default credentials (admin/admin)
2. Set new password
3. Add Data Source:
   - Type: Prometheus
   - URL: http://prometheus:9090
   - Click: Save & Test
4. Import Dashboard:
   - Click: Dashboards → New → Import
   - Paste JSON from: monitoring/10-grafana-dashboard-titanic-api.json
   - Select: Prometheus data source
   - Click: Import
```

### Step 2: View Titanic API Dashboard

Once logged in and dashboard imported:

```bash
# Click: Dashboards → Titanic API

# View 8 panels:

Panel 1: Request Rate by Method
├─ Shows: GET/POST/PUT/DELETE requests per minute
├─ Color: Green (increasing traffic)
└─ Click: Drill down to see method breakdown

Panel 2: Response Latency Percentiles
├─ Shows: P50/P95/P99 response times
├─ Color: Yellow if >1s (warning threshold)
├─ Click: See latency trends

Panel 3: Error Rate by Status Code
├─ Shows: 4xx/5xx error percentage
├─ Color: Red if >5% (alert threshold)
└─ Click: Filter by status code

Panel 4: Resource Utilization
├─ Shows: CPU and Memory usage
├─ Color: Orange if >80% (warning)
├─ Color: Red if >90% (critical)

Panels 5-8: Summary Statistics
├─ Current request rate
├─ Current error rate
├─ P95 latency
└─ Running pods count
```

### Step 3: Generate Test Traffic

To see live data on dashboard:

```bash
# Terminal 1: Keep Grafana port-forwarded
# (already running from Step 1)

# Terminal 2: Generate traffic (in another terminal)
# Simple loop
while true; do
  curl -s http://localhost:5000/people > /dev/null
  sleep 1
done

# Or use Apache Bench
ab -n 100 -c 10 http://localhost:5000/people

# Or use load testing tool
# Install: pip install locust
# Create locustfile.py:
cat > locustfile.py <<'EOF'
from locust import HttpUser, task, between

class TitanicUser(HttpUser):
    wait_time = between(1, 3)
    
    @task
    def view_people(self):
        self.client.get("/people")
    
    @task(2)
    def health_check(self):
        self.client.get("/health/live")
EOF

# Run: locust -f locustfile.py --host=http://localhost:5000
```

### Step 4: Monitor Metrics in Real-Time

```bash
# Watch dashboard auto-refresh (30 seconds)
# Metrics should update:

✅ Request Rate increases
✅ Latency appears on charts
✅ Error Rate shows 0%
✅ CPU/Memory increase slightly
✅ Pod count remains stable

# Click time range dropdown to see:
- Last 5 minutes (tight zoom)
- Last 1 hour (see patterns)
- Last 24 hours (see daily trends)
```

### Step 5: Explore Prometheus (Metrics Database)

```bash
# Port-forward Prometheus
kubectl port-forward svc/prometheus 9090:9090 -n monitoring

# In browser: http://localhost:9090

# Click: Graph (or Metrics)

# Type metric name:
api_requests_total
# Expected: Graph shows request count over time

# Try other metrics:
api_response_latency_seconds
api_request_duration_seconds_bucket
up (shows which targets are scraping)

# Click: Alerts tab
# View:
- HighErrorRate (threshold: >5%)
- HighLatencyP95 (threshold: >2s)
- PodCrashLoop (threshold: >3 restarts)
- DeploymentReplicasMismatch

# Status should show: ✅ All firing rules in green
```

### Step 6: View Application Logs (Loki)

```bash
# Option 1: Via Grafana
# 1. Click: Explore
# 2. Data Source: Loki
# 3. Log Browser
# 4. Select labels:
#    - job: titanic-api
#    - namespace: titanic-api
# 5. View logs in real-time

# Option 2: Port-forward Loki (advanced)
kubectl port-forward svc/loki 3100:3100 -n monitoring

# Query logs with LogQL:
curl 'http://localhost:3100/loki/api/v1/query_range' \
  --data-urlencode 'query={namespace="titanic-api"}' \
  --data-urlencode 'start=<timestamp>' \
  --data-urlencode 'end=<timestamp>'
```

### Step 7: View Distributed Traces (Tempo)

```bash
# Port-forward Tempo UI (usually via Grafana Explore)
kubectl port-forward svc/tempo 3100:3100 -n monitoring

# Via Grafana:
# 1. Click: Explore
# 2. Data Source: Tempo
# 3. Select: Service (titanic-api)
# 4. View traces:
#    - Request flow
#    - Database queries
#    - External calls
#    - Errors with stack traces

# Trace details show:
- Latency breakdown (where time is spent)
- Service dependencies
- Error messages
- Full request context
```

### Step 8: Check Alert Rules

```bash
# View rules in Prometheus UI: http://localhost:9090/alerts

# Or in kubectl:
kubectl get prometheusrule -n monitoring
kubectl describe prometheusrule titanic-api-alerts -n monitoring

# Common alerts:
1. HighErrorRate
   └─ Fires when error rate > 5% for 5 minutes

2. HighLatencyP95
   └─ Fires when P95 latency > 2 seconds

3. PodCrashLoop
   └─ Fires when pod restarts > 3 times in 15 minutes

4. HighMemoryUsage
   └─ Fires when memory > 85% of limit

# To trigger alert (demo purposes):
# Cause high error rate:
while true; do
  curl -s http://localhost:5000/people/invalid-id 2>&1
  sleep 1
done

# Wait 5 minutes for alert to fire
# Check: http://localhost:9090/alerts (should turn red)
```

### Monitoring Demo Summary

```
✅ Grafana dashboard accessible
✅ 8 monitoring panels displayed
✅ Live metrics visible
✅ Test traffic generated
✅ Prometheus metrics accessible
✅ Loki logs viewable
✅ Tempo traces available
✅ Alert rules configured
```

---

## Demo 4: End-to-End Workflow

**Duration**: 25-30 minutes (combines all demos)

### Scenario: Deploy New Feature with Full Observability

#### Step 1: Make a Code Change

```bash
# 1. Create feature branch
git checkout -b feat/demo-new-endpoint

# 2. Add a simple endpoint to src/views/people.py:
cat >> src/views/people.py <<'EOF'

@people.route('/people/count', methods=['GET'])
def get_count():
    """Get total count of people"""
    count = db.session.query(Person).count()
    return custom_response({"total": count}, 200)
EOF

# 3. Commit change
git add src/views/people.py
git commit -m "feat: add people count endpoint"

# 4. Push to GitHub (creates PR if fork)
git push origin feat/demo-new-endpoint
```

#### Step 2: Watch CI Pipeline

```bash
# 1. Go to GitHub Actions
# https://github.com/PipeOpsHQ/titanic-api/actions

# 2. Find your workflow run

# 3. Watch status:
#    - 🟠 Queued (30 sec)
#    - 🔵 Running tests (2 min)
#    - 🔵 Security scan (3 min)
#    - ✅ Completed (if all pass)

# 4. If tests fail, review logs and fix locally
# 5. If tests pass, proceed to deployment
```

#### Step 3: Deploy to Staging

```bash
# Once tests pass in CI:

# 1. Merge to main
git checkout main
git merge feat/demo-new-endpoint
git push origin main

# 2. Monitor CI pipeline again (tests + build + push)

# 3. Deploy to staging cluster:
kubectl set image deployment/titanic-api \
  app=titanic-api:main \
  -n titanic-api

# 4. Verify deployment:
kubectl rollout status deployment/titanic-api -n titanic-api

# Expected: deployment "titanic-api" successfully rolled out
```

#### Step 4: Test in Staging

```bash
# 1. Port-forward
kubectl port-forward svc/titanic-api 5000:5000 -n titanic-api

# 2. Test new endpoint
curl http://localhost:5000/people/count
# Expected: {"total": 891}

# 3. Test existing endpoints still work
curl http://localhost:5000/people | head -20

# 4. Check health
curl http://localhost:5000/health/live
```

#### Step 5: Monitor New Deployment

```bash
# 1. Open Grafana dashboard
# (from previous port-forward or: kubectl port-forward svc/grafana 3000:80 -n monitoring)

# 2. Navigate to: Dashboards → Titanic API

# 3. Observe:
#    - Request Rate: Should see requests to /people/count
#    - Latency: New endpoint latency visible
#    - Error Rate: Should be 0%
#    - Resource Usage: CPU/Memory for new container
#    - Pod Count: Shows 2 replicas running

# 4. Generate traffic:
while true; do
  curl -s http://localhost:5000/people/count > /dev/null
  curl -s http://localhost:5000/people > /dev/null
  sleep 1
done

# 5. Watch metrics update in real-time
```

#### Step 6: Check Logs

```bash
# 1. View pod logs:
kubectl logs -f deployment/titanic-api -n titanic-api

# Expected output:
# 127.0.0.1 - - [23/Jan/2026 10:15:23] "GET /people/count HTTP/1.1" 200 -
# 127.0.0.1 - - [23/Jan/2026 10:15:24] "GET /people HTTP/1.1" 200 -

# 2. In Grafana Explore:
#    - Select: Loki data source
#    - View logs from titanic-api pods
#    - Filter by error level (if any)

# 3. Search logs:
#    {namespace="titanic-api"} | "people/count"
```

#### Step 7: Verify Traces

```bash
# 1. In Grafana Explore:
#    - Select: Tempo data source
#    - Service: titanic-api

# 2. View traces for:
#    - GET /people/count
#    - GET /people
#    - POST /people (if created)

# 3. Click trace to see:
#    - Total latency
#    - Database query time
#    - Middleware overhead
#    - Breakdown by span

# Example trace:
# Total: 25ms
#   ├─ Flask middleware: 2ms
#   ├─ Database query: 20ms
#   └─ Response serialization: 3ms
```

#### Step 8: Check Deployment Status

```bash
# 1. View all resources:
kubectl get all -n titanic-api

# Expected:
# NAME                           READY   STATUS    RESTARTS   AGE
# pod/titanic-api-abc-xyz        1/1     Running   0          5m
# pod/titanic-api-def-uvw        1/1     Running   0          5m
# pod/postgres-0                 1/1     Running   0          2h

# NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
# service/titanic-api ClusterIP   10.0.100.10     <none>        5000/TCP
# service/postgres    ClusterIP   10.0.100.20     <none>        5432/TCP

# NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
# deployment.apps/titanic-api 2/2     2            2           2h

# 2. Check HPA (if enabled):
kubectl get hpa -n titanic-api

# Expected:
# NAME         REFERENCE                    TARGETS      MINPODS  MAXPODS  REPLICAS  AGE
# titanic-api  Deployment/titanic-api       25%/70%      2        5        2         2h
```

#### Step 9: Test Failure Scenario (Advanced)

```bash
# Demonstrate system resilience:

# 1. Kill a pod
kubectl delete pod <pod-name> -n titanic-api

# 2. Watch replacement start:
kubectl get pods -n titanic-api --watch

# Expected:
# titanic-api-old-id               Terminating
# titanic-api-new-id               Pending
# titanic-api-new-id               ContainerCreating
# titanic-api-new-id               Running

# 3. API should remain available:
curl http://localhost:5000/people
# Expected: Still working (other pod handles request)

# 4. Check dashboard:
# - Pod count briefly shows 1, then 2
# - Error rate stays 0% (graceful failover)
# - Latency slightly elevated (pod warming up)
```

#### Step 10: Deployment Complete

```bash
# Summary of what we verified:

✅ Code change in Git
✅ CI pipeline executed
   - Tests passed (unit tests, linting)
   - Security scan passed
   - Docker image built and pushed
✅ Deployed to Kubernetes
   - 2 replicas running
   - Service accessible
   - Database connected
✅ Monitored with observability stack
   - Metrics visible in Grafana
   - Logs collected in Loki
   - Traces available in Tempo
   - Alerts configured
✅ Tested functionality
   - New endpoint working
   - Existing endpoints unchanged
   - Health checks passing
✅ Observed resilience
   - Pod failure handling
   - Automatic replacement
   - Zero downtime

Total time: ~30 minutes for complete deployment cycle
```

---

## Quick Reference

### Deployment Commands

```bash
# Deploy to staging
kubectl apply -k k8s/overlays/staging

# Deploy to production
kubectl apply -k k8s/overlays/prod

# Check status
kubectl rollout status deployment/titanic-api -n titanic-api

# View logs
kubectl logs -f <pod-name> -n titanic-api

# Port-forward to access locally
kubectl port-forward svc/titanic-api 5000:5000 -n titanic-api

# Get all resources
kubectl get all -n titanic-api
```

### CI/CD Commands

```bash
# View latest workflow runs
gh run list --repo PipeOpsHQ/titanic-api

# Watch specific workflow
gh run watch <run-id>

# View logs
gh run view <run-id> --log

# Trigger workflow manually (if needed)
git push origin main
```

### Monitoring Commands

```bash
# Port-forward Grafana
kubectl port-forward svc/grafana 3000:80 -n monitoring

# Port-forward Prometheus
kubectl port-forward svc/prometheus 9090:9090 -n monitoring

# Port-forward Loki
kubectl port-forward svc/loki 3100:3100 -n monitoring

# Check monitoring pods
kubectl get pods -n monitoring

# View ServiceMonitor
kubectl get servicemonitor -n monitoring

# View PrometheusRule
kubectl get prometheusrule -n monitoring
```

### API Testing

```bash
# Health check
curl http://localhost:5000/health/live

# Get all
curl http://localhost:5000/people

# Create
curl -X POST http://localhost:5000/people \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","age":30,"passengerClass":1,"survived":true}'

# Update
curl -X PUT http://localhost:5000/people/<id> \
  -H "Content-Type: application/json" \
  -d '{"age":31}'

# Delete
curl -X DELETE http://localhost:5000/people/<id>

# Metrics
curl http://localhost:5000/metrics
```

### Generate Load

```bash
# Simple curl loop
while true; do curl -s http://localhost:5000/people > /dev/null; sleep 1; done

# Apache Bench
ab -n 1000 -c 10 http://localhost:5000/people

# Locust (load testing)
locust -f locustfile.py --host=http://localhost:5000 --headless -u 100 -r 10
```

### Troubleshooting

```bash
# Check deployment errors
kubectl describe deployment titanic-api -n titanic-api

# View pod events
kubectl describe pod <pod-name> -n titanic-api

# Check pod logs
kubectl logs <pod-name> -n titanic-api
kubectl logs <pod-name> -n titanic-api --previous  # Crashed pod

# Get resource usage
kubectl top pods -n titanic-api
kubectl top nodes

# Check services
kubectl get svc -n titanic-api
kubectl describe svc titanic-api -n titanic-api

# View events
kubectl get events -n titanic-api --sort-by='.lastTimestamp'
```

---

## Demo Checklist

Use this before doing live demos:

### Pre-Demo (5 minutes)
- [ ] Git repo cloned and updated
- [ ] kubectl configured and connected
- [ ] Docker image built locally
- [ ] Kubernetes namespace created
- [ ] Monitoring stack deployed
- [ ] All port-forwards closed
- [ ] Terminal windows arranged

### During Demo (30 minutes)
- [ ] Deployment step by step
- [ ] CI pipeline triggered
- [ ] Tests passing in GitHub Actions
- [ ] Image pushed to registry
- [ ] Pod rolling out
- [ ] API responding to requests
- [ ] Monitoring dashboard showing metrics
- [ ] Load test running for visible data
- [ ] Logs and traces accessible

### Post-Demo (5 minutes)
- [ ] Clean up resources: `kubectl delete -k k8s/overlays/staging`
- [ ] Close port-forwards
- [ ] Document observations
- [ ] Note any issues for fixes

---

## Estimated Timing

| Step | Duration | Subtotal |
|------|----------|----------|
| Pre-demo setup | 5 min | 5 min |
| Demo 1: K8s Deployment | 15 min | 20 min |
| Demo 2: CI/CD Pipeline | 10 min | 30 min |
| Demo 3: Monitoring | 15 min | 45 min |
| Demo 4: End-to-end | 25 min | 70 min |
| Q&A + cleanup | 10 min | **80 min** |

**Optimal for**: 60-minute conference talk or 90-minute workshop

---

## Reference Links

**Relevant Documentation**:
- [Kubernetes Deployment Guide](README_K8S.md)
- [Docker Local Run Guide](DOCKER_LOCAL_RUN.md)
- [Monitoring Guide](monitoring/README.md)
- [CI/CD Configuration](.github/workflows/ci-cd.yml)
- [Terraform Deployment](terraform/DEPLOYMENT_RUNBOOK.md)

**External Resources**:
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Grafana Dashboards](https://grafana.com/docs/)
- [Prometheus Queries](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [GitHub Actions](https://docs.github.com/en/actions)

---

**Version**: 1.0.0
**Last Updated**: January 23, 2026
**Status**: Ready for Live Demo 🚀
