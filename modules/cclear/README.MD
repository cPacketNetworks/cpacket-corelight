# cPacket cClear-V terraform

Terraform for cPacket's cClear-V Deployment.

## Description

This module is used for deploying a cClear-V.

## Usage
```
module "cclear" {
  source = "../modules/cclear"  # Relative path to the cclear module.

  # Required Variables
  resource_group_name      = "<Resource group name where cClear-V will be deployed>"
  vnet_resource_group_name = "<Resource group vnet name that cClear-V will be attached to (Can be the same as the resource_group_name)>"
  vnet_name                = "<VNET cCclear-V will be deployed>"
  subnet                   = "<Subnet to assign to cClear-V>"
  image_id                 = "<Specifies the ID of the image to use to create cClear-V>"
  ssh_public_key           = "<Public ssh key to be used for accessing cClear-V>"
  public_ip                = "<A boolean to assign a public IP to cClear-V>"

  # Optional Variables with default values.  Default values are shown.
  tags                            = {}                                        # The tags to associate with your resources.
  ipv4_address                    = null                                      # The private IP to assign to cClear-V.
  size                            = "Standard_D4s_v5"                         # VM instance size.
  storage_type_os                 = "Standard_LRS"                            # Specifies the type of storage account type to be created for OS.
  storage_type_data               = "Premium_LRS"                             # Specifies the type of storage account type to be created for data disks. Valid options are Premium_LRS.
  data_size                       = 500                                       # Specifies the size of the data disk in GB.
  admin_username                  = "ubuntu"                                  # The admin username of the cClear-V that will be deployed.
  zones                           = true                                      # Place the cClear-V instance in an Availability Zone.
  required_env_vars               = ["CCLEARV_USERNAME", "CCLEARV_PASSWORD"]  # Username and password environment variables to supply for the HTTP basic authentication.
  resource_names                  = {                                         # The names of the resources to be created.
    machine        = "cclear"
    management_nic = "cclear-management"
    data_disk      = "cclear-data"
    os_disk        = "cclear-OS"
  }
  cloud_init_data                 = null                 # The cloud-init data will be used for the cClear-V.

  # Depends On
  depends_on = [ <resource_group_name>, <vnet_resource_group_name>, <vnet_name> ]
}
```

## Variable information (with examples)
```
# Required Variables

resource_group_name: This should be set to the resource group where cClear-V will be deployed.
  resource_group_name = "cpacket-inline-demo"

vnet_resource_group_name: This should be set to the resource group containing the virtual network that cClear-V will be attached to. This can be the same as resource_group_name.
  vnet_resource_group_name = "cpacket-inline-demo"

vnet_name: This should be set to the virtual network name of vnet_resource_group_name.
  vnet_name = "example-vnet"

subnet: This is the subnet within the virtual network cClear-V will use.
  subnet = "management"

image_id: This is ID of the image to use for creating the cClear-V.
  image_id = "/subscriptions/93004638-8c6b-4e33-ba58-946afd57efdf/resourceGroups/cloud-builds/providers/Microsoft.Compute/galleries/dev_builds/images/cclear-v/versions/24.1.603"

ssh_public_key: This is the public SSH key to be added to cClear-V for access.
  ssh_public_key = "~/.ssh/id_rsa.pub"

public_ip: A boolean value indicating whether to assign a public IP to cClear-V.
  public_ip = false

# Optional Variables

tags: This is a map with key and value tags to assign to resources.
  tags = {
    "owner" = "someone@example.com"
  }

ipv4_address: This is an IP address to assign to cClear-V.
  ipv4_address = "10.0.254.10"

size: This is the instance size of cClear-V.
  size = "Standard_D4s_v5"

storage_type_os: This is the type of storage account for the OS disk.
  storage_type_os = "Standard_LRS"

storage_type_data: This is the type of storage account for data disk(s). cClear-V must use premium storage to function correctly.
  storage_type_data = "Premium_LRS"

data_size: This is the size of the data disk(s) in GB.
  data_size = 500

admin_username: This is the admin username for cClear-V.
  admin_username = "ubuntu"

zones: This is a boolean value to indicate if cClear-V will be placed in an Availability Zone.
  zones = true

required_env_vars: This is a list of environment variables (CCLEARV_USERNAME and CCLEARV_PASSWORD) required for HTTP basic authentication.
  required_env_vars = ["CCLEARV_USERNAME", "CCLEARV_PASSWORD"]

resource_names: This is a map of resource names to be used for the resources to be created, including machine, management_nic, data_disk, and os_disk.
  resource_names= {
    machine        = "cclear"
    management_nic = "cclear-management"
    data_disk      = "cclear-data"
    os_disk        = "cclear-os"
  }

cloud_init_data: This is the cloud-init data that will be passed to the cClear-V.
  cloud_init_data = "scripts/cclear-cloud-init.tpl"

```
