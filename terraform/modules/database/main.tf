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
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  tags = var.tags
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password-${var.environment}"
  value        = var.db_admin_password
  key_vault_id = azurerm_key_vault.this.id
}

data "azurerm_client_config" "current" {}