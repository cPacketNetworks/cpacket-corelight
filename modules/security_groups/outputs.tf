output "nva_security_group_id" {
  value = azurerm_network_security_group.nva.id
}

output "corelight_security_group_id" {
  value = azurerm_network_security_group.corelight.id
}