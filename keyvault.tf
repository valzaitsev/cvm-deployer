# Create Azure Key Vault for the disk encryption key
resource "azurerm_key_vault" "cvm_poc_keyvault" {
  # Name should be globally unique and with total length < 24 chars - using random suffix created above
  name = "cvmpockv-${random_id.suffix.hex}"

  resource_group_name = azurerm_resource_group.cvm_poc_rg.name
  location            = azurerm_resource_group.cvm_poc_rg.location
  tenant_id           = data.azurerm_client_config.current.tenant_id

  # Premium level is needed for the Key Vault to support "advanced" key types
  # Premium level is also required for Confidential VM disk encryption
  sku_name = "premium"

  # Mark the Key Vault as available for disk encryption
  enabled_for_disk_encryption = true

  # Mark the Key Vailed as available for Compute resource provider to retrieve secrets from this key vault when creating a virtual machine
  enabled_for_deployment = true

  # RBAC method is the new standard in Azure since 2026-02-xx update, see role assignment below
  rbac_authorization_enabled = true

  # POC only - We can disable purge protection for the keys allowing them to be permanently deleted instantly.
  # This won't work if this key vault is used for disk encryption - Azure limitation.
  purge_protection_enabled = true

  # POC only - to keep costs down once the environment is destroyed, can use if purge protection is still required
  # Manual purge is still required to permanently remove a key within this period
  soft_delete_retention_days = 7
}

# Create Azure Key Vault for the workload encryption keys
resource "azurerm_key_vault" "cvm_poc_keyvault_workload" {
  # Name should be globally unique and with total length < 24 chars - using random suffix created above
  name = "cvmpockvwrk-${random_id.suffix.hex}"

  resource_group_name = azurerm_resource_group.cvm_poc_rg.name
  location            = azurerm_resource_group.cvm_poc_rg.location
  tenant_id           = data.azurerm_client_config.current.tenant_id

  # Premium level is needed for the Key Vault to support "advanced" key types
  # Premium level is also required for Confidential VM disk encryption
  sku_name = "premium"

  # RBAC method is the new standard in Azure since 2026-02-xx update, see role assignment below
  rbac_authorization_enabled = true

  # POC only - We can disable purge protection for the keys allowing them to be permanently deleted instantly.
  # This won't work if this key vault is used for disk encryption - Azure limitation.
  # Disabliong purge protection for POC to save costs
  purge_protection_enabled = false

  # POC only - to keep costs down once the environment is destroyed, can use if purge protection is still required
  # Manual purge is still required to permanently remove a key within this period
  #soft_delete_retention_days = 7
}

# Assign RBAC Secrets User role for the Workload VM's identity to let it access the Key Vault to get the KBS certificate
resource "azurerm_role_assignment" "cvm_poc_vm_keyavult_assignment" {
  scope                = azurerm_key_vault.cvm_poc_keyvault_workload.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.cvm_poc_vm.identity[0].principal_id
}

# Assign RBAC Secrets Officer role for the Trustee KBS VM's identity to let it access the Workload Key Vault to store the KBS certificate
resource "azurerm_role_assignment" "cvm_poc_kbs_vm_keyavult_assignment" {
  scope                = azurerm_key_vault.cvm_poc_keyvault_workload.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azurerm_linux_virtual_machine.cvm_poc_kbs_vm.identity[0].principal_id
}

# Grant the Crypto Officer role to ourselves to create a key in the Disk Encryption Key Vault
resource "azurerm_role_assignment" "cvm_poc_kv_admin_assignment" {
  scope                = azurerm_key_vault.cvm_poc_keyvault.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Grant the Crypto Officer role to ourselves to create a secret in the Workload Encryption Key Vault
resource "azurerm_role_assignment" "cvm_poc_kv_admin_assignment_workload" {
  scope                = azurerm_key_vault.cvm_poc_keyvault_workload.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Wait for 60s for Crypto Secrets Officer role to propagate
resource "time_sleep" "cvm_poc_workload_kv_wait" {
  create_duration = "60s"
  depends_on = [
    azurerm_role_assignment.cvm_poc_kv_admin_assignment_workload
  ]
}

# Get the built-in Microsoft Confidential VM Orchestrator
resource "azuread_service_principal" "cvm_orchestrator" {
  # Application ID for the Confidential VM Orchestrator is predefined by MS
  client_id    = "bf7b6499-ff71-4aa2-97a4-f372087be7f0"
  use_existing = true
}

# Grant the CVM Orchestrator permission to securely release keys during VM boot
resource "azurerm_role_assignment" "cvm_orchestrator_release_assignment" {
  scope                = azurerm_key_vault.cvm_poc_keyvault.id
  role_definition_name = "Key Vault Crypto Service Release User"
  principal_id         = azuread_service_principal.cvm_orchestrator.object_id
}
