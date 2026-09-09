#!/bin/bash
# Installed at /usr/local/sbin/ci-deploy-image.sh on the Proxmox host by
# setup.sh. Invoked via a narrowly-scoped sudoers rule by the CI deploy
# user (see setup.sh) — not meant to be run by hand without knowing
# exactly which VMID/image you're pointing at, since it stops the VM and
# overwrites its disk.
set -euo pipefail

VMID="${1:?usage: ci-deploy-image.sh <vmid> <path-to-raw-image>}"
IMAGE_PATH="${2:?usage: ci-deploy-image.sh <vmid> <path-to-raw-image>}"

CONFIG_FILE="/etc/ci-deploy-image/allowed-vmids.conf"
# shellcheck source=/dev/null
source "$CONFIG_FILE"

ALLOWED=false
for v in $ALLOWED_VMIDS; do
  if [ "$v" = "$VMID" ]; then
    ALLOWED=true
  fi
done
if [ "$ALLOWED" != true ]; then
  echo "refusing to touch VMID $VMID (not in $CONFIG_FILE)" >&2
  exit 1
fi

if [ ! -f "$IMAGE_PATH" ]; then
  echo "no such file: $IMAGE_PATH" >&2
  exit 1
fi

DISK_LINE=$(qm config "$VMID" | grep -E '^(scsi|virtio|sata|ide)[0-9]+:' | head -1)
if [ -z "$DISK_LINE" ]; then
  echo "could not find a disk on VM $VMID" >&2
  exit 1
fi
VOLID=$(echo "$DISK_LINE" | cut -d: -f2- | cut -d, -f1 | xargs)
DISK_PATH=$(pvesm path "$VOLID")

NEW_SIZE=$(stat -c %s "$IMAGE_PATH")
OLD_SIZE=$(stat -c %s "$DISK_PATH")
if [ "$NEW_SIZE" -ne "$OLD_SIZE" ]; then
  echo "refusing to deploy: new image is ${NEW_SIZE} bytes, existing disk ($DISK_PATH) is ${OLD_SIZE} bytes" >&2
  exit 1
fi

echo "stopping VM $VMID"
qm stop "$VMID" --timeout 60

STATUS="unknown"
for _ in $(seq 1 30); do
  STATUS=$(qm status "$VMID" | awk '{print $2}')
  if [ "$STATUS" = "stopped" ]; then
    break
  fi
  sleep 2
done
if [ "$STATUS" != "stopped" ]; then
  echo "VM $VMID did not stop in time" >&2
  exit 1
fi

echo "writing new image to $DISK_PATH"
cp "$IMAGE_PATH" "$DISK_PATH"
sync
rm -f "$IMAGE_PATH"

echo "starting VM $VMID"
qm start "$VMID"

echo "done"
