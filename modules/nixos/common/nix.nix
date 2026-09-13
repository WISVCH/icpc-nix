{ ... }:

{
  nixpkgs.config.allowUnfree = true;

  # Add experimental flakes support
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
