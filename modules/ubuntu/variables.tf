variable "name" {
  description = "Name of the scale set and its load balancer"
  type        = string
  default     = "corelight-standin"
}

variable "resource_group_name" {
  description = "Resource group to deploy into"
  type        = string
}

variable "location" {
  description = "Azure region to deploy into"
  type        = string
}

variable "monitoring_subnet_id" {
  description = "Subnet for the stand-in sensors and the load balancer frontend that cVu-V mirrors traffic to"
  type        = string
}

variable "management_subnet_id" {
  description = "Subnet to attach the NAT gateway to, as the Corelight sensor module does"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for the corelight user"
  type        = string
}

variable "size" {
  description = "VM size of the stand-in sensors"
  type        = string
  default     = "Standard_D2s_v5"
}

variable "instances" {
  description = "Number of stand-in sensors"
  type        = number
  default     = 1
}

variable "vxlan_vni" {
  description = "VXLAN network identifier of the mirrored traffic. cloud-init/cvu.tpl gives the first downstream tool 1337."
  type        = number
  default     = 1337
}

variable "vxlan_port" {
  description = "UDP port of the mirrored VXLAN traffic"
  type        = number
  default     = 4789
}

variable "tags" {
  description = "Tags to apply to the resources"
  type        = map(string)
  default     = {}
}
