{ ... }:

# Settings that apply only when this host is built as a bootable disk image
# (`nix build .#contestant` -> packages.x86_64-linux.contestant), imported by
# both that build path and ./configuration.nix so the two can't drift.
#
# Before this file existed these attributes were written inline in flake.nix's
# packages.* block, with ./inventory.nix's language/IDE toggles duplicated by
# hand between there, configuration.nix and tests/contestant/default.nix.
{
  imports = [ ./inventory.nix ];

  system.stateVersion = "23.11";

  # The raw-efi format reads this via config.virtualisation.diskSize to pick
  # the disk image size (make-disk-image.nix). It must match the size of the
  # existing Proxmox VM disk exactly, since deploy/proxmox/ci-deploy-image.sh
  # refuses to deploy an image whose size differs from the target disk.
  #
  # Per-host rather than in modules/nixos/common: each image sizes its own
  # disk, and common has no business knowing how big any of them are.
  virtualisation.diskSize = 20 * 1024;

  # image.baseName only exists within the per-format extended eval
  # (config.system.build.images.<format>), not the top-level config, so it's
  # set via image.modules.raw-efi rather than directly - deferredModule merges
  # this in alongside the built-in raw-efi definition
  # (nixos/modules/image/images.nix).
  image.modules.raw-efi = {
    image.baseName = "nixos";
  };
}
