#!/bin/bash

TARGET_DIR="/opt/vault"
cd "$TARGET_DIR" || exit 1

# Creating .env file with container user/group for docker
C_UID=$(id -u vault) || exit 1
C_GID=$(id -g vault) || exit 1
cat <<EOF > .env
CONTAINER_UID=${C_UID}
CONTAINER_GID=${C_GID}
EOF
chown root:docker .env
chmod 0640 .env

#
# Generate the CA and Server certificates for the Vault
#
if [ ! -f "ca.key" ] && [ ! -f "ca.crt" ] && [ ! -f "vault.key" ] && [ ! -f "vault.crt" ]; then
    echo "Generating new Vault certificates..."
    # Generate CA Key and Root Certificate
    openssl ecparam -genkey -name prime256v1 -out ca.key
    openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt -subj "/O=Test Org/CN=Vault Root CA" -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign"

    # Generate Server certificate
    openssl ecparam -genkey -name prime256v1 -out vault.key
    openssl req -new -key vault.key -subj "/O=Test Org/CN=vault" | openssl x509 -req -CA ca.crt -CAkey ca.key -CAcreateserial -out vault.crt -days 365 -sha256 -extfile <(printf "subjectAltName=DNS:localhost,DNS:vault,IP:127.0.0.1\nbasicConstraints=CA:FALSE\nkeyUsage=digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth")
else
    echo "Vault certificates already exist. Skipping generation."
fi

chown vault:vault vault.key vault.crt ca.crt vault.hcl vault-trustee-policy.hcl
chmod 0600 vault.key

# Copy CA certificate to Trustee container
cp ca.crt /opt/trustee-kbs/vault-ca.crt
chown trustee:trustee /opt/trustee-kbs/vault-ca.crt

# Create local data directory for Vault and assign ownership
mkdir -p data
chown vault:vault data

# Start the Vault systemd service
systemctl daemon-reload
systemctl enable --now vault.service

# Wait for Vault API to become reachable, with 30s timeout
echo "Waiting for Vault to start..."
SECONDS=0
while ! curl -s --cacert ca.crt https://localhost:8200/v1/sys/health > /dev/null; do
    if [ "$SECONDS" -ge 30 ]; then
        echo "Error: Timeout reached after 30 seconds."
        exit 1
    fi
    sleep 2
done

# Check if Vault needs initialization
INIT_STATUS=$(docker exec vault vault status -format=json | jq -r '.initialized')

if [ "$INIT_STATUS" == "false" ]; then
    echo "Initializing Vault..."
    
    # POC only    
    # Initialize Vault with only 1 key share and store locally
    docker exec vault vault operator init -key-shares=1 -key-threshold=1 -format=json > vault-keys.json
    chmod 0600 vault-keys.json
    UNSEAL_KEY=$(jq -r '.unseal_keys_b64[0]' vault-keys.json)
    ROOT_TOKEN=$(jq -r '.root_token' vault-keys.json)

    echo "Unsealing Vault..."
    docker exec vault vault operator unseal "$UNSEAL_KEY"

    echo "Enabling Secrets engine in Vault..."
    docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault secrets enable -path=secret-v1/default -version=1 kv

    echo "Injecting workload key into Vault via stdin..."
    echo -n "$WORKLOAD_KEY" | docker exec -i -e VAULT_TOKEN="$ROOT_TOKEN" vault vault kv put secret-v1/default/workload_key/1 data=-

    echo "Applying Trustee Policy..."
    docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault policy write trustee-policy /vault/config/vault-trustee-policy.hcl

    echo "Generating Vault access token for Trustee..."
    TRUSTEE_TOKEN=$(docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault token create -policy=trustee-policy -format=json | jq -r '.auth.client_token')

    # Inject Vault Access Token into Trustee config    
    if [ -n "$TRUSTEE_TOKEN" ] && [ "$TRUSTEE_TOKEN" != "null" ]; then
        echo "Injecting token into kbs-config.toml..."
        sed -i "s/VAULT_TOKEN_PLACEHOLDER/$TRUSTEE_TOKEN/g" /opt/trustee-kbs/kbs-config.toml
    else
        echo "ERROR: Failed to generate Trustee token from Vault!"
        exit 1
    fi
else
    echo "Vault is already initialized. Ensure it is unsealed."
    if [ -f "vault-keys.json" ]; then
        UNSEAL_KEY=$(jq -r '.unseal_keys_b64[0]' vault-keys.json)
        docker exec vault vault operator unseal "$UNSEAL_KEY"
    fi
fi