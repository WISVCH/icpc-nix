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
# Works with directory storage (e.g. Proxmox's default "local") or
# LVM-thin (e.g. "local-lvm") — the deploy step's disk-overwrite approach
# just needs `pvesm path` to resolve to something it can write raw bytes
# into directly, which holds for a plain file (dir/nfs/cifs) or a block
# device (lvmthin/lvm) alike. The script checks the pool is one of these
# and refuses to proceed otherwise.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "run this as root" >&2
  exit 1
fi

STORAGE="${STORAGE:-local}"
BRIDGE="${BRIDGE:-vmbr1}"
MEMORY_MB="${MEMORY_MB:-4096}"
CORES="${CORES:-2}"

STORAGE_TYPE=$(pvesm status | awk -v s="$STORAGE" '$1 == s { print $2 }')
if [ -z "$STORAGE_TYPE" ]; then
  echo "storage pool '$STORAGE' not found (check \`pvesm status\`)" >&2
  exit 1
fi
case "$STORAGE_TYPE" in
  dir|nfs|cifs|lvmthin|lvm) ;;
  *)
    echo "storage pool '$STORAGE' is type '$STORAGE_TYPE', which this script hasn't" >&2
    echo "been checked against. It needs \`pvesm path\` to resolve to something raw" >&2
    echo "bytes can be written into directly (a file or a block device) - dir, nfs," >&2
    echo "cifs, lvmthin and lvm all qualify. Pick a different pool (STORAGE=... $0)." >&2
    exit 1
  ;;
esac

STORAGE_CONTENT=$(awk -v s="$STORAGE" '
  $0 ~ "^[a-z]+: " s "$" { grab=1; next }
  grab && /^[a-z]/ { grab=0 }
  grab && $1 == "content" { print $2 }
' /etc/pve/storage.cfg)
case ",$STORAGE_CONTENT," in
  *,images,*) ;;
  *)
    echo "storage pool '$STORAGE' doesn't have the 'images' content type enabled" >&2
    echo "(currently: ${STORAGE_CONTENT:-none}) - directory storage like the default" >&2
    echo "'local' pool usually only allows iso/vztmpl/backup out of the box." >&2
    echo "Enable it with:" >&2
    echo "  pvesm set $STORAGE --content ${STORAGE_CONTENT:+$STORAGE_CONTENT,}images" >&2
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
  # Wording varies by Proxmox version, e.g.:
  #   "Successfully imported disk as 'unused0:local:104/vm-104-disk-0.raw'"
  #   "unused0: successfully imported disk 'local:302/vm-302-disk-1.raw'"
  # Either way, take whatever's inside the single quotes on that line, then
  # strip a leading "unusedN:" if the version above included it there too.
  IMPORTED_LINE=$(echo "$IMPORT_OUTPUT" | grep -i "imported disk" | tail -1)
  RAW=$(echo "$IMPORTED_LINE" | sed -n "s/.*'\([^']*\)'.*/\1/p")
  if [ -z "$RAW" ]; then
    echo "could not parse the imported disk's volume id from importdisk output" >&2
    exit 1
  fi
  VOLID="${RAW#unused[0-9]*:}"

  qm set "$vmid" --scsi0 "$VOLID"
  qm set "$vmid" --boot order=scsi0
  qm set "$vmid" --description "icpc-nix $name staging VM - managed by CI, see deploy/proxmox/ci-deploy-image.sh"

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
