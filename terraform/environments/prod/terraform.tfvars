location = "East US"
environment = "prod"
resource_group_name = "titanic-api-prod-rg"

vnet_address_space = ["10.0.0.0/16"]
subnet_prefixes = ["10.0.1.0/24", "10.0.2.0/24"]

aks_node_count = 3
aks_vm_size = "Standard_DS2_v2"

db_sku_name = "GP_Gen5_4"
db_storage_mb = 10240

tags = {
  Environment = "prod"
  Project     = "titanic-api"
}
