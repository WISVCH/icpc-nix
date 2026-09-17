{ ... }:

{
  imports = [
    ./boot.nix
    ./secure-boot-live-signing.nix
    ./nix.nix
    ./journald.nix
    ./locale.nix
    ./networking.nix
    ./home-manager.nix
  ];
}
