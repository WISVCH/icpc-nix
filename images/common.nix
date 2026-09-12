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

  environment.etc = {
    "persistent-udev-rules" = {
      text = "";
      target = "udev/rules.d/75-persistent-net-generator.rules";
    };
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
