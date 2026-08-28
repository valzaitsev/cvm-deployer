
# Confidential VM creation for Key Broker Service virtual machine
resource "azurerm_linux_virtual_machine" "cvm_poc_kbs_vm" {
  name                = "cvm-poc-kbs-vm"
  resource_group_name = azurerm_resource_group.cvm_poc_rg.name
  location            = azurerm_resource_group.cvm_poc_rg.location

  # Standard_DC2as_v6 = 2 x vCPU (AMD EPYC 9004 Genoa) + 8 GiB RAM
  # Confidential VM with AMD SEV-SNP technology 
  size = "Standard_DC2as_v6"

  # Defining the administrator user account with SSH public key access
  admin_username = var.cvm_poc_admin_username
  admin_ssh_key {
    username   = var.cvm_poc_admin_username
    public_key = file(var.cvm_poc_admin_ssh_pubkey_path)
  }

  # Confidential VM image
  source_image_reference {
    publisher = "canonical"
    offer = "ubuntu-22_04-lts"
    sku = "cvm"
    version   = "22.04.202608210" # pinned version
    #version   = "latest" # latest version
  }
  
  # Enabling the Secure boot and vTPM - required for a Confidential VM type. The VM security type will be set to "Confidential" automatically.
  secure_boot_enabled = true
  vtpm_enabled        = true

  # Assign NIC to the VM
  network_interface_ids = [
    azurerm_network_interface.cvm_poc_kbs_nic.id
  ]

  # Encrypted disk using the key from the Key Vault
  os_disk {
    name                 = "cvm_poc_kbs_osdisk"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"

    # Customer managed key (CMK) from the Key Vault
    security_encryption_type         = "DiskWithVMGuestState"
    secure_vm_disk_encryption_set_id = azurerm_disk_encryption_set.cvm_poc_kbs_des.id
  }

  # POC only - to turn off and deallocate the VM once created to save money
  #provisioner "local-exec" {
  #  command = "az vm deallocate --resource-group ${self.resource_group_name} --name ${self.name}"
  #}

  # Auto create an identity and assign principal_id to later use with Key Vault RBAC
  identity {
    type = "SystemAssigned"
  }

  # POC Only:
  # Enable managed Boot Diagnostics for troubleshooting
  # Enables a serial console for the VM in the Azure Portal
  boot_diagnostics {
    storage_account_uri = null
  }

  # Expose the workload encryption key info (Key Vault URL and Key Name)
  # to the admin user of the Confidential VM
  # For Secure Key Release of the workload KEK after the attestation 
  # of CPU and GPU from the VM
  user_data = sensitive(data.cloudinit_config.setup_KBS.rendered)

  # POC only:
  # Ignore changes to custom_data scripts to stop replacing the whole VM on updates
  lifecycle {
    ignore_changes = [
      custom_data,
      source_image_reference
    ]
  }

  # Ensure that the role assignment was created 
  # for the Disk Encryption Set to have access to the Key Vault 
  # BEFORE provisioning the VM
  # Plus waiting an artificial delay for a role assignment to complete
  depends_on = [
    time_sleep.cvm_poc_kbs_des_wait,
    azurerm_key_vault_secret.cvm_poc_kbs_cert
    ]
}

# One time VM initialization scripts
locals {
  kbs_vm_init_yaml = templatefile("${path.module}/cloud-config/cloud-config-kbs.yaml.tftpl", {
    module_path = path.module
    workload_key  = var.workload_key
    keyvault_name = azurerm_key_vault.cvm_poc_keyvault_workload.name
    cert_name = azurerm_key_vault_secret.cvm_poc_kbs_cert.name    
  })
}

data "cloudinit_config" "setup_KBS" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = local.kbs_vm_init_yaml
  }
}