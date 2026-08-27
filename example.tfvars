# COPY THIS FILE TO terraform.tfvars AND FILL IN YOUR SECRETS
# DO NOT COMMIT terraform.tfvars TO VERSION CONTROL

cvm_poc_admin_username          = "your_admin_username_for_VMs"
cvm_poc_admin_ssh_pubkey_path   = "~/.ssh/your_ssh_public_key.pub"

ghcr_username                   = "your_github_username"
ghcr_token                      = "your_github_private_access_token_readonly"

azure_storage_container_name    = "your_azure_container_name_for_models"
encrypted_image_name            = "your_encrypted_model_image.img"
workload_key                    = "your_model_image_file_encryption_secret"

workload_model_name             = "Qwen/Qwen3.8-27B"