variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vnet_id" {
  description = "Virtual Network ID"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for load balancer"
  type        = string
}

variable "lb_type" {
  description = "Load balancer type: public or internal"
  type        = string
  default     = "public"
}

variable "enable_public_ip" {
  description = "Enable public IP for load balancer"
  type        = bool
  default     = true
}

variable "sku" {
  description = "Load balancer SKU: Basic or Standard"
  type        = string
  default     = "Standard"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
