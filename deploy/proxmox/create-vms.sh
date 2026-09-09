#!/bin/bash
# Run this ONCE, as root, on the Proxmox host, to create the two staging
# VMs (console, contestant) that the release workflow later deploys to.
#
# You need a raw-efi image for each already sitting on this host first —
# build them with `nix build .#console` / `nix build .#contestant` and
# copy result/nixos.img over, or grab one from a GitHub release. The
# image you import here becomes each VM's initial disk, so its size is
# what the CI deploy step's pre-flight size check will compare future
# builds against (see ci-deploy-image.sh) — if a later build changes
# size, that check will (correctly) refuse to deploy until you resize
# or recreate the VM's disk deliberately.
#
# Requires a directory/file-based storage pool (e.g. Proxmox's default
# "local") — LVM-thin/ZFS volumes aren't plain files, which the deploy
# step's disk-overwrite approach depends on. The script checks this and
# refuses to proceed on an unsupported storage type.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "run this as root" >&2
  exit 1
fi

STORAGE="${STORAGE:-local}"
BRIDGE="${BRIDGE:-vmbr0}"
MEMORY_MB="${MEMORY_MB:-4096}"
CORES="${CORES:-2}"

STORAGE_TYPE=$(pvesm status | awk -v s="$STORAGE" '$1 == s { print $2 }')
if [ -z "$STORAGE_TYPE" ]; then
  echo "storage pool '$STORAGE' not found (check \`pvesm status\`)" >&2
  exit 1
fi
case "$STORAGE_TYPE" in
  dir|nfs|cifs) ;;
  *)
    echo "storage pool '$STORAGE' is type '$STORAGE_TYPE', not directory/file-based." >&2
    echo "The CI deploy step overwrites the VM's disk file directly, which needs" >&2
    echo "dir/nfs/cifs storage. Pick a different pool (STORAGE=... $0) or set one up." >&2
    exit 1
  ;;
esac

create_vm() {
  local vmid="$1" name="$2" image_path="$3"

  if qm status "$vmid" >/dev/null 2>&1; then
    echo "VMID $vmid already exists, skipping creation (check it by hand)" >&2
    return
  fi
  if [ ! -f "$image_path" ]; then
    echo "no such image file: $image_path" >&2
    exit 1
  fi

  echo "creating VM $vmid ($name) from $image_path"
  qm create "$vmid" \
    --name "$name" \
    --memory "$MEMORY_MB" \
    --cores "$CORES" \
    --cpu host \
    --net0 "virtio,bridge=$BRIDGE" \
    --ostype l26 \
    --machine q35 \
    --bios ovmf \
    --scsihw virtio-scsi-pci

  qm set "$vmid" --efidisk0 "${STORAGE}:1,efitype=4m,pre-enrolled-keys=0"

  IMPORT_OUTPUT=$(qm importdisk "$vmid" "$image_path" "$STORAGE" --format raw)
  echo "$IMPORT_OUTPUT"
  UNUSED_REF=$(echo "$IMPORT_OUTPUT" | grep -oE "unused[0-9]+:[^']+" | tail -1)
  if [ -z "$UNUSED_REF" ]; then
    echo "could not parse the imported disk's volume id from importdisk output" >&2
    exit 1
  fi
  VOLID="${UNUSED_REF#*:}"

  qm set "$vmid" --scsi0 "$VOLID"
  qm set "$vmid" --boot order=scsi0
  qm set "$vmid" --description "chipcie-nix $name staging VM - managed by CI, see deploy/proxmox/ci-deploy-image.sh"

  echo "VM $vmid ($name) ready. Disk file: $(pvesm path "$VOLID")"
}

read -rp "Console VM ID: " CONSOLE_VMID
read -rp "Path to built console raw image on this host: " CONSOLE_IMAGE
read -rp "Contestant VM ID: " CONTESTANT_VMID
read -rp "Path to built contestant raw image on this host: " CONTESTANT_IMAGE

create_vm "$CONSOLE_VMID" console "$CONSOLE_IMAGE"
create_vm "$CONTESTANT_VMID" contestant "$CONTESTANT_IMAGE"

echo
echo "=== Done ==="
echo "Use these same VMIDs ($CONSOLE_VMID, $CONTESTANT_VMID) when running setup.sh,"
echo "and as PROXMOX_CONSOLE_VMID / PROXMOX_CONTESTANT_VMID in the GitHub repo variables."
