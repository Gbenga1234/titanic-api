location = "East US"
environment = "dev"
resource_group_name = "titanic-api-dev-rg"

vnet_address_space = ["10.0.0.0/16"]
subnet_prefixes = ["10.0.1.0/24", "10.0.2.0/24"]

aks_node_count = 2
aks_vm_size = "Standard_DS2_v2"

db_sku_name = "GP_Gen5_2"
db_storage_mb = 5120

tags = {
  Environment = "dev"
  Project     = "titanic-api"
}
