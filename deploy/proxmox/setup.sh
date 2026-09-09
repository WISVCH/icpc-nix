#!/bin/bash
# Run this ONCE, as root, on the Proxmox host, to set up the scoped
# deploy user CI uses to push console/contestant images to their
# staging VMs. See ../../README.md for how this fits into the release
# workflow.
#
# Creates:
#   - a "ci-deploy" system user with no login shell privileges beyond SSH
#   - /usr/local/sbin/ci-deploy-image.sh (installed from this directory)
#   - /etc/ci-deploy-image/allowed-vmids.conf, restricting the script to
#     only the two VMIDs you provide below
#   - a sudoers rule letting ci-deploy run that one script as root,
#     nothing else
#   - an SSH keypair for ci-deploy; the private key is what you paste
#     into the PROXMOX_SSH_KEY GitHub Actions secret
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "run this as root" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_USER="${DEPLOY_USER:-ci-deploy}"
CONFIG_DIR="/etc/ci-deploy-image"
CONFIG_FILE="$CONFIG_DIR/allowed-vmids.conf"
SCRIPT_PATH="/usr/local/sbin/ci-deploy-image.sh"
SUDOERS_PATH="/etc/sudoers.d/ci-deploy-image"
KEY_PATH="/root/ci-deploy-key"

read -rp "Console VM ID: " CONSOLE_VMID
read -rp "Contestant VM ID: " CONTESTANT_VMID

if ! id -u "$DEPLOY_USER" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$DEPLOY_USER"
fi

install -d -m 755 "$CONFIG_DIR"
cat > "$CONFIG_FILE" <<EOF
ALLOWED_VMIDS="$CONSOLE_VMID $CONTESTANT_VMID"
EOF

install -m 755 "$SCRIPT_DIR/ci-deploy-image.sh" "$SCRIPT_PATH"

cat > "$SUDOERS_PATH" <<EOF
$DEPLOY_USER ALL=(root) NOPASSWD: $SCRIPT_PATH
EOF
chmod 440 "$SUDOERS_PATH"
visudo -cf "$SUDOERS_PATH"

SSH_DIR="/home/$DEPLOY_USER/.ssh"
install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$SSH_DIR"

if [ ! -f "$KEY_PATH" ]; then
  ssh-keygen -t ed25519 -N "" -C "chipcie-nix CI deploy" -f "$KEY_PATH"
fi

touch "$SSH_DIR/authorized_keys"
if ! grep -qxF "$(cat "$KEY_PATH.pub")" "$SSH_DIR/authorized_keys"; then
  cat "$KEY_PATH.pub" >> "$SSH_DIR/authorized_keys"
fi
chown "$DEPLOY_USER":"$DEPLOY_USER" "$SSH_DIR/authorized_keys"
chmod 600 "$SSH_DIR/authorized_keys"

echo
echo "=== Setup complete ==="
echo
echo "Add these as GitHub repo Variables (Settings > Secrets and variables > Actions > Variables):"
echo "  PROXMOX_HOST             = $(hostname -f 2>/dev/null || hostname)"
echo "  PROXMOX_SSH_USER         = $DEPLOY_USER"
echo "  PROXMOX_CONSOLE_VMID     = $CONSOLE_VMID"
echo "  PROXMOX_CONTESTANT_VMID  = $CONTESTANT_VMID"
echo
echo "Add this as a GitHub repo Secret (Settings > Secrets and variables > Actions > Secrets):"
echo "  PROXMOX_SSH_KEY = (contents of $KEY_PATH, printed below)"
echo
cat "$KEY_PATH"
echo
echo "Once the secret and variables are set in GitHub, you can remove $KEY_PATH"
echo "and $KEY_PATH.pub from this host — only the public key needs to stay in"
echo "$SSH_DIR/authorized_keys."
