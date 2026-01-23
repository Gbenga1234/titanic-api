# 🚀 Getting Started - Monitoring Stack

Welcome! You have a complete production-ready monitoring and instrumentation stack for Titanic API.

## ⚡ 60-Second Quick Start

### 1. Deploy (30 seconds)
```bash
cd monitoring/
kubectl apply -f .
```

### 2. Wait (15 seconds)
```bash
kubectl get pods -n monitoring
# Wait until all pods are Running
```

### 3. Verify (15 seconds)
```bash
# Check metrics endpoint
kubectl port-forward -n titanic-api svc/titanic-api 5000:5000 &
curl -s http://localhost:5000/metrics | head -5
```

**Done!** You now have:
- ✅ Prometheus metrics collection
- ✅ OpenTelemetry tracing
- ✅ Centralized logging
- ✅ Alert rules
- ✅ Grafana dashboard ready

---

## 📁 What You Have

### Kubernetes Manifests (10 files)
All YAML manifests ready to deploy:
- Namespaces, RBAC, Services
- Titanic API with OTEL instrumentation
- OpenTelemetry Collector
- Promtail log collector
- Prometheus ServiceMonitor & rules

### Grafana Dashboard (1 file)
8-panel dashboard showing:
- Request rate & latency
- Error rate
- Resource utilization
- Current health metrics

### Documentation (6 files)
Everything you need to know:

| File | Read This If... |
|------|-----------------|
| **DEPLOYMENT_SUMMARY.md** | You want a quick overview |
| **README.md** | You want complete details |
| **DEPLOYMENT_CHECKLIST.md** | You're deploying for the first time |
| **APP_INSTRUMENTATION_GUIDE.md** | You're adding tracing/metrics to code |
| **SCRAPE_CONFIGS_NO_OPERATOR.md** | Your cluster has no Prometheus Operator |
| **INDEX.md** | You want a file reference |

---

## 📋 Choose Your Path

### Path 1: Deploy Now (Recommended)
**Time: 10 minutes**

1. Read: [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) (5 min)
2. Run: `kubectl apply -f monitoring/` (2 min)
3. Verify: Follow verification section (3 min)

→ **Then**: Read [README.md](README.md) Configuration section

### Path 2: Understand First
**Time: 30 minutes**

1. Read: [DEPLOYMENT_SUMMARY.md](DEPLOYMENT_SUMMARY.md) (5 min)
2. Read: [README.md](README.md) Architecture section (10 min)
3. Read: [INDEX.md](INDEX.md) File details (10 min)
4. Deploy: `kubectl apply -f monitoring/` (5 min)

→ **Then**: Follow [APP_INSTRUMENTATION_GUIDE.md](APP_INSTRUMENTATION_GUIDE.md)

### Path 3: Custom Setup
**Time: 45 minutes**

1. Read: [README.md](README.md) Configuration section (15 min)
2. Customize: Edit YAML manifests (15 min)
3. Deploy: `kubectl apply -f .` (5 min)
4. Verify: Follow README verification section (10 min)

→ **Then**: Configure alerts in [README.md](README.md) Alerting section

---

## 🎯 Common Tasks

### "I just want to deploy"
```bash
cd monitoring/
kubectl apply -f .
# Done! See README.md for verification steps
```

### "I want to add tracing to my code"
→ **Read**: [APP_INSTRUMENTATION_GUIDE.md](APP_INSTRUMENTATION_GUIDE.md)

### "My cluster doesn't have Prometheus Operator"
→ **Read**: [SCRAPE_CONFIGS_NO_OPERATOR.md](SCRAPE_CONFIGS_NO_OPERATOR.md)

### "I need to configure something"
→ **Read**: [README.md](README.md) Configuration section

### "Something isn't working"
→ **Read**: [README.md](README.md) Troubleshooting section

### "I need the complete picture"
→ **Read**: [DEPLOYMENT_SUMMARY.md](DEPLOYMENT_SUMMARY.md)

---

## ✅ Deployment Verification

After running `kubectl apply -f .`:

### 1. Check Pods
```bash
kubectl get pods -n monitoring
# All should show "1/1 Running"
```

### 2. Check Metrics
```bash
kubectl port-forward -n titanic-api svc/titanic-api 5000:5000 &
curl http://localhost:5000/metrics
# Should show prometheus metrics
```

### 3. Check Prometheus
```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
# Visit http://localhost:9090/targets
# Should show 3 jobs UP (titanic-api, otel-collector, promtail)
```

### 4. Check Dashboard
```bash
kubectl port-forward -n monitoring svc/grafana 3000:3000 &
# Visit http://localhost:3000
# Import 10-grafana-dashboard-titanic-api.json
```

→ **For detailed verification**: See [README.md Verification Steps](README.md#verification-steps)

---

## 📊 What Gets Monitored

| What | How | View In |
|------|-----|---------|
| **API Requests** | /metrics endpoint | Prometheus |
| **Request Latency** | Histogram | Grafana Dashboard |
| **Errors** | 5xx count | Grafana Dashboard + Alerts |
| **Traces** | OTEL SDK | Jaeger/Tempo |
| **Logs** | stdout → Promtail | Loki |
| **Pod Health** | Restarts, CPU, Memory | Prometheus + Grafana |
| **Alerts** | Error rate, Latency, Crashes | Prometheus Alerts |

---

## 🔧 Configuration Essentials

### OTEL Tracing Sampling
By default: **10% of traces** (production-friendly)

To change:
```bash
kubectl set env deployment/titanic-api \
  OTEL_TRACES_SAMPLER_ARG=0.5 \
  -n titanic-api
# Valid values: 0.0 (none) to 1.0 (all)
```

### OTEL Exporter Endpoint
By default: `otel-collector.monitoring.svc.cluster.local:4317`

To change:
```bash
kubectl set env deployment/titanic-api \
  OTEL_EXPORTER_OTLP_ENDPOINT=http://your-jaeger:4317 \
  -n titanic-api
```

### Log Level
By default: `INFO`

To change:
```bash
kubectl set env deployment/titanic-api \
  LOG_LEVEL=DEBUG \
  -n titanic-api
```

→ **For all configuration options**: See [README.md Configuration](README.md#configuration)

---

## 🚨 Key Alert Rules

| Alert | Fires When | Severity |
|-------|-----------|----------|
| HighErrorRate | 5xx > 5% for 5m | 🔴 Critical |
| HighLatencyP95 | P95 > 2s for 5m | 🟡 Warning |
| PodRestartBurst | >3 restarts in 15m | 🔴 Critical |
| HighMemoryUsage | > 85% for 5m | 🟡 Warning |
| HighCPUUsage | > 80% for 5m | 🟡 Warning |

→ **To customize**: Edit [09-prometheusrule.yaml](09-prometheusrule.yaml)

→ **For all rules**: See [README.md Alerting Rules](README.md#-alerting-rules)

---

## 🆘 Quick Troubleshooting

### Pods not running?
```bash
kubectl describe pod -n monitoring <pod-name>
kubectl logs -n monitoring <pod-name>
```

### Metrics not appearing?
```bash
# Verify endpoint works
kubectl port-forward -n titanic-api svc/titanic-api 5000:5000
curl http://localhost:5000/metrics
```

### Prometheus not scraping?
```bash
# Check targets
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Visit http://localhost:9090/targets
# Check for errors in target details
```

→ **For detailed help**: See [README.md Troubleshooting](README.md#troubleshooting)

---

## 📚 Documentation Map

```
📖 START HERE → DEPLOYMENT_SUMMARY.md
                      ↓
                [Choose Path]
                 /    |    \
                /     |     \
               /      |      \
   Path 1    Path 2   Path 3
   "Deploy   "Learn   "Custom"
   Now"      First"   Setup"
    ↓         ↓        ↓
  CHECK →  README → SCRAPE_
  LIST.md   CONFIGS.md
    ↓         ↓
  APPLY   CONFIG
   yaml    yaml
    ↓         ↓
    ✅ Running
    
For Code Changes:
  README.md → APP_INSTRUMENTATION_GUIDE.md → Add to code
  
File Reference:
  INDEX.md → Detailed description of each file
```

---

## 🎓 Learning Resources

### For Kubernetes/Monitoring Engineers
1. [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) - Step-by-step deploy
2. [README.md](README.md) - Complete reference
3. [INDEX.md](INDEX.md) - File descriptions

### For Application Developers
1. [APP_INSTRUMENTATION_GUIDE.md](APP_INSTRUMENTATION_GUIDE.md) - Add tracing/metrics
2. [README.md](README.md) - Structured logging section

### For DevOps/SRE
1. [README.md](README.md) - Security notes section
2. [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) - Rollback plan

### For Non-Prometheus-Operator Clusters
1. [SCRAPE_CONFIGS_NO_OPERATOR.md](SCRAPE_CONFIGS_NO_OPERATOR.md) - Manual config

---

## ✨ Features at a Glance

✅ **Application Metrics**
- Request rate, latency, error rate
- Custom metrics support
- Prometheus `/metrics` endpoint

✅ **Distributed Tracing**
- OpenTelemetry SDK integration
- 10% default sampling (tunable)
- Exports to Jaeger/Tempo
- Trace propagation via W3C headers

✅ **Centralized Logging**
- Promtail pod log collection
- Automatic label extraction
- Exports to Loki
- Query by service, level, trace_id, request_id

✅ **Alerting**
- 10+ pre-built alert rules
- Error rate, latency, crashes, resources
- Severity labels (critical, warning)
- Integration with your alert manager

✅ **Grafana Dashboard**
- 8 monitoring panels
- Request rate & latency
- Error rate breakdown
- Resource utilization
- Health metrics

✅ **Production Ready**
- RBAC configured
- Security best practices
- Resource limits
- Health checks
- Graceful shutdown

---

## 🚀 Next: What to Do After Deployment

### Immediate (Day 1)
1. ✅ Deploy with `kubectl apply -f monitoring/`
2. ✅ Verify all pods running
3. ✅ Check metrics endpoint works
4. ✅ Import Grafana dashboard

### Short Term (Week 1)
1. 📝 Add tracing to application code (see APP_INSTRUMENTATION_GUIDE.md)
2. 🔔 Configure alert notifications
3. 📊 Review dashboard panels
4. 🔍 Make test requests and check traces

### Medium Term (Month 1)
1. 🎯 Tune alert thresholds
2. ⚙️ Adjust sampling rates for your load
3. 📈 Add custom metrics/dashboards
4. 🛡️ Review security settings

### Long Term (Ongoing)
1. 📊 Monitor dashboard health
2. 🔔 Respond to alerts
3. 🔧 Fine-tune configuration
4. 📈 Track metrics trends

---

## 💡 Pro Tips

### Tip 1: Test Everything
Make requests to generate metrics:
```bash
kubectl port-forward svc/titanic-api 5000:5000
for i in {1..100}; do curl http://localhost:5000/people; done
```

### Tip 2: Check Component Health
```bash
# Check all monitoring pods
watch kubectl get pods -n monitoring

# Check logs
kubectl logs -n monitoring -l app=otel-collector
kubectl logs -n monitoring -l app=promtail
```

### Tip 3: Save Customizations
Make a copy before editing:
```bash
cp 09-prometheusrule.yaml 09-prometheusrule.yaml.bak
# Then edit
kubectl apply -f 09-prometheusrule.yaml
```

### Tip 4: Use Port-Forward for Testing
```bash
# Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Loki
kubectl port-forward -n monitoring svc/loki 3100:3100

# Jaeger
kubectl port-forward -n monitoring svc/jaeger 16686:16686

# Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

---

## 📞 Getting Help

### Problem → Solution

| Problem | See |
|---------|-----|
| "How do I deploy?" | [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) |
| "Pods aren't running" | [README.md Troubleshooting](README.md#troubleshooting) |
| "No metrics showing" | [README.md Verification](README.md#2-verify-metrics-endpoint) |
| "How do I add tracing?" | [APP_INSTRUMENTATION_GUIDE.md](APP_INSTRUMENTATION_GUIDE.md) |
| "No Prometheus Operator" | [SCRAPE_CONFIGS_NO_OPERATOR.md](SCRAPE_CONFIGS_NO_OPERATOR.md) |
| "Which file does what?" | [INDEX.md](INDEX.md) |
| "Complete overview?" | [README.md](README.md) |
| "Step-by-step guide?" | [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) |

---

## 🎉 You're All Set!

You now have everything needed for production-grade monitoring:

✅ **10 Kubernetes manifests** - Ready to deploy
✅ **1 Grafana dashboard** - Ready to import  
✅ **6 documentation files** - Complete guides
✅ **Best practices applied** - Security, RBAC, health checks
✅ **Production ready** - No placeholders, no TODOs

### Start Here:
```bash
# Option 1: Deploy immediately
cd monitoring/
kubectl apply -f .

# Option 2: Read first, then deploy
cat DEPLOYMENT_CHECKLIST.md
# ... read checklist ...
kubectl apply -f .

# Option 3: Understand everything
cat DEPLOYMENT_SUMMARY.md
cat README.md
# ... then deploy ...
kubectl apply -f .
```

**Happy monitoring!** 🚀

---

**Questions?** Check [README.md](README.md) or [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)
