{
  pkgs,
  inputs,
  languages,
}:

# checks.judgehost-toolchains: the judging chroot and the contestant image
# must compile submissions with the same derivations, not merely the same
# version numbers (#61, #74).
#
# Store paths, so this is exact: a rebuild of either side with a different
# nixpkgs, a different wrapper around gcc, or an extra package passed to the
# image shows up here as a different path.
let
  inherit (pkgs) lib;

  judgehost = import ../modules/home-manager/icpcadmin/judgehost.nix {
    inherit pkgs inputs languages;
  };

  paths = map (p: p.outPath);

  inChroot = lib.sort (a: b: a < b) (paths judgehost.chroot.toolchains);
  judged = lib.sort (a: b: a < b) (paths languages.judgedPackages);

  # Every language the contestant image installs is judged by one of those
  # same packages - a language added to languages.nix without reaching the
  # judgehost would otherwise pass the comparison above unnoticed.
  contestantOnly = lib.filterAttrs (_: l: !(lib.all (p: lib.elem p.outPath judged) l.packages)) (
    lib.filterAttrs (_: l: l ? packages) languages
  );
in
assert lib.assertMsg (inChroot == judged) ''
  the judgehost chroot's toolchains are not the contestant image's:
    chroot:   ${lib.concatStringsSep " " inChroot}
    languages: ${lib.concatStringsSep " " judged}'';
assert lib.assertMsg (contestantOnly == { }) (
  "languages judged with a package the judgehost never gets: "
  + lib.concatStringsSep ", " (lib.attrNames contestantOnly)
);
pkgs.runCommand "judgehost-toolchains-check" { } "touch $out"
