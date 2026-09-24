{
  pkgs,
  inputs,
  languages,
}:

# The judgehost image, built from WISVCH/domjudge-packaging's flake with the
# toolchains ../../../languages.nix pins (#74) - so a submission is judged
# with the same derivations the contestant image installs, not with whatever
# a pulled image happened to contain.
#
# A file of its own rather than inline in ./judgehost-image.nix because
# tests/judgehost-toolchains.nix checks *this* value: a check that rebuilt
# the image from languages.judgedPackages itself could not notice a
# judgehost built from something else.
inputs.domjudge-packaging.lib.judgehostFor {
  inherit pkgs;
  toolchains = languages.judgedPackages;
}
