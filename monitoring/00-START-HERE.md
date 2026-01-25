# 📦 Monitoring Stack Guide

---

### 🐳 Kubernetes Manifests (10 files)
Production-ready YAML for Kubernetes deployment.

```
00-namespace.yaml
   ├─ titanic-api namespace (app)
   └─ monitoring namespace (observability)

01-serviceaccount-role-rolebinding.yaml
   ├─ titanic-api-sa (app namespace)
   ├─ otel-collector-sa (monitoring namespace)
   ├─ promtail-sa (monitoring namespace)
   ├─ Roles and ClusterRoles (RBAC)
   └─ RoleBindings and ClusterRoleBindings

02-service.yaml
   └─ titanic-api ClusterIP service (port 5000)

03-deployment.yaml
   ├─ titanic-api Deployment (2 replicas)
   ├─ OTEL environment variables
   ├─ Prometheus annotations
   ├─ Health checks
   ├─ Security context
   └─ Pod anti-affinity

04-otel-collector-configmap.yaml
   ├─ OTLP receivers (gRPC 4317, HTTP 4318)
   ├─ Prometheus receiver (metrics scraping)
   ├─ Processors (batch, resource, attributes, memory_limiter, tail_sampling)
   ├─ Exporters (jaeger/tempo, prometheus, logging)
   └─ Service pipelines (traces, metrics, logs)

05-otel-collector-deployment.yaml
   ├─ OTEL Collector Deployment (1 replica)
   ├─ Image: otel/opentelemetry-collector-k8s:0.88.0
   ├─ Ports: 4317, 4318, 8888, 13133, 1777
   ├─ Services and probes
   └─ Security context (non-root, read-only FS)

06-promtail-configmap.yaml
   ├─ Promtail scrape configuration
   ├─ Kubernetes pod discovery
   ├─ Log path configuration
   ├─ Label extraction rules
   └─ Loki client configuration

07-promtail-daemonset.yaml
   ├─ Promtail DaemonSet (1 pod per node)
   ├─ Image: grafana/promtail:2.9.3
   ├─ Volume mounts (logs, journal)
   ├─ Tolerations for all taints
   └─ Low resource usage (50m/64Mi)

08-servicemonitor.yaml
   ├─ ServiceMonitor: titanic-api-monitor
   ├─ ServiceMonitor: otel-collector-monitor
   ├─ ServiceMonitor: promtail-monitor
   └─ (Requires Prometheus Operator)

09-prometheusrule.yaml
   ├─ PrometheusRule: titanic-api-alerts (8 rules)
   ├─ PrometheusRule: otel-collector-alerts (2 rules)
   └─ Rules with severity labels (critical, warning)

10-grafana-dashboard-titanic-api.json
   ├─ Grafana dashboard (8 panels)
   ├─ Request rate by method (timeseries)
   ├─ Response latency percentiles (timeseries)
   ├─ Error rate by status code (timeseries)
   ├─ Resource utilization CPU/Memory (timeseries)
   ├─ Current request rate (stat)
   ├─ Current error rate (stat)
   ├─ P95 latency (stat)
   └─ Running pods (stat)
```

**Deploy with:**
```bash
kubectl apply -f *.yaml
```

---

### 📖 Documentation Files (8 files)

#### Entry Points (Read First)

**[GETTING_STARTED.md](GETTING_STARTED.md)** ⭐ START HERE
- 5-minute quick start
- Path selection (deploy now vs. learn first)
- Common tasks
- Troubleshooting quick links
- Pro tips
- **Best for**: First-time deployers

**[DEPLOYMENT_SUMMARY.md](DEPLOYMENT_SUMMARY.md)**
- What was created (overview)
- Key features
- Observability coverage
- 3-step quick start
- Files checklist
- Configuration defaults
- **Best for**: Getting the big picture

#### Complete Guides

**[README.md](README.md)** 📘 COMPLETE REFERENCE
- Architecture overview
- Files listing
- Quick start options
- Configuration guide (sampling, endpoints, etc.)
- Verification steps (8 detailed steps)
- Alerting rules (10+ rules with details)
- Dashboard panels (8 panels explained)
- Structured logging format
- Trace propagation
- Security notes
- Cleanup and rollback
- Troubleshooting (with solutions)
- **Best for**: Complete understanding, reference

**[DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)** ✅ STEP-BY-STEP
- Pre-deployment checklist
- Installation steps (11 detailed steps)
- Post-deployment verification (8 detailed steps)
- Generate test data
- Verification checklist (all components)
- Rollback plan
- Troubleshooting during deployment
- **Best for**: First-time deployment

#### Specialized Guides

**[APP_INSTRUMENTATION_GUIDE.md](APP_INSTRUMENTATION_GUIDE.md)** 💻 FOR DEVELOPERS
- Python dependencies installation
- Prometheus metrics setup (copy-paste code)
- OpenTelemetry tracing configuration (copy-paste code)
- Structured logging setup (copy-paste code)
- Flask app integration (copy-paste code)
- View instrumentation examples
- Testing instrumentation
- Performance tuning
- Troubleshooting
- **Best for**: Adding metrics/tracing/logging to Flask app

**[SCRAPE_CONFIGS_NO_OPERATOR.md](SCRAPE_CONFIGS_NO_OPERATOR.md)** 🔧 WITHOUT OPERATOR
- Prometheus scrape configurations
- For non-Prometheus-Operator clusters
- Configuration options (ConfigMap, Helm, Operator spec)
- Verification steps
- Troubleshooting scrape configs
- Cloud provider examples (EKS, GKE, AKS)
- **Best for**: Clusters without Prometheus Operator

