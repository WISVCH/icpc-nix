{ lib, pkgs, modulesPath, ... }:

{
  imports = [
    # Pulls in virtio_scsi/virtio_blk (among others) for the initrd, so the
    # root partition (found by label) is visible when these images run as
    # Proxmox VMs (scsi0 on a virtio-scsi-pci controller). Harmless on real
    # hardware - these modules just never get used there.
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.kernelParams = [ "console=tty0" "consoleblank=0" "biosdevname=0" "net.ifnames=0" ];
  nixpkgs.config.allowUnfree = true;

  # The raw-efi format reads this via config.virtualisation.diskSize to pick
  # the disk image size (make-disk-image.nix). It must match the size of the
  # existing Proxmox VM disks exactly, since deploy/proxmox/ci-deploy-image.sh
  # refuses to deploy an image whose size differs from the target disk.
  virtualisation.diskSize = 20 * 1024;

  # Native `system.build.images.raw-efi` (nixos/modules/image/images.nix)
  # defaults to systemd-boot, not GRUB. Configure GRUB explicitly - both the
  # Secure Boot pipeline (docs/adr/0001, scripts/sign-image.sh) and physical
  # deployment via `nixos-rebuild switch` depend on GRUB specifically, with a
  # removable-media install so it boots without a firmware NVRAM entry.
  boot.loader.grub.device = "nodev";
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.efiInstallAsRemovable = true;
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
  };

  # Add experimental flakes support
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  services.journald.console = "tty1";
  services.journald.forwardToSyslog = false;
  services.journald.extraConfig = ''
    ForwardToKMsg=no
    ForwardToConsole=yes
    ForwardToWall=no
    TTYPath=/dev/tty1
    Storage=volatile
  '';

  # systemd.extraConfig = ''
  #   ShowStatus=no
  # '';

  time.timeZone = "Europe/Amsterdam";

  # Masks systemd's own 75-persistent-net-generator.rules (predictable
  # network interface naming - already disabled via net.ifnames=0 above,
  # this additionally stops the generator rule from running at all) with
  # an empty file of the same name.
  #
  # This must go through services.udev.packages, not a plain
  # environment.etc."udev/rules.d/..." target: NixOS's udev module
  # (nixos/modules/services/hardware/udev.nix) normally makes
  # /etc/udev/rules.d a single symlink to the merged rules derivation
  # built from services.udev.packages/extraRules. A second, independent
  # environment.etc entry targeting a path *inside* that same directory
  # conflicts with that whole-directory symlink - confirmed on a running
  # system that /etc/udev/rules.d silently fell back to a plain directory
  # containing only this one masked file, with every other rule (systemd's
  # own bundled ones excepted, which are read from a separate compiled-in
  # vendor path) never reaching the running udevd at all.
  services.udev.packages = [
    (pkgs.writeTextDir "etc/udev/rules.d/75-persistent-net-generator.rules" "")
  ];

  environment.etc = {
    "netcfg" = {
      text = ''
        network:
          version: 2
          renderer: networkd
          ethernets:
            default:
              match:
                name: e*
              dhcp4: yes
              dhcp-identifier: mac
      '';
      target = "netplan/01-netcfg.yaml";
    };
  };

  # Enable audio support through pulseaudio
  # hardware.pulseaudio.enable = true;
  # hardware.pulseaudio.support32Bit = true;
}
