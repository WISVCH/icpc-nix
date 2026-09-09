{ lib, pkgs, ... }:

{
  imports = [
    ./packages.nix
    ./base.nix
    ./desktop.nix
    ./docker.nix
    ./home.nix
  ];
}
