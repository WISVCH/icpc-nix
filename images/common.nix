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
  nixpkgs.config.permittedInsecurePackages = [ "squid-6.10" ];

  # cptofs (from the `lkl` package, used by make-disk-image.nix to populate
  # the disk image) never resets errno before calling readdir(), so a stale
  # errno left over from an earlier LKL syscall gets misreported as
  # "error while reading directory ... Invalid argument" on ordinary,
  # successful end-of-directory. Harmless but extremely noisy in CI logs -
  # patch it at the source instead of filtering the output.
  nixpkgs.overlays = [
    (_final: prev: {
      lkl = prev.lkl.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ../patches/cptofs-reset-errno-before-readdir.patch ];
      });
    })
  ];

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
