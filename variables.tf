# Admin username for the Confidential VM
# for later reference
variable "cvm_poc_admin_username" {
  type    = string
  default = "poc-admin-user"
}

# Admin SSH public key for the Confidential VM
# for later reference
variable "cvm_poc_admin_ssh_pubkey_path" {
  type    = string
  default = "~/.ssh/id_rsa.pub" # UPDATE to actual public key path!
}

# Secure tmpfs partition size for the temp decrypted model storage before it is loaded into the GPU
variable "secure_tmp_partition_size" {
  type = string
  default = "120G"
}

variable "workload_model_name" {
  type = string
  default = "Qwen/Qwen3.8-27B"
}

variable "azure_storage_container_name" {
  type = string
  default = "models"
}

variable "encrypted_image_name" {
  type = string
  default = "model.img"
}

# POC - not needed. Nvidia allows requests without it for testing.
# Nvidia attestation API key
#variable "nv_attestation_apikey" {
#  type = string
#  description = "Nvidia attestation API key"
#  sensitive = true
#}

# POC only:
# Workload key injection into the HashiCorp Vault
# Key will be exposed to VM via cloud-init and logged in user-data.txt
# For production: load that key externally to the HashiCorp Vault
variable "workload_key" {
  type        = string
  sensitive   = true
  description = "Workload key to be injected into Vault for the KBS client"
}