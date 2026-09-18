{ lib, ... }:

{
  # Imported by relative path rather than through the flake's `self`, so evals
  # without specialArgs (tests/secure-boot) can import this module too.
  nixpkgs.overlays = [ (import ../../../overlays { inherit lib; }).default ];
}
