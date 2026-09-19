{ pkgs, languages }:

# checks.languages: languages.nix states versions (in `pins`, and per
# language in `version`) that the contestant image, the systems page and
# eventually the judgehost all rely on. Fail evaluation if any of them isn't
# what the resolved revision actually ships, or if the pins stop fitting in
# one nixpkgs revision (each extra one is another full nixpkgs fetch, and a
# second set of shared libraries in the closure).
let
  inherit (pkgs) lib;

  wrongPins = lib.filterAttrs (
    attr: version: languages.resolved.${attr}.version != version
  ) languages.pins;

  langs = lib.filterAttrs (_: l: l ? packages) languages;
  wrongLanguages = lib.filterAttrs (_: l: (builtins.head l.packages).version != l.version) langs;

  describe = set: lib.concatStringsSep ", " (lib.attrNames set);
in
assert lib.assertMsg (languages.plan.revisions == 1)
  "languages.nix: pins need ${toString languages.plan.revisions} nixpkgs revisions, expected 1: ${languages.plan.why}";
assert lib.assertMsg (
  wrongPins == { }
) "languages.nix: pinned version differs from what its revision ships: ${describe wrongPins}";
assert lib.assertMsg (
  wrongLanguages == { }
) "languages.nix: `version` differs from the language's package: ${describe wrongLanguages}";
pkgs.runCommand "languages-check" { } "touch $out"
