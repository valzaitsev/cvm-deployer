# Create the Disk Encryption Set for a Confidential VM - Workload VM
resource "azurerm_disk_encryption_set" "cvm_poc_des" {
  name                = "cvm-poc-des"
  resource_group_name = azurerm_resource_group.cvm_poc_rg.name
  location            = azurerm_resource_group.cvm_poc_rg.location

  # Set the disk encryption KEK to the one we created above
  key_vault_key_id = azurerm_key_vault_key.cvm_poc_key_diskKEK.id

  # Setting disk encryption type to Confidential VM with CMK
  encryption_type = "ConfidentialVmEncryptedWithCustomerKey"

  identity {
    type = "SystemAssigned"
  }
}

# Create the Disk Encryption Set for a Confidential VM - Key Broker Service VM
resource "azurerm_disk_encryption_set" "cvm_poc_kbs_des" {
  name                = "cvm-poc-kbs-des"
  resource_group_name = azurerm_resource_group.cvm_poc_rg.name
  location            = azurerm_resource_group.cvm_poc_rg.location

  # Set the disk encryption KEK to the one we created above
  key_vault_key_id = azurerm_key_vault_key.cvm_poc_kbs_key_diskKEK.id

  # Setting disk encryption type to Confidential VM with CMK
  encryption_type = "ConfidentialVmEncryptedWithCustomerKey"

  identity {
    type = "SystemAssigned"
  }
}

# Grant the Disk Encryption Set permission to wrap/unwrap keys in the Key Vault - Workload VM
resource "azurerm_role_assignment" "cvm_poc_des_kv_assignment" {
  scope                = azurerm_key_vault.cvm_poc_keyvault.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_disk_encryption_set.cvm_poc_des.identity[0].principal_id
}

# Grant the Disk Encryption Set permission to wrap/unwrap keys in the Key Vault - Key Broker Service VM
resource "azurerm_role_assignment" "cvm_poc_kbs_des_kv_assignment" {
  scope                = azurerm_key_vault.cvm_poc_keyvault.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_disk_encryption_set.cvm_poc_kbs_des.identity[0].principal_id
}

# Wait for 30 seconds to allow the Entra ID role assignment to propagate globally - for Workload VM
resource "time_sleep" "cvm_poc_des_wait" {
  create_duration = "30s"

  depends_on = [
    azurerm_role_assignment.cvm_poc_des_kv_assignment,
    azurerm_role_assignment.cvm_orchestrator_release_assignment
  ]
}

# Wait for 30 seconds to allow the Entra ID role assignment to propagate globally - for Key Broker Service VM
# Separate because that VM is provisioned at later stage during development
resource "time_sleep" "cvm_poc_kbs_des_wait" {
  create_duration = "30s"

  depends_on = [
    azurerm_role_assignment.cvm_poc_kbs_des_kv_assignment,
    azurerm_role_assignment.cvm_orchestrator_release_assignment
  ]
}