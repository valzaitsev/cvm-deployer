#!/bin/bash

TARGET_DIR="/opt/vault"
KEYS_FILE="/opt/vault/vault-keys.json"
CA_FILE="/opt/vault/ca.crt"

cd "$TARGET_DIR" || exit 1

echo "Waiting for Vault to unseal..."
SECONDS=0

while true; do
    if [ "$SECONDS" -ge 30 ]; then
        echo "Error: Timeout reached after 30 seconds."
        exit 1
    fi
    
    # Fetch the health JSON; hide connection errors while Vault is starting
    HEALTH_JSON=$(curl -s --cacert "$CA_FILE" https://localhost:8200/v1/sys/health 2>/dev/null)
    
    # Ensure we got a valid JSON response before parsing
    if [ -n "$HEALTH_JSON" ] && echo "$HEALTH_JSON" | jq -e . >/dev/null 2>&1; then
        INITIALIZED=$(echo "$HEALTH_JSON" | jq -r '.initialized')
        SEALED=$(echo "$HEALTH_JSON" | jq -r '.sealed')
        
        if [ "$INITIALIZED" != "true" ]; then
            echo "Vault is responding, but not initialized. Skipping unseal."
            exit 0
        fi
        
        if [ "$SEALED" == "false" ]; then
            echo "Vault is already unsealed. Skipping unseal."
            exit 0
        fi
        
        if [ "$INITIALIZED" == "true" ] && [ "$SEALED" == "true" ]; then
            echo "Vault is initialized and sealed. Proceeding with unseal..."
            break
        fi
    fi
    
    sleep 2
done

if [ ! -f "$KEYS_FILE" ]; then
    echo "Warning: $KEYS_FILE not found. Skipping unseal."
    exit 0
fi

if ! KEY1=$(jq -e -r '.unseal_keys_b64[0]' "$KEYS_FILE" 2>/dev/null); then
    echo "Error: $KEYS_FILE is invalid."
    exit 1
fi

if [ -z "$KEY1" ]; then
    echo "Error: Extracted unseal key is empty."
    exit 1
fi

docker exec vault vault operator unseal "$KEY1"