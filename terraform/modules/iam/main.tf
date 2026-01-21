resource "azurerm_role_assignment" "aks_keyvault" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.aks_principal_id
}

resource "azurerm_user_assigned_identity" "aks" {
  name                = "titanic-aks-identity"
  resource_group_name = var.resource_group_name
  location            = "East US"
}