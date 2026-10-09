# cPacket/Corelight observability network

> Terraform module to deploy cPacket and Corelight observability network

## Overview

This module deploys a cPacket and Corelight monitoring network in Azure.

![Monitoring network](/assets/images/cpacket-corelight.png)

A dedicated VNET is created that will contain the cPacket and Corelight VMs.
There is a management subnet that will contain cClear, and the capture subnet that contains the cVu and Corelight VM Scale Sets.

You supply the network security groups for the capture and management subnets; see [Network security groups](#network-security-groups).
The Azure Gateway Load Balancer is created to receive traffic from chained VMs or public load balancers in other VNETs.

The cVu-V and cClear-V modules in `modules/` are reusable components; see [Using the cVu-V and cClear-V modules elsewhere](#using-the-cvu-v-and-cclear-v-modules-elsewhere).

## Deployment architecture

![Deployment architecture](/assets/cpacket-corelight-deployment.png)

The diagram shows the resources that `terraform apply` creates and the three kinds of traffic between them:

- **Inspected traffic** arrives at the Gateway Load Balancer from a client public load balancer chained to it, and is tunnelled over VXLAN to the cVu-V scale set and back.
- **Mirrored traffic** is the copy that cVu-V sends over VXLAN (VNI 1337) to the Corelight sensors' internal load balancer.
- **Management traffic** covers admin access to cClear-V, cClear-V managing cVu-V, cVu-V sending its statistics to cClear-V, load balancer health probes, and outbound internet access through the NAT gateway.

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

```bash
terraform init
```

### Images

cVu-V and cClear-V use cPacket's Azure Marketplace images (BYOL) by default, at `cvu_mp_version` and `cclear_mp_version` (both default to `latest`).
Accept the Marketplace terms once in each subscription before the first deployment:

```bash
az vm image terms accept --publisher cpacketnetworks1719269615814 --offer cpacket-cvu-v --plan cvu_v_byol
az vm image terms accept --publisher cpacketnetworks1719269615814 --offer cpacket-cclear-v --plan cclear_v_byol
```

To use your own images instead, set `cvu_image_id` and `cclear_image_id`.
The cClear-V module attaches cClear-V's data disk after the VM has started.
Older cClear-V images expected the disk to be present at first boot, so use the current Marketplace release or a recent cClear-V release.

The Corelight sensor image is always set with `corelight_image_id`.

### Ubuntu in place of Corelight

If there is no valid Corelight license available, an Ubuntu machine can stand in for the Corelight system, so that the rest of the deployment can still be built and tested.
Set `ubuntu = true`; `corelight_image_id`, `corelight_license_key_path` and `corelight_sensor_community_string` are then not needed.
The Ubuntu module, `modules/ubuntu`, mirrors the Corelight sensor module's layout: an internal load balancer in the capture subnet that cVu-V mirrors traffic to, a scale set of the latest Ubuntu LTS behind it, and the NAT gateway on the management subnet.
cloud-init gives each VM a VXLAN interface, `vxlan1337`, that receives the mirrored traffic (VNI 1337, UDP 4789) and does nothing else with it.
Watch it with `sudo tcpdump -ni vxlan1337`, logged in as `corelight` with the SSH key in `ssh_public_key_file`.
Each VM has one NIC, in the capture subnet, so reach it from inside the VNet, for example through cClear-V.

### Network security groups

This module does not create network security groups.
Create two before deploying, in the same region as the deployment, and set their resource IDs in `capture_security_group_id` and `management_security_group_id`.
They must be in a resource group that already exists, not the one this module creates.
You can use the same group for both if its rules suit both.

The groups are attached to the capture and management subnets, so they apply to every NIC in those subnets, including the Corelight sensors'.
The `gwlb` subnet holds only the Gateway Load Balancer's frontend and has no group.

Azure's default rules allow all traffic within the VNet, the load balancer health probes, and all outbound traffic.
If you keep them, add only the inbound rules for traffic from outside the VNet, such as admin access to cClear-V.
cClear-V's public IP, when `cclear_public_ip = true`, is reachable only through a rule that allows it.
If you replace the defaults with your own deny rules, the groups must allow at least:

| Group | Inbound | Outbound |
| --- | --- | --- |
| `capture_security_group_id` | UDP 10800 and 10801 from the Gateway Load Balancer to cVu-V (VXLAN tunnels)<br>UDP 4789 from cVu-V to the Corelight load balancer and sensors (mirrored traffic)<br>TCP 443 from cClear-V to cVu-V<br>Health probes from `AzureLoadBalancer`: TCP 443 to cVu-V, TCP 41080 to the Corelight sensors (TCP 22 to the Ubuntu VMs, when `ubuntu = true`) | UDP 10800 and 10801 to the Gateway Load Balancer<br>UDP 4789 to the Corelight load balancer<br>TCP 8086 (statistics) and 443 to cClear-V |
| `management_security_group_id` | TCP 22 (SSH) and 443 (HTTPS) from your admin addresses to cClear-V<br>TCP 8086 and 443 from cVu-V to cClear-V<br>TCP 22 to the Corelight sensors through their load balancer<br>Health probes from `AzureLoadBalancer`: TCP 22 to the Corelight sensors | TCP 443 to cVu-V<br>The internet, through the NAT gateway, for the Azure API, licensing, and the Corelight sensors |

### Availability zones and instance count

By default (`zones = true`), cVu-V instances are spread across Availability Zones 1 to 3, and cClear-V is placed in zone 1.
Set `zones = false` in a region without Availability Zones.

`cvu_scaling` defaults to a fixed size of 3 cVu-V instances (`min_count`, `max_count` and `default_count` are all 3).
If `min_count` and `max_count` differ, the scale set autoscales on its total outbound traffic: it adds an instance above 4 Gbps and removes one below 4 Gbps.
Because both rules use the same threshold, it tends to swing between the minimum and the maximum, and each scale-in breaks the connections passing through the removed instance.

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

### Chain your public load balancers to the Gateway Load Balancer

Traffic reaches cVu-V only after a public load balancer's frontend is chained to the Gateway Load Balancer, `cpacket-corelight`.
`scripts/ccloud-azure-gwlb` chains every public load balancer that has a given tag, using the Azure CLI:

```bash
scripts/ccloud-azure-gwlb --tag KEY=VALUE chain --gwlb cpacket-corelight
```

The script is a copy of the `ccloud-azure-gwlb` tool from cPacket's cloud tools.
Run `scripts/ccloud-azure-gwlb --help` for its other commands, such as `unchain`.

## Using the cVu-V and cClear-V modules elsewhere

`modules/cvu` and `modules/cclear` are reusable, and other Terraform configurations can use them straight from this repository.
Pin a release tag with `?ref=`:

```hcl
module "cvu" {
  source = "github.com/cPacketNetworks/cpacket-corelight//modules/cvu?ref=v1.0.0"
  # ...
}

module "cclear" {
  source = "github.com/cPacketNetworks/cpacket-corelight//modules/cclear?ref=v1.0.0"
  # ...
}
```

Each module's `README.MD` lists its inputs, and this repository's `main.tf` is a complete example.
The modules render cloud-init templates that the caller provides; `cloud-init/cvu.tpl` and `cloud-init/cclear.tpl` work with them.
The modules read the template and SSH key paths you pass relative to Terraform's working directory, so build them with `${path.module}`.
