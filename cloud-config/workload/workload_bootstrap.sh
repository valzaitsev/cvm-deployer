#!/bin/bash

TARGET_DIR="/opt/cvm_workload"
cd "$TARGET_DIR" || exit 1

# Creating .env file with 
#  - container users/groups for docker
#  - KBS server address
#  - Size of secure tmpfs partition
#  - Owner group id of /dev/tpmrm0 device (TPM Resource Manager - used for evidence collection & key exchange / attestation in kbs-client)
#  - Azure storage account name for encrypted model
#  - Azure storage container name for encrypted model
#  - LLM Model name
KBSCLIENT_UID=$(id -u kbsclient) || exit 1
KBSCLIENT_GID=$(id -g kbsclient) || exit 1
TPMRM_GID=$(stat -c %g /dev/tpmrm0) && [ "${TPMRM_GID}" -ne 0 ] || exit 1
VLLM_UID=$(id -u vllm) || exit 1
VLLM_GID=$(id -g vllm) || exit 1

cat <<EOF > .env
KBSCLIENT_UID=${KBSCLIENT_UID}
KBSCLIENT_GID=${KBSCLIENT_GID}
KBS_ADDRESS=${KBS_ADDRESS}
TPMRM_GID=${TPMRM_GID}

VLLM_UID=${VLLM_UID}
VLLM_GID=${VLLM_GID}
SECURE_TMPFS_SIZE=${SECURE_TMPFS_SIZE}

AZURE_STORAGE_ACCOUNT="${STORAGE_ACCOUNT_NAME}" 
AZURE_STORAGE_ACCOUNT_CONTAINER="${STORAGE_CONTAINER_NAME}" 
IMAGE_NAME="${IMAGE_NAME}"

MODEL_NAME="${MODEL_NAME}"
EOF
chown root:docker .env
chmod 0640 .env

# Download the KBS web certificate from the Azure Key Vault
echo "Waiting for azure login and KBS certificate download to succeed..."
SECONDS=0
LOGGED_IN=false
while true; do
    if [ "$SECONDS" -ge 600 ]; then
        echo "Error: Timeout reached after 600 seconds."
        exit 1
    fi
    if [ "$LOGGED_IN" = false ]; then
        LOGIN_OUTPUT=$(az login --identity 2>&1)
        if [ $? -ne 0 ]; then
            echo "[$SECONDS s] az login failed. Error: $LOGIN_OUTPUT"
            echo "Retrying in 2 seconds..."
            sleep 2
            continue
        else
            echo "[$SECONDS s] az login successful!"
            LOGGED_IN=true
        fi
    fi
    KV_OUTPUT=$(az keyvault secret download --vault-name "$KEYVAULT_NAME" --name "$CERT_NAME" --query "value" --output tsv --overwrite --file ./kbs.crt)
    if [ $? -eq 0 ]; then
        if grep -q "PLACEHOLDER" ./kbs.crt; then
            echo "[$SECONDS s] Certificate is still the PLACEHOLDER. KBS VM has not uploaded it yet. Retrying in 10 seconds..."
            sleep 10
            continue
        fi
        
        echo "[$SECONDS s] Certificate successfully downloaded from Key Vault!"
        break
    else
        echo "[$SECONDS s] Key Vault download failed. Error: $KV_OUTPUT"
        echo "Retrying in 2 seconds..."
        sleep 2
    fi
done

echo "Copying Microsoft PGP key for use in a docker container for Azure tools..."
cp /etc/apt/keyrings/microsoft.asc /opt/cvm_workload/

echo "Enabling Workload container via systemd..."
systemctl daemon-reload
systemctl enable cvm-workload.service
