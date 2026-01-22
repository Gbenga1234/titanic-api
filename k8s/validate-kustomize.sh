#!/bin/bash

# Kustomize Validation Script
# Validates base and overlay kustomization files for deployment readiness

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="${SCRIPT_DIR}/k8s"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================"
echo "Kustomize Validation Script"
echo "================================"
echo ""

# Check if kustomize is installed
if ! command -v kustomize &> /dev/null; then
    echo -e "${RED}❌ kustomize not found. Install it first:${NC}"
    echo "   curl -s 'https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh' | bash"
    exit 1
fi

echo -e "${GREEN}✓ kustomize found: $(kustomize version)${NC}"
echo ""

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found. Install it first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ kubectl found: $(kubectl version --client --short)${NC}"
echo ""

# Validate base kustomization
echo "================================"
echo "Validating Base Configuration"
echo "================================"

if [ ! -d "${K8S_DIR}/base" ]; then
    echo -e "${RED}❌ k8s/base directory not found${NC}"
    exit 1
fi

echo -e "${YELLOW}Building base kustomization...${NC}"
if kustomize build "${K8S_DIR}/base" > /tmp/base-manifest.yaml 2>&1; then
    echo -e "${GREEN}✓ Base kustomization built successfully${NC}"
    
    # Check resource count
    RESOURCE_COUNT=$(grep -c "^kind:" /tmp/base-manifest.yaml || true)
    echo -e "${GREEN}✓ Found ${RESOURCE_COUNT} resources in base${NC}"
    
    # Validate with kubectl
    if kubectl apply -f /tmp/base-manifest.yaml --dry-run=client > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Base manifest validates against Kubernetes schema${NC}"
    else
        echo -e "${RED}❌ Base manifest failed Kubernetes validation${NC}"
        kubectl apply -f /tmp/base-manifest.yaml --dry-run=client
        exit 1
    fi
else
    echo -e "${RED}❌ Failed to build base kustomization${NC}"
    cat /tmp/base-manifest.yaml
    exit 1
fi
echo ""

# Validate dev overlay
echo "================================"
echo "Validating Dev Overlay"
echo "================================"

if [ ! -d "${K8S_DIR}/overlays/dev" ]; then
    echo -e "${RED}❌ k8s/overlays/dev directory not found${NC}"
    exit 1
fi

echo -e "${YELLOW}Building dev overlay kustomization...${NC}"
if kustomize build "${K8S_DIR}/overlays/dev" > /tmp/dev-manifest.yaml 2>&1; then
    echo -e "${GREEN}✓ Dev overlay kustomization built successfully${NC}"
    
    # Check resource count
    RESOURCE_COUNT=$(grep -c "^kind:" /tmp/dev-manifest.yaml || true)
    echo -e "${GREEN}✓ Found ${RESOURCE_COUNT} resources in dev overlay${NC}"
    
    # Validate with kubectl
    if kubectl apply -f /tmp/dev-manifest.yaml --dry-run=client > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Dev manifest validates against Kubernetes schema${NC}"
    else
        echo -e "${RED}❌ Dev manifest failed Kubernetes validation${NC}"
        kubectl apply -f /tmp/dev-manifest.yaml --dry-run=client
        exit 1
    fi
    
    # Check specific configurations
    if grep -q "replicas: 1" /tmp/dev-manifest.yaml; then
        echo -e "${GREEN}✓ Dev configured with 1 replica (cost optimized)${NC}"
    fi
    
    if grep -q "FLASK_DEBUG: \"true\"" /tmp/dev-manifest.yaml; then
        echo -e "${GREEN}✓ Dev configured with Flask debug mode${NC}"
    fi
    
    if grep -q "image: titanic-api:dev-latest" /tmp/dev-manifest.yaml; then
        echo -e "${GREEN}✓ Dev configured with dev-latest image tag${NC}"
    fi
else
    echo -e "${RED}❌ Failed to build dev overlay kustomization${NC}"
    cat /tmp/dev-manifest.yaml
    exit 1
fi
echo ""

# Validate prod overlay
echo "================================"
echo "Validating Prod Overlay"
echo "================================"

if [ ! -d "${K8S_DIR}/overlays/prod" ]; then
    echo -e "${RED}❌ k8s/overlays/prod directory not found${NC}"
    exit 1
fi

echo -e "${YELLOW}Building prod overlay kustomization...${NC}"
if kustomize build "${K8S_DIR}/overlays/prod" > /tmp/prod-manifest.yaml 2>&1; then
    echo -e "${GREEN}✓ Prod overlay kustomization built successfully${NC}"
    
    # Check resource count
    RESOURCE_COUNT=$(grep -c "^kind:" /tmp/prod-manifest.yaml || true)
    echo -e "${GREEN}✓ Found ${RESOURCE_COUNT} resources in prod overlay${NC}"
    
    # Validate with kubectl
    if kubectl apply -f /tmp/prod-manifest.yaml --dry-run=client > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Prod manifest validates against Kubernetes schema${NC}"
    else
        echo -e "${RED}❌ Prod manifest failed Kubernetes validation${NC}"
        kubectl apply -f /tmp/prod-manifest.yaml --dry-run=client
        exit 1
    fi
    
    # Check specific configurations
    if grep -q "replicas: 3" /tmp/prod-manifest.yaml; then
        echo -e "${GREEN}✓ Prod configured with 3 replicas (HA)${NC}"
    fi
    
    if grep -q "FLASK_ENV: production" /tmp/prod-manifest.yaml || grep -q "FLASK_ENV=production" /tmp/prod-manifest.yaml; then
        echo -e "${GREEN}✓ Prod configured with production environment${NC}"
    fi
    
    if grep -q "minAvailable: 2" /tmp/prod-manifest.yaml; then
        echo -e "${GREEN}✓ Prod PodDisruptionBudget configured for HA${NC}"
    fi
    
    if grep -q "image: titanic-api:latest" /tmp/prod-manifest.yaml; then
        echo -e "${GREEN}✓ Prod configured with latest image tag${NC}"
    fi
else
    echo -e "${RED}❌ Failed to build prod overlay kustomization${NC}"
    cat /tmp/prod-manifest.yaml
    exit 1
fi
echo ""

# Summary
echo "================================"
echo "Validation Summary"
echo "================================"
echo -e "${GREEN}✓ All kustomization configurations validated successfully!${NC}"
echo ""
echo "Next steps:"
echo "  1. Dev deployment:  kubectl kustomize k8s/overlays/dev | kubectl apply -f -"
echo "  2. Prod deployment: kubectl kustomize k8s/overlays/prod | kubectl apply -f -"
echo ""
echo "Generated manifests:"
echo "  - Base:  /tmp/base-manifest.yaml"
echo "  - Dev:   /tmp/dev-manifest.yaml"
echo "  - Prod:  /tmp/prod-manifest.yaml"
echo ""
