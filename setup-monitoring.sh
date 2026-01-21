#!/bin/bash

# Prometheus & Grafana Quick Start Script
# This script sets up monitoring on a Kubernetes cluster

set -e

NAMESPACE="monitoring"
PROMETHEUS_VERSION="latest"
GRAFANA_VERSION="latest"

echo "========================================="
echo "Kubernetes Monitoring Setup"
echo "========================================="

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed"
    exit 1
fi

echo "✅ kubectl found"

# Create namespace
echo ""
echo "📦 Creating monitoring namespace..."
kubectl apply -f k8s/monitoring/namespace.yaml

# Apply Prometheus
echo ""
echo "📊 Installing Prometheus..."
kubectl apply -f k8s/monitoring/prometheus-rbac.yaml
kubectl apply -f k8s/monitoring/prometheus-configmap.yaml
kubectl apply -f k8s/monitoring/prometheus-rules.yaml
kubectl apply -f k8s/monitoring/prometheus-deployment.yaml

# Apply Grafana
echo ""
echo "📈 Installing Grafana..."
kubectl apply -f k8s/monitoring/grafana-deployment.yaml

# Wait for deployments to be ready
echo ""
echo "⏳ Waiting for deployments to be ready..."
kubectl rollout status deployment/prometheus -n $NAMESPACE --timeout=5m
kubectl rollout status deployment/grafana -n $NAMESPACE --timeout=5m

echo ""
echo "========================================="
echo "✅ Monitoring Stack Installed Successfully!"
echo "========================================="

echo ""
echo "🔗 Access Information:"
echo "---"

# Get service info
PROMETHEUS_IP=$(kubectl get svc prometheus -n $NAMESPACE -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "pending")
GRAFANA_IP=$(kubectl get svc grafana -n $NAMESPACE -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "pending")

echo "Prometheus: http://$PROMETHEUS_IP:9090"
echo "Grafana: http://$GRAFANA_IP:3000"

echo ""
echo "📝 Quick Commands:"
echo "---"
echo "# Port-forward Prometheus"
echo "kubectl port-forward svc/prometheus 9090:9090 -n $NAMESPACE &"
echo ""
echo "# Port-forward Grafana"
echo "kubectl port-forward svc/grafana 3000:3000 -n $NAMESPACE &"
echo ""
echo "# Check status"
echo "kubectl get pods -n $NAMESPACE"
echo "kubectl get svc -n $NAMESPACE"
echo ""
echo "# View Prometheus logs"
echo "kubectl logs -f deployment/prometheus -n $NAMESPACE"
echo ""
echo "# View Grafana logs"
echo "kubectl logs -f deployment/grafana -n $NAMESPACE"
echo ""

echo "📚 For complete setup guide, see MONITORING_GUIDE.md"
echo ""
