# Generic nixosTest harness for the contestant image, plus a temporary
# DOMjudge instance ("domjudge" node) that tests needing a real DOMjudge to
# authenticate against can use (see domjudge.nix). Both nodes boot exactly
# once; every check below runs as a subtest against that single boot instead
# of spinning up a fresh VM (or VMs) per check. To add a new check (see
# issue #20's checklist - printing, domjudge, proxy, language versions, ...),
# add a fragment file exporting `{ name, script }` and list it in `subtests`
# below.
{ pkgs, self, inputs, system, vars }:

let
  lib = pkgs.lib;

  # The contestant image bakes vars.domjudge_url and vars.judge_ip into the
  # egress allowlist, the self_test script, etc. Point both at the ephemeral
  # "domjudge" node instead of the real production host, so the whole
  # allow-list/autologin path gets exercised against something this test
  # actually controls.
  domjudgeUrl = "domjudge.icpc-nix.test";
  domjudgeIp = "192.168.1.1";
  machineIp = "192.168.1.2";
  testVars = vars // { domjudge_url = domjudgeUrl; judge_ip = domjudgeIp; };

  domjudgeCert = import ../domjudge/cert.nix {
    inherit pkgs;
    commonName = domjudgeUrl;
  };

  subtests = [
    # Must run before firewall.nix: firewall.nix's regression test leaves
    # DOMjudge autologin credentials configured on "machine" as a side
    # effect, which would break this subtest's "not configured yet"
    # assertion.
    (import ./domjudge.nix { inherit domjudgeUrl; })
    (import ./firewall.nix { inherit pkgs self inputs system vars; })
    (import ./usbguard.nix { inherit pkgs self inputs system vars; })
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
  # hang for the full default hour before the framework gives up. Raised
  # from the original 10 minutes to cover the "domjudge" node's mariadb +
  # domserver container boot, DB install/migration, and REST seeding.
  globalTimeout = 25 * 60;

  node.specialArgs = { inherit self inputs system; vars = testVars; };
  # images/common.nix sets nixpkgs.config.allowUnfree, which runNixOSTest's
  # default node.pkgs would otherwise make read-only.
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

    # images/contestant/base.nix forces networking.useDHCP = true globally;
    # left at its default (null -> inherits that global true) for eth1,
    # the static address below silently never gets applied at all (no
    # network-addresses-eth1 unit even runs) - confirmed by CI, where
    # "domjudge" (no such override) got its static IP fine but "machine"
    # never did, leaving it with no route to "domjudge" whatsoever.
    networking.interfaces.eth1.useDHCP = lib.mkForce false;
    networking.interfaces.eth1.ipv4.addresses = [
      { address = machineIp; prefixLength = 24; }
    ];
    networking.extraHosts = "${domjudgeIp} ${domjudgeUrl}\n";

    # Trust the "domjudge" node's test-only cert, so self_test's unmodified,
    # `-k`-less `curl https://@domjudge_url@/...` autologin check succeeds.
    security.pki.certificateFiles = [ domjudgeCert.cert ];
  };

  nodes.domjudge = import ../domjudge/module.nix {
    inherit domjudgeIp domjudgeUrl;
    cert = domjudgeCert;
  };

  # Deliberately not waiting on multi-user.target: it pulls in unrelated
  # units (firstboot self-test, cups printer detection, the GUI/login
  # chain) that don't need to succeed for these checks and have already
  # been observed to hang boot indefinitely in this VM. Each subtest waits
  # for exactly the units it needs instead.
  testScript = lib.concatMapStrings subtestScript subtests;
}
