variable "resource_group" {
  description = "resource group properties"
  type = object({
    name     = string
    location = string
  })
}

variable "vnet_cidr" {
  description = "CIDR block for the virtual network"
  type        = string
}

variable "capture_subnet" {
  description = "capture subnet properties"
  type = object({
    name = string
    cidr = string
  })
}

variable "management_subnet" {
  description = "management subnet properties"
  type = object({
    name = string
    cidr = string
  })
}

variable "tags" {
  description = "Map of default tags to apply to cPacket resources"
  type        = map(string)
  default     = null
}