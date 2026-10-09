# cPacket cVu-V terraform

Terraform for cPacket's cVu-V Deployment.

## Description

This module is used for deploying cVu-V(s).  cVu-V(s) are deployed behind a load balancer.

## Usage
```terraform
module "cvu" {
  source = "../modules/cvu"         # Relative path to the cvu module.

  # Required Variables
  resource_group            = "<Resource group name where cVu-V will be deployed>"
  vnet                      = {
    name           = "<VNET cVu-V(s) will be deployed>"
    resource_group = "<Resource group VNET name that cVu-V(s) will be attached to (Can be the same as the resource_group)>"
  }
  capture_subnet_name       = "<Subnet to assign to capture nic on cVu-V(s)>"
  ssh_public_key            = "<Path to the public ssh key to be used for accessing cVu-V(s)>"
 
  # Optional Variables with values.  Default values are shown.
  management_subnet_name          = null                 # Subnet to assign to management nic on cVu-V(s).
  image_id                        = null                 # ID of the cVu-V(s) image.
  tags                            = {}                   # Tags to associate with your cVu-V(s).
  admin_username                  = "ubuntu"             # The admin username of the cVu-V(s) that will be deployed.
  cvu_scaleset_lb_grace_period    = "PT10M"              # The auto match instance repair grace period for the load balancer. time given in ISO 8601 format.  
  cvu_scaleset_autoscale_default  = 2                    # The default number of instances to deploy.
  cvu_scaleset_autoscale_min      = 2                    # The minimum number of instances to deploy.
  cvu_scaleset_autoscale_max      = 5                    # The maximum number of instances to deploy.
  size                            = "Standard_D4ls_v5"   # Specifies the size of the virtual machine.
  storage_type                    = "Premium_LRS"        # Specifies the type of storage account to be created. Valid options are Standard_LRS, Standard_ZRS, Standard_GRS, Standard_RAGRS, Premium_LRS.
  zones                           = true                 # Use a rotating set of Availability Zones for the cVu-V(s).
  dual_nic                        = true                 # Deploy cVu-V(s) with dual NICs.
  lb_name                         = "cvu"                # The name of the load balancer.
  vmss_name                       = "cvu-vmss"           # Name of cVu-V VMSS.
  instance_prefix                 = "cvu"                # Prefix of cVu-V(s) instances.
  capture_nic_name                = "capture"            # Name of the capture NIC.
  management_nic_name             = "management"         # Name of the management NIC.
  cloud_init_data                 = null                 # Path of the cloud-init template for the cVu-V(s).
  gwlb                            = false                # Use a gateway load balancer in front of cVu-V(s).
  gwlb_external_tunnel            = {                    # Gateway load balancer external tunnel interface.
      identifier          = 901
      port                = 10801
    }
  gwlb_internal_tunnel            = {                    # Gateway load balancer internal tunnel interface.
      identifier          = 900
      port                = 10800
    }

  # Depends On
  depends_on = [ <resource_group>, <vnet> ]
}
```

## Variable information (with examples)
```
# Required Variables

resource_group: This should be set to the resource group where cVu-V(s) will be deployed.
  resource_group = "cpacket-inline-demo"

vnet: This is a map with vnet name and resource group.  resource_group should be set to the resource group containing the virtual network that cVu-V(s) will be attached to. This can be the same as resource_group. name should be set to the virtual network of the resource_group in this map.
  vnet = {
    name           = "example-vnet"
    resource_group = "cpacket-inline-demo"
  }

capture_subnet_name: This is the subnet within the virtual network cVu-V(s) will use for the capture interface.
  capture_subnet_name = "capture"

ssh_public_key: This is the path of the public SSH key to be added to cVu-V(s) for access.
  ssh_public_key = "~/.ssh/id_rsa.pub"

# Optional Variables

management_subnet_name: This is the subnet within the virtual network cVu-V(s) will use for the management interface.
  management_subnet_name = "management"

image_id: This is ID of the image to use for creating the cVu-V(s).
  image_id = "/subscriptions/52ba377e-6215-48d9-beee-b3553fd81150/resourceGroups/CLOUD-BUILDS/providers/Microsoft.Compute/galleries/releases/images/cvu-v-mp/versions/26.1.1155"

tags: This is a map with key and value tags to assign to resources.
  tags = {
    "owner" = "someone@example.com"
  }

admin_username: This is the admin username for cVu-V(s).
  admin_username = "ubuntu"

cvu_scaleset_lb_grace_period: This is the time grace period for repairs to the cVu-V(s) behind the load balancer. Time given in ISO 8601 format.  
  cvu_scaleset_lb_grace_period = "PT10M"

cvu_scaleset_autoscale_default: This is the default number of cVu-V(s) instances to deploy.
  cvu_scaleset_autoscale_default = 2                    # The default number of instances to deploy.

cvu_scaleset_autoscale_min: This is the minimum number of cVu-V(s) instances in the scale set.
  cvu_scaleset_autoscale_min = 2

cvu_scaleset_autoscale_max: This is the maximum number of cVu-V(s) instances in the scale set.
  cvu_scaleset_autoscale_max = 5

size: This is the instance size of cVu-V(s).
  size = "Standard_D4ls_v5"

storage_type: This is the type of storage account for OS disk.
  storage_type = "Premium_LRS"

zones: This is a boolean value to indicate if cVu-V(s) will be placed in an Availability Zone.
  zones = true

dual_nic: This is a boolean value to indicate if cVu-V(s) will deploy with dual NICs.
  dual_nic = true

lb_name: This is the name of the load balancer in front of cVu-V(s).
  lb_name = "cvu"

vmss_name: This is the name to give to cVu-V VMSS.
  vmss_name = "cvu-vmss"

instance_prefix: This is the prefix name to give to the cVu-V(s) instances in the scale set.
  instance_prefix = "cvu"

capture_nic_name: This is the name to give cVu-V(s)'s capture NIC.
  capture_nic_name = "capture"

management_nic_name: This is the name to give cVu-V(s)'s management NIC.
  management_nic_name = "management"

cloud_init_data: This is the path of a cloud-init template for the cVu-V(s). It is rendered with templatefile() using cloud_init_data_vars.
  cloud_init_data = "scripts/cvu-cloud-init.tpl"

gwlb: # This enables a gateway load balancer in front of cVu-V(s).  A gateway load balancer enables chaining of load balancers.
  gwlb = false

gwlb_external_tunnel: This is the gateway load balancer external tunnel interface.
  gwlb_external_tunnel  = {
      identifier          = 901
      port                = 10801
    }

gwlb_internal_tunnel: This is the gateway load balancer internal tunnel interface.
  gwlb_internal_tunnel  = {
      identifier          = 900
      port                = 10800
    }

```
