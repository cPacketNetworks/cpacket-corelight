data "azurerm_resource_group" "ccloud" {
  count = var.location == null ? 1 : 0
  name  = var.resource_group
}

data "azurerm_subnet" "capture" {
  count                = var.lookup_subnets ? (var.capture_subnet_id == null ? 1 : 0) : 0
  resource_group_name  = var.vnet.resource_group
  virtual_network_name = var.vnet.name
  name                 = var.capture_subnet_name
}

data "azurerm_subnet" "gwlb" {
  count                = var.lookup_subnets ? (var.gwlb_subnet_id == null && var.gwlb ? 1 : 0) : 0
  resource_group_name  = var.vnet.resource_group
  virtual_network_name = var.vnet.name
  name                 = var.gwlb_subnet_name
}

data "azurerm_subnet" "management" {
  count                = var.lookup_subnets ? (var.management_subnet_id == null && var.dual_nic ? 1 : 0) : 0
  resource_group_name  = var.vnet.resource_group
  virtual_network_name = var.vnet.name
  name                 = var.management_subnet_name
}

locals {
  location             = var.location != null ? var.location : data.azurerm_resource_group.ccloud[0].location
  resource_group_name  = var.resource_group
  capture_subnet_id    = var.capture_subnet_id != null ? var.capture_subnet_id : data.azurerm_subnet.capture[0].id
  gwlb_subnet_id       = var.gwlb_subnet_id != null ? var.gwlb_subnet_id : try(data.azurerm_subnet.gwlb[0].id, null)
  management_subnet_id = var.management_subnet_id != null ? var.management_subnet_id : try(data.azurerm_subnet.management[0].id, null)
}

resource "azurerm_linux_virtual_machine_scale_set" "cvu" {
  name                = var.vmss_name
  instances           = var.cvu_scaleset_autoscale_default
  location            = local.location
  resource_group_name = local.resource_group_name
  sku                 = var.size
  zones               = var.zones ? [1, 2, 3] : []
  overprovision       = false

  admin_username = var.admin_username
  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key)
  }

  dynamic "identity" {
    for_each = length(var.user_assigned_identity_ids) > 0 ? [1] : []
    content {
      type         = "UserAssigned"
      identity_ids = var.user_assigned_identity_ids
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.storage_type
  }

  dynamic "network_interface" {
    for_each = var.dual_nic ? toset([0]) : toset([])
    content {
      name                          = var.management_nic_name
      primary                       = true
      enable_ip_forwarding          = false
      enable_accelerated_networking = false
      ip_configuration {
        name                                   = "management"
        primary                                = true
        subnet_id                              = local.management_subnet_id
        load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.management[network_interface.value].id]
      }
    }
  }

  network_interface {
    name                          = var.capture_nic_name
    primary                       = var.dual_nic ? false : true
    enable_accelerated_networking = true
    enable_ip_forwarding          = true
    ip_configuration {
      name                                   = "capture"
      primary                                = true
      subnet_id                              = local.capture_subnet_id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.capture.id]
    }
  }

  dynamic "source_image_reference" {
    for_each = var.image_id == null ? [1] : []

    content {
      publisher = "cpacketnetworks1719269615814"
      offer     = "cpacket-cvu-v"
      sku       = "cvu_v_byol"
      version   = var.mp_version
    }
  }

  source_image_id = var.image_id != null ? var.image_id : null

  dynamic "plan" {
    for_each = var.image_id == null ? [1] : []

    content {
      name      = "cvu_v_byol"
      publisher = "cpacketnetworks1719269615814"
      product   = "cpacket-cvu-v"
    }
  }

  computer_name_prefix = var.instance_prefix
  custom_data = var.cloud_init_data != null ? base64encode(templatefile(var.cloud_init_data,
    merge(var.cloud_init_data_vars,
      {
        GWLB_IPV4_ADDRESS        = var.gwlb ? azurerm_lb.cvu.frontend_ip_configuration[0].private_ip_address : "",
        GWLB_INTERNAL_VXLAN_PORT = var.gwlb ? var.gwlb_internal_tunnel.port : "",
        GWLB_INTERNAL_VXLAN_VNI  = var.gwlb ? var.gwlb_internal_tunnel.identifier : "",
        GWLB_EXTERNAL_VXLAN_PORT = var.gwlb ? var.gwlb_external_tunnel.port : "",
        GWLB_EXTERNAL_VXLAN_VNI  = var.gwlb ? var.gwlb_external_tunnel.identifier : "",
      },
      var.topology_config_file != null ? {
        TOPOLOGY_JSON = templatefile(var.topology_config_file, merge(var.topology_config_vars, {
          GWLB_IPV4_ADDRESS = var.gwlb ? azurerm_lb.cvu.frontend_ip_configuration[0].private_ip_address : ""
        }))
      } : {},
    )
  )) : null

  automatic_instance_repair {
    enabled      = true
    grace_period = var.cvu_scaleset_lb_grace_period
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
      protocol          = "tcp"
      port              = 22
      intervalInSeconds = 35
      numberOfProbes    = 3
    })
  }

  tags = merge(var.tags, {
    "cpacket:cluster-device-type" = "cvu"
    "disableSnatOnPL"             = "true"
  })

  lifecycle {
    ignore_changes = [instances, tags]
  }

  depends_on = [
    azurerm_lb_rule.management,
    azurerm_lb_rule.capture,
  ]
}

# This is for outputting prviate IP addresses of the primary NICs of the CVU instances
data "azurerm_virtual_machine_scale_set" "cvu" {
  name                = azurerm_linux_virtual_machine_scale_set.cvu.name
  resource_group_name = var.resource_group
}

resource "azurerm_monitor_autoscale_setting" "cvu" {
  name                = var.vmss_name
  location            = local.location
  resource_group_name = local.resource_group_name
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.cvu.id

  profile {
    name = "network-throughput"
    capacity {
      default = var.cvu_scaleset_autoscale_default
      minimum = var.cvu_scaleset_autoscale_min
      maximum = var.cvu_scaleset_autoscale_max
    }
    # Supported metrics:
    # https://learn.microsoft.com/en-us/azure/azure-monitor/reference/supported-metrics/metrics-index
    # https://learn.microsoft.com/en-us/azure/azure-monitor/reference/supported-metrics/microsoft-compute-virtualmachinescalesets-metrics
    # https://learn.microsoft.com/en-us/azure/azure-monitor/reference/supported-metrics/microsoft-compute-virtualmachinescalesets-virtualmachines-metrics
    rule {
      metric_trigger {
        metric_name              = "Network Out Total"
        metric_resource_id       = azurerm_linux_virtual_machine_scale_set.cvu.id
        operator                 = "GreaterThan"
        statistic                = "Average"
        time_aggregation         = "Average"
        time_window              = "PT5M"
        time_grain               = "PT1M"
        threshold                = 30000000000 # (4 gbps) 4000000000 bps * 60 s / 8 bit per byte = 3000000000 bytes/min
        metric_namespace         = "Microsoft.Compute/virtualMachineScaleSets"
        divide_by_instance_count = false
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name              = "Network Out Total"
        metric_resource_id       = azurerm_linux_virtual_machine_scale_set.cvu.id
        operator                 = "LessThan"
        statistic                = "Average"
        time_aggregation         = "Average"
        time_window              = "PT5M"
        time_grain               = "PT1M"
        threshold                = 30000000000 # (4 gbps) 4000000000 bps * 60 s / 8 bit per byte = 3000000000 bytes/min
        metric_namespace         = "Microsoft.Compute/virtualMachineScaleSets"
        divide_by_instance_count = false
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }
    }
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [tags]
  }
}
