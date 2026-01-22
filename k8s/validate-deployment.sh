#!/bin/bash

# Titanic API - Pre-Deployment Validation Script
# Run this before deploying to ArgoCD to catch configuration issues

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

echo "=========================================="
echo "Titanic API Pre-Deployment Validation"
echo "=========================================="
echo ""

# Function to check conditions
check_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASSED++))
}

check_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((FAILED++))
}

check_warn() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1"
}

# 1. Check kubectl context
echo "[1/9] Checking kubectl configuration..."
if kubectl cluster-info &> /dev/null; then
    CONTEXT=$(kubectl config current-context)
    check_pass "kubectl configured (context: $CONTEXT)"
else
    check_fail "kubectl not configured. Run: kubectl config get-contexts"
fi
echo ""

# 2. Check Kubernetes version
echo "[2/9] Checking Kubernetes version..."
K8S_VERSION=$(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}' || echo "unknown")
if [[ "$K8S_VERSION" != "unknown" ]]; then
    check_pass "Kubernetes version: $K8S_VERSION"
else
    check_warn "Could not determine Kubernetes version"
fi
echo ""

# 3. Check if ArgoCD is installed
echo "[3/9] Checking ArgoCD installation..."
if kubectl get namespace argocd &> /dev/null; then
    ARGOCD_PODS=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server --no-headers 2>/dev/null | wc -l)
    if [ "$ARGOCD_PODS" -gt 0 ]; then
        check_pass "ArgoCD is installed and running"
    else
        check_fail "ArgoCD namespace exists but server pod not found"
    fi
else
    check_fail "ArgoCD namespace not found. Install with: kubectl create namespace argocd && kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
fi
echo ""

# 4. Check metrics-server (required for HPA)
echo "[4/9] Checking metrics-server (required for HPA autoscaling)..."
if kubectl get deployment metrics-server -n kube-system &> /dev/null; then
    METRICS_STATUS=$(kubectl get deployment metrics-server -n kube-system -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')
    if [ "$METRICS_STATUS" == "True" ]; then
        check_pass "metrics-server is deployed and ready"
    else
        check_warn "metrics-server exists but not in Ready state. HPA may not work."
    fi
else
    check_fail "metrics-server not found. HPA autoscaling will not work. Install with: kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
fi
echo ""

# 5. Check NGINX Ingress Controller
echo "[5/9] Checking NGINX Ingress Controller..."
INGRESS_NAMESPACES=("ingress-nginx" "nginx-ingress" "kube-ingress")
FOUND=0
for ns in "${INGRESS_NAMESPACES[@]}"; do
    if kubectl get pods -n "$ns" -l app.kubernetes.io/name=ingress-nginx --no-headers 2>/dev/null | grep -q .; then
        check_pass "NGINX Ingress Controller found in namespace: $ns"
        FOUND=1
        break
    fi
done
if [ $FOUND -eq 0 ]; then
    check_fail "NGINX Ingress Controller not found. Install with: helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace"
fi
echo ""

# 6. Check storage class availability
echo "[6/9] Checking storage class for persistent volumes..."
if kubectl get storageclass standard &> /dev/null; then
    check_pass "StorageClass 'standard' is available"
else
    STORAGE_CLASSES=$(kubectl get storageclass -o jsonpath='{.items[*].metadata.name}')
    if [ -n "$STORAGE_CLASSES" ]; then
        check_warn "StorageClass 'standard' not found. Available classes: $STORAGE_CLASSES"
        echo "            Update k8s/pvc-postgres.yaml with: storageClassName: $(echo $STORAGE_CLASSES | awk '{print $1}')"
    else
        check_fail "No storage classes available. A default storage class is required for PostgreSQL persistence."
    fi
fi
echo ""

# 7. Validate YAML manifests
echo "[7/9] Validating Kubernetes YAML manifests..."
YAML_ERRORS=0
for file in deployment-app.yaml statefulset-postgres.yaml configmap.yaml secret.yaml service-clusterip.yaml ingress.yaml hpa.yaml; do
    if kubectl apply --dry-run=client -f "$file" &> /dev/null; then
        check_pass "$file"
    else
        check_fail "$file - YAML syntax error"
        ((YAML_ERRORS++))
    fi
done
echo ""

# 8. Check image configuration
echo "[8/9] Checking container image configuration..."
IMAGE_NAME=$(grep "image: " deployment-app.yaml | head -1 | awk '{print $2}' | xargs)
if [[ "$IMAGE_NAME" == "YOUR_DOCKERHUB_USERNAME/titanic-api:latest" ]]; then
    check_fail "Docker image username not set. Update deployment-app.yaml with: image: your-username/titanic-api:latest"
elif [[ "$IMAGE_NAME" == "titanic-api:latest" ]]; then
    check_fail "Docker image not fully qualified. Update with registry: image: your-username/titanic-api:latest"
else
    check_pass "Docker image configured: $IMAGE_NAME"
fi
echo ""

# 9. Check AppProject and Application files
echo "[9/9] Validating ArgoCD configuration..."
if kubectl apply --dry-run=client -f ../argocd/appproject.yaml &> /dev/null; then
    check_pass "appproject.yaml is valid"
else
    check_fail "appproject.yaml has errors"
fi

if kubectl apply --dry-run=client -f ../argocd/argocd-application.yaml &> /dev/null; then
    check_pass "argocd-application.yaml is valid"
else
    check_fail "argocd-application.yaml has errors"
fi
echo ""

# Summary
echo "=========================================="
echo "Validation Summary"
echo "=========================================="
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Ready to deploy.${NC}"
    exit 0
else
    echo -e "${RED}✗ Fix the above errors before deploying.${NC}"
    exit 1
fi
