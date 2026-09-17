{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./image.nix
    ../../modules/nixos/common
    ../../modules/nixos/console
    ./users/icpcadmin.nix
    ./users/icpctools.nix
    ./users/judgehost.nix
  ];
}
