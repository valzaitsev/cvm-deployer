#!/bin/bash

TARGET_DIR="/opt/trustee-kbs"
cd "$TARGET_DIR" || exit 1

# Creating .env file with container user/group for docker
C_UID=$(id -u trustee) || exit 1
C_GID=$(id -g trustee) || exit 1
cat <<EOF > .env
CONTAINER_UID=${C_UID}
CONTAINER_GID=${C_GID}
EOF
chown root:docker .env
chmod 0640 .env

# Fetch the primary internal IP from Azure IMDS
INTERNAL_IP=$(curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/privateIpAddress?api-version=2021-02-01&format=text")

# Fallback to standard Linux networking if IMDS is empty
if [ -z "$INTERNAL_IP" ]; then
    INTERNAL_IP=$(hostname -I | awk '{print $1}')
fi

# Generate the self-signed KBS certificate for web
echo "Generating Trustee KBS web certificate..."
if [ ! -f "kbs.key" ] && [ ! -f "kbs.crt" ]; then
    openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
        -keyout kbs.key -out kbs.crt \
        -subj "/CN=${INTERNAL_IP}" \
        -addext "subjectAltName=IP:${INTERNAL_IP}" \
        -addext "basicConstraints=CA:FALSE"

    # Upload the KBS certificate to the Azure Key Vault
    echo "Waiting for azure login and KBS certificate upload to succeed..."
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
        KV_OUTPUT=$(az keyvault secret set \
            --vault-name "$KEYVAULT_NAME" \
            --name "$CERT_NAME" \
            --file kbs.crt 2>&1)
        if [ $? -eq 0 ]; then
            echo "[$SECONDS s] Certificate successfully uploaded to Key Vault!"
            break
        else
            echo "[$SECONDS s] Key Vault upload failed. Error: $KV_OUTPUT"
            echo "Retrying in 2 seconds..."
            sleep 2
        fi
    done
else
    echo "KBS certificates already exist. Skipping generation."
fi

#
# Generate the CA and Token Signer certificates for the Attestation Service
#
echo "Generating Trustee CA and Token Signer certificates..."
if [ ! -f "ca.key" ] && [ ! -f "ca.crt" ] && [ ! -f "token_signer.key" ] && [ ! -f "token_signer.crt" ] && [ ! -f "token_signer.csr" ]; then
    # CA:
    openssl ecparam -genkey -name prime256v1 -out ca.key
    openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt -subj "/O=Confidential Containers/CN=Trustee Root CA"
    # Token signer:
    openssl ecparam -genkey -name prime256v1 -out token_signer.key
    openssl req -new -key token_signer.key -out token_signer.csr -subj "/O=Confidential Containers/CN=Trustee Token Signer"
    openssl x509 -req -in token_signer.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out token_signer.crt -days 365 -sha256
    rm token_signer.csr
else
    echo "Trustee CA or Token Signer certificates certificates already exist. Skipping generation."
fi

# Build the certificate chain
cat token_signer.crt > token_signer_chain.crt
cat ca.crt >> token_signer_chain.crt

chown trustee:trustee kbs-config.toml *.rego *.crt *.key
chmod 0600 *.key

# Create the local repository directory and assign permissions
mkdir -p repository/kbs
mkdir -p repository/attestation_service_policy
chown -R trustee:trustee repository

systemctl daemon-reload
systemctl enable --now trustee-kbs.service