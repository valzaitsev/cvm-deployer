# COPY THIS FILE TO terraform.tfvars AND FILL IN YOUR SECRETS
# DO NOT COMMIT terraform.tfvars TO VERSION CONTROL

ghcr_username                   = "your_github_username"
ghcr_token                      = "your_github_private_access_token_readonly"

cvm_poc_admin_username          = "your_admin_username_for_VMs"
cvm_poc_admin_ssh_pubkey_path   = "~/.ssh/your_ssh_public_key.pub"

workload_key                    = "your_model_image_file_encryption_secret"