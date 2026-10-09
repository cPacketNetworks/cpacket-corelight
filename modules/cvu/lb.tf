resource "azurerm_lb" "cvu" {
  name                = var.lb_name
  location            = local.location
  resource_group_name = local.resource_group_name
  sku                 = var.gwlb ? "Gateway" : "Standard"

  frontend_ip_configuration {
    name                          = "capture"
    subnet_id                     = var.gwlb ? local.gwlb_subnet_id : local.capture_subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  dynamic "frontend_ip_configuration" {
    for_each = var.dual_nic ? toset([0]) : toset([])
    content {
      name                          = "management"
      subnet_id                     = local.management_subnet_id
      private_ip_address_allocation = "Dynamic"
    }
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_lb_backend_address_pool" "capture" {
  name            = "capture"
  loadbalancer_id = azurerm_lb.cvu.id

  dynamic "tunnel_interface" {
    for_each = var.gwlb ? toset([0]) : toset([])
    content {
      type       = "Internal"
      protocol   = "VXLAN"
      identifier = var.gwlb_internal_tunnel.identifier
      port       = var.gwlb_internal_tunnel.port
    }
  }

  dynamic "tunnel_interface" {
    for_each = var.gwlb ? toset([0]) : toset([])
    content {
      type       = "External"
      protocol   = "VXLAN"
      identifier = var.gwlb_external_tunnel.identifier
      port       = var.gwlb_external_tunnel.port
    }
  }
}

resource "azurerm_lb_backend_address_pool" "management" {
  count           = var.dual_nic ? 1 : 0
  name            = "management"
  loadbalancer_id = azurerm_lb.cvu.id

  dynamic "tunnel_interface" {
    for_each = var.gwlb ? toset([0]) : toset([])
    content {
      type       = "Internal"
      protocol   = "VXLAN"
      identifier = var.gwlb_internal_tunnel.identifier
      port       = var.gwlb_internal_tunnel.port
    }
  }

  dynamic "tunnel_interface" {
    for_each = var.gwlb ? toset([0]) : toset([])
    content {
      type       = "External"
      protocol   = "VXLAN"
      identifier = var.gwlb_external_tunnel.identifier
      port       = var.gwlb_external_tunnel.port
    }
  }
}

resource "azurerm_lb_probe" "capture" {
  name                = "capture"
  loadbalancer_id     = azurerm_lb.cvu.id
  protocol            = var.capture_health_probe.protocol
  request_path        = var.capture_health_probe.request_path
  port                = var.capture_health_probe.port
  probe_threshold     = var.capture_health_probe.probe_threshold
  interval_in_seconds = var.capture_health_probe.interval_in_seconds
  number_of_probes    = var.capture_health_probe.number_of_probes
}

resource "azurerm_lb_probe" "management" {
  count               = var.dual_nic ? 1 : 0
  name                = "management"
  loadbalancer_id     = azurerm_lb.cvu.id
  protocol            = "Https"
  request_path        = "/api/info/v1/health"
  port                = 443
  probe_threshold     = 1
  interval_in_seconds = 15
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "capture" {
  name                           = "capture"
  loadbalancer_id                = azurerm_lb.cvu.id
  protocol                       = "All"
  frontend_ip_configuration_name = "capture"
  frontend_port                  = 0
  backend_port                   = 0
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.capture.id]
  probe_id                       = azurerm_lb_probe.capture.id
  tcp_reset_enabled              = var.gwlb ? false : true
}

resource "azurerm_lb_rule" "management" {
  count                          = var.dual_nic ? 1 : 0
  name                           = "management"
  loadbalancer_id                = azurerm_lb.cvu.id
  protocol                       = "All"
  frontend_ip_configuration_name = "management"
  frontend_port                  = 0
  backend_port                   = 0
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.management[count.index].id]
  probe_id                       = azurerm_lb_probe.management[0].id
  tcp_reset_enabled              = var.gwlb ? false : true
}
