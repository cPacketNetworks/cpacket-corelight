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
}

variable "capture_subnet_id" {
  type = string
}

variable "nva_security_group_id" {
  type = string
}

variable "public_key" {
  type = string
}

variable "downstream_tool" {
  type        = string
  description = "frontend ip of the Corelight load balancer"
}

variable "cvu_image_id" {
  description = "cVu-V image ID"
  type        = string
}

variable "cvu_scaleset" {
  description = "cVu-V scaleset properties"
  type = object({
    # number of instances to deploy
    sku          = string
    storage_type = string
  })
}

variable "cvu_scaling" {
  description = "cVu-V scaling properties"
  type = object({
    default_count = number
    min_count     = number
    max_count     = number
  })
}

