{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./image.nix
    ../../modules/nixos/common
    ../../modules/nixos/contestant
    ./users/contestant.nix
    ./users/icpcadmin.nix
  ];
}
