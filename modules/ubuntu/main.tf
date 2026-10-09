# Ubuntu VMs that stand in for the Corelight sensors when there is no valid Corelight license. Like the
# Corelight sensor module, it puts the sensors behind an internal load balancer that cVu-V mirrors traffic to, and
# attaches a NAT gateway to the management subnet. Each VM terminates the mirrored VXLAN on an interface and does
# nothing else with it.

locals {
  vxlan_interface = "vxlan${var.vxlan_vni}"
}

resource "azurerm_lb" "standin" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"

  frontend_ip_configuration {
    name      = "monitoring"
    subnet_id = var.monitoring_subnet_id
  }

  tags = var.tags
}

resource "azurerm_lb_backend_address_pool" "monitoring" {
  loadbalancer_id = azurerm_lb.standin.id
  name            = "monitoring"
}

# The VXLAN tunnel has no listener to probe, so the probe checks that the VM is up through SSH.
resource "azurerm_lb_probe" "ssh" {
  loadbalancer_id = azurerm_lb.standin.id
  name            = "ssh"
  port            = 22
  protocol        = "Tcp"
}

resource "azurerm_lb_rule" "vxlan" {
  loadbalancer_id                = azurerm_lb.standin.id
  name                           = "vxlan"
  protocol                       = "Udp"
  frontend_port                  = var.vxlan_port
  backend_port                   = var.vxlan_port
  frontend_ip_configuration_name = azurerm_lb.standin.frontend_ip_configuration[0].name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.monitoring.id]
  probe_id                       = azurerm_lb_probe.ssh.id
}

# A single NIC, in the monitoring subnet. A probe of a second NIC would be answered through the first, which Azure
# drops.
resource "azurerm_linux_virtual_machine_scale_set" "standin" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.size
  instances           = var.instances
  overprovision       = false
  upgrade_mode        = "Manual"

  admin_username = "corelight"
  admin_ssh_key {
    username   = "corelight"
    public_key = var.ssh_public_key
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-26_04-lts"
    sku       = "server"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  network_interface {
    name    = "monitoring"
    primary = true
    ip_configuration {
      name                                   = "monitoring"
      primary                                = true
      subnet_id                              = var.monitoring_subnet_id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.monitoring.id]
    }
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tpl", {
    interface = local.vxlan_interface
    vni       = var.vxlan_vni
    port      = var.vxlan_port
  }))

  boot_diagnostics {}

  tags = var.tags

  depends_on = [azurerm_lb_rule.vxlan]
}

# cClear-V reaches the internet through the management subnet's NAT gateway, which the Corelight sensor module
# creates. Create it here too, so the stand-in doesn't change cClear-V's outbound path.

resource "azurerm_public_ip" "nat" {
  name                = "${var.name}-nat"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "management" {
  name                = "${var.name}-management"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "management" {
  nat_gateway_id       = azurerm_nat_gateway.management.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "management" {
  subnet_id      = var.management_subnet_id
  nat_gateway_id = azurerm_nat_gateway.management.id
}
