{ pkgs, ... }:

# The smallest NixOS image that boots through the same chain as the real
# images: it takes its bootloader setup from modules/nixos/common/boot.nix
# (GRUB, efiInstallAsRemovable, kernels copied to /kernels on the ESP) and is
# built as the same raw-efi image, so sign-image.sh sees the same ESP layout.
# Everything else is left out to keep the build small.
#
# Once it reaches userspace it reports on the serial port and powers off;
# ./default.nix looks for that line.
{
  system.stateVersion = "26.05";

  # Appended after boot.nix's console=tty0, so the kernel log (and
  # /dev/console) goes to the serial port the harness records.
  boot.kernelParams = [ "console=ttyS0,115200" ];
  boot.loader.timeout = 1;

  documentation.enable = false;

  systemd.services.secure-boot-report = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    path = [ pkgs.coreutils ];
    script = ''
      # SecureBoot variable: 4 bytes of attributes, then 1 byte of value.
      sb="$(od -An -t u1 -j4 -N1 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c | tr -d ' ')"
      echo "SECURE-BOOT-TEST: reached userspace, SecureBoot=$sb" > /dev/ttyS0
      systemctl poweroff --no-block
    '';
  };

  image.modules.raw-efi = {
    image.baseName = "nixos";
  };
}
