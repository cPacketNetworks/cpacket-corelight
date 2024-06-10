resource "azurerm_resource_group" "capture" {
  name     = "cpacket-corelight"
  location = var.resource_group.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "capture" {
  name                = "cpacket-corelight"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.capture.location
  resource_group_name = azurerm_resource_group.capture.name
  tags                = var.tags
}

resource "azurerm_subnet" "capture" {
  name                 = "capture"
  resource_group_name  = azurerm_resource_group.capture.name
  virtual_network_name = azurerm_virtual_network.capture.name
  address_prefixes     = [var.capture_subnet.cidr]
}

resource "azurerm_subnet" "management" {
  name                 = "management"
  resource_group_name  = azurerm_resource_group.capture.name
  virtual_network_name = azurerm_virtual_network.capture.name
  address_prefixes     = [var.management_subnet.cidr]
}

resource "azurerm_network_security_group" "nva" {
  # https://learn.microsoft.com/en-us/azure/load-balancer/tutorial-gateway-portal#create-nsg
  name                = "nva"
  location            = azurerm_resource_group.capture.location
  resource_group_name = azurerm_resource_group.capture.name

  security_rule {
    name                       = "AllowAll"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAllTCP"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_network_security_group" "corelight" {
  name                = "corelight"
  location            = azurerm_resource_group.capture.location
  resource_group_name = azurerm_resource_group.capture.name

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

resource "azurerm_network_security_group" "ubuntu" {
  name                = "ubuntu"
  location            = azurerm_resource_group.capture.location
  resource_group_name = azurerm_resource_group.capture.name

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

resource "azurerm_lb" "gwlb" {
  name                = "cpacket-corelight"
  location            = azurerm_resource_group.capture.location
  resource_group_name = azurerm_resource_group.capture.name
  frontend_ip_configuration {
    name                          = "cpacket-capture"
    subnet_id                     = azurerm_subnet.capture.id
    private_ip_address            = var.gwlb.private_ip_address
    private_ip_address_allocation = "Static"
  }
  sku  = "Gateway"
  tags = var.tags
}

resource "azurerm_lb_backend_address_pool" "gwlb" {
  name            = "cpacket-capture"
  loadbalancer_id = azurerm_lb.gwlb.id
  tunnel_interface {
    type       = "Internal"
    identifier = "900"
    protocol   = "VXLAN"
    port       = "10800"
  }
  tunnel_interface {
    type       = "External"
    identifier = "901"
    protocol   = "VXLAN"
    port       = "10801"
  }
}

resource "azurerm_lb_probe" "cvu" {
  name                = "cvu-health"
  loadbalancer_id     = azurerm_lb.gwlb.id
  port                = 443
  protocol            = "Https"
  request_path        = "/sess/login"
  probe_threshold     = var.gwlb.probe_threshold
  interval_in_seconds = var.gwlb.interval_in_seconds
  number_of_probes    = var.gwlb.number_of_probes
}

resource "azurerm_lb_rule" "capture_inbound" {
  name                           = "capture-inbound"
  loadbalancer_id                = azurerm_lb.gwlb.id
  protocol                       = var.gwlb.protocol
  frontend_ip_configuration_name = azurerm_lb.gwlb.frontend_ip_configuration[0].name
  frontend_port                  = var.gwlb.frontend_port
  backend_port                   = var.gwlb.backend_port
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.gwlb.id]
  probe_id                       = azurerm_lb_probe.cvu.id
}

resource "azurerm_linux_virtual_machine_scale_set" "cvu" {
  name                 = "cvu"
  resource_group_name  = azurerm_resource_group.capture.name
  location             = azurerm_resource_group.capture.location
  sku                  = var.cvu_scaleset.sku
  computer_name_prefix = "cvu"
  overprovision        = false
  admin_username       = "ubuntu"

  source_image_id = var.cvu_image_id

  custom_data = base64encode(templatefile("${path.module}/scripts/cvu-cloud-init.tpl", {
    downstream_tool_ip1 = data.azurerm_lb.corelight.frontend_ip_configuration[0].private_ip_address,
    gwlb_ip             = azurerm_lb.gwlb.frontend_ip_configuration[0].private_ip_address,
  }))

  upgrade_mode = "Automatic"
  automatic_os_upgrade_policy {
    disable_automatic_rollback  = false
    enable_automatic_os_upgrade = false
  }

  admin_ssh_key {
    username   = "ubuntu"
    public_key = azurerm_ssh_public_key.cpacket.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.cvu_scaleset.storage_type
  }

  network_interface {
    name                          = "cvu"
    primary                       = true
    enable_accelerated_networking = true
    enable_ip_forwarding          = true
    network_security_group_id     = azurerm_network_security_group.nva.id
    ip_configuration {
      name                                   = "cvu"
      primary                                = true
      subnet_id                              = azurerm_subnet.capture.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.gwlb.id]
    }
  }

  # For binary health states, the extension schema is as follows:
  # https://learn.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-health-extension?tabs=rest-api#extension-schema-for-binary-health-states
  # Related provider PR: https://github.com/hashicorp/terraform-provider-azurerm/pull/9136/files
  extension {
    name                       = "HealthExtension"
    publisher                  = "Microsoft.ManagedServices"
    type                       = "ApplicationHealthLinux"
    type_handler_version       = "1.0"
    auto_upgrade_minor_version = true
    settings = jsonencode({
      protocol          = "https"
      port              = 443
      requestPath       = "/sess/login"
      intervalInSeconds = 5
      numberOfProbes    = 2
    })
  }

  tags = merge(var.tags, {
    Name                    = "cvu"
    "cpacket:ApplianceType" = "cVu-V"
  })
}

resource "azurerm_monitor_autoscale_setting" "cvu_scaling" {
  name                = "cvu"
  resource_group_name = azurerm_resource_group.capture.name
  location            = azurerm_resource_group.capture.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.cvu.id
  profile {
    name = "Manual"
    capacity {
      default = var.cvu_scaling.default_count
      minimum = var.cvu_scaling.min_count
      maximum = var.cvu_scaling.max_count
    }
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
  name                          = "admin"
  location                      = azurerm_resource_group.capture.location
  resource_group_name           = azurerm_resource_group.capture.name
  enable_accelerated_networking = true
  ip_configuration {
    name                          = "ubuntu-primary"
    primary                       = true
    subnet_id                     = azurerm_subnet.management.id
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

module "sensor" {
  source                         = "github.com/corelight/terraform-azure-sensor"
  license_key                    = var.corelight_license_key
  location                       = azurerm_resource_group.capture.location
  resource_group_name            = azurerm_resource_group.capture.name
  virtual_network_name           = azurerm_virtual_network.capture.name
  virtual_network_resource_group = azurerm_resource_group.capture.name
  virtual_network_address_space  = azurerm_virtual_network.capture.address_space[0]
  corelight_sensor_image_id      = var.corelight_image_id
  community_string               = "/some/api/endpoint"
  sensor_ssh_public_key          = azurerm_ssh_public_key.cpacket.public_key
  tags                           = var.tags
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
