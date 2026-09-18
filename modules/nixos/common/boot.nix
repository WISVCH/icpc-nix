{
  lib,
  pkgs,
  modulesPath,
  ...
}:

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
  # What shim and GRUB itself require of the GRUB image once Secure Boot is
  # on (#84, found by tests/secure-boot):
  #
  # - shim refuses to start any binary without an .sbat section, even one
  #   whose signature it accepts. grub-install only adds one when given
  #   --sbat. The grub line's generation (5) must be at least the one in
  #   shim's SbatLevel; nixpkgs' GRUB 2.12 carries the February 2025 CVE
  #   fixes that generation 5 stands for.
  # - GRUB's shim_lock verifier denies loading modules from disk
  #   (grub-core/kern/efi/sb.c: GRUB_FILE_TYPE_GRUB_MODULE is not on its
  #   list), so everything grub.cfg needs is built into the image instead.
  #   The list covers what NixOS's install-grub.pl writes into grub.cfg
  #   (search, load_env, graphics setup, linux/initrd) plus a few commands
  #   for the GRUB shell. Anything grub.cfg insmods that is missing here
  #   fails only under Secure Boot.
  boot.loader.grub.extraGrubInstallArgs = [
    "--sbat=${pkgs.writeText "grub-sbat.csv" ''
      sbat,1,SBAT Version,sbat,1,https://github.com/rhboot/shim/blob/main/SBAT.md
      grub,5,Free Software Foundation,grub,2.12,https://www.gnu.org/software/grub/
      grub.icpc-nix,1,WISVCH icpc-nix,grub,2.12,https://github.com/WISVCH/icpc-nix
    ''}"
    (
      "--modules="
      + lib.concatStringsSep " " [
        # Boot flow
        "normal"
        "configfile"
        "linux"
        "boot"
        "gzio"
        # Finding /boot and reading it
        "part_gpt"
        "part_msdos"
        "fat"
        "ext2"
        "search"
        "search_fs_uuid"
        "search_fs_file"
        "search_label"
        # grub.cfg scripting and state
        "test"
        "echo"
        "loadenv"
        "sleep"
        # Graphics setup grub.cfg does on EFI
        "all_video"
        "efi_gop"
        "efi_uga"
        "font"
        "gfxterm"
        "gfxterm_background"
        "png"
        "jpeg"
        # GRUB shell
        "minicmd"
        "ls"
        "cat"
        "halt"
        "reboot"
      ]
    )
  ];
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
