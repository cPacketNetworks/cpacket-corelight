output "name" {
  description = "Virtual machine names created."
  value       = azurerm_linux_virtual_machine.cclear.name
}

output "id" {
  description = "Virtual machine names created."
  value       = azurerm_linux_virtual_machine.cclear.id
}

output "private_ip" {
  description = "The private ip address allocated for the resource."
  value       = azurerm_network_interface.cclear.private_ip_address
}

output "public_ip" {
  description = "The public ip address allocated for the resource."
  value       = var.public_ip ? data.azurerm_public_ip.cclear[0].ip_address : null
}

output "image_id" {
  description = "The custom image ID used, or null if using marketplace image"
  value       = var.image_id
}
