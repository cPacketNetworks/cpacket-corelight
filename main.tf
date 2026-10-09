locals {
  # Shared by the cvu module and the cClear cloud-init.
  cvu_vmss_name = "cvu"

  # cVu-V mirrors the inspected traffic to this load balancer address: the Corelight sensors', or the Ubuntu VMs'.
  sensor_ip_address = (var.ubuntu
    ? module.ubuntu[0].load_balancer_ip_address
    : module.sensor[0].sensor_load_balancer_monitoring_frontend_ip_address
  )
}

resource "azurerm_resource_group" "capture" {
  name     = var.resource_group.name
  location = var.resource_group.location
  tags     = var.tags
}

# The network belongs to this deployment. The cvu and cclear modules are reusable components that are given its subnets.

resource "azurerm_virtual_network" "capture" {
  name                = var.vnet.name
  address_space       = [var.vnet.cidr]
  location            = azurerm_resource_group.capture.location
  resource_group_name = azurerm_resource_group.capture.name
  tags                = var.tags
}

resource "azurerm_subnet" "capture" {
  name                 = var.capture_subnet.name
  resource_group_name  = azurerm_resource_group.capture.name
  virtual_network_name = azurerm_virtual_network.capture.name
  address_prefixes     = [var.capture_subnet.cidr]
}

resource "azurerm_subnet" "management" {
  name                 = var.management_subnet.name
  resource_group_name  = azurerm_resource_group.capture.name
  virtual_network_name = azurerm_virtual_network.capture.name
  address_prefixes     = [var.management_subnet.cidr]
}

resource "azurerm_subnet" "gwlb" {
  name                 = var.gwlb_subnet.name
  resource_group_name  = azurerm_resource_group.capture.name
  virtual_network_name = azurerm_virtual_network.capture.name
  address_prefixes     = [var.gwlb_subnet.cidr]
}

# The user supplies the network security groups (see README.md). They are attached to the subnets, so they also
# cover the Corelight sensors' NICs. The gwlb subnet holds only the Gateway Load Balancer frontend, and has none.

resource "azurerm_subnet_network_security_group_association" "capture" {
  subnet_id                 = azurerm_subnet.capture.id
  network_security_group_id = var.capture_security_group_id
}

resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = var.management_security_group_id
}

module "cvu" {
  source = "github.com/cPacketNetworks/cpacket-corelight//modules/cvu?ref=0.3.0"

  resource_group = azurerm_resource_group.capture.name
  location       = azurerm_resource_group.capture.location
  vnet = {
    name           = azurerm_virtual_network.capture.name
    resource_group = azurerm_resource_group.capture.name
  }
  # Subnet IDs are passed directly; looking them up would make the data sources' count unknown at plan time.
  capture_subnet_name = azurerm_subnet.capture.name
  capture_subnet_id   = azurerm_subnet.capture.id
  gwlb_subnet_name    = azurerm_subnet.gwlb.name
  gwlb_subnet_id      = azurerm_subnet.gwlb.id
  lookup_subnets      = false

  # A single capture NIC per instance, in line behind a Gateway Load Balancer.
  dual_nic = false
  gwlb     = true
  lb_name  = "cpacket-corelight"
  zones    = var.zones

  vmss_name                      = local.cvu_vmss_name
  image_id                       = var.cvu_image_id
  mp_version                     = var.cvu_mp_version
  size                           = var.cvu_scaleset.sku
  storage_type                   = var.cvu_scaleset.storage_type
  cvu_scaleset_autoscale_default = var.cvu_scaling.default_count
  cvu_scaleset_autoscale_min     = var.cvu_scaling.min_count
  cvu_scaleset_autoscale_max     = var.cvu_scaling.max_count
  ssh_public_key                 = var.ssh_public_key_file

