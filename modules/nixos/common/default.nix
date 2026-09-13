{ ... }:

{
  imports = [
    ./boot.nix
    ./nix.nix
    ./journald.nix
    ./locale.nix
    ./networking.nix
    ./home-manager.nix
  ];
}
