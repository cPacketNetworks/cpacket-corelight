# # Required variables

variable "resource_group_name" {
  description = "resource group name where cClear will be deployed"
  type        = string
  nullable    = false
}

variable "vnet_resource_group_name" {
  description = "resource group vnet name that cClear will be attached to. (Can be the same as the resource_group_name.)"
  type        = string
  nullable    = false
}

variable "vnet_name" {
  description = "Name of the vnet to use"
  type        = string
  nullable    = false
}

variable "subnet" {
  description = "subnet to assign to cClear"
  type        = string
  nullable    = false
}

variable "ssh_public_key" {
  description = "The public ssh key to be used for access to the appliances. i.e. ~/.ssh/id_rsa.pub."
  type        = string
}

variable "public_ip" {
  description = "A booleon to assign a public IP to cClear."
  type        = bool
}

variable "image_id" {
  description = "Specifies the ID of the image to use to create the Virtual Machine. /subscriptions/<subscription_id>/resourceGroups/<resource_group>/providers/Microsoft.Compute/images/<cclear_image_id>"
  type        = string
  default     = null
}


# # Optional variables

variable "mp_version" {
  description = "Specifies the ID of the image to use to create the Virtual Machine. /subscriptions/<subscription_id>/resourceGroups/<resource_group>/providers/Microsoft.Compute/images/<cclear_image_id>"
  type        = string
  default     = "latest"
}

variable "tags" {
  description = "The tags to associate with your traffic source."
  type        = map(string)
  default     = {}
}

variable "ipv4_address" {
  description = "An IP to assign to cClear"
  type        = string
  default     = null
}

variable "size" {
  description = "Specifies the size of the virtual machine."
  type        = string
  default     = "Standard_D8s_v5"
}

variable "storage_type_os" {
  description = "Specifies the type of storage account type to be created for OS."
  type        = string
  default     = "Standard_LRS"
  validation {
    condition     = contains(["Standard_LRS", "Premium_LRS"], var.storage_type_os)
    error_message = "Invalid storage type."
  }
}

variable "storage_type_data" {
  description = "Specifies the type of storage account type to be created for data disks. Valid options are Premium_LRS."
  type        = string
  default     = "Premium_LRS"
  validation {
    condition     = contains(["Premium_LRS"], var.storage_type_data)
    error_message = "Invalid storage type."
  }
}

variable "data_size" {
  description = "Specifies the size of the data disk in GB."
  type        = number
  default     = 500

  validation {
    condition     = var.data_size >= 32
    error_message = "Data disk size must be at least 32 GB."
  }
}

variable "admin_username" {
  description = "The admin username of the cClear that will be deployed."
  type        = string
  default     = "ubuntu"
}

variable "zones" {
  description = "Place the cClear-V instance in an Availability Zone."
  type        = bool
  default     = true
}

variable "resource_names" {
  description = "The names of the resources to be created."
  type        = map(string)
  default = {
    machine        = "cclear"
    management_nic = "cclear-management"
    data_disk      = "cclear-data"
    os_disk        = "cclear-os"
  }
}

variable "cloud_init_data" {
  description = "The file path containing the cloud-init data to be used for the VM."
  type        = string
  default     = null
}

variable "cloud_init_data_vars" {
  description = "The cloud-init data to be used for the cClear."
  type        = map(string)
  default     = {}
}

variable "system_assigned_managed_identity" {
  description = "Enable system managed identity for cClear."
  type        = bool
  default     = true
}

variable "user_assigned_identity_ids" {
  description = "List of user-assigned managed identity IDs to assign to cClear. Used for passwordless PostgreSQL access via Azure AD."
  type        = list(string)
  default     = []
}

variable "location" {
  description = "Azure region. When provided, avoids a data-source lookup on the resource group."
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "Subnet ID for the cClear NIC. When provided, avoids a subnet data-source lookup."
  type        = string
  default     = null
}

variable "lookup_subnets" {
  description = "Whether to look up subnets via data sources when subnet IDs are not provided. Set to false when callers always pass subnet IDs computed from other resources (which would otherwise make the data-source `count` unknown at plan time)."
  type        = bool
  default     = true
}

variable "resource_group_id" {
  description = "Resource group ID (used for role assignments). When provided, avoids a data-source lookup."
  type        = string
  default     = null
}
