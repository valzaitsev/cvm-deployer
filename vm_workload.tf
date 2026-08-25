# Confidential VM creation - Workload VM
resource "azurerm_linux_virtual_machine" "cvm_poc_vm" {
  name                = "cvm-poc-vm"
  resource_group_name = azurerm_resource_group.cvm_poc_rg.name
  location            = azurerm_resource_group.cvm_poc_rg.location

  # Standard_NCC40ads_H100_v5 includes 40 vCPUs (AMD EPYC Genoa) + 320 GiB RAM + Nvidia H100 NVL (94 Gb VRAM) GPU in confidential compute mode
  # Hardware based Trusted Execution Environment for both CPU and GPU
  # Quota is requested/approved manually outside of this terraform script
  size = "Standard_NCC40ads_H100_v5"

  # Defining the administrator user account with SSH public key access
  admin_username = var.cvm_poc_admin_username
  admin_ssh_key {
    username   = var.cvm_poc_admin_username
    public_key = file(var.cvm_poc_admin_ssh_pubkey_path)
  }

  # Removed because of extra software
  # Using the Confidential GPU VM image
  #source_image_id = "/communityGalleries/cgpuimage-db870bae-5bcf-4120-9415-b841adef61d3/images/CGPU-NCC-2204-base-image/versions/latest"
  #
  # Using clean Canonical CVM image
  source_image_reference {
    publisher = "canonical"
    offer     = "ubuntu-22_04-lts"
    sku       = "cvm"
    version   = "22.04.202608210" # pinned version
    #version   = "latest" # latest version
  }  

  # Enabling the Secure boot and vTPM - required for a Confidential VM type. The VM security type will be set to "Confidential" automatically.
  secure_boot_enabled = true
  vtpm_enabled        = true

  # Assign NIC to the VM
  network_interface_ids = [
    azurerm_network_interface.cvm_poc_nic.id
  ]

  # VM disk drive, encrypted with the Platform-managed key (option A), or with Customer-managed key (CMK) from the Key Vault (option B)
  os_disk {
    name                 = "cvm_poc_osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"

    disk_size_gb         = 100

    # Option A: Platform Managed Keys: encrypting the disk and the VM Guest State
    # only one line - encrypting Disk + Guest State
    #security_encryption_type = "DiskWithVMGuestState"

    # Option B: Customer managed key (CMK) from the Key Vault
    # still encrypting Disk + Guest State, 
    # but also referencing the Disk Encryption Set (DES) specifying further encryption requirements in the relevant section
    security_encryption_type         = "DiskWithVMGuestState"
    secure_vm_disk_encryption_set_id = azurerm_disk_encryption_set.cvm_poc_des.id
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
  user_data = sensitive(data.cloudinit_config.setup.rendered)

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
    time_sleep.cvm_poc_des_wait,
    azurerm_key_vault_secret.cvm_poc_kbs_cert,
    azurerm_linux_virtual_machine.cvm_poc_kbs_vm
    ]
}

# One time VM initialization scripts
locals {
  workload_vm_init_yaml = templatefile("${path.module}/cloud-config/cloud-config-workload.yaml.tftpl", {
    module_path = path.module
    ghcr_username = var.ghcr_username
    ghcr_token    = var.ghcr_token
    keyvault_name = azurerm_key_vault.cvm_poc_keyvault_workload.name
    cert_name = azurerm_key_vault_secret.cvm_poc_kbs_cert.name
    kbs_address = azurerm_network_interface.cvm_poc_kbs_nic.private_ip_address
    storage_account_name   = azurerm_storage_account.cvm_poc_storage.name
    storage_container_name = azurerm_storage_container.cvm_poc_models_container.name
    secure_tmp_partition_size = var.secure_tmp_partition_size
    model_name = var.workload_model_name
    encrypted_image_name = var.encrypted_image_name
  })
}

data "cloudinit_config" "setup" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = local.workload_vm_init_yaml
  }
}