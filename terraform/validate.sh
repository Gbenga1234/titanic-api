#!/bin/bash

# Titanic API - Terraform Validation Script
# Validates the Terraform configuration before deployment

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNINGS=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Terraform Configuration Validation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

# 1. Check if Terraform is installed
echo "[1/12] Checking Terraform installation..."
if command -v terraform &> /dev/null; then
    TF_VERSION=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || echo "unknown")
    check_pass "Terraform installed (version: $TF_VERSION)"
else
    check_fail "Terraform not found in PATH"
fi
echo ""

# 2. Check if Azure CLI is installed
echo "[2/12] Checking Azure CLI..."
if command -v az &> /dev/null; then
    check_pass "Azure CLI installed"
else
    check_fail "Azure CLI not found"
fi
echo ""

# 3. Validate Terraform syntax
echo "[3/12] Validating Terraform syntax..."
if terraform validate > /dev/null 2>&1; then
    check_pass "Terraform syntax is valid"
else
    check_fail "Terraform syntax validation failed"
    terraform validate
fi
echo ""

# 4. Check Terraform formatting
echo "[4/12] Checking Terraform formatting..."
if terraform fmt -recursive -check . > /dev/null 2>&1; then
    check_pass "All files are properly formatted"
else
    check_warn "Some files are not formatted. Run: terraform fmt -recursive ."
fi
echo ""

# 5. Check for required variables
echo "[5/12] Checking required variables..."
REQUIRED_VARS=("db_admin_password")
for var in "${REQUIRED_VARS[@]}"; do
    if grep -r "variable \"$var\"" . --include="*.tf" > /dev/null; then
        check_pass "Variable '$var' is defined"
    else
        check_fail "Missing required variable: $var"
    fi
done
echo ""

# 6. Check database password is not in tfvars
echo "[6/12] Checking for secrets in terraform.tfvars..."
SECRETS_FOUND=0
for file in */terraform.tfvars */*/terraform.tfvars; do
    if [ -f "$file" ]; then
        if grep -i "password\|secret\|key" "$file" | grep -v "#" > /dev/null; then
            check_fail "Found potential secret in $file"
            ((SECRETS_FOUND++))
        fi
    fi
done
if [ $SECRETS_FOUND -eq 0 ]; then
    check_pass "No secrets found in terraform.tfvars files"
fi
echo ""

# 7. Check for hardcoded passwords
echo "[7/12] Checking for hardcoded passwords in code..."
if grep -r "password\|Password" . --include="*.tf" | grep -i "= \"" | grep -v "var\." | grep -v "random_password\|azurerm_key" > /dev/null; then
    check_fail "Found potentially hardcoded passwords"
else
    check_pass "No hardcoded passwords found"
fi
echo ""

# 8. Check PostgreSQL version
echo "[8/12] Checking PostgreSQL version..."
if grep -r "version.*=.*\"14\"" . --include="*.tf" > /dev/null; then
    check_pass "PostgreSQL version 14 (supported)"
else
    check_fail "PostgreSQL version 14 not found (ensure upgrade from EOL versions)"
fi
echo ""

# 9. Check backup retention
echo "[9/12] Checking backup configuration..."
if grep -r "backup_retention_days" . --include="*.tf" > /dev/null; then
    check_pass "Production backup retention configured"
else
    check_warn "Production backup retention may not be set"
fi
echo ""

# 10. Check network security rules
echo "[10/12] Checking network security rules..."
if grep -r "azurerm_network_security_rule" . --include="*.tf" > /dev/null; then
    NSG_RULES=$(grep -r "azurerm_network_security_rule" . --include="*.tf" | wc -l)
    if [ "$NSG_RULES" -ge 4 ]; then
        check_pass "Network security rules configured ($NSG_RULES rules)"
    else
        check_warn "Only $NSG_RULES NSG rules found (minimum 4 recommended)"
    fi
else
    check_fail "No network security rules defined"
fi
echo ""

# 11. Check monitoring module
echo "[11/12] Checking monitoring configuration..."
if grep -r "module \"monitoring\"" . --include="*.tf" > /dev/null; then
    check_pass "Monitoring module included"
else
    check_fail "Monitoring module not found"
fi
echo ""

# 12. Check backend configuration
echo "[12/12] Checking backend state configuration..."
if grep -r "backend \"azurerm\"" . --include="*.tf" > /dev/null; then
    check_pass "Azure backend configured"
else
    check_fail "Azure backend not configured"
fi
echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Validation Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Passed: $PASSED${NC}"
if [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
fi
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $FAILED${NC}"
fi
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ Terraform configuration is ready for deployment!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Set database password: export TF_VAR_db_admin_password=<secure-password>"
    echo "2. Run backend setup: bash setup-backend.sh"
    echo "3. Initialize Terraform: terraform init"
    echo "4. Plan deployment: terraform plan -var-file=environments/prod/terraform.tfvars"
    echo "5. Review and apply: terraform apply"
    exit 0
else
    echo -e "${RED}✗ Fix the errors above before deploying${NC}"
    exit 1
fi