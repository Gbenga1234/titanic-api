variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vnet_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "sku_name" {
  type = string
}

variable "storage_mb" {
  type = number
}

variable "environment" {
  type = string
  default = "dev"
}

variable "db_admin_password" {
  description = "Database administrator password - must be at least 12 characters"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.db_admin_password) >= 12
    error_message = "Database password must be at least 12 characters."
  }
}

variable "tags" {
  type = map(string)
}