output "capture_virtual_network" {
  value = {
    name : azurerm_virtual_network.capture.name
    id : azurerm_virtual_network.capture.id
    address_space : azurerm_virtual_network.capture.address_space[0]
  }
}

output "capture_subnet" {
  value = {
    id : azurerm_subnet.capture.id
  }
}

output "management_subnet" {
  value = {
    id : azurerm_subnet.management.id
  }
}