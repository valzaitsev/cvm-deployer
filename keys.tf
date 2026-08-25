# Generate the KEK key in Azure Key Vault for disk encryption - Workload VM
resource "azurerm_key_vault_key" "cvm_poc_key_diskKEK" {
  name         = "cvm-poc-key-diskKEK"
  key_vault_id = azurerm_key_vault.cvm_poc_keyvault.id

  # RSA-HSM for Confidential VM
  key_type = "RSA-HSM"

  key_size = 4096
  key_opts = ["unwrapKey", "wrapKey"]

  # Secure Key Release policy for disk encryption KEK
  release_policy {
    json = jsonencode({
      version = "1.0.0"
      anyOf = [
        {
          authority = "https://sharedcus.cus.attest.azure.net"
          allOf = [
            {
              # Validating the attestation type
              # AMD SEV-SNP (Secure Encrypted Virtualization-Secure Nested Paging) 
              claim  = "x-ms-attestation-type"
              equals = "sevsnpvm"
            },
            {
              # Validating the compliance status
              # Presence of this claim in guest attestation token proves that the CVM is running on SEV-SNP host on Azure with platform version that Microsoft deems healthy.
              # (https://github.com/Azure/confidential-computing-cvm-guest-attestation/blob/main/cvm-guest-attestation.md)
              claim  = "x-ms-compliance-status"
              equals = "azure-compliant-cvm"
            },
            {
              # Checks that hardware debugging is not enabled on an AMD SEV-SNP 
              claim = "x-ms-sevsnpvm-is-debuggable"
              equals = "false"
            }
          ]
        }
      ]
    })
  }

  depends_on = [azurerm_role_assignment.cvm_poc_kv_admin_assignment]
}

# Generate the KEK key in Azure Key Vault for disk encryption - Key Broker Service VM
resource "azurerm_key_vault_key" "cvm_poc_kbs_key_diskKEK" {
  name         = "cvm-poc-kbs-key-diskKEK"
  key_vault_id = azurerm_key_vault.cvm_poc_keyvault.id

  # RSA-HSM for Confidential VM
  key_type = "RSA-HSM"

  key_size = 4096
  key_opts = ["unwrapKey", "wrapKey"]

  # Secure Key Release policy for disk encryption KEK
  release_policy {
    json = jsonencode({
      version = "1.0.0"
      anyOf = [
        {
          authority = "https://sharedcus.cus.attest.azure.net"
          allOf = [
            {
              # Validating the attestation type
              # AMD SEV-SNP (Secure Encrypted Virtualization-Secure Nested Paging) 
              claim  = "x-ms-attestation-type"
              equals = "sevsnpvm"
            },
            {
              # Validating the compliance status
              # Presence of this claim in guest attestation token proves that the CVM is running on SEV-SNP host on Azure with platform version that Microsoft deems healthy.
              # (https://github.com/Azure/confidential-computing-cvm-guest-attestation/blob/main/cvm-guest-attestation.md)
              claim  = "x-ms-compliance-status"
              equals = "azure-compliant-cvm"
            },
            {
              # Checks that hardware debugging is not enabled on an AMD SEV-SNP 
              claim = "x-ms-sevsnpvm-is-debuggable"
              equals = "false"
            }
          ]
        }
      ]
    })
  }

  depends_on = [azurerm_role_assignment.cvm_poc_kv_admin_assignment]
}

# Create the Key Vault Secret to store the Trustee KBS web server certificate
resource "azurerm_key_vault_secret" "cvm_poc_kbs_cert" {
  name         = "cvm-poc-kbs-cert"
  value        = "PLACEHOLDER"
  key_vault_id = azurerm_key_vault.cvm_poc_keyvault_workload.id

  lifecycle {
    ignore_changes = [value, tags]
  }

  depends_on = [
    time_sleep.cvm_poc_workload_kv_wait
  ]
}
