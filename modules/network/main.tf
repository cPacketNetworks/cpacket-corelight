resource "azurerm_virtual_network" "capture" {
  name                = var.vnet.name
  address_space       = [var.vnet.cidr]
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  tags                = var.tags
}

resource "azurerm_subnet" "capture" {
  name                 = var.capture_subnet.name
  resource_group_name  = var.resource_group.name
  virtual_network_name = azurerm_virtual_network.capture.name
  address_prefixes     = [var.capture_subnet.cidr]
}

resource "azurerm_subnet" "management" {
  name                 = var.management_subnet.name
  resource_group_name  = var.resource_group.name
  virtual_network_name = azurerm_virtual_network.capture.name
  address_prefixes     = [var.management_subnet.cidr]
}

resource "azurerm_subnet" "gwlb" {
  name                 = var.gwlb_subnet.name
  resource_group_name  = var.resource_group.name
  virtual_network_name = azurerm_virtual_network.capture.name
  address_prefixes     = [var.gwlb_subnet.cidr]
}
