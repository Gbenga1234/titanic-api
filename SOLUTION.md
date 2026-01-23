# Titanic API - Complete Solution Documentation

**Project**: Titanic Passenger Data REST API
**Version**: 1.0.0
**Status**: Production Ready
**Last Updated**: January 2026

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Setup Instructions](#setup-instructions)
3. [Design Decisions & Trade-offs](#design-decisions--trade-offs)
4. [Known Limitations](#known-limitations)
5. [Future Improvements](#future-improvements)
6. [Estimated Cloud Costs](#estimated-cloud-costs)

---

## Architecture Overview

### High-Level System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         External Users / Clients                      │
└────────────────────────────────┬────────────────────────────────────┘
                                 │ HTTPS
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      Azure Load Balancer / Ingress                    │
│                        (Public IP, SSL/TLS)                          │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    ▼                         ▼
        ┌──────────────────────┐   ┌──────────────────────┐
        │   Kubernetes Cluster │   │   Kubernetes Cluster │
        │   (Azure AKS - US)   │   │  (Azure AKS - EU)    │
        │   (Primary)          │   │  (Failover)          │
        └──────────────────────┘   └──────────────────────┘
                    │
    ┌───────────────┼───────────────┐
    ▼               ▼               ▼
┌─────────────┐ ┌──────────────┐ ┌──────────────┐
│  Flask App  │ │ Prometheus   │ │  Promtail    │
│  (Titanic   │ │  (Metrics)   │ │  (Logs)      │
│   API)      │ │              │ │              │
│  2-5 pods   │ │ ServiceMon   │ │  DaemonSet   │
│  HPA        │ │  PrometheusR │ │  1 per node  │
│  PDB        │ │  (Alerts)    │ │              │
└─────────────┘ └──────────────┘ └──────────────┘
    │               │                   │
    │               ▼                   ▼
    │           ┌──────────────┐   ┌──────────────┐
    │           │ PostgreSQL   │   │ OpenTelemetry│
    │           │ (Stateful)   │   │ Collector    │
    │           │ 15.x         │   │ (Distributed │
    │           │ Replication  │   │  Tracing)    │
    │           │ Backup       │   │              │
    │           └──────────────┘   └──────────────┘
    │                                   │
    └───────────────┬───────────────────┘
                    │
    ┌───────────────┼───────────────┐
    ▼               ▼               ▼
┌────────────┐ ┌────────────┐ ┌────────────┐
│   Loki     │ │   Tempo    │ │  Grafana   │
│  (Log      │ │  (Traces)  │ │  (Visual   │
│ Storage)   │ │            │ │  Dashbd)   │
└────────────┘ └────────────┘ └────────────┘
                    │               │
                    └───────┬───────┘
                            ▼
                    ┌───────────────┐
                    │ Alertmanager  │
                    │ (Notifications│
                    │  PagerDuty)   │
                    └───────────────┘
```

### Network Architecture (Kubernetes)

```
┌─────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                     │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   titanic-api│  │  monitoring  │  │   security   │  │
│  │  namespace   │  │  namespace   │  │  namespace   │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│       │                   │                   │          │
│       ├─ Flask App        ├─ Prometheus       ├─ Vault  │
│       ├─ Service          ├─ Grafana          └─ Secrets│
│       ├─ ConfigMap        ├─ Loki             Manager  │
│       ├─ Ingress          ├─ Tempo                      │
│       └─ PostgreSQL       ├─ OTEL Collector            │
│                           └─ Alertmanager              │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐│
│  │            Network Policies (per namespace)         ││
│  │  - Deny ingress by default                          ││
│  │  - Allow from Prometheus only on :8888              ││
│  │  - Allow DNS egress                                 ││
│  │  - Database access restricted to app namespace      ││
│  └─────────────────────────────────────────────────────┘│
│                                                           │
│  ┌─────────────────────────────────────────────────────┐│
│  │              Service Mesh (Optional)                ││
│  │  - Istio/Linkerd for:                              ││
│  │    • Traffic routing (canary deploys)              ││
│  │    • Circuit breaking                              ││
│  │    • Rate limiting                                 ││
│  └─────────────────────────────────────────────────────┘│
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Data Flow

#### Request Flow
```
1. Client Request
   │
   ├─> Load Balancer (IP forwarding)
   │
   ├─> Kubernetes Ingress
   │   ├─ SSL/TLS termination
   │   ├─ Rate limiting
   │   └─ Authentication (OAuth optional)
   │
   ├─> Flask Application
   │   ├─ Request logging (JSON + trace_id)
   │   ├─ Prometheus metric increment (api_requests_total)
   │   ├─ OpenTelemetry span creation
   │   └─ Database query execution
   │
   ├─> PostgreSQL
   │   ├─ Connection pooling (10-20 connections)
   │   ├─ Query execution
   │   └─ Transaction logging
   │
   ├─> Response generation
   │   ├─ Prometheus metric observation (api_response_latency_seconds)
   │   ├─ Structured JSON response
   │   └─ Trace headers (W3C traceparent)
   │
   ├─> Log Export
   │   └─> Promtail -> Loki (async)
   │
   └─> Response to Client (with trace_id header)
```

#### Monitoring Flow
```
Metrics Collection:
  Flask App (prometheus-client)
    ↓
  /metrics endpoint (Prometheus format)
    ↓
  Prometheus Scraper (ServiceMonitor)
    ↓
  Prometheus TSDB (15-day retention)
    ↓
  Grafana Dashboards
    ↓
  PrometheusRule (Alert evaluation)
    ↓
  Alertmanager (Notification routing)
    ↓
  PagerDuty / Slack / Email

Tracing Collection:
  OpenTelemetry SDK (Flask)
    ↓
  OTEL Collector (tail sampling)
    ↓
  Tempo / Jaeger backend
    ↓
  Trace visualization (Grafana)

Logs Collection:
  stdout/stderr (JSON)
    ↓
  Promtail (pod discovery)
    ↓
  Loki (log aggregation)
    ↓
  Grafana Explore (log search)
    ↓
  Alert rules (LogQL)
```

### Component Details

#### Flask Application
- **Language**: Python 3.11
- **Framework**: Flask 2.0.1
- **Database**: PostgreSQL 15
- **ORM**: SQLAlchemy 1.4.x
- **Serialization**: Marshmallow 3.12.2
- **WSGI Server**: Gunicorn 20.1.0
- **Port**: 5000 (internal), 443 (external via TLS)

#### Database Layer
- **Type**: PostgreSQL 15 (Azure Database for PostgreSQL)
- **Connection Pool**: PgBouncer (20 connections)
- **Replication**: Read replicas in secondary region (HA)
- **Backup**: Automated daily + point-in-time recovery (35 days)
- **Encryption**: At-rest (AES-256) and in-transit (SSL/TLS)
- **Scaling**: Vertical (larger instance type)

#### Observability Stack
- **Metrics**: Prometheus Operator + ServiceMonitor CRDs
- **Tracing**: OpenTelemetry Collector → Tempo (Grafana)
- **Logging**: Promtail DaemonSet → Loki (Grafana)
- **Visualization**: Grafana 9+ (8-panel dashboard)
- **Alerting**: PrometheusRule CRDs → Alertmanager → PagerDuty

#### Deployment Stack
- **Container Orchestration**: Azure Kubernetes Service (AKS) 1.29+
- **Container Registry**: Azure Container Registry (ACR)
- **Infrastructure as Code**: Terraform 1.5+
- **GitOps**: ArgoCD (optional, for continuous deployment)
- **Secrets Management**: Azure Key Vault or Sealed Secrets

---

## Setup Instructions

### Prerequisites

#### Local Development
- Docker Desktop (includes Docker Compose)
- Git
- Python 3.11+ (for direct execution)
- PostgreSQL 15+ (or use Docker)
- kubectl (for Kubernetes interaction)

#### Production Deployment
- Azure Subscription
- Terraform 1.5+
- kubectl 1.29+
- Helm 3.x (optional)
- ArgoCD CLI (optional)

### Option 1: Local Development (Fastest)

```bash
# 1. Clone repository
git clone https://github.com/PipeOpsHQ/titanic-api.git
cd titanic-api

# 2. Start with Docker Compose (includes hot-reload)
docker-compose -f docker-compose.dev.yml up --build

# 3. API available at http://localhost:5000
curl http://localhost:5000/people
```

**Time**: 5 minutes | **Resources**: 2GB RAM

**See**: [DOCKER_LOCAL_RUN.md](DOCKER_LOCAL_RUN.md) for detailed Docker setup

### Option 2: Kubernetes (Local/Minikube)

```bash
# 1. Start Minikube
minikube start --cpus=4 --memory=8192

# 2. Build and push image
docker build -t titanic-api:latest .
minikube image load titanic-api:latest

# 3. Apply base Kubernetes manifests
kubectl apply -k k8s/

# 4. Port forward to access
kubectl port-forward svc/titanic-api 5000:5000 -n titanic-api

# 5. API available at http://localhost:5000
```

**Time**: 10-15 minutes | **Resources**: 8GB RAM, 4 CPU cores

### Option 3: Azure Production Deployment (Terraform)

```bash
# 1. Setup Azure credentials
az login
az account set --subscription <your-subscription-id>

# 2. Configure Terraform variables
cd terraform/environments/prod/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 3. Validate and plan
terraform validate
terraform plan -out=tfplan

# 4. Apply infrastructure
terraform apply tfplan

# 5. Get cluster credentials
az aks get-credentials \
  --resource-group <rg-name> \
  --name <cluster-name>

# 6. Deploy monitoring stack
cd ../../..
kubectl apply -f monitoring/

# 7. Deploy application (manual or ArgoCD)
kubectl apply -f k8s/
# OR: argocd app create titanic-api --repo ... --path k8s/
```

**Time**: 30-45 minutes | **Cost**: ~$500/month (see estimates below)

**See**: [terraform/DEPLOYMENT_RUNBOOK.md](terraform/DEPLOYMENT_RUNBOOK.md) for detailed steps

### Option 4: Production Deployment (GitOps/ArgoCD)

```bash
# 1. Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 2. Create ArgoCD Application
kubectl apply -f argocd/argocd-application.yaml
kubectl apply -f argocd/appproject.yaml

# 3. Access ArgoCD
kubectl port-forward svc/argocd-server 8080:443 -n argocd
# Login at http://localhost:8080

# 4. Deployment syncs automatically on git push
git push origin main
# ArgoCD detects changes and deploys within 3 minutes
```

**Time**: 15 minutes | **Sync**: Automatic (3-5 min after git push)

**See**: [argocd/README.md](argocd/README.md) for ArgoCD setup

### Monitoring Stack Setup

```bash
# 1. Create monitoring namespace
kubectl create namespace monitoring

# 2. Install Prometheus Operator (if not using Kustomize)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f monitoring-values.yaml

# 3. Deploy application-specific monitoring
kubectl apply -f monitoring/

# 4. Verify deployment
kubectl get pods -n monitoring
kubectl get servicemonitor -n monitoring

# 5. Access Grafana
kubectl port-forward svc/grafana 3000:80 -n monitoring
# Login at http://localhost:3000 (admin/admin)

# 6. Import dashboard
# Dashboard ID: 10-grafana-dashboard-titanic-api.json
# Data source: Prometheus
```

**Time**: 10 minutes

**See**: [monitoring/README.md](monitoring/README.md) for detailed monitoring setup

---

## Design Decisions & Trade-offs

### 1. Python Flask vs. Go/Node.js

#### Decision: Python Flask
**Rationale**:
- ✅ Rapid development and prototyping
- ✅ Rich ecosystem (SQLAlchemy, Marshmallow, pytest)
- ✅ Excellent documentation and community support
- ✅ Easy to maintain and onboard developers
- ✅ Strong observability libraries (OpenTelemetry, prometheus-client)

**Trade-offs**:
- ❌ Slightly slower than Go/Rust (mitigated by horizontal scaling)
- ❌ Higher memory footprint per pod (~100MB vs 10MB Go)
- ❌ GIL limits true parallelism (mitigated by async patterns)

**Alternative Considered**: FastAPI
- FastAPI offers async/await out-of-the-box
- Would provide 2-3x performance improvement
- However, for Titanic API scale (simple CRUD), Flask is sufficient

### 2. PostgreSQL vs. MongoDB/Cassandra

#### Decision: PostgreSQL (Relational)
**Rationale**:
- ✅ ACID compliance essential for Titanic data integrity
- ✅ Strong schema validation
- ✅ Complex queries (joins, aggregations) on passenger data
- ✅ Cost-effective for small-medium datasets
- ✅ Excellent backup/replication support

**Trade-offs**:
- ❌ Vertical scaling limit (~64 CPU, 1TB RAM)
- ❌ Horizontal scaling requires sharding (complex)
- ❌ Slower at massive scale (100M+ records)

**For Titanic Scale**: Perfect fit
- Dataset: 891 records base → max 100K with synthetic expansion
- Queries: ~1K req/sec = 86M/day (well within PostgreSQL limits)

### 3. Kubernetes vs. Serverless/AppService

#### Decision: Kubernetes (Container Orchestration)
**Rationale**:
- ✅ Full control over deployment and scaling
- ✅ Runs anywhere (Azure, AWS, on-premises)
- ✅ Cost-effective for steady workloads (vs serverless)
- ✅ Supports complex monitoring/tracing/logging stacks
- ✅ Infrastructure as Code (Terraform) for reproducibility

**Trade-offs**:
- ❌ Requires operational overhead (cluster management)
- ❌ More complex than Azure App Service
- ❌ Higher baseline cost (~$500/month vs $50/month App Service)

**Hybrid Approach Considered**: Azure App Service + Docker
- Would be simpler for basic deployments
- Lacks fine-grained observability control
- Less suitable for multi-region failover

### 4. Prometheus + Loki + Tempo vs. Datadog/New Relic

#### Decision: Open Source Stack (Prometheus + Loki + Tempo)
**Rationale**:
- ✅ No recurring licensing costs (~$500/month → $0)
- ✅ Data stays in your infrastructure
- ✅ Unlimited cardinality (tags)
- ✅ Fully customizable (dashboards, alerts)
- ✅ Active open-source communities

**Trade-offs**:
- ❌ Requires self-hosting and maintenance
- ❌ No built-in anomaly detection (Datadog ML features)
- ❌ Smaller community vs enterprise SaaS tools
- ❌ Storage/retention management needed

**Cost Comparison**:
| Tool | Monthly Cost | Included |
|------|-------------|----------|
| Open Stack | $0 (self-hosted) | Metrics, Logs, Traces, Alerts |
| Datadog | $500-2000 | Metrics, Logs, Traces + ML + APM |
| New Relic | $300-1500 | Similar to Datadog |
| Dynatrace | $400-1200 | APM-focused |

### 5. Single Region vs. Multi-Region

#### Decision: Primary Region + Hot Standby (Prod) / Single Region (Dev)
**Rationale**:
- ✅ High availability (99.95% SLA with failover)
- ✅ Disaster recovery capability
- ✅ Compliance with data residency (GDPR)
- ✅ Acceptable cost-benefit for production

**Trade-offs**:
- ❌ Double infrastructure cost (~$1000/month for 2 regions)
- ❌ Data synchronization latency (5-10ms)
- ❌ Complexity in managing two clusters

**Alternative**: Single region with automated backups
- Lower cost but no geographic redundancy
- Acceptable for internal/non-critical systems

### 6. Stateless API Design

#### Decision: Stateless (Horizontal Scalable)
**Rationale**:
- ✅ Unlimited horizontal scaling (add pods)
- ✅ No session affinity needed
- ✅ Simpler deployments and restarts
- ✅ Better fault tolerance

**Implementation**:
- No in-memory caching (Redis added as layer)
- Database as single source of truth
- Request context in HTTP headers (trace_id)

### 7. Infrastructure as Code (Terraform)

#### Decision: Terraform over ARM Templates / Helm
**Rationale**:
- ✅ Cloud-agnostic (works on AWS, GCP, Azure)
- ✅ Excellent state management
- ✅ Easy to version control and review
- ✅ Reusable modules
- ✅ Strong community

**Trade-offs**:
- ❌ HCL language has learning curve
- ❌ State file management critical (use remote backend)

**Why not CloudFormation?** AWS-specific, harder to read
**Why not Helm?** Package manager, not IaC (use together with Terraform)

### 8. Monitoring Granularity

#### Decision: Comprehensive (Metrics + Traces + Logs)
**Rationale**:
- ✅ Complete observability (three pillars)
- ✅ Correlate issues across signals (via trace_id)
- ✅ Historical analysis capability
- ✅ Compliance audit trails

**Trade-offs**:
- ❌ High storage costs (Loki/Tempo)
- ❌ Complexity in correlation queries

**Conservative Alternative**: Metrics only
- Smaller storage footprint
- Loses ability to trace individual requests
- Not production-recommended

---

## Known Limitations

### Operational Limitations

#### 1. Database Scaling
**Limitation**: PostgreSQL vertical scaling limit (~64 CPU, 1TB RAM)

**Impact**: Dataset growth beyond 10M records requires sharding strategy

**Workaround**:
- Implement range-based sharding (by PassengerId)
- Setup read replicas for analytics workloads
- Consider PostgreSQL horizontal solutions (Citus, TimescaleDB)

**Timeline**: Year 3+ of operation

---

#### 2. Kubernetes Cluster Management
**Limitation**: Cluster requires ongoing maintenance (upgrades, patching)

**Impact**: 2-4 hours downtime per quarter for critical updates

**Mitigation**:
- Azure AKS automatic patching (staged updates)
- Multi-zone deployment within AKS
- Node pool drain/cordoning procedures

**Effort**: 4 hours/quarter operations work

---

#### 3. Cost Visibility
**Limitation**: Azure costs hard to predict (usage-based)

**Impact**: Monthly bills can vary ±20% due to autoscaling

**Mitigation**:
- Azure Cost Management + Billing alerts
- Budget caps per resource group
- Regular cost analysis reports

---

### Feature Limitations

#### 1. Authentication
**Current**: No built-in authentication (assumes internal network)

**Missing**:
- OAuth2/OpenID Connect
- API key validation
- Rate limiting per user

**Workaround**: 
- Implement at Ingress level (Azure API Management)
- Add auth middleware in Flask (JWT tokens)
- Use service mesh (Istio) for mTLS

**Effort**: 2-3 weeks development

---

#### 2. Caching
**Current**: No application-level caching

**Impact**: Repeated queries hit database every time

**Workaround**:
- Redis caching layer (in-memory)
- HTTP caching headers
- Query result caching with TTL

**Effort**: 1 week implementation

**Cost**: +$50/month (Redis managed service)

---

#### 3. Full-Text Search
**Current**: Only exact match and basic filters

**Missing**:
- Full-text search on passenger names
- Fuzzy matching for name corrections
- Elasticsearch integration

**Workaround**:
- PostgreSQL full-text search (built-in)
- Elasticsearch sidecar (heavy)

**Effort**: 1 week for PostgreSQL FTS

---

### Infrastructure Limitations

#### 1. Single Kubernetes Version
**Limitation**: AKS cluster runs single version (minor updates in background)

**Impact**: Breaking API changes require cluster upgrade

**Mitigation**:
- Test upgrades in dev environment first
- Use cluster autoupgrade (off-peak hours)
- Maintain backward compatibility

---

#### 2. Network Policy Coverage
**Limitation**: Network policies are permissive (development-focused)

**Hardening Needed**:
- Deny-all default policy
- Explicit allow rules per namespace
- Egress restrictions

**Effort**: 1 day security hardening

---

#### 3. Secrets Management
**Current**: Environment variables in ConfigMaps (development)

**Production Issue**: Secrets exposed in etcd unencrypted

**Mitigation**:
- Azure Key Vault integration
- Sealed Secrets (Kubernetes-native)
- External Secrets Operator (fetches from vault)

**Effort**: 1 week implementation

---

### Observability Limitations

#### 1. Metric Cardinality
**Limitation**: Prometheus TSDB unbounded cardinality risk

**Example**: Unique user IDs as label could explode metric count

**Mitigation**:
- Avoid high-cardinality labels (user_id, request_id)
- Use structural metadata (trace_id in logs, spans)
- Prometheus cardinality alerts

---

#### 2. Trace Sampling
**Current**: 10% default sampling (discard 90% of traces)

**Impact**: Low-frequency errors may not appear in traces

**Mitigation**:
- Error sampling at 100%
- High-latency sampling (>1s)
- Service-name based sampling

**Alternative**: 100% sampling (cost +$500/month for storage)

---

#### 3. Log Retention
**Current**: 15-day retention (cost-optimized)

**Limitation**: Debugging 30+ day old issues requires log replay

**Trade-off**:
- 15 days: $100/month
- 30 days: $200/month
- 90 days: $600/month

---

### Compliance Limitations

#### 1. GDPR Right to Deletion
**Limitation**: Database backups retain deleted data

**Impact**: Legal obligation to delete data within 30 days

**Mitigation**:
- Soft deletes (mark deleted, not remove)
- Backup encryption with deletion keys
- Separate backup for PII (shorter retention)

**Effort**: 2 weeks compliance work

---

#### 2. Audit Logging
**Current**: No change audit trail

**Missing**:
- Who updated record X at time Y
- Previous values for all changes
- Immutable audit log

**Workaround**:
- PostgreSQL event triggers
- CDC (Change Data Capture)
- Separate audit schema

**Effort**: 2 weeks implementation

---

## Future Improvements

### Phase 1 (Q1 2026): Security Hardening
**Effort**: 4-6 weeks

- [ ] OAuth2 integration (Azure AD)
- [ ] API key management
- [ ] Rate limiting (per IP, per user)
- [ ] Input validation library (Pydantic)
- [ ] SQL injection prevention audit
- [ ] OWASP Top 10 compliance scan
- [ ] Secrets rotation automation
- [ ] Pod security policies
- [ ] Network policies hardening

**Cost Impact**: +$50/month (API Management)

---

### Phase 2 (Q2 2026): Performance & Caching
**Effort**: 3-4 weeks

- [ ] Redis caching layer
- [ ] Query result caching (with TTL)
- [ ] HTTP cache headers
- [ ] Database connection pooling tuning
- [ ] Query optimization (indexes, execution plans)
- [ ] Load testing (k6/JMeter)
- [ ] CDN for static assets (if any)
- [ ] Full-text search (PostgreSQL)

**Expected Impact**:
- P95 latency: 200ms → 50ms (cached queries)
- Throughput: 1K req/sec → 5K req/sec
- Cost Impact: +$50/month (Redis)

---

### Phase 3 (Q3 2026): Advanced Observability
**Effort**: 4-6 weeks

- [ ] Application Performance Monitoring (APM) deeper
- [ ] Custom metrics for business KPIs
- [ ] Anomaly detection (ML-based alerting)
- [ ] Synthetic monitoring (uptime checks)
- [ ] Cost optimization dashboards
- [ ] SLA dashboards
- [ ] Incident post-mortems (automation)
- [ ] Trace sampling optimization (dynamic)

**Cost Impact**: ~$0 (open-source tools)

---

### Phase 4 (Q4 2026): Scalability & Automation
**Effort**: 6-8 weeks

- [ ] Database read replicas (geo-distributed)
- [ ] Connection pooling optimization
- [ ] Horizontal database sharding (if needed)
- [ ] Service mesh implementation (Istio)
- [ ] Canary deployments (automatic rollback)
- [ ] GitOps full automation (ArgoCD)
- [ ] Chaos engineering tests
- [ ] Disaster recovery drills

**Cost Impact**: +$500/month (second region, service mesh)

---

### Phase 5 (2027): Enterprise Features
**Effort**: Ongoing

- [ ] Multi-tenancy support
- [ ] Advanced analytics (BI integration)
- [ ] GraphQL endpoint
- [ ] Event streaming (Apache Kafka)
- [ ] AI/ML features (recommendation engine)
- [ ] Backup compliance (WORM storage)
- [ ] Advanced audit logging
- [ ] Legal hold for eDiscovery

**Cost Impact**: +$1000/month (Big Data platform)

---

### Infrastructure Roadmap

```
2026 Timeline:

Q1 ├─ Security Hardening (OAuth2, rate limiting, input validation)
   └─ Cost: +$50/month

Q2 ├─ Performance (Redis, query optimization, caching)
   └─ Cost: +$50/month

Q3 ├─ Observability (APM, anomaly detection, synthetic monitoring)
   └─ Cost: ~$0

Q4 ├─ Scalability (read replicas, sharding, service mesh)
   └─ Cost: +$500/month

2027 ├─ Enterprise (multi-tenant, GraphQL, streaming)
     ├─ Cost: +$1000/month
     └─ Estimated Annual Spending: $15K-20K

Architecture Evolution:
  Current  → Single region, single DB, stateless API
  Phase 2  → Single region, DB + Redis, optimized queries
  Phase 4  → Multi-region, sharded DB, service mesh
  Phase 5  → Global, multi-tenant, big data platform
```

---

## Estimated Cloud Costs

### Cost Model Overview

**Assumptions**:
- Cloud provider: Azure
- Region: US East (primary)
- SLA: 99.95% availability
- 1K requests/second sustained
- 100K records in database
- Development + Staging + Production environments

---

### Production Environment Monthly Cost Breakdown

#### Compute (Kubernetes)
```
AKS Cluster:
├─ Control Plane (managed by Azure, included)
├─ Worker Nodes (3 nodes × 4 CPU, 16GB RAM)
│  └─ Standard_D4s_v3: $185/month each
│     = 3 × $185 = $555/month
├─ Node autoscaling (max 5 nodes)
│  └─ Peak hours: 2 additional nodes
│     = 2 × $185 × 0.3 (30% utilization) = $111/month
├─ Load Balancer (public IP + rules)
│  └─ $16/month
└─ Managed Identity + RBAC
   └─ $0 (included)

SUBTOTAL: $682/month
```

#### Database
```
Azure Database for PostgreSQL Flexible Server:
├─ Compute (1 vCore, 2GB RAM)
│  └─ Burstable SKU: $60/month
├─ Storage (100GB SSD)
│  └─ $0.29/GB = $29/month
├─ Backup (automated, 7-day retention)
│  └─ First 100GB free
│  └─ Overage: $0.15/GB
│  └─ Estimated: $15/month
├─ Read replica (secondary region)
│  └─ Same as primary: $60/month (HA tier)
├─ Network bandwidth (egress only)
│  └─ 1TB/month at 86K requests/day
│  └─ Estimated: $50/month
└─ vCore peak pricing (during spikes)
   └─ Estimated: $20/month

SUBTOTAL: $234/month
```

#### Monitoring & Logging
```
Prometheus (self-hosted on AKS):
├─ Storage: ~5GB/month (15-day retention)
│  └─ Included in AKS disk
│  └─ Cost: $0

Loki (self-hosted on AKS):
├─ Log ingestion: ~86M logs/day
│  └─ 100GB/month storage at 15-day retention
│  └─ Disk cost: $3/month (AKS persistent volume)
│  └─ Processing: Included in node compute
│  └─ Cost: $3/month

Tempo (self-hosted on AKS):
├─ Traces: 86K traces/day (10% sampling)
│  └─ ~30GB/month storage
│  └─ Disk cost: $1/month
│  └─ Cost: $1/month

Grafana (self-hosted on AKS):
├─ Pod cost: Included in AKS compute
│  └─ Cost: $0

SUBTOTAL: $4/month (mostly disk)
```

#### Networking
```
VNet (Virtual Network):
├─ Peering (to secondary region)
│  └─ $0.02/GB transferred
│  └─ Estimated (replication): $30/month
├─ NAT Gateway (egress optimization)
│  └─ $32/month (fixed) + $0.045/GB
│  └─ Estimated: $50/month
└─ DNS (Azure DNS)
   └─ $0.50/zone/month
   └─ Cost: $1/month

SUBTOTAL: $81/month
```

#### Storage
```
Container Registry (ACR):
├─ Storage (image layers, 10 images)
│  └─ ~5GB: $0.29/GB/month
│  └─ Cost: $1.50/month
├─ Registry operations
│  └─ 50 pushes/day during deployment
│  └─ Cost: $0/month (100 free operations)

SUBTOTAL: $1.50/month
```

#### Optional Add-ons
```
Cost depends on features:

Redis (caching):
├─ Azure Cache for Redis (1GB)
│  └─ Basic tier: $15/month
│  └─ Standard tier (HA): $50/month

API Management:
├─ Azure API Management
│  └─ Developer tier: $50/month
│  └─ Basic tier: $150/month

Application Insights (Advanced APM):
├─ Pay-per-GB (beyond free tier)
│  └─ ~50GB/month: $150/month

Key Vault (secrets):
├─ Standard tier
│  └─ $0.67/month (operations charged separately)

OPTIONAL SUBTOTAL: $0-$350/month
```

#### Management & Support
```
Azure Support:
├─ Developer plan (free with subscription)
├─ Standard plan: $100/month
└─ Professional Direct: $1000/month

SUBTOTAL: $0 (developer)
```

---

### Total Monthly Production Cost

#### Minimal Setup (No Optional Add-ons)
```
Compute:      $682
Database:     $234
Monitoring:   $4
Networking:   $81
Storage:      $1.50
─────────────────────
TOTAL:        $1,002.50/month
Annual:       ~$12,000/year
Per Instance: ~$3.40/day
```

#### With High Availability (Recommended)
```
Compute:      $682
Database:     $234
Monitoring:   $4
Networking:   $81 (includes replication)
Storage:      $1.50
─────────────────────
TOTAL:        $1,002.50/month
Annual:       ~$12,000/year
(Secondary region adds: +$600/month)
```

#### With Optional Features
```
Base:         $1,002.50
Redis:        +$50
API Mgmt:     +$150
Insights:     +$150
─────────────────────
TOTAL:        $1,352.50/month
Annual:       ~$16,000/year
```

---

### Cost Comparison: Different Scales

#### Dev Environment (1 vCore, minimal pods)
```
Compute:      $200
Database:     $60
Monitoring:   $2
─────────────────────
TOTAL:        $262/month
Annual:       ~$3,000/year
```

#### Staging Environment (2 vCores, 2 pods)
```
Compute:      $350
Database:     $150
Monitoring:   $2
─────────────────────
TOTAL:        $502/month
Annual:       ~$6,000/year
```

#### Production Environment (Full Stack)
```
TOTAL:        $1,000-$1,500/month
Annual:       ~$12,000-$18,000/year
```

#### All Environments (Dev + Staging + Prod)
```
TOTAL:        ~$1,750/month
Annual:       ~$21,000/year
```

---

### Cost Optimization Strategies

#### 1. Reserved Instances (30-40% savings)
```
AKS Nodes: Pay $555/month → $333/month (40% savings)
Database: Pay $234/month → $140/month (40% savings)
─────────────────────────────────────────────────────
Savings: ~$316/month = $3,792/year
```

#### 2. Spot Instances (up to 90% savings for non-critical workloads)
```
Dev/Staging environments use spot:
├─ Cost: $50-$100/month instead of $350/month
└─ Trade-off: 5-30 min disruption tolerance
```

#### 3. Rightsizing
```
If actual usage is 30% of provisioned:
├─ Reduce node count: 3 → 2 nodes
├─ Reduce DB vCore: 1 → 0.5 burstable
├─ Savings: ~$400/month
└─ Risk: Performance degradation under spikes
```

#### 4. Shared Database (Dev + Staging)
```
Use single PostgreSQL with separate schemas:
├─ Current: 2 databases @ $234 = $468
├─ Optimized: 1 database @ $150
└─ Savings: $318/month ($3,816/year)
```

---

### Cost Trends (Year-over-Year)

```
Year 1 (Current Setup):
├─ Months 1-3: Validation phase
│  └─ $500/month (minimal)
├─ Months 4-12: Production ramping
│  └─ $1,000/month avg
└─ Annual Total: ~$9,000

Year 2 (Optimization):
├─ Reserved instances: -40% compute
├─ Better resource utilization: -20%
└─ Annual Total: ~$6,000 (-33%)

Year 3+ (Scaling):
├─ Multi-region: +$500/month
├─ Additional features: +$300/month
└─ Annual Total: ~$13,000 (+116% vs Year 2)
```

---

### Comparison with Alternatives

```
Monthly Cost Comparison (1K req/sec, same data):

┌──────────────────────────────┬──────────────┐
│ Platform                     │ Monthly Cost │
├──────────────────────────────┼──────────────┤
│ Azure App Service (simple)   │ $100-300     │
│ AWS Lambda + DynamoDB        │ $200-400     │
│ Azure AKS (current)          │ $1,000-1,500 │
│ AWS EKS                      │ $1,200-1,600 │
│ Managed PaaS (Heroku, etc)   │ $500-2,000   │
│ On-premises (est. amortized) │ $800-1,200   │
└──────────────────────────────┴──────────────┘

Recommendation:
- Low traffic (<100 req/sec): Use App Service ($100-300)
- Medium traffic (100-5K req/sec): Use Kubernetes ($1,000-2,000)
- High traffic (>5K req/sec): Use multi-region/sharding ($2,000-5,000)
```

---

### Budget Planning

#### Conservative Estimate
```
Assume: 50% higher cost than calculated
├─ Justification: Unexpected scaling, optimization lag
├─ Monthly budget: $1,500
└─ Annual budget: $18,000
```

#### Monitoring Monthly Costs
```
Set up Azure Cost Management alerts:
├─ Alert 1: Warn at 80% of monthly budget
├─ Alert 2: Alert at 100% of budget
├─ Review actual vs forecast weekly
└─ Implement auto-scaling limits if overrun
```

#### Cost Attribution
```
Tag resources by:
├─ Environment (dev/staging/prod)
├─ Team/project
├─ Cost center
└─ Generates monthly breakdown reports
```

---

## Summary

### Architecture Highlights
✅ **Production-Ready** - Multi-tier observability, RBAC, security context
✅ **Scalable** - Horizontal pod autoscaling, connection pooling
✅ **Resilient** - Health checks, PDB, multi-zone capable
✅ **Observable** - Metrics, traces, logs, alerts
✅ **Cost-Effective** - Open-source stack, ~$1K/month for production

### Setup Time Estimates
- **Local dev**: 5 minutes (Docker Compose)
- **Kubernetes local**: 15 minutes (Minikube)
- **Azure production**: 45 minutes (Terraform)
- **With monitoring**: +10 minutes
- **Full GitOps setup**: +20 minutes

### Next Steps
1. Choose setup path (Dev/K8s Local/Production)
2. Follow relevant documentation:
   - Local: [DOCKER_LOCAL_RUN.md](DOCKER_LOCAL_RUN.md)
   - K8s: [README_K8S.md](README_K8S.md)
   - Terraform: [terraform/DEPLOYMENT_RUNBOOK.md](terraform/DEPLOYMENT_RUNBOOK.md)
   - Monitoring: [monitoring/README.md](monitoring/README.md)
3. Review monitoring dashboards
4. Test API endpoints
5. Implement Phase 1 improvements (security hardening)

---

**Version**: 1.0.0 | **Last Updated**: January 2026 | **Status**: Production Ready 🚀
