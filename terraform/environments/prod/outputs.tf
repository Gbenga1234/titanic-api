output "resource_group_name" {
  value = module.resource_group.name
}

output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "database_server_name" {
  value = module.database.server_name
}

output "key_vault_uri" {
  value = module.database.key_vault_uri
}