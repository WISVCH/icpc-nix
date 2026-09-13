{ lib, pkgs, ... }:

{
  imports = [
    ./admintools.nix
    ./base.nix
    ./desktop-icon-emblems.nix
    ./devtools.nix
    ./firewall.nix
    ./gui.nix
    ./icpc.nix
    ./ides
    ./languages
    ./localweb.nix
    ./monitoring.nix
    ./printer.nix
    ./scripts.nix
    ./usbguard.nix
    ./vmtouch.nix
  ];
}
