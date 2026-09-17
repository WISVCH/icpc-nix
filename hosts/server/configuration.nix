{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./image.nix
    ../../modules/nixos/common
    ../../modules/nixos/server
    ./users/icpcadmin.nix
  ];
}
