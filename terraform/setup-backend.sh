#!/bin/bash

# Titanic API - Terraform Backend Setup Script
# This script creates the Azure resources needed for Terraform state management
# Run this BEFORE running 'terraform init'

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Titanic API - Terraform Backend Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check prerequisites
if ! command -v az &> /dev/null; then
    echo -e "${RED}✗ Azure CLI not found. Install from: https://docs.microsoft.com/cli/azure/install-azure-cli${NC}"
    exit 1
fi

if ! az account show &> /dev/null; then
    echo -e "${RED}✗ Not logged into Azure. Run: az login${NC}"
    exit 1
fi

SUBSCRIPTION=$(az account show --query id -o tsv)
echo -e "${GREEN}✓${NC} Logged in to Azure (Subscription: ${SUBSCRIPTION:0:8}...)"
echo ""

# Configuration
RESOURCE_GROUP="terraform-state-rg"
STORAGE_ACCOUNT="titanicapistate"
CONTAINER_NAME="tfstate"
LOCATION="${1:-East US}"

echo -e "${YELLOW}Configuration:${NC}"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Storage Account: $STORAGE_ACCOUNT"
echo "  Container: $CONTAINER_NAME"
echo "  Location: $LOCATION"
echo ""

# Create resource group
echo -e "${BLUE}[1/4]${NC} Creating resource group..."
if az group exists -n "$RESOURCE_GROUP" | grep -q true; then
    echo -e "${GREEN}✓${NC} Resource group already exists"
else
    az group create -n "$RESOURCE_GROUP" -l "$LOCATION"
    echo -e "${GREEN}✓${NC} Resource group created"
fi
echo ""

# Create storage account
echo -e "${BLUE}[2/4]${NC} Creating storage account..."
if az storage account show -n "$STORAGE_ACCOUNT" -g "$RESOURCE_GROUP" &> /dev/null; then
    echo -e "${GREEN}✓${NC} Storage account already exists"
else
    az storage account create \
        -n "$STORAGE_ACCOUNT" \
        -g "$RESOURCE_GROUP" \
        -l "$LOCATION" \
        --sku Standard_LRS \
        --kind StorageV2 \
        --https-only true \
        --min-tls-version TLS1_2
    echo -e "${GREEN}✓${NC} Storage account created"
fi
echo ""

# Create blob container
echo -e "${BLUE}[3/4]${NC} Creating blob container..."
STORAGE_KEY=$(az storage account keys list -n "$STORAGE_ACCOUNT" -g "$RESOURCE_GROUP" -o json | jq -r '.[0].value')

if az storage container exists -n "$CONTAINER_NAME" --account-name "$STORAGE_ACCOUNT" --account-key "$STORAGE_KEY" | grep -q true; then
    echo -e "${GREEN}✓${NC} Container already exists"
else
    az storage container create \
        -n "$CONTAINER_NAME" \
        --account-name "$STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY"
    echo -e "${GREEN}✓${NC} Container created"
fi
echo ""

# Enable versioning and soft delete
echo -e "${BLUE}[4/4]${NC} Configuring storage account security..."
az storage account blob-service-properties update \
    --account-name "$STORAGE_ACCOUNT" \
    --account-key "$STORAGE_KEY" \
    --enable-change-feed true \
    --enable-versioning true \
    --enable-delete-retention true \
    --delete-retention-days 7
echo -e "${GREEN}✓${NC} Security features enabled"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Backend setup complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Set environment variables or pass terraform init backend config:"
echo ""
echo "   terraform init \\"
echo "     -backend-config=\"resource_group_name=$RESOURCE_GROUP\" \\"
echo "     -backend-config=\"storage_account_name=$STORAGE_ACCOUNT\" \\"
echo "     -backend-config=\"container_name=$CONTAINER_NAME\" \\"
echo "     -backend-config=\"key=prod.terraform.tfstate\""
echo ""
echo "2. Or add these to a backend config file and pass:"
echo "   terraform init -backend-config=backend.hcl"
echo ""
