#!/usr/bin/env bash
# Re-signs GRUB and every kernel on THIS machine's live ESP, in place. Wired
# in via boot.loader.grub.extraInstallCommands
# (modules/nixos/common/secure-boot-live-signing.nix), which runs this
# script every time `switch-to-configuration boot` installs GRUB - i.e. on
# every `nixos-rebuild switch`/`boot`, AND inside the sandboxed raw-efi
# image build (since packages.x86_64-linux.console/contestant share the same
# module). See docs/adr/0007-live-resigning-after-nixos-rebuild.md for why
# this needs its own mechanism, separate from scripts/sign-image.sh.
#
# Unlike sign-image.sh (which operates on an offline .img via mtools), /boot
# here is already a live, mounted vfat filesystem - plain file operations,
# no mtools needed.
#
# Only does anything on a machine that:
#   - already has our cert MOK-enrolled on it (from an earlier
#     sign-image.sh-signed image + MOK enrollment - this script does not do
#     enrollment, it only re-signs)
#   - has had the private release key placed at $LIVE_KEY out of band,
#     never through Nix (see docs/signing-key.md) - if it's absent (true for
#     every `nix build`/image-build invocation, and for any machine that
#     hasn't been provisioned with it), this script quietly no-ops so it
#     never breaks a build or an ordinary switch.
#
# Requires SHIM_DIR and ICPC_NIX_SIGNING_CERT to be set by the caller
# (baked-in Nix store paths - neither is sensitive).
set -euo pipefail

LIVE_KEY="/etc/icpc-nix/release.key"
ESP="/boot"

: "${SHIM_DIR:?SHIM_DIR must point to the built shim package (shimx64.efi, mmx64.efi)}"
: "${ICPC_NIX_SIGNING_CERT:?ICPC_NIX_SIGNING_CERT must point to the release certificate file}"

if [ ! -f "$LIVE_KEY" ]; then
  echo "icpc-nix: no live signing key at $LIVE_KEY - leaving GRUB/kernel(s) unsigned" >&2
  exit 0
fi

if [ ! -f "$ESP/EFI/BOOT/BOOTX64.EFI" ]; then
  echo "icpc-nix: $ESP/EFI/BOOT/BOOTX64.EFI not found - nothing to sign" >&2
  exit 0
fi

[ -f "$SHIM_DIR/shimx64.efi" ] || { echo "error: $SHIM_DIR/shimx64.efi not found" >&2; exit 1; }
[ -f "$SHIM_DIR/mmx64.efi" ] || { echo "error: $SHIM_DIR/mmx64.efi not found" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# grub-install (efiInstallAsRemovable) just wrote a fresh, plain, unsigned
# GRUB to the removable-media fallback path - unconditionally, on every
# run, regardless of what was there before. Sign it, then put our shim back
# in the fallback slot with the newly-signed GRUB alongside it - the same
# shape scripts/sign-image.sh produces on a freshly built image.
sbsign --key "$LIVE_KEY" --cert "$ICPC_NIX_SIGNING_CERT" \
  --output "$WORK/grubx64.efi" "$ESP/EFI/BOOT/BOOTX64.EFI"

install -D -m444 "$SHIM_DIR/shimx64.efi" "$ESP/EFI/BOOT/BOOTX64.EFI"
install -D -m444 "$WORK/grubx64.efi" "$ESP/EFI/BOOT/grubx64.efi"
install -D -m444 "$SHIM_DIR/mmx64.efi" "$ESP/EFI/BOOT/mmx64.efi"

openssl x509 -in "$ICPC_NIX_SIGNING_CERT" -outform DER -out "$WORK/icpc-nix.cer"
install -D -m444 "$WORK/icpc-nix.cer" "$ESP/EFI/keys/icpc-nix.cer"

sbverify --cert "$ICPC_NIX_SIGNING_CERT" "$ESP/EFI/BOOT/grubx64.efi" >&2

# A live system can have several old generations' kernels sitting in
# /boot/kernels at once (still listed in the GRUB menu), not just the one
# this switch just added - sign all of them, every run, so every menu entry
# stays bootable under enforcement, not just the newest. sbsign on an
# already-signed file just replaces its signature, so this is idempotent.
shopt -s nullglob
KERNELS=("$ESP"/kernels/*bzImage*)
shopt -u nullglob

for kernel in "${KERNELS[@]}"; do
  sbsign --key "$LIVE_KEY" --cert "$ICPC_NIX_SIGNING_CERT" \
    --output "$WORK/kernel.signed" "$kernel"
  install -m444 "$WORK/kernel.signed" "$kernel"
  sbverify --cert "$ICPC_NIX_SIGNING_CERT" "$kernel" >&2
done

if [ "${#KERNELS[@]}" -eq 0 ]; then
  echo "icpc-nix: warning: no kernels found under $ESP/kernels to sign" >&2
fi

echo "icpc-nix: live-signed shim + grubx64.efi + ${#KERNELS[@]} kernel(s) from $LIVE_KEY" >&2
