# Overlays that change packages nixpkgs already ships (patches,
# overrideAttrs). New derivations belong in ../packages instead.
#
# One directory per package being changed, holding its overlay and any
# patches. modules/nixos/common/overlays.nix applies `default`, and the flake
# exports the whole set as `overlays`.
{ lib }:
let
  overlays = {
    lkl = import ./lkl;
  };
in
overlays
// {
  default = lib.composeManyExtensions (lib.attrValues overlays);
}
