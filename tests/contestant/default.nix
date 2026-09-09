# Generic nixosTest harness for the contestant image: a single VM ("machine")
# boots once, and every check below runs against it as a subtest, instead of
# each check spinning up its own VM. To add a new check (see issue #20's
# checklist - printing, domjudge, proxy, language versions, ...), add a
# fragment file exporting `{ name, script }` and list it in `subtests` below.
{ pkgs, self, inputs, system, vars }:

let
  lib = pkgs.lib;

  subtests = [
    (import ./squid.nix { inherit pkgs self inputs system vars; })
  ];

  indent = script:
    lib.concatMapStrings (line: "    " + line + "\n")
      (lib.splitString "\n" (lib.removeSuffix "\n" script));

  subtestScript = t: ''
    with subtest("${t.name}"):
    ${indent t.script}
  '';
in
pkgs.testers.runNixOSTest {
  name = "contestant";

  node.specialArgs = { inherit self inputs system vars; };
  # images/common.nix sets nixpkgs.config (allowUnfree, permittedInsecurePackages
  # for squid), which runNixOSTest's default node.pkgs would otherwise make
  # read-only.
  node.pkgsReadOnly = false;

  nodes.machine = {
    imports = [
      ../../images/contestant
      ../../images/common.nix
    ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

  '' + lib.concatMapStrings subtestScript subtests;
}
