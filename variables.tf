variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "tags" {
  description = "Map of default tags to apply to cPacket resources"
  type        = map(string)
  default     = {}
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

variable "gwlb_subnet" {
  description = "gwlb subnet properties"
  type = object({
    name = string
    cidr = string
  })
  default = {
    name = "gwlb"
    cidr = "10.0.251.0/28"
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

variable "zones" {
  description = "Place cVu-V instances across Availability Zones 1-3 and cClear-V in zone 1. Set to false in regions without Availability Zones."
  type        = bool
  default     = true
}

# Without an image ID, cVu-V and cClear-V use cPacket's Azure Marketplace (BYOL) images at the given version.

variable "cvu_image_id" {
  description = "cVu-V image ID. When null, the Azure Marketplace image at cvu_mp_version is used."
  type        = string
  default     = null
}

variable "cvu_mp_version" {
  description = "cVu-V Azure Marketplace image version, used when cvu_image_id is null"
  type        = string
  default     = "latest"
}

variable "vnet" {
  description = "CIDR block for the virtual network"
  type = object({
    name = string
    cidr = string
  })
  default = {
    cidr = "10.0.0.0/16"
    name = "cpacket-corelight"
  }
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
  description = "cVu-V instance counts. Equal values give a fixed size; when min_count and max_count differ, the scale set autoscales on its total outbound network traffic."
  type = object({
    default_count = number
    min_count     = number
    max_count     = number
  })
  default = {
    default_count = 3
    min_count     = 3
    max_count     = 3
  }
}

variable "ubuntu" {
  description = "Deploy Ubuntu VMs in place of the Corelight sensors, for when there is no valid Corelight license. They receive cVu-V's mirrored VXLAN traffic and do nothing else with it. The other corelight_* variables are then not needed."
  type        = bool
  default     = false
}

variable "corelight_image_id" {
  description = "Corelight image ID. Required unless ubuntu is true."
  type        = string
  default     = null

  validation {
    condition     = var.ubuntu || var.corelight_image_id != null
    error_message = "corelight_image_id is required unless ubuntu is true."
  }
}

variable "corelight_license_key_path" {
  description = "Corelight license key file path. Required unless ubuntu is true."
  type        = string
  default     = null

  validation {
    condition     = var.ubuntu || var.corelight_license_key_path != null
    error_message = "corelight_license_key_path is required unless ubuntu is true."
  }
}

variable "corelight_sensor_community_string" {
  description = "Corelight sensor password. Required unless ubuntu is true."
  type        = string
  default     = null

  validation {
    condition     = var.ubuntu || var.corelight_sensor_community_string != null
    error_message = "corelight_sensor_community_string is required unless ubuntu is true."
  }
}

variable "ssh_public_key_file" {
  description = "Path to the SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "capture_security_group_id" {
  description = "ID of an existing network security group to attach to the capture subnet (cVu-V and the Corelight sensors' monitoring NICs)"
  type        = string
}

variable "management_security_group_id" {
  description = "ID of an existing network security group to attach to the management subnet (cClear-V and the Corelight sensors' management NICs)"
  type        = string
}

variable "cclear_public_ip" {
  description = "cClear public IP address"
  type        = bool
  default     = false
}

variable "cclear_cloud_init_data" {
  description = "Path to the cClear cloud-init template. Defaults to cloud-init/cclear.tpl in this module."
  type        = string
  default     = null
}

variable "cclear_license" {
  description = "cClear license, written to /etc/cclear/cirrus/cclear.lic at boot. Empty deploys cClear unlicensed."
  type        = string
  sensitive   = true
  default     = ""
}

variable "cclear_managed_registration" {
  description = "Register the cVu-V scale set with cClear. Gives cClear a managed identity with Reader on the resource group, so the deploying identity must be able to create role assignments."
  type        = bool
  default     = true
}

variable "cclear_image_id" {
  description = "cClear-V image ID. When null, the Azure Marketplace image at cclear_mp_version is used."
  type        = string
  default     = null
}

variable "cclear_mp_version" {
  description = "cClear-V Azure Marketplace image version, used when cclear_image_id is null"
  type        = string
  default     = "latest"
}

variable "auto_licensing" {
  description = "Auto licensing for cClear"
  type        = bool
  default     = true
}
