# cPacket/Corelight observability network

> Terraform module to deploy cPacket and Corelight observability network

## Overview

This module deploys a cPacket and Corelight monitoring network in Azure.

![Monitoring network](/assets/images/cpacket-corelight.png)

A dedicated VNET is created that will contain the cPacket and Corelight VMs.
There is a management subnet that will contain cClear, and the capture subnet that contains the cVu and Corelight VM Scale Sets.

You supply the network security groups for cVu-V and cClear-V; see [Network security groups](#network-security-groups).
The Azure Gateway Load Balancer is created to receive traffic from chained VMs or public load balancers in other VNETs.

## Deployment architecture

![Deployment architecture](/assets/cpacket-corelight-deployment.png)

The diagram shows the resources that `terraform apply` creates and the three kinds of traffic between them:

- **Inspected traffic** arrives at the Gateway Load Balancer from a client public load balancer chained to it, and is tunnelled over VXLAN to the cVu-V scale set and back.
- **Mirrored traffic** is the copy that cVu-V sends over VXLAN (VNI 1337) to the Corelight sensors' internal load balancer.
- **Management traffic** covers admin access to cClear-V, cClear-V managing cVu-V, load balancer health probes, and outbound internet access through the NAT gateway.

The source is [`assets/cpacket-corelight-deployment.drawio`](/assets/cpacket-corelight-deployment.drawio).
The PNG also embeds it, so either file can be opened and edited in [draw.io](https://app.diagrams.net).

## Usage

Clone the repository and navigate to the `cpacket-corelight` directory.

```bash
git clone git@github.com:/terraform-azure.git
cd cpacket-corelight
```

The `cpacket-corelight.auto.tfvars.example` is a template for a `.tfvars` file.
Copy it and modify its values to suit your needs.

```bash
cp cpacket-corelight.auto.tfvars.example cpacket-corelight.auto.tfvars
```

### Initialize the Terraform configuration

The version of the Azure provider is pinned to `2.46.0` to avoid any breaking changes.

```bash
terraform init
```

### Network security groups

This module does not create network security groups.
Create them before deploying, in the same region as the deployment, and set their resource IDs in `cvu_security_group_id` and `cclear_security_group_id`.
They must be in a resource group that already exists, not the one this module creates.
You can use the same group for both if its rules suit both.

| Variable | Attached to | Rules this module used to create |
| --- | --- | --- |
| `cvu_security_group_id` | NIC of each cVu-V scale set instance | Allow all inbound and all outbound, as in [Microsoft's Gateway Load Balancer tutorial](https://learn.microsoft.com/en-us/azure/load-balancer/tutorial-gateway-portal#create-nsg). cVu-V receives VXLAN on UDP 10800 and 10801 from the Gateway Load Balancer, answers its HTTPS 443 health probe, and sends mirrored traffic on UDP 4789 to the Corelight load balancer. |
| `cclear_security_group_id` | cClear-V NIC | Allow inbound TCP 22 (SSH) and 443 (HTTPS), and all outbound. |

### Azure permissions

By default (`cclear_managed_registration = true`), cClear-V gets a system-assigned managed identity with the **Reader** role on the resource group.
cClear-V uses it to discover the cVu-V scale set's instances and register them.

Creating that role assignment requires the identity that runs Terraform to have `Microsoft.Authorization/roleAssignments/write`, for example through the **Owner** or **User Access Administrator** role.
**Contributor** alone is not enough, and `terraform apply` will fail when it creates the role assignment.

If you can't get that permission, set `cclear_managed_registration = false`.
cClear-V will then not discover or manage the cVu-V instances automatically.

### Deploy the cPacket and Corelight monitoring network

First run plan to see what resources will be created.

```bash
terraform plan
```

Then run apply to create the resources.

```bash
terraform apply
```
