output "server_id" {
  value = azurerm_postgresql_server.this.id
}

output "server_name" {
  value = azurerm_postgresql_server.this.name
}

output "database_name" {
  value = azurerm_postgresql_database.this.name
}

output "connection_string" {
  value = "postgresql://postgresadmin@${azurerm_postgresql_server.this.name}:PASSWORD_HERE@${azurerm_postgresql_server.this.name}.postgres.database.azure.com:5432/${azurerm_postgresql_database.this.name}?sslmode=require"
  sensitive = false
  description = "Replace PASSWORD_HERE with the db_admin_password. Use as DATABASE_URL environment variable."
}

output "key_vault_id" {
  value = azurerm_key_vault.this.id
}

output "key_vault_uri" {
  value = azurerm_key_vault.this.vault_uri
}