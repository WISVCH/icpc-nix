{ ... }:

# Settings that apply only when this host is built as a bootable disk image
# (`nix build .#server` -> packages.x86_64-linux.server), imported by both
# that build path and ./configuration.nix so the two can't drift.
{
  system.stateVersion = "26.05";

  # The raw-efi format reads this via config.virtualisation.diskSize to pick
  # the disk image size (make-disk-image.nix). It must match the size of the
  # existing Proxmox VM disk exactly, since deploy/proxmox/ci-deploy-image.sh
  # refuses to deploy an image whose size differs from the target disk.
  #
  # 20G matches console/contestant and VM 303 as created by
  # deploy/proxmox/create-vms.sh. Note that a deploy overwrites this whole
  # disk, MariaDB included - see docs/adr/0006 for why that's acceptable on
  # 303 and why it means this image must never be deployed at peter.
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
