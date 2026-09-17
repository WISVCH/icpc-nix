{ ... }:
{
  # qemu-guest.nix comes from modules/nixos/common, which this host's
  # configuration.nix also imports - the server only ever runs as a VM
  # (Proxmox 303 today, peter later), so there's no bare-metal variant.

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # boot.loader.grub.device / efiSupport / efiInstallAsRemovable come from
  # modules/nixos/common, shared with the image-building packages.
  boot.loader.timeout = 0;
}
