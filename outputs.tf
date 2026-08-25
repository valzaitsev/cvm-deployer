# Print out the workload VM's public IP once done provisioning
output "cvm_public_ip" {
  value = azurerm_public_ip.cvm_poc_pubIP.ip_address
}

# Print out the Key Broker Serice VM public IP
output "cvm_kbs_public_ip" {
  value = azurerm_public_ip.cvm_poc_kbs_pubIP.ip_address
}

# Output the storage account details
output "storage_account_name" {
  value = azurerm_storage_account.cvm_poc_storage.name
}

output "storage_container_name" {
  value = azurerm_storage_container.cvm_poc_models_container.name
}