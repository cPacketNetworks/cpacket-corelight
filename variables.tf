variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
}

variable "tags" {
  description = "Map of default tags to apply to cPacket resources"
  type        = map(string)
  default     = null
}

variable "resource_group" {
  description = "resource group properties"
  type = object({
    name     = string
    location = string
  })
}

variable "capture_subnet" {
  description = "capture subnet properties"
  type = object({
    name = string
    cidr = string
  })
  default = {
    name = "capture"
    cidr = "10.0.253.0/24"
  }
}

variable "management_subnet" {
  description = "management subnet properties"
  type = object({
    name = string
    cidr = string
  })
  default = {
    name = "management"
    cidr = "10.0.252.0/24"
  }
}

variable "gwlb" {
  description = "Map of gateway load balancer properties"
  type = object({
    private_ip_address  = string
    protocol            = string
    frontend_port       = string
    backend_port        = string
    probe_port          = number
    probe_threshold     = number
    interval_in_seconds = number
    number_of_probes    = number
  })
  default = {
    private_ip_address  = "10.0.253.5"
    protocol            = "All"
    frontend_port       = "0"
    backend_port        = "0"
    probe_port          = 80
    probe_threshold     = 1
    interval_in_seconds = 15
    number_of_probes    = 2
  }
}

# Image IDs are specified in free standing variables seperately from the VM configuration objects because
# there are no meaningful defaults for them, and Terraform object defaults cannot be omitted if _any_ of the defaults are specified.

variable "cvu_image_id" {
  description = "cVu-V image ID"
  type        = string
}

variable "vnet_cidr" {
  description = "CIDR block for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cvu_scaleset" {
  description = "cVu-V scaleset properties"
  type = object({
    # number of instances to deploy
    sku          = string
    storage_type = string
  })
  default = {
    sku          = "Standard_D4ls_v5"
    storage_type = "Premium_LRS"
  }
}

variable "cvu_scaling" {
  description = "cVu-V scaling properties"
  type = object({
    default_count = number
    min_count     = number
    max_count     = number
  })
  default = {
    default_count = 3
    min_count     = 1
    max_count     = 5
  }
}

variable "corelight_image_id" {
  description = "Corelight image ID"
  type        = string
}

variable "corelight_license_key_path" {
  description = "Corelight license key file path"
  type        = string
}

variable "corelight_sensor_community_string" {
  description = "Corelight sensor password"
  type        = string
}

variable "ssh_public_key_file" {
  description = "Path to the SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "cclear_public_ip" {
  description = "cClear public IP address"
  type        = bool
  default     = false
}

variable "cclear_cloud_init_data" {
  description = "cClear cloud-init data"
  type        = string
  default     = null
}

variable "cclear_image_id" {
  description = "cClear image ID"
  type        = string
}
