resource "azurerm_resource_group" "capture" {
  name     = var.resource_group.name
  location = var.resource_group.location
  tags     = var.tags
}

module "network" {
  source            = "./modules/network"
  capture_subnet    = var.capture_subnet
  management_subnet = var.management_subnet
  resource_group = {
    name     = azurerm_resource_group.capture.name
    location = azurerm_resource_group.capture.location
  }
  vnet_cidr = var.vnet_cidr
}

module "security_groups" {
  source = "./modules/security_groups"
  resource_group = {
    name     = azurerm_resource_group.capture.name
    location = azurerm_resource_group.capture.location
  }
}

module "cvu" {
  source = "./modules/cvu"

  resource_group = {
    name     = azurerm_resource_group.capture.name
    location = azurerm_resource_group.capture.location
  }

  public_key            = file(var.ssh_public_key_file)
  nva_security_group_id = module.security_groups.cvu
  capture_subnet_id     = module.network.capture_subnet.id

  cvu_image_id    = var.cvu_image_id
  cvu_scaleset    = var.cvu_scaleset
  cvu_scaling     = var.cvu_scaling
  downstream_tool = module.sensor.sensor_load_balancer_monitoring_frontend_ip_address
  gwlb            = var.gwlb

  depends_on = [module.cclear]
}

module "sensor" {
  # source = "github.com/corelight/terraform-azure-sensor"
  source = "../../terraform-azure-sensor"

  license_key               = file(var.corelight_license_key_path)
  location                  = azurerm_resource_group.capture.location
  resource_group_name       = azurerm_resource_group.capture.name
  monitoring_subnet_id      = module.network.capture_subnet.id
  management_subnet_id      = module.network.management_subnet.id
  corelight_sensor_image_id = var.corelight_image_id
  community_string          = var.corelight_sensor_community_string
  sensor_ssh_public_key     = azurerm_ssh_public_key.cpacket.public_key
  tags                      = var.tags
}

resource "azurerm_ssh_public_key" "cpacket" {
  name                = "cpacket-corelight"
  resource_group_name = azurerm_resource_group.capture.name
  location            = azurerm_resource_group.capture.location
  public_key          = file(var.ssh_public_key_file)
}

module "cclear" {
  source = "./modules/cclear" # Relative path to the cclear module.
  # Required Variables
  resource_group_name      = azurerm_resource_group.capture.name
  vnet_resource_group_name = module.network.capture_virtual_network.resource_group.name
  vnet_name                = module.network.capture_virtual_network.name
  subnet                   = module.network.management_subnet.name
  image_id                 = var.cclear_image_id
  ssh_public_key           = var.ssh_public_key_file
  public_ip                = var.cclear_public_ip
  size                     = "Standard_D4s_v5"
  data_size                = 500                        # Specifies the size of the data disk in GB.
  cloud_init_data          = var.cclear_cloud_init_data # The cloud-init data to be used for the cClear-V instance.
  security_group_id        = module.security_groups.cclear
  tags                     = var.tags
  # why do we need to specify this when there's an implicit reference to the resource group above?
  depends_on = [azurerm_resource_group.capture]
}
