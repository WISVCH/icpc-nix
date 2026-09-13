{ config, lib, pkgs, ... }:
{
  # qemu-guest.nix now comes from modules/nixos/common, which this host's
  # configuration.nix also imports.

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # boot.loader.grub.device / efiSupport / efiInstallAsRemovable come from
  # modules/nixos/common, shared with the image-building packages.
  boot.loader.timeout = 0;
}
