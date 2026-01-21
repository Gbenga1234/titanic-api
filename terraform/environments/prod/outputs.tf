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

output "load_balancer_id" {
  value = module.load_balancer.load_balancer_id
}

output "load_balancer_public_ip" {
  value = module.load_balancer.public_ip_address
}

output "load_balancer_name" {
  value = module.load_balancer.lb_name
}
