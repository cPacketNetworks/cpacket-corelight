output "capture_virtual_network" {
  value = {
    name          = azurerm_virtual_network.capture.name
    id            = azurerm_virtual_network.capture.id
    address_space = element(tolist(azurerm_virtual_network.capture.address_space), 0)
    resource_group = {
      name     = azurerm_virtual_network.capture.resource_group_name
      location = azurerm_virtual_network.capture.location
    }
  }
}

output "capture_subnet" {
  value = {
    id   = azurerm_subnet.capture.id
    name = azurerm_subnet.capture.name
  }
}

output "management_subnet" {
  value = {
    id   = azurerm_subnet.management.id
    name = azurerm_subnet.management.name
  }
}

