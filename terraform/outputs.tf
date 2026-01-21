output "resource_group_name" {
  value = module.resource_group.name
}

output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "aks_kube_config" {
  value     = module.aks.kube_config
  sensitive = true
}

output "database_server_name" {
  value = module.database.server_name
}

output "database_connection_string" {
  value     = module.database.connection_string
  sensitive = true
}

output "key_vault_uri" {
  value = module.database.key_vault_uri
}