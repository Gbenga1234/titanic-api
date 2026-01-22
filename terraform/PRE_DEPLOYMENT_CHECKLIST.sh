#!/bin/bash

# Titanic API - Pre-Production Deployment Checklist
# Use this checklist before deploying to production

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Pre-Production Deployment Checklist${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to prompt for completion
check_item() {
    local item="$1"
    local num="$2"
    local total="$3"
    read -p "[${num}/${total}] ☐ $item (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}✓${NC} $item"
    else
        echo -e "${RED}✗${NC} $item - BLOCKING"
        return 1
    fi
    return 0
}

FAILED=0

# Prerequisites
echo -e "${BLUE}Prerequisites${NC}"
check_item "Azure account with sufficient quota" 1 20 || ((FAILED++))
check_item "Azure CLI installed and authenticated" 2 20 || ((FAILED++))
check_item "Terraform v1.0+ installed" 3 20 || ((FAILED++))
check_item "kubectl installed" 4 20 || ((FAILED++))
check_item "jq installed" 5 20 || ((FAILED++))
echo ""

# Configuration
echo -e "${BLUE}Configuration${NC}"
check_item "Generated secure database password" 6 20 || ((FAILED++))
check_item "Password exported as TF_VAR_db_admin_password" 7 20 || ((FAILED++))
check_item "Password NOT stored in terraform.tfvars" 8 20 || ((FAILED++))
check_item "Reviewed environments/prod/terraform.tfvars" 9 20 || ((FAILED++))
echo ""

# Infrastructure Preparation
echo -e "${BLUE}Infrastructure Preparation${NC}"
check_item "Ran setup-backend.sh successfully" 10 20 || ((FAILED++))
check_item "Backend resource group created" 11 20 || ((FAILED++))
check_item "Backend storage account created" 12 20 || ((FAILED++))
check_item "Backend blob container created" 13 20 || ((FAILED++))
echo ""

# Terraform Validation
echo -e "${BLUE}Terraform Validation${NC}"
check_item "Ran terraform validate successfully" 14 20 || ((FAILED++))
check_item "Ran validate.sh with no failures" 15 20 || ((FAILED++))
check_item "Reviewed terraform plan output" 16 20 || ((FAILED++))
echo ""

# Security Review
echo -e "${BLUE}Security Review${NC}"
check_item "No passwords in code/tfvars" 17 20 || ((FAILED++))
check_item "Network security rules defined" 18 20 || ((FAILED++))
check_item "Database backup enabled (30 days prod)" 19 20 || ((FAILED++))
check_item "Monitoring/logging configured" 20 20 || ((FAILED++))
echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed! Ready to deploy.${NC}"
    echo ""
    echo "Next command:"
    echo "  terraform apply tfplan"
    echo ""
    echo "After deployment:"
    echo "  terraform output -json > deployment-outputs.json"
    echo "  kubectl get nodes"
    exit 0
else
    echo -e "${RED}❌ $FAILED items failed. Fix them before deployment.${NC}"
    exit 1
fi