  cloud_init_data = "${path.module}/cloud-init/cvu.tpl"
  cloud_init_data_vars = {
    # cVu-V mirrors the inspected traffic over VXLAN to the sensors' load balancer.
    DOWNSTREAM_IPV4_ADDRESSES = local.sensor_ip_address
    MIRROR                    = false
    GWLB                      = true
    # cVu-V sends its statistics to cClear-V.
    STATS_DB_IP = module.cclear.private_ip
  }

  tags = var.tags
}

module "sensor" {
  count  = var.ubuntu ? 0 : 1
  source = "github.com/corelight/terraform//modules/azure/sensor?ref=v29.0.5-9"

  license_key               = file(var.corelight_license_key_path)
  location                  = azurerm_resource_group.capture.location
  resource_group_name       = azurerm_resource_group.capture.name
  monitoring_subnet_id      = azurerm_subnet.capture.id
  management_subnet_id      = azurerm_subnet.management.id
  corelight_sensor_image_id = var.corelight_image_id
  community_string          = var.corelight_sensor_community_string
  sensor_ssh_public_key     = azurerm_ssh_public_key.cpacket.public_key
  tags                      = var.tags
  # Fleet is not used; these were the defaults in the original terraform-azure-sensor module.
  fleet_token          = ""
  fleet_url            = ""
  fleet_server_sslname = "1.broala.fleet.product.corelight.io"
}

# The sensor module had no count before the ubuntu option; keep existing deployments' sensors.
moved {
  from = module.sensor
  to   = module.sensor[0]
}

# Ubuntu VMs stand in for the Corelight sensors when there is no valid Corelight license.
module "ubuntu" {
  count  = var.ubuntu ? 1 : 0
  source = "github.com/cPacketNetworks/cpacket-corelight//modules/ubuntu?ref=0.3.0"

  resource_group_name  = azurerm_resource_group.capture.name
  location             = azurerm_resource_group.capture.location
  monitoring_subnet_id = azurerm_subnet.capture.id
  management_subnet_id = azurerm_subnet.management.id
  ssh_public_key       = azurerm_ssh_public_key.cpacket.public_key
  tags                 = var.tags
}

resource "azurerm_ssh_public_key" "cpacket" {
  name                = "cpacket-corelight"
  resource_group_name = azurerm_resource_group.capture.name
  location            = azurerm_resource_group.capture.location
  public_key          = file(var.ssh_public_key_file)
}

module "cclear" {
  source = "github.com/cPacketNetworks/cpacket-corelight//modules/cclear?ref=0.3.0"

  resource_group_name      = azurerm_resource_group.capture.name
  resource_group_id        = azurerm_resource_group.capture.id
  location                 = azurerm_resource_group.capture.location
  vnet_resource_group_name = azurerm_resource_group.capture.name
  vnet_name                = azurerm_virtual_network.capture.name
  subnet                   = azurerm_subnet.management.name
  subnet_id                = azurerm_subnet.management.id
  lookup_subnets           = false

  image_id       = var.cclear_image_id
  mp_version     = var.cclear_mp_version
  ssh_public_key = var.ssh_public_key_file
  public_ip      = var.cclear_public_ip
  size           = "Standard_D4s_v5"
  data_size      = 500 # Specifies the size of the data disk in GB.
  zones          = var.zones

  # The cloud-init template for the cClear-V instance, and the values it is rendered with.
  cloud_init_data = coalesce(var.cclear_cloud_init_data, "${path.module}/cloud-init/cclear.tpl")
  cloud_init_data_vars = {
    cclear_license       = var.cclear_license
    vmss_name            = local.cvu_vmss_name
    resource_group       = azurerm_resource_group.capture.name
    subscription_id      = var.subscription_id
    auto_licensing       = var.auto_licensing
    managed_registration = var.cclear_managed_registration
  }
  # Managed device registration: cClear-V reads the cVu-V scale set through the Azure API.
  system_assigned_managed_identity = var.cclear_managed_registration

  tags = var.tags
}