#### Reference Guides

**[INDEX.md](INDEX.md)** 📑 QUICK REFERENCE
- Files overview (detailed)
- Configuration reference
- Resource limits table
- Metrics catalog
- Integration points
- Verification checklist
- Support quick links
- **Best for**: Looking up specific information

---

## 📊 File Statistics

| Category | Count | Total Lines |
|----------|-------|------------|
| YAML Manifests | 10 | ~1,200 |
| Grafana Dashboard | 1 | ~500 |
| Documentation | 7 | ~2,500 |
| **Total** | **18** | **~4,200** |

---

## 🎯 Reading Paths

### Path 1: Deploy Now (15 min)
```
GETTING_STARTED.md
        ↓
   kubectl apply -f .
        ↓
README.md (Verification section)
```

### Path 2: Learn First (45 min)
```
GETTING_STARTED.md
        ↓
DEPLOYMENT_SUMMARY.md
        ↓
README.md (Architecture section)
        ↓
INDEX.md (File descriptions)
        ↓
DEPLOYMENT_CHECKLIST.md
        ↓
   kubectl apply -f .
```

### Path 3: Deep Dive (2 hours)
```
GETTING_STARTED.md
        ↓
DEPLOYMENT_SUMMARY.md
        ↓
README.md (entire document)
        ↓
INDEX.md
        ↓
APP_INSTRUMENTATION_GUIDE.md
        ↓
SCRAPE_CONFIGS_NO_OPERATOR.md
        ↓
DEPLOYMENT_CHECKLIST.md
        ↓
   kubectl apply -f .
        ↓
   Instrument application
```

---

## 🔍 Find What You Need

### "I want to deploy"
→ [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)

### "I don't have Prometheus Operator"
→ [SCRAPE_CONFIGS_NO_OPERATOR.md](SCRAPE_CONFIGS_NO_OPERATOR.md)

### "I want to add tracing/metrics to my code"
→ [APP_INSTRUMENTATION_GUIDE.md](APP_INSTRUMENTATION_GUIDE.md)

### "Something isn't working"
→ [README.md](README.md) Troubleshooting section

### "I want to understand the architecture"
→ [README.md](README.md) Overview section + [DEPLOYMENT_SUMMARY.md](DEPLOYMENT_SUMMARY.md)

### "I need to configure something"
→ [README.md](README.md) Configuration section

### "What does this file do?"
→ [INDEX.md](INDEX.md) File descriptions

### "I need step-by-step deployment"
→ [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)

### "I'm new and confused"
→ Start with [GETTING_STARTED.md](GETTING_STARTED.md)

---

## ✅ Deployment Readiness Checklist

- [x] 10 Kubernetes manifests created
  - [x] Namespaces
  - [x] RBAC
  - [x] Services
  - [x] Deployments
  - [x] DaemonSets
  - [x] ConfigMaps
  - [x] ServiceMonitor CRDs
  - [x] PrometheusRule CRDs

- [x] 1 Grafana dashboard created
  - [x] 8 monitoring panels
  - [x] Ready to import

- [x] 8 documentation files created
  - [x] Getting started guide
  - [x] Complete README
  - [x] Step-by-step checklist
  - [x] Deployment summary
  - [x] Application instrumentation guide
  - [x] Non-operator scrape configs
  - [x] File index/reference
  - [x] This file (file listing)

- [x] All manifests follow best practices
  - [x] RBAC configured
  - [x] Security context applied
  - [x] Resource limits set
  - [x] Health checks implemented
  - [x] Pod anti-affinity configured
  - [x] No secrets in YAML
  - [x] Proper labels/annotations

---

## 🚀 Quick Start (Choose One)

### Option 1: Deploy Immediately
```bash
cd monitoring/
kubectl apply -f .
# Done! See README.md for verification
```

### Option 2: Read First
```bash
cat DEPLOYMENT_CHECKLIST.md
# ... read ...
cd monitoring/
kubectl apply -f .
```

### Option 3: Full Understanding
```bash
cat GETTING_STARTED.md
cat DEPLOYMENT_SUMMARY.md
cat README.md
# ... then ...
cd monitoring/
kubectl apply -f .
```

---

## 📞 Support

**First issue?** → Check [README.md](README.md) Troubleshooting
**How to deploy?** → Read [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)
**Adding code changes?** → Follow [APP_INSTRUMENTATION_GUIDE.md](APP_INSTRUMENTATION_GUIDE.md)
**No Prometheus Operator?** → Use [SCRAPE_CONFIGS_NO_OPERATOR.md](SCRAPE_CONFIGS_NO_OPERATOR.md)
**Need quick reference?** → Check [INDEX.md](INDEX.md)
**Confused?** → Start with [GETTING_STARTED.md](GETTING_STARTED.md)

---

## 📌 Summary

You have a complete, production-ready monitoring stack:

**✅ 10 Kubernetes manifests** - Ready to deploy
**✅ 1 Grafana dashboard** - Ready to import
**✅ 8 documentation files** - Everything explained
**✅ 2,500+ lines of documentation** - Comprehensive guides
**✅ Copy-paste ready code** - For application instrumentation
**✅ Best practices applied** - Security, RBAC, health checks

**Status: READY FOR DEPLOYMENT** 🚀

Start with [GETTING_STARTED.md](GETTING_STARTED.md) and pick your path!
