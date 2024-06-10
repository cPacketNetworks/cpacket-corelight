output "resource_group" {
  value = azurerm_resource_group.capture.name
}

output "public_ubuntu_ip_address" {
  value = azurerm_public_ip.ubuntu.ip_address
}

output "gwlb_frontend_ip" {
  value = azurerm_lb.gwlb.frontend_ip_configuration[0].id
}
