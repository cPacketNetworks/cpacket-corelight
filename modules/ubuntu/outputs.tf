output "load_balancer_ip_address" {
  description = "Address cVu-V mirrors traffic to"
  value       = azurerm_lb.standin.frontend_ip_configuration[0].private_ip_address
}

output "scale_set_name" {
  value = azurerm_linux_virtual_machine_scale_set.standin.name
}
