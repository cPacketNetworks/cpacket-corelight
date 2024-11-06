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
}

variable "subnet" {
  description = "subnet to assign to cClear"
  type        = string
}

variable "image_id" {
  description = "Specifies the ID of the image to use to create the Virtual Machine. /subscriptions/<subscription_id>/resourceGroups/<resource_group>/providers/Microsoft.Compute/images/<cclear_image_id>"
  type        = string
}

variable "ssh_public_key" {
  description = "The public ssh key to be used for access to the appliances. i.e. ~/.ssh/id_rsa.pub."
  type        = string
}

variable "public_ip" {
  description = "A booleon to assign a public IP to cClear."
  type        = bool
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
  default     = "Standard_D4s_v5"
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

variable "security_group_id" {
  description = "The security group to attach to the cClear."
  type        = string
}
