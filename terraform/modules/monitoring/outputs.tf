output "log_analytics_workspace_id" {
  value       = azurerm_log_analytics_workspace.this.id
  description = "Log Analytics Workspace ID"
}

output "log_analytics_workspace_key" {
  value       = azurerm_log_analytics_workspace.this.primary_shared_key
  sensitive   = true
  description = "Log Analytics Workspace primary key"
}

output "application_insights_key" {
  value       = azurerm_application_insights.this.instrumentation_key
  sensitive   = true
  description = "Application Insights instrumentation key"
}

output "application_insights_connection_string" {
  value       = azurerm_application_insights.this.connection_string
  sensitive   = true
  description = "Application Insights connection string"
}
