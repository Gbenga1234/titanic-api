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

output "db_password_secret_id" {
  value       = azurerm_key_vault_secret.db_password.id
  description = "Key Vault Secret ID for database password"
}

output "db_connection_string_secret_id" {
  value       = azurerm_key_vault_secret.db_connection_string.id
  description = "Key Vault Secret ID for database connection string"
}

output "flask_secret_key_secret_id" {
  value       = azurerm_key_vault_secret.flask_secret_key.id
  description = "Key Vault Secret ID for Flask secret key"
}

output "key_vault_name" {
  value       = azurerm_key_vault.this.name
  description = "Key Vault name for secret retrieval"
}