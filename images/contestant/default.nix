{ lib, pkgs, ... }:

{
  imports = [
    ./admintools.nix
    ./base.nix
    ./compilers.nix
    ./devtools.nix
    ./firewall.nix
    ./gui.nix
    ./home.nix
    ./icpc.nix
    ./localweb.nix
    ./monitoring.nix
    ./printer.nix
    ./scripts.nix
    ./vmtouch.nix
  ];
}
