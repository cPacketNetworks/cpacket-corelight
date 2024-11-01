resource "azurerm_virtual_network" "capture" {
  name                = "cpacket-corelight"
  address_space       = [var.vnet_cidr]
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  tags                = var.tags
}

resource "azurerm_subnet" "capture" {
  name                 = "capture"
  resource_group_name  = var.resource_group.name
  virtual_network_name = azurerm_virtual_network.capture.name
  address_prefixes     = [var.capture_subnet.cidr]
}

resource "azurerm_subnet" "management" {
  name                 = "management"
  resource_group_name  = var.resource_group.name
  virtual_network_name = azurerm_virtual_network.capture.name
  address_prefixes     = [var.management_subnet.cidr]
}