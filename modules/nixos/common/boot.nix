{ modulesPath, ... }:

{
  imports = [
    # Pulls in virtio_scsi/virtio_blk (among others) for the initrd, so the
    # root partition (found by label) is visible when these images run as
    # Proxmox VMs (scsi0 on a virtio-scsi-pci controller). Harmless on real
    # hardware - these modules just never get used there.
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.kernelParams = [
    "console=tty0"
    "consoleblank=0"
    "biosdevname=0"
    "net.ifnames=0"
  ];

  # virtualisation.diskSize (the raw-efi image's disk size) used to live here,
  # but it's a per-image number that has to match each Proxmox VM's own disk -
  # it's set in hosts/<host>/image.nix now.

  # Native `system.build.images.raw-efi` (nixos/modules/virtualisation/disk-image.nix)
  # defaults boot.loader.systemd-boot.enable to true whenever EFI support is
  # on, regardless of the GRUB options below - the two are independent
  # options, not alternatives, so enabling GRUB alone doesn't turn systemd-boot
  # off. With both enabled, `switch-to-configuration boot` (invoked by
  # make-disk-image.nix) installs both: systemd-boot fully (real
  # loader/entries/*.conf, kernel copied to /EFI/nixos/), while GRUB ends up
  # on the ESP with no grub.cfg. Firmware then boots via systemd-boot, which
  # was never part of the shim/MOK Secure Boot chain (docs/adr/0001,
  # scripts/sign-image.sh) - confirmed on real hardware while testing #7,
  # see the comment on issue #7 from 2026-09-14.
  boot.loader.systemd-boot.enable = false;
  # Both the Secure Boot pipeline (docs/adr/0001, scripts/sign-image.sh) and
  # physical deployment via `nixos-rebuild switch` depend on GRUB
  # specifically, with a removable-media install so it boots without a
  # firmware NVRAM entry.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.efiInstallAsRemovable = true;
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
  };

  # systemd.extraConfig = ''
  #   ShowStatus=no
  # '';

  # Enable audio support through pulseaudio
  # hardware.pulseaudio.enable = true;
  # hardware.pulseaudio.support32Bit = true;
}
