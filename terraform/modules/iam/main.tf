variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
  default = "East US"
}

variable "aks_principal_id" {
  description = "Principal ID of the AKS cluster for role assignment"
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault ID for secret access"
  type        = string
}

# Grant AKS kubelet identity access to Key Vault secrets
resource "azurerm_role_assignment" "aks_keyvault" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.aks_principal_id
}