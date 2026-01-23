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

variable "aks_principal_id" {
  description = "AKS cluster kubelet identity object ID (for Key Vault access)"
  type        = string
  default     = null
}

variable "flask_secret_key" {
  description = "Flask application secret key for session management"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.flask_secret_key) >= 32
    error_message = "Flask secret key must be at least 32 characters."
  }
}