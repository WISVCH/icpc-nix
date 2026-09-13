{ pkgs, ... }:

{
  # Masks systemd's own 75-persistent-net-generator.rules (predictable
  # network interface naming - already disabled via net.ifnames=0 in boot.nix,
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
}
