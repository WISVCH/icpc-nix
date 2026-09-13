{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/common
    ../../modules/nixos/console
    ./users/icpcadmin.nix
    ./users/icpctools.nix
    ./users/judgehost.nix
  ];

  system.stateVersion = "23.11";
}
