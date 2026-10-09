data "azurerm_resource_group" "ccloud" {
  count = var.location == null ? 1 : 0
  name  = var.resource_group_name # This is the name of the resource group that the cclear will be deployed to
}

data "azurerm_subnet" "cclear" {
  count                = var.lookup_subnets ? (var.subnet_id == null ? 1 : 0) : 0
  resource_group_name  = var.vnet_resource_group_name
  virtual_network_name = var.vnet_name
  name                 = var.subnet
}

locals {
  location            = var.location != null ? var.location : data.azurerm_resource_group.ccloud[0].location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id != null ? var.subnet_id : data.azurerm_subnet.cclear[0].id
  resource_group_id   = var.resource_group_id != null ? var.resource_group_id : data.azurerm_resource_group.ccloud[0].id
}

resource "azurerm_role_assignment" "cclear_reader" {
  count                = var.system_assigned_managed_identity ? 1 : 0
  scope                = local.resource_group_id
  role_definition_name = "Reader"
  principal_id         = azurerm_linux_virtual_machine.cclear.identity[0].principal_id
}

resource "azurerm_linux_virtual_machine" "cclear" {
  name                  = var.resource_names.machine
  location              = local.location
  resource_group_name   = local.resource_group_name
  network_interface_ids = [azurerm_network_interface.cclear.id]
  size                  = var.size
  zone                  = var.zones ? "1" : null
  computer_name         = var.resource_names.machine
  admin_username        = var.admin_username
  custom_data = var.cloud_init_data != null ? base64encode(templatefile(var.cloud_init_data,
  merge(var.cloud_init_data_vars, {}))) : null
  disable_password_authentication = true

  dynamic "identity" {
    for_each = var.system_assigned_managed_identity || length(var.user_assigned_identity_ids) > 0 ? [1] : []
    content {
      type = var.system_assigned_managed_identity && length(var.user_assigned_identity_ids) > 0 ? "SystemAssigned, UserAssigned" : (
        var.system_assigned_managed_identity ? "SystemAssigned" : "UserAssigned"
      )
      identity_ids = length(var.user_assigned_identity_ids) > 0 ? var.user_assigned_identity_ids : null
    }
  }

  source_image_id = var.image_id != null ? var.image_id : null

  dynamic "source_image_reference" {
    for_each = var.image_id == null ? [1] : []
    content {
      publisher = "cpacketnetworks1719269615814"
      offer     = "cpacket-cclear-v"
      sku       = "cclear_v_byol"
      version   = var.mp_version
    }
  }

  dynamic "plan" {
    for_each = var.image_id == null ? [1] : []
    content {
      name      = "cclear_v_byol"
      publisher = "cpacketnetworks1719269615814"
      product   = "cpacket-cclear-v"
    }
  }

  os_disk {
    name                 = var.resource_names.os_disk
    caching              = "ReadWrite"
    storage_account_type = var.storage_type_os
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key)
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_managed_disk" "cclear_data_disk" {
  name                 = var.resource_names.data_disk
  location             = local.location
  resource_group_name  = local.resource_group_name
  storage_account_type = var.storage_type_data
  create_option        = "Empty"
  disk_size_gb         = var.data_size
  zone                 = var.zones ? "1" : null
  tags                 = var.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "cclear_data_disk" {
  managed_disk_id    = azurerm_managed_disk.cclear_data_disk.id
  virtual_machine_id = azurerm_linux_virtual_machine.cclear.id
  lun                = 1
  caching            = "ReadWrite"
}


resource "azurerm_network_interface" "cclear" {
  name                           = var.resource_names.management_nic
  location                       = local.location
  resource_group_name            = local.resource_group_name
  accelerated_networking_enabled = true
  ip_configuration {
    name                          = "management"
    subnet_id                     = local.subnet_id
    private_ip_address_allocation = var.ipv4_address != null ? "Static" : "Dynamic"
    private_ip_address            = var.ipv4_address
    public_ip_address_id          = var.public_ip ? azurerm_public_ip.cclear[0].id : null
  }
  tags = var.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_public_ip" "cclear" {
  count               = var.public_ip ? 1 : 0
  name                = "cclear"
  location            = local.location
  resource_group_name = local.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.zones ? ["1"] : []
  tags                = var.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

# Add explicit dependency to ensure IPs are fully available, data source wasn't cutting it
resource "time_sleep" "wait_for_ips" {
  count           = var.public_ip ? 1 : 0
  depends_on      = [azurerm_public_ip.cclear, azurerm_linux_virtual_machine.cclear]
  create_duration = "30s"
}

data "azurerm_public_ip" "cclear" {
  count               = var.public_ip ? 1 : 0
  name                = "cclear"
  resource_group_name = local.resource_group_name
  depends_on          = [time_sleep.wait_for_ips]
}
