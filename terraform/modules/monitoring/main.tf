resource "azurerm_log_analytics_workspace" "this" {
  name                = "titanic-api-${var.environment}-law"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.environment == "prod" ? "PerGB2018" : "Free"
  retention_in_days   = var.environment == "prod" ? 30 : 7

  tags = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "aks_diagnostics" {
  name                       = "aks-diagnostics"
  target_resource_id         = var.aks_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  enabled_log {
    category = "kube-scheduler"
  }

  enabled_log {
    category = "kube-audit"
  }

  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "postgres_diagnostics" {
  name                       = "postgres-diagnostics"
  target_resource_id         = var.postgres_server_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "PostgreSQLLogs"
  }

  metric {
    category = "AllMetrics"
  }
}

# Application Insights for APM
resource "azurerm_application_insights" "this" {
  name                = "titanic-api-${var.environment}-ai"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.this.id

  tags = var.tags
}

# Alert Rule for high CPU
resource "azurerm_monitor_metric_alert" "high_cpu" {
  name                = "aks-high-cpu-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes              = [var.aks_id]
  description         = "Alert when AKS nodes have high CPU usage"
  severity            = 2
  enabled             = var.environment == "prod" ? true : false

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_cpu_usage_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
}

# Alert Rule for database connection failures
resource "azurerm_monitor_metric_alert" "db_connections" {
  name                = "postgres-failed-connections-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes              = [var.postgres_server_id]
  description         = "Alert on failed database connections"
  severity            = 2
  enabled             = var.environment == "prod" ? true : false

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/servers"
    metric_name      = "active_connections"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
}

resource "azurerm_monitor_action_group" "this" {
  name                = "titanic-api-${var.environment}-ag"
  resource_group_name = var.resource_group_name
  short_name          = "titanic-api"

  tags = var.tags
}
