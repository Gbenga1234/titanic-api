# Public IP for Load Balancer (optional)
resource "azurerm_public_ip" "lb" {
  count               = var.enable_public_ip ? 1 : 0
  name                = "titanic-api-${var.environment}-lb-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = var.sku
  tags                = var.tags
}

# Load Balancer
resource "azurerm_lb" "main" {
  name                = "titanic-api-${var.environment}-lb"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku

  frontend_ip_configuration {
    name                 = "titanic-api-${var.environment}-frontend"
    public_ip_address_id = var.enable_public_ip ? azurerm_public_ip.lb[0].id : null
  }

  tags = var.tags
}

# Backend Pool
resource "azurerm_lb_backend_address_pool" "main" {
  name            = "titanic-api-${var.environment}-backend-pool"
  loadbalancer_id = azurerm_lb.main.id
}

# Health Probe
resource "azurerm_lb_probe" "main" {
  name            = "titanic-api-${var.environment}-health-probe"
  loadbalancer_id = azurerm_lb.main.id
  port            = 5000
  protocol        = "Http"
  request_path    = "/health/ready"
  interval_in_seconds = 15
  number_of_probes    = 3
}

# Load Balancer Rule - HTTP
resource "azurerm_lb_rule" "http" {
  name                           = "titanic-api-${var.environment}-http"
  loadbalancer_id                = azurerm_lb.main.id
  frontend_ip_configuration_name = azurerm_lb.main.frontend_ip_configuration[0].name
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 5000
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main.id]
  probe_id                       = azurerm_lb_probe.main.id
  idle_timeout_in_minutes        = 4
  enable_floating_ip             = false
}

# Load Balancer Rule - HTTPS
# NOTE: For production SSL/TLS, use Application Gateway instead
# OR configure SSL certificates from Key Vault and update this configuration
resource "azurerm_lb_rule" "https" {
  name                           = "titanic-api-${var.environment}-https"
  loadbalancer_id                = azurerm_lb.main.id
  frontend_ip_configuration_name = azurerm_lb.main.frontend_ip_configuration[0].name
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 5000
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main.id]
  probe_id                       = azurerm_lb_probe.main.id
  idle_timeout_in_minutes        = 4
  enable_floating_ip             = false
  depends_on                     = [azurerm_lb_rule.http]
}

# NAT Rule for SSH access (optional)
resource "azurerm_lb_nat_rule" "ssh" {
  name                    = "titanic-api-${var.environment}-ssh"
  loadbalancer_id         = azurerm_lb.main.id
  frontend_ip_configuration_name = azurerm_lb.main.frontend_ip_configuration[0].name
  protocol                = "Tcp"
  frontend_port           = 3389
  backend_port            = 22
  idle_timeout_in_minutes = 4
}
