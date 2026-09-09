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

  # Fail fast: the full contestant image has plenty of unit dependency
  # chains (printer detection, the firstboot self-test, GUI/login) that were
  # never designed to resolve inside an isolated test VM and can otherwise
  # hang for the full default hour before the framework gives up.
  globalTimeout = 10 * 60;

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

    # vmtouch.nix's warm-fs-cache service does `find / ... -print` to warm
    # the page cache on real hardware - pointless (and, empirically, slow
    # enough to keep multi-user.target from ever becoming active) in a
    # single-boot test VM.
    systemd.services.warm-fs-cache.enable = lib.mkForce false;
  };

  # Deliberately not waiting on multi-user.target: it pulls in unrelated
  # units (firstboot self-test, cups printer detection, the GUI/login
  # chain) that don't need to succeed for these checks and have already
  # been observed to hang boot indefinitely in this VM. Each subtest waits
  # for exactly the units it needs instead.
  testScript = lib.concatMapStrings subtestScript subtests;
}
