#!/bin/bash
# Exit on error, undefined variable, or pipe failure
set -euo pipefail

# --- ADD YOUR HuggingFace TOKEN HERE (or leave empty for slower speeds)---
HF_TOKEN=""

# Model to download
HF_MODEL="Qwen/Qwen3.8-27B"

# Volume image size (must fit the model)
IMG_SIZE="75G"

# Volume image file name
IMG_NAME="model.img"

##############################################################################################################

cleanup() {
    local exit_code=$?
    echo -e "\n[Cleanup] Running cleanup tasks..." 
    if mountpoint -q /tmp/model_mount; then
        echo "[Cleanup] Unmounting /tmp/model_mount..."
        sudo umount /tmp/model_mount || true
    fi
    if sudo cryptsetup status local_model_vol &>/dev/null; then
        echo "[Cleanup] Closing LUKS volume local_model_vol..."
        sudo cryptsetup luksClose local_model_vol || true
    fi
    if [[ "${VIRTUAL_ENV:-}" != "" ]]; then
        echo "[Cleanup] Deactivating virtual environment..."
        deactivate || true
    fi
    if [ $exit_code -ne 0 ]; then
        echo -e "\nScript failed or was interrupted (Exit code: $exit_code)."
    else
        echo -e "\nScript completed successfully."
    fi
    exit $exit_code
}
trap cleanup EXIT INT TERM

echo "Installing required packages..."
sudo apt-get update -qq && sudo apt-get install -y -qq python3-venv python3-full python3-pip cryptsetup

echo "Running pre-checks..."
for cmd in sudo cryptsetup fallocate mkfs.ext4 python3 pip3; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Required command '$cmd' is not installed."
        exit 1
    fi
done

if [[ -d "./model" && -n "$(ls -A ./model 2>/dev/null)" ]]; then
    echo "Error: Directory ./model exists and is not empty. Please clean up and start again."
    exit 1
fi

if [[ -f "$IMG_NAME" ]]; then
    echo "Error: File $IMG_NAME already exists. Please remove it and start again."
    exit 1
fi

while true; do
    secret_var=""
    while [[ -z "$secret_var" ]]; do
        read -sp "Enter model encryption secret: " secret_var
        echo
        [[ -z "$secret_var" ]] && echo "Error: Input cannot be blank."
    done

    read -sp "Confirm model encryption secret: " confirm_var
    echo

    if [[ "$secret_var" == "$confirm_var" ]]; then
        break
    else
        echo "Error: Secrets do not match! Try again."
        echo
    fi
done

echo "Setting up Python virtual environment..."
python3 -m venv .hf_venv

source .hf_venv/bin/activate

echo "Installing HuggingFace..."
pip3 install -U "huggingface_hub" --quiet

echo "Downloading model ($HF_MODEL)..."
if [[ -n "${HF_TOKEN//[[:space:]]/}" ]]; then
    hf download "$HF_MODEL" \
        --local-dir ./model \
        --token "$HF_TOKEN"
else
    hf download "$HF_MODEL" \
        --local-dir ./model
fi

echo "Cleaning up virtual environment..."
deactivate
rm -rf .hf_venv

echo "Creating $IMG_SIZE disk image..."
# Fallback to dd if fallocate fails (e.g., on certain filesystems/WSL)
fallocate -l "$IMG_SIZE" "$IMG_NAME" || dd if=/dev/zero of="$IMG_NAME" bs=1M count=$(numfmt --from=iec "$IMG_SIZE" | awk '{print $1/1048576}')

echo "Encrypting image with LUKS..."
echo -n "$secret_var" | sudo cryptsetup luksFormat --type luks2 "$IMG_NAME" -

echo "Unlocking temporary volume..."
echo -n "$secret_var" | sudo cryptsetup luksOpen "$IMG_NAME" local_model_vol -d -

echo "Wiping free space to obscure disk usage (this will take a few minutes)..."
echo "Please ignore the ""No space left on device"" error - this is expected behavior."
sudo dd if=/dev/zero of=/dev/mapper/local_model_vol bs=1M status=progress || true

echo "Formatting inside of LUKS volume..."
sudo mkfs.ext4 /dev/mapper/local_model_vol

echo "Mounting volume..."
mkdir -p /tmp/model_mount
sudo mount /dev/mapper/local_model_vol /tmp/model_mount

echo "Copying weights into encrypted drive..."
sudo cp -r ./model/* /tmp/model_mount/

echo "Applying permissions (root:root, folders 0700, files 0400)..."
sudo chown -R root:root /tmp/model_mount
sudo find /tmp/model_mount -type d -exec chmod 0700 {} +
sudo find /tmp/model_mount -type f -exec chmod 0400 {} +

echo "Locking drive..."
sudo umount /tmp/model_mount
sudo cryptsetup luksClose local_model_vol

# Uncomment to remove unencrypted model data automatically
# rm -rf ./model

echo "Success! $IMG_NAME is ready to be uploaded."