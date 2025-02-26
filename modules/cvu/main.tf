resource "azurerm_lb" "gwlb" {
  name                = "cpacket-corelight"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  frontend_ip_configuration {
    name                          = "cpacket-capture"
    subnet_id                     = var.capture_subnet_id
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
  location             = var.resource_group.location
  resource_group_name  = var.resource_group.name
  sku                  = var.cvu_scaleset.sku
  computer_name_prefix = "cvu"
  overprovision        = false
  admin_username       = "ubuntu"
  instances            = 1
  source_image_id      = var.cvu_image_id

  custom_data = base64encode(templatefile("${path.module}/scripts/cvu-cloud-init.tpl", {
    downstream_tool_ip1 = var.downstream_tool,
    gwlb_ip             = azurerm_lb.gwlb.frontend_ip_configuration[0].private_ip_address,
  }))

  upgrade_mode = "Automatic"
  automatic_os_upgrade_policy {
    disable_automatic_rollback  = false
    enable_automatic_os_upgrade = false
  }

  admin_ssh_key {
    username   = "ubuntu"
    public_key = var.public_key
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
    network_security_group_id     = var.nva_security_group_id
    ip_configuration {
      name                                   = "cvu"
      primary                                = true
      subnet_id                              = var.capture_subnet_id
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
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
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

