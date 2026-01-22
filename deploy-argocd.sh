#!/bin/bash

# ArgoCD Deployment Script for Titanic API
# This script helps deploy the Titanic API application to ArgoCD

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Titanic API ArgoCD Deployment Script${NC}"
echo "========================================"

# Check prerequisites
echo -e "\n${YELLOW}📋 Checking prerequisites...${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found. Please install kubectl first.${NC}"
    exit 1
fi

if ! command -v argocd &> /dev/null; then
    echo -e "${YELLOW}⚠️  ArgoCD CLI not found. Some features will be limited.${NC}"
    echo -e "${YELLOW}   Install with: brew install argocd (macOS) or download from https://argo-cd.readthedocs.io/en/stable/cli_installation/${NC}"
fi

# Check if ArgoCD is installed
if ! kubectl get namespace argocd &> /dev/null; then
    echo -e "${RED}❌ ArgoCD namespace not found. Please install ArgoCD first.${NC}"
    echo -e "${YELLOW}   Installation guide: https://argo-cd.readthedocs.io/en/stable/getting_started/${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"

# Update repository URL
echo -e "\n${YELLOW}📝 Repository Configuration${NC}"
read -p "Enter your Git repository URL (e.g., https://github.com/username/titanic-api): " repo_url

if [ -n "$repo_url" ]; then
    sed -i.bak "s|https://github.com/your-username/titanic-api|$repo_url|g" argocd/argocd-application.yaml
    sed -i.bak "s|https://github.com/your-username/titanic-api|$repo_url|g" argocd/appproject.yaml
    echo -e "${GREEN}✅ Repository URL updated${NC}"
else
    echo -e "${YELLOW}⚠️  Using default repository URL. Remember to update it manually.${NC}"
fi

# Deploy ArgoCD resources
echo -e "\n${YELLOW}🚀 Deploying ArgoCD resources...${NC}"

echo "Deploying AppProject..."
kubectl apply -f argocd/appproject.yaml

echo "Deploying Application..."
kubectl apply -f argocd/argocd-application.yaml

echo -e "${GREEN}✅ ArgoCD resources deployed${NC}"

# Wait for application to be processed
echo -e "\n${YELLOW}⏳ Waiting for ArgoCD to process the application...${NC}"
sleep 10

# Check application status
echo -e "\n${YELLOW}📊 Checking application status...${NC}"

if command -v argocd &> /dev/null; then
    echo "Application status:"
    argocd app get titanic-api --show-events || echo "Could not retrieve application status"
else
    echo "ArgoCD CLI not available. Check status manually in the ArgoCD UI."
fi

# Display next steps
echo -e "\n${GREEN}🎉 Deployment initiated!${NC}"
echo "========================================"
echo -e "${BLUE}Next steps:${NC}"
echo "1. Access ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "2. Open https://localhost:8080 in your browser"
echo "3. Login with admin user and get password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
echo "4. Navigate to Applications → titanic-api to monitor deployment"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "- Check sync status: kubectl describe application titanic-api -n argocd"
echo "- View application logs: kubectl logs -n argocd deployment/argocd-application-controller"
echo "- Force sync: argocd app sync titanic-api"
echo ""
echo -e "${GREEN}Happy deploying! 🎊${NC}"