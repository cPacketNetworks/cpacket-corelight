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
  nva_security_group_id = module.security_groups.nva_security_group_id
  capture_subnet_id     = module.network.capture_subnet.id

  cvu_image_id = var.cvu_image_id
  cvu_scaleset = var.cvu_scaleset
  cvu_scaling  = var.cvu_scaling
  // TODO @thathaneydude: Expose the LB frontend IP in the terraform-azure-sensor module
  downstream_tool = data.azurerm_lb.corelight.frontend_ip_configuration[0].private_ip_address
  gwlb            = var.gwlb
}


module "sensor" {
  source                         = "github.com/corelight/terraform-azure-sensor"
  license_key                    = file(var.corelight_license_key_path)
  location                       = azurerm_resource_group.capture.location
  resource_group_name            = azurerm_resource_group.capture.name
  virtual_network_name           = module.network.capture_virtual_network.name
  virtual_network_resource_group = azurerm_resource_group.capture.name
  virtual_network_address_space  = module.network.capture_virtual_network.address_space
  corelight_sensor_image_id      = var.corelight_image_id
  community_string               = "/some/api/endpoint"
  sensor_ssh_public_key          = azurerm_ssh_public_key.cpacket.public_key
  tags                           = var.tags
}

resource "azurerm_network_security_group" "ubuntu" {
  name                = "ubuntu"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  security_rule {
    name                       = "SSH"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_public_ip" "ubuntu" {
  name                = "ubuntu"
  location            = azurerm_resource_group.capture.location
  resource_group_name = azurerm_resource_group.capture.name
  allocation_method   = "Dynamic"
  tags                = var.tags
}

resource "azurerm_network_interface" "admin" {
  name                = "admin"
  location            = azurerm_resource_group.capture.location
  resource_group_name = azurerm_resource_group.capture.name

  # Deprecated
  # enable_accelerated_networking = true
  accelerated_networking_enabled = true
  ip_configuration {
    name                          = "ubuntu-primary"
    primary                       = true
    subnet_id                     = module.network.management_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ubuntu.id
  }
  tags = merge(var.tags, {
    Name = "ubuntu"
  })
}

resource "azurerm_linux_virtual_machine" "admin" {
  name                  = "admin"
  location              = azurerm_resource_group.capture.location
  resource_group_name   = azurerm_resource_group.capture.name
  network_interface_ids = [azurerm_network_interface.admin.id]
  admin_username        = "ubuntu"
  size                  = "Standard_D4s_v3"
  computer_name         = "admin"

  admin_ssh_key {
    username   = "ubuntu"
    public_key = azurerm_ssh_public_key.cpacket.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = merge(var.tags, {
    Name = "admin"
  })
}

data "azurerm_lb" "corelight" {
  name                = module.sensor.internal_load_balancer_name
  resource_group_name = azurerm_resource_group.capture.name
}

resource "azurerm_ssh_public_key" "cpacket" {
  name                = "cpacket-corelight"
  resource_group_name = azurerm_resource_group.capture.name
  location            = azurerm_resource_group.capture.location
  public_key          = file(var.ssh_public_key_file)
}
