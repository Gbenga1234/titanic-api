resource "azurerm_postgresql_server" "this" {
  name                = "titanic-postgres-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name

  sku_name = var.sku_name

  storage_mb                   = var.storage_mb
  backup_retention_days        = var.environment == "prod" ? 30 : 7
  geo_redundant_backup_enabled = var.environment == "prod" ? true : false
  auto_grow_enabled            = true

  administrator_login          = "postgresadmin"
  administrator_login_password = var.db_admin_password
  version                      = "14"
  ssl_enforcement_enabled      = true

  tags = var.tags
}

resource "azurerm_postgresql_database" "this" {
  name                = "titanic"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_postgresql_server.this.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

resource "azurerm_postgresql_virtual_network_rule" "this" {
  name                                 = "postgresql-vnet-rule"
  resource_group_name                  = var.resource_group_name
  server_name                          = azurerm_postgresql_server.this.name
  subnet_id                            = var.subnet_id
  ignore_missing_vnet_service_endpoint = true
}

resource "azurerm_key_vault" "this" {
  name                        = "titanic-kv-${var.environment}"
  location                    = var.location
  resource_group_name         = var.resource_group_name
  enabled_for_disk_encryption = true
  enabled_for_template_deployment = true
  enabled_for_deployment      = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 90
  purge_protection_enabled    = var.environment == "prod" ? true : false

  sku_name = "standard"

  network_acls {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  tags = var.tags
}

# Key Vault access policy for current user/service principal (Terraform)
resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = azurerm_key_vault.this.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Backup",
    "Delete",
    "Get",
    "List",
    "Purge",
    "Recover",
    "Restore",
    "Set",
  ]

  key_permissions = [
    "Create",
    "Delete",
    "Get",
    "List",
    "Update",
  ]
}

# Key Vault access policy for AKS cluster (read-only)
resource "azurerm_key_vault_access_policy" "aks" {
  count        = var.aks_principal_id != null ? 1 : 0
  key_vault_id = azurerm_key_vault.this.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = var.aks_principal_id

  secret_permissions = [
    "Get",
    "List",
  ]
}

# Database password secret
resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = var.db_admin_password
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [azurerm_key_vault_access_policy.terraform]

  tags = var.tags
}

# Database connection string secret
resource "azurerm_key_vault_secret" "db_connection_string" {
  name         = "db-connection-string"
  value        = "postgresql+psycopg2://postgresadmin:${var.db_admin_password}@${azurerm_postgresql_server.this.fqdn}:5432/titanic?sslmode=require"
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [azurerm_key_vault_access_policy.terraform]

  tags = var.tags
}

# Flask JWT secret (for session management)
resource "azurerm_key_vault_secret" "flask_secret_key" {
  name         = "flask-secret-key"
  value        = var.flask_secret_key
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [azurerm_key_vault_access_policy.terraform]

  tags = var.tags
}

data "azurerm_client_config" "current" {}