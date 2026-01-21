#!/bin/bash

# Terraform Validation Script
# This script validates the Terraform configuration and checks for common issues

set -e

echo "🔍 Validating Terraform Configuration"
echo "====================================="

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed. Please install Terraform first."
    exit 1
fi

# Check if we're in the terraform directory
if [ ! -f "providers.tf" ]; then
    echo "❌ Not in terraform directory. Please run from terraform/ directory."
    exit 1
fi

echo "✅ Terraform installed: $(terraform version)"

# Initialize terraform
echo ""
echo "📦 Initializing Terraform..."
terraform init -upgrade

# Validate configuration
echo ""
echo "🔍 Validating configuration..."
terraform validate

# Format check
echo ""
echo "📝 Checking formatting..."
terraform fmt -check -recursive

# Security scan with tfsec if available
if command -v tfsec &> /dev/null; then
    echo ""
    echo "🔒 Running security scan..."
    tfsec --concise-output
else
    echo ""
    echo "⚠️  tfsec not installed. Consider installing for security scanning."
fi

# Check for required variables
echo ""
echo "📋 Checking for required variables..."
if [ ! -f "environments/dev/terraform.tfvars" ]; then
    echo "⚠️  dev terraform.tfvars not found. Create environments/dev/terraform.tfvars"
fi

if [ ! -f "environments/prod/terraform.tfvars" ]; then
    echo "⚠️  prod terraform.tfvars not found. Create environments/prod/terraform.tfvars"
fi

echo ""
echo "✅ Validation complete!"
echo ""
echo "Next steps:"
echo "1. Create terraform.tfvars files in environments/dev/ and environments/prod/"
echo "2. Run 'terraform plan -var-file=environments/dev/terraform.tfvars' to see changes"
echo "3. Run 'terraform apply' when ready to deploy"