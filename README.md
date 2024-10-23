# cPacket/Corelight observability network

> Terraform module to deploy cPacket and Corelight observability network

## Overview

This module deploys a cPacket and Corelight monitoring network in Azure.

![Monitoring network](/assets/images/Azure-monitoring-network.drawio)

## Usage

The `cpacket-corelight.auto.tfvars.example` is template `.tfvars` file.
Copy the `cpacket-corelight.auto.tfvars.example` file to `cpacket-corelight.auto.tfvars` and update the variables with your own values.


```bash
terraform init
terraform plan
terraform apply
```
