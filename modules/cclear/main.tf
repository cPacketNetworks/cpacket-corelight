data "azurerm_resource_group" "cclear" {
  name = var.resource_group_name # This is the name of the resource group that the cclear will be deployed to
}

data "azurerm_subnet" "cclear" {
  resource_group_name  = data.azurerm_resource_group.cclear.name
  virtual_network_name = var.vnet_name
  name                 = var.subnet
}

# This resource is frozen and will continue to be available throughout the 3.x azurerm provider series.
# We are unable to use the newer azurerm_linux_virtual_machine because it will not create
# and attach the data disks before starting, causing issues while admin_app.service allocates data disks.
# TODO: replace this with azurerm_linux_virtual_machine when it is possible.
resource "azurerm_virtual_machine" "cclear" {
  name                             = var.resource_names.machine
  location                         = data.azurerm_resource_group.cclear.location
  resource_group_name              = data.azurerm_resource_group.cclear.name
  network_interface_ids            = [azurerm_network_interface.cclear.id]
  vm_size                          = var.size
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true
  zones                            = var.zones ? ["1"] : []

  storage_image_reference {
    id = var.image_id
  }

  storage_os_disk {
    name              = var.resource_names.os_disk
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = var.storage_type_os
  }

  storage_data_disk {
    name              = var.resource_names.data_disk
    create_option     = "Empty"
    caching           = "ReadWrite"
    managed_disk_type = var.storage_type_data
    disk_size_gb      = var.data_size
    lun               = 1
  }

  os_profile {
    computer_name  = var.resource_names.machine
    admin_username = var.admin_username
    custom_data    = var.cloud_init_data == null ? null : var.cloud_init_data
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = file(var.ssh_public_key)
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
    }
  }

  tags = var.tags
}

resource "azurerm_network_interface" "cclear" {
  name                           = var.resource_names.management_nic
  location                       = data.azurerm_resource_group.cclear.location
  resource_group_name            = data.azurerm_resource_group.cclear.name
  accelerated_networking_enabled = true
  ip_configuration {
    name                          = "management"
    subnet_id                     = data.azurerm_subnet.cclear.id
    private_ip_address_allocation = var.ipv4_address != null ? "Static" : "Dynamic"
    private_ip_address            = var.ipv4_address
    public_ip_address_id          = var.public_ip ? azurerm_public_ip.cclear[0].id : null
  }
  tags = var.tags
}

resource "azurerm_network_interface_security_group_association" "cclear_network_security_group" {
  network_interface_id      = azurerm_network_interface.cclear.id
  network_security_group_id = var.security_group_id
}

resource "azurerm_public_ip" "cclear" {
  count               = var.public_ip ? 1 : 0
  name                = "cclear"
  location            = data.azurerm_resource_group.cclear.location
  resource_group_name = data.azurerm_resource_group.cclear.name
  allocation_method   = var.zones ? "Static" : "Dynamic"
  sku                 = var.zones ? "Standard" : "Basic"
  zones               = var.zones ? ["1"] : []
  tags                = var.tags
}
