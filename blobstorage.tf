
# Create the Storage Account
resource "azurerm_storage_account" "cvm_poc_storage" {
  # Must be globally unique, lowercase alphanumeric, max 24 chars
  name                     = "cvmpocstore${random_id.suffix.hex}"
  resource_group_name      = azurerm_resource_group.cvm_poc_rg.name
  location                 = azurerm_resource_group.cvm_poc_rg.location
  
  # Standard performance is sufficient, Hot tier avoids retrieval penalties
  account_tier             = "Standard"
  account_replication_type = "LRS"
  access_tier              = "Hot"
}

# Create a private Blob Container inside the Storage Account
resource "azurerm_storage_container" "cvm_poc_models_container" {
  name                  = "models"
  storage_account_id  = azurerm_storage_account.cvm_poc_storage.id
  container_access_type = "private"
}

# Grant the Workload VM's Managed Identity read access to the Blob Storage
resource "azurerm_role_assignment" "cvm_poc_vm_storage_assignment" {
  scope                = azurerm_storage_account.cvm_poc_storage.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_linux_virtual_machine.cvm_poc_vm.identity[0].principal_id
}

# Grant the admin permission to upload files to the Blob Storage
resource "azurerm_role_assignment" "cvm_poc_admin_storage_assignment" {
  scope                = azurerm_storage_account.cvm_poc_storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}
