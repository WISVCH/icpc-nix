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
  # The shared domjudge module (../domjudge/module.nix) also always hosts
  # hostnames_api/pdns for tests/contestant/hostname.nix - this suite
  # doesn't test either, but still needs to supply real cert/URL values
  # since the module isn't parameterized to skip them.
  hostnamesApiUrl = "hostnames.icpc-nix.test";
  dnsApiUrl = "dns.icpc-nix.test";
  domjudgeIp = "192.168.1.1";
  consoleIp = "192.168.1.2";

  domjudgeCert = import ../domjudge/cert.nix {
    inherit pkgs;
    commonName = domjudgeUrl;
  };
  hostnamesCert = import ../domjudge/cert.nix {
    inherit pkgs;
    commonName = hostnamesApiUrl;
  };
  dnsCert = import ../domjudge/cert.nix {
    inherit pkgs;
    commonName = dnsApiUrl;
  };

  # judgehost.nix must run first: submissions.nix needs a real judgehost
  # registered to actually judge anything.
  subtests = [
    (import ./judgehost.nix { inherit domjudgeIp domjudgeUrl domjudgeCert; })
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

    # nixosTest's ~1GB default is nowhere near enough for a full XFCE
    # desktop plus a nested, privileged judgehost container that itself
    # compiles/runs JVM-based submissions - CI observed domserver's own
    # mariadb dying mid-request ("MySQL server has gone away") under the
    # resulting memory pressure, which looks like host-level contention
    # bleeding into the sibling "domjudge" node. Same rationale as
    # ../domjudge/module.nix's own bump for its heavier-than-default needs.
    virtualisation.memorySize = 4096;
    virtualisation.cores = 2;

    # images/console/base.nix forces networking.useDHCP = true globally;
    # left at its default (null -> inherits that global true) for eth1, the
    # static address below would otherwise silently never get applied - see
    # tests/contestant/default.nix's identical comment for how this was
    # confirmed in CI for that image.
    networking.interfaces.eth1.useDHCP = lib.mkForce false;
    networking.interfaces.eth1.ipv4.addresses = [
      { address = consoleIp; prefixLength = 24; }
    ];
    # judgehost.nix's container uses --network=host, so it resolves
    # domjudgeUrl through whatever this VM itself resolves it to.
    networking.extraHosts = "${domjudgeIp} ${domjudgeUrl}\n";
  };

  nodes.domjudge = import ../domjudge/module.nix {
    inherit domjudgeIp domjudgeUrl hostnamesApiUrl dnsApiUrl;
    cert = domjudgeCert;
    inherit hostnamesCert dnsCert;
  };

  testScript = lib.concatMapStrings subtestScript subtests;
}
