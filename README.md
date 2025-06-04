# cPacket/Corelight observability network

> Terraform module to deploy cPacket and Corelight observability network

## Overview

This module deploys a cPacket and Corelight monitoring network in Azure.

![Monitoring network](/assets/images/cpacket-corelight.png)

A dedicated VNET is created that will contain the cPacket and Corelight VMs.
There is a management subnet that will contain cClear, and the capture subnet that contains the cVu and Corelight VM Scale Sets.

Security groups are created to allow management traffic between the VMs and the internet.
The Azure Gateway Load Balancer is created to receive traffic from chained VMs or public load balancers in other VNETs.

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

### Deploy the cPacket and Corelight monitoring network

First run plan to see what resources will be created.

```bash
terraform plan
```

Then run apply to create the resources.

```bash
terraform apply
```
