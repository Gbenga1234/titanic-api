terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "titanicapistate"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }
}

module "resource_group" {
  source   = "../../modules/resource_group"
  name     = "titanic-api-dev-rg"
  location = "East US"
  tags = {
    Environment = "dev"
    Project     = "titanic-api"
  }
}

module "network" {
  source              = "../../modules/network"
  resource_group_name = module.resource_group.name
  location           = "East US"
  vnet_address_space = ["10.0.0.0/16"]
  subnet_prefixes    = ["10.0.1.0/24", "10.0.2.0/24"]
  tags = {
    Environment = "dev"
    Project     = "titanic-api"
  }
}

module "database" {
  source              = "../../modules/database"
  resource_group_name = module.resource_group.name
  location           = "East US"
  vnet_id            = module.network.vnet_id
  subnet_id          = module.network.subnet_ids[1]
  sku_name           = "GP_Gen5_2"
  storage_mb         = 5120
  environment        = "dev"
  tags = {
    Environment = "dev"
    Project     = "titanic-api"
  }
}

module "aks" {
  source              = "../../modules/aks"
  resource_group_name = module.resource_group.name
  location           = "East US"
  vnet_id            = module.network.vnet_id
  subnet_id          = module.network.subnet_ids[0]
  node_count         = 2
  vm_size            = "Standard_DS2_v2"
  environment        = "dev"
  tags = {
    Environment = "dev"
    Project     = "titanic-api"
  }
}

module "iam" {
  source              = "../../modules/iam"
  resource_group_name = module.resource_group.name
  aks_principal_id    = module.aks.kubelet_identity_object_id
  key_vault_id        = module.database.key_vault_id
}