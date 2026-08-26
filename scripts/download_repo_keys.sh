#!/bin/bash

# This script downloads NVIDIA and Microsoft pgp keys needed to use their repositories

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
cd "$SCRIPT_DIR/.."

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey -o cloud-config/nvidia.asc
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc -o cloud-config/microsoft.asc
