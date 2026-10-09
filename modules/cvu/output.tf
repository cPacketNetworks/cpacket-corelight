output "custom_data" {
  value = azurerm_linux_virtual_machine_scale_set.cvu.custom_data
}

output "lb_capture_private_ip" {
  value = azurerm_lb.cvu.frontend_ip_configuration[0].private_ip_address
}

output "lb_capture_frontend_id" {
  value = azurerm_lb.cvu.frontend_ip_configuration[0].id
}

output "lb_management_private_ip" {
  value = var.dual_nic ? azurerm_lb.cvu.frontend_ip_configuration[1].private_ip_address : null
}

output "cvu_primary_nic_private_ips" {
  value = data.azurerm_virtual_machine_scale_set.cvu.instances[*].private_ip_address
}

output "gwlb_id" {
  value = var.gwlb ? azurerm_lb.cvu.frontend_ip_configuration[0].id : null
}

output "vmss_name" {
  value = azurerm_linux_virtual_machine_scale_set.cvu.name
}

output "image_id" {
  description = "The custom image ID used, or null if using marketplace image"
  value       = var.image_id
}