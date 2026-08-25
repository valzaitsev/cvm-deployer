# Create the Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "cvm_poc_logs" {
  name                = "cvm-poc-logs"
  location            = azurerm_resource_group.cvm_poc_rg.location
  resource_group_name = azurerm_resource_group.cvm_poc_rg.name
  sku                 = "PerGB2018"

  # POC only - keep retention short to save costs
  retention_in_days = 30
}

# Send Audit Logs from the Disk Encryption Key Vault to the Workspace
resource "azurerm_monitor_diagnostic_setting" "cvm_poc_kv_diag" {
  name                       = "kv-audit-logs"
  target_resource_id         = azurerm_key_vault.cvm_poc_keyvault.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.cvm_poc_logs.id

  # Enable the AuditEvent category
  enabled_log {
    category_group = "audit"
  }
}

# Send Audit Logs from the Workload Encryption Key Vault to the Workspace
resource "azurerm_monitor_diagnostic_setting" "cvm_poc_kv_workload_diag" {
  name                       = "kv-workload-audit-logs"
  target_resource_id         = azurerm_key_vault.cvm_poc_keyvault_workload.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.cvm_poc_logs.id

  # Enable the AuditEvent category
  enabled_log {
    category_group = "audit"
  }
}

# Create a Saved Query in the Log Analytics Workspace
# This query looks for any records showing access to the Key Vaults
resource "azurerm_log_analytics_saved_search" "cvm_poc_kv_audit_query" {
  name                       = "KeyVault-Audit"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.cvm_poc_logs.id
  category                   = "Security"
  display_name               = "Key Vault Audit Log"

  query = <<-EOF
    AzureDiagnostics
    | where ResourceProvider == "MICROSOFT.KEYVAULT"
    | project TimeGenerated, OperationName, identity_claim_appid_g, id_s, clientInfo_s, ResultSignature, ResultDescription
    | order by TimeGenerated desc
  EOF

  lifecycle {
      ignore_changes = [
        query
      ]
  }
}