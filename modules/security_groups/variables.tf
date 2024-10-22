variable "resource_group" {
  description = "resource group properties"
  type = object({
    name     = string
    location = string
  })
}

variable "tags" {
  description = "Map of default tags to apply to cPacket resources"
  type        = map(string)
  default     = null
}