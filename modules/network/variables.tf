variable "resource_group" {
  description = "resource group properties"
  type = object({
    name     = string
    location = string
  })
}

variable "vnet" {
  description = "virtual network properties"
  type = object({
    name = string
    cidr = string
  })
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

variable "gwlb_subnet" {
  description = "GWLB subnet properties"
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

