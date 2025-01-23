output "gwlb_id" {
  value = azurerm_lb.gwlb.id
}

output "gwlb_frontend_config_id" {
  value = azurerm_lb.gwlb.frontend_ip_configuration[0].id
}