#!/usr/bin/env bash

ACR_RESOURCE_GROUP_NAME="mbright-ubiquitous-cricket"
ACR_NAME="corelight"

# Create a resource group to store container registry
# az group create --name "$ACR_RESOURCE_GROUP_NAME" --location westus2

# Create a container registry that will be where you deploy your image to
az acr create --resource-group "$ACR_RESOURCE_GROUP_NAME" --name "$ACR_NAME" --sku Basic --admin-enabled
