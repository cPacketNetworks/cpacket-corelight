# # Required variables

variable "resource_group" {
  description = "resource group that contains the cCloud resources."
  type        = string
  nullable    = false
}

variable "vnet" {
  description = "VNET to put the cVu in."
  type = object({
    name           = string
    resource_group = string
  })
  nullable = false
}

variable "capture_subnet_name" {
  description = "capture subnet name (contains the cVu-V capture NIC)"
  type        = string
  nullable    = false
}

variable "ssh_public_key" {
  description = "The public ssh key to be used for access to the appliances. i.e. ~/.ssh/id_rsa.pub."
  type        = string
}


# # Optional variables

variable "management_subnet_name" {
  description = "management subnet name"
  type        = string
  default     = null
}

variable "gwlb_subnet_name" {
  description = "GWLB subnet name"
  type        = string
  default     = null
}

variable "image_id" {
  description = "ID of the cVu-V image"
  type        = string
  nullable    = true
  default     = null
}

variable "mp_version" {
  description = "ID of the cVu-V image"
  type        = string
  nullable    = true
  default     = "latest"
}

variable "tags" {
  description = "tags to associate with your cVu(s)."
  type        = map(string)
  default     = {}
}

variable "admin_username" {
  description = "The admin username of the cVu(s) that will be deployed."
  type        = string
  default     = "ubuntu"
}

variable "cvu_scaleset_lb_grace_period" {
  description = "The auto match instance repair grace period for the load balancer."
  type        = string
  default     = "PT10M" # time given in ISO 8601 format
}

variable "cvu_scaleset_autoscale_default" {
  description = "The default number of instances to deploy."
  type        = number
  default     = 2

  validation {
    condition     = var.cvu_scaleset_autoscale_default >= 1
    error_message = "Default autoscale count must be at least 1."
  }

  validation {
    condition     = var.cvu_scaleset_autoscale_default >= var.cvu_scaleset_autoscale_min && var.cvu_scaleset_autoscale_default <= var.cvu_scaleset_autoscale_max
    error_message = "Default autoscale count must be between min and max values."
  }
}

variable "cvu_scaleset_autoscale_min" {
  description = "The minimum number of instances to deploy."
  type        = number
  default     = 2

  validation {
    condition     = var.cvu_scaleset_autoscale_min >= 1
    error_message = "Minimum autoscale count must be at least 1."
  }
}

variable "cvu_scaleset_autoscale_max" {
  description = "The maximum number of instances to deploy."
  type        = number
  default     = 5

  validation {
    condition     = var.cvu_scaleset_autoscale_max >= var.cvu_scaleset_autoscale_min
    error_message = "Maximum autoscale count must be greater than or equal to minimum."
  }
}

variable "size" {
  description = "Specifies the size of the virtual machine."
  type        = string
  default     = "Standard_D4ls_v5"
}

variable "storage_type" {
  description = "Specifies the type of storage account to be created. Valid options are Standard_LRS, Standard_ZRS, Standard_GRS, Standard_RAGRS, Premium_LRS."
  type        = string
  default     = "Premium_LRS"

  validation {
    condition     = contains(["Standard_LRS", "Standard_ZRS", "Standard_GRS", "Standard_RAGRS", "Premium_LRS"], var.storage_type)
    error_message = "Storage type must be one of: Standard_LRS, Standard_ZRS, Standard_GRS, Standard_RAGRS, Premium_LRS."
  }
}

variable "zones" {
  description = "Use a rotating set of Availability Zones for the cVu(s)."
  type        = bool
  default     = true
}

variable "dual_nic" {
  description = "deploy cVu with dual NICs"
  type        = bool
  default     = true
}

variable "lb_name" {
  description = "The name of the load balancer."
  type        = string
  default     = "cvu"
}

variable "vmss_name" {
  description = "name of cVu VMSS"
  type        = string
  default     = "cvu-vmss"
}

variable "instance_prefix" {
  description = "prefix of cVu instances"
  type        = string
  default     = "cvu"
}

variable "capture_nic_name" {
  description = "name of the capture NIC"
  type        = string
  default     = "capture"
}

variable "management_nic_name" {
  description = "name of the management NIC"
  type        = string
  default     = "management"
}

variable "cloud_init_data" {
  description = "The cloud-init data to be used for the cVu(s)."
  type        = string
  default     = null
  nullable    = true
}

variable "cloud_init_data_vars" {
  description = "The cloud-init data to be used for the cVu(s)."
  type        = map(string)
  default     = {}
}

variable "topology_config_file" {
  description = "Path to a topology.json Terraform template. When set, the module renders it (injecting GWLB_IPV4_ADDRESS from the LB) and adds TOPOLOGY_JSON to cloud_init_data_vars."
  type        = string
  default     = null
}

variable "topology_config_vars" {
  description = "Variables passed to the topology_config_file template (e.g. DOWNSTREAM_IPV4_ADDRESSES). GWLB_IPV4_ADDRESS is added automatically by the module."
  type        = any
  default     = {}
}

variable "user_assigned_identity_ids" {
  description = "List of user-assigned managed identity IDs to assign to the cVu VMSS instances. Used for passwordless PostgreSQL access via Azure AD."
  type        = list(string)
  default     = []
}

variable "gwlb" {
  description = "use a Gateway Load Balancer in front of cVu(s)"
  type        = bool
  default     = false
}

variable "gwlb_external_tunnel" {
  description = "Gateway Load Balancer external tunnel interface"
  type = object({
    identifier = number
    port       = number
  })
  default = {
    identifier = 901
    port       = 10801
  }
}

variable "gwlb_internal_tunnel" {
  description = "Gateway Load Balancer internal tunnel interface"
  type = object({
    identifier = number
    port       = number
  })
  default = {
    identifier = 900
    port       = 10800
  }
}

variable "capture_health_probe" {
  description = "The health probe for the capture NIC."
  type = object({
    protocol            = string
    request_path        = string
    port                = number
    probe_threshold     = number
    interval_in_seconds = number
    number_of_probes    = number
  })
  default = {
    protocol            = "Https"
    request_path        = "/api/info/v1/health"
    port                = 443
    probe_threshold     = 1
    interval_in_seconds = 15
    number_of_probes    = 2
  }
}

variable "location" {
  description = "Azure region. When provided, avoids a data-source lookup on the resource group."
  type        = string
  default     = null
}

variable "capture_subnet_id" {
  description = "Capture subnet ID. When provided, avoids a subnet data-source lookup."
  type        = string
  default     = null
}

variable "management_subnet_id" {
  description = "Management subnet ID (for dual-NIC). When provided, avoids a subnet data-source lookup."
  type        = string
  default     = null
}

variable "gwlb_subnet_id" {
  description = "GWLB subnet ID. When provided, avoids a subnet data-source lookup."
  type        = string
  default     = null
}

variable "lookup_subnets" {
  description = "Whether to look up subnets via data sources when subnet IDs are not provided. Set to false when callers always pass subnet IDs computed from other resources (which would otherwise make the data-source `count` unknown at plan time)."
  type        = bool
  default     = true
}

