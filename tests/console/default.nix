# Generic nixosTest harness for the console image, plus a temporary
# DOMjudge instance ("domjudge" node, shared with tests/contestant - see
# ../domjudge/module.nix) that this suite's checks judge real submissions
# against. Covers issue #54's "console judgehost" checklist: the console
# image's own pre-staged judgehost connects to a real domserver
# (judgehost.nix), and can actually judge submissions in every contestant
# language (submissions.nix).
#
# Both nodes boot exactly once; every check runs as a subtest against that
# single boot instead of spinning up a fresh VM per check - same rationale
# as tests/contestant/default.nix.
{ pkgs, self, inputs, system, vars }:

let
  lib = pkgs.lib;

  domjudgeUrl = "domjudge.icpc-nix.test";
  domjudgeIp = "192.168.1.1";
  consoleIp = "192.168.1.2";

  domjudgeCert = import ../domjudge/cert.nix {
    inherit pkgs;
    commonName = domjudgeUrl;
  };

  # judgehost.nix must run first: submissions.nix needs a real judgehost
  # registered to actually judge anything.
  subtests = nodes: [
    (import ./judgehost.nix {
      inherit domjudgeIp;
      judgehostUid = nodes.console.config.users.users.judgehost.uid;
    })
    (import ./submissions.nix { inherit pkgs; })
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
  name = "console";

  # See tests/contestant/default.nix's comment on globalTimeout: this
  # covers the "domjudge" node's mariadb + domserver container boot, DB
  # install/migration and REST seeding, plus judgehost registering and
  # actually compiling/running five languages' worth of submissions.
  globalTimeout = 25 * 60;

  node.specialArgs = { inherit self inputs system vars; };
  # images/common.nix sets nixpkgs.config.allowUnfree, which runNixOSTest's
  # default node.pkgs would otherwise make read-only.
  node.pkgsReadOnly = false;

  nodes.console = {
    imports = [
      ../../images/console
      ../../images/common.nix
    ];

    # images/console/base.nix forces networking.useDHCP = true globally;
    # left at its default (null -> inherits that global true) for eth1, the
    # static address below would otherwise silently never get applied - see
    # tests/contestant/default.nix's identical comment for how this was
    # confirmed in CI for that image.
    networking.interfaces.eth1.useDHCP = lib.mkForce false;
    networking.interfaces.eth1.ipv4.addresses = [
      { address = consoleIp; prefixLength = 24; }
    ];
  };

  nodes.domjudge = import ../domjudge/module.nix {
    inherit domjudgeIp domjudgeUrl;
    cert = domjudgeCert;
  };

  testScript = { nodes, ... }: lib.concatMapStrings subtestScript (subtests nodes);
}
