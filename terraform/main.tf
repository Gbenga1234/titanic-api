module "resource_group" {
  source   = "./modules/resource_group"
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "network" {
  source              = "./modules/network"
  resource_group_name = module.resource_group.name
  location           = var.location
  vnet_address_space = var.vnet_address_space
  subnet_prefixes    = var.subnet_prefixes
  tags               = var.tags
}

module "database" {
  source              = "./modules/database"
  resource_group_name = module.resource_group.name
  location           = var.location
  vnet_id            = module.network.vnet_id
  subnet_id          = module.network.subnet_ids[1]
  sku_name           = var.db_sku_name
  storage_mb         = var.db_storage_mb
  tags               = var.tags
}

module "aks" {
  source              = "./modules/aks"
  resource_group_name = module.resource_group.name
  location           = var.location
  vnet_id            = module.network.vnet_id
  subnet_id          = module.network.subnet_ids[0]
  node_count         = var.aks_node_count
  vm_size            = var.aks_vm_size
  tags               = var.tags
}

module "iam" {
  source              = "./modules/iam"
  resource_group_name = module.resource_group.name
  aks_principal_id    = module.aks.kubelet_identity_object_id
  key_vault_id        = module.database.key_vault_id
}