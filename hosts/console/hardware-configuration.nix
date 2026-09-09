{ config, lib, pkgs, ... }:
{
  # qemu-guest.nix now comes from images/common.nix, which this host's
  # nixosConfigurations entry also imports.

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  boot.loader.grub.device = "nodev";
  boot.loader.timeout = 0;
}
