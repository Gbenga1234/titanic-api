output "load_balancer_id" {
  value = azurerm_lb.main.id
}

output "public_ip_address" {
  value       = var.enable_public_ip ? azurerm_public_ip.lb[0].ip_address : null
  description = "Public IP address of the load balancer"
}

output "public_ip_fqdn" {
  value       = var.enable_public_ip ? azurerm_public_ip.lb[0].fqdn : null
  description = "FQDN of the load balancer public IP"
}

output "private_ip_address" {
  value = azurerm_lb.main.private_ip_address
}

output "backend_address_pool_id" {
  value = azurerm_lb_backend_address_pool.main.id
}

output "lb_name" {
  value = azurerm_lb.main.name
}
