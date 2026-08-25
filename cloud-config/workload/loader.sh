#!/bin/bash
set -e

LOOP_DEV=""
cleanup() {
  echo "[Loader] Executing cleanup routine..."

  echo "[Loader] Terminating background processes..."
  JOBS=$(jobs -p)
  if [ -n "$JOBS" ]; then
    kill $JOBS || true
  fi

  sleep 1

  if mountpoint -q /mnt/luks_temp; then
    umount -l /mnt/luks_temp || echo "Warning: Failed to unmount /mnt/luks_temp"
  fi

  if [ -b "/dev/mapper/secure_luks_model" ]; then
    cryptsetup luksClose secure_luks_model || echo "Warning: Failed to close LUKS volume"
  fi

  if [ -n "$LOOP_DEV" ]; then
    losetup -d "$LOOP_DEV" || echo "Warning: Failed to detach $LOOP_DEV"
  fi

  if mountpoint -q /mnt/encrypted; then
    umount -l /mnt/encrypted || echo "Warning: Failed to unmount Azure Blobfuse"
  fi
}

trap cleanup EXIT

echo "[Loader] Waiting for KBS client semaphore (up to 60 seconds)..."
SECONDS=0
while [ ! -f "/keys/model.key.ready" ] && [ $SECONDS -lt 60 ]; do
  sleep 1
done

if [ ! -f "/keys/model.key.ready" ]; then
  echo "Error: Timeout. KBS client did not finish within 60 seconds! Exiting..."
  exit 1
fi

echo "[Loader] Semaphore detected! Validating key..."

# Validate the file isn't empty
if [ ! -s "/keys/model.key" ]; then
  echo "Error: Semaphore exists but key file is empty! Exiting..."
  exit 1
fi

echo "[Loader] Mounting encrypted model from Azure blob storage..."
mkdir -p /mnt/encrypted
touch /var/log/blobfuse2.log

blobfuse2 mount /mnt/encrypted --config-file=/blobfuse2-config.yml --read-only
echo "[Loader] Azure blob storage mounted. Files list for /mnt/encrypted:"
ls -l /mnt/encrypted

echo "[Loader] Attaching $IMAGE_NAME to a loop device..."
LOOP_DEV=$(losetup -r --show -f /mnt/encrypted/"$IMAGE_NAME")
echo "[Loader] Successfully attached to $LOOP_DEV"

echo "[Loader] Unlocking LUKS volume..."
cat /keys/model.key | cryptsetup luksOpen "$LOOP_DEV" secure_luks_model --readonly -d -
rm -f /keys/model.key /keys/model.key.ready
mkdir -p /mnt/luks_temp
mount  -t ext4 -o ro,noload /dev/mapper/secure_luks_model /mnt/luks_temp

echo "[Loader] Successfully mounted LUKS volume. Contents:"
ls -l /mnt/luks_temp

echo "[Loader] Copying model files to a secure RAM disk..."
mkdir -p /mnt/secure_tmp/model
rsync -a --chmod=D500,F400 /mnt/luks_temp/ /mnt/secure_tmp/model/ &
COPY_PID=$!

TARGET_SIZE=$(du -sh /mnt/luks_temp 2>/dev/null | cut -f1 || echo "0")

SECONDS=0
while ps -p $COPY_PID > /dev/null; do
  sleep 10
  CURRENT_SIZE=$(du -sh /mnt/secure_tmp/model 2>/dev/null | cut -f1 || echo "0")
  echo "[Loader] Operation time: $SECONDS s. Progress: $CURRENT_SIZE of $TARGET_SIZE copied..."
done

wait $COPY_PID

echo "[Loader] Assigning ownership to vLLM user..."
chown -R $VLLM_UID:$VLLM_GID /mnt/secure_tmp/model

trap - EXIT
cleanup

touch /mnt/secure_tmp/model.ready

echo "[Loader] Finished successfully."