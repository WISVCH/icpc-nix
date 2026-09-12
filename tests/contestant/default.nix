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
  # firewall.nix resolves vars.hostnames_api/vars.dns_api to vars.judge_ip
  # (see images/contestant/firewall.nix and vars.nix) exactly the same way
  # it resolves domjudge_url - overriding judge_ip here is enough to route
  # both at the "domjudge" node too, with no separate vars needed.
  testVars = vars // { domjudge_url = domjudgeUrl; judge_ip = domjudgeIp; };
  inherit (vars) hostnames_api dns_api dns_zone;

  domjudgeCert = import ./domjudge/cert.nix {
    inherit pkgs;
    commonName = domjudgeUrl;
  };
  hostnamesCert = import ./domjudge/cert.nix {
    inherit pkgs;
    commonName = hostnames_api;
  };
  dnsCert = import ./domjudge/cert.nix {
    inherit pkgs;
    commonName = dns_api;
  };

  # A real serial/hostname pair from chipcie-dns's own
  # hostnames_api/fixtures/sticks.yaml, baked into the hostnames image
  # this test pulls - see tests/contestant/hostname.nix.
  testSerial = "050157c4c93bb6047912ac42cfb1d3f4e02d2b78412d9bec99236cad3693ef69b2b700000000000000000000f5642fe4ff8c1310815581077faa8e76";
  testHostname = "pc1";

  subtests = [
    # Must run before firewall.nix: firewall.nix's regression test leaves
    # DOMjudge autologin credentials configured on "machine" as a side
    # effect, which would break this subtest's "not configured yet"
    # assertion.
    (import ./domjudge.nix { inherit domjudgeUrl; })
    (import ./hostname.nix { inherit dns_zone testHostname; })
    (import ./firewall.nix { inherit pkgs self inputs system vars; })
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

    # Trust the "domjudge" node's test-only certs, so self_test's and
    # set_hostname.sh's unmodified, `-k`-less `curl https://...` calls
    # succeed against all three ephemeral services.
    security.pki.certificateFiles = [ domjudgeCert.cert hostnamesCert.cert dnsCert.cert ];

    # runNixOSTest hardcodes the root disk's own QEMU serial to the literal
    # string "root" (nixos/modules/virtualisation/qemu-vm.nix builds that
    # drives list itself, with no per-test override point), so
    # set_hostname.sh's `udevadm info | grep ID_SERIAL_SHORT` would
    # otherwise always read "root" here. Force it to a real serial from
    # chipcie-dns's fixtures instead - test-only, no production code
    # changes needed.
    #
    # CI showed services.udev.extraRules (which NixOS places in a late
    # "99-local.rules") never taking effect here: the device's own
    # ID_SERIAL=root already gets set by an earlier persistent-storage
    # rule, which likely GOTOs past everything else for a recognized
    # virtio-blk device - including our own 99-numbered rule. Use
    # services.udev.packages instead to land in an early "10-"-numbered
    # file, so ours runs *before* that GOTO. (":=" was tried for good
    # measure too, to survive being overwritten downstream, but ENV{}
    # only accepts '==', '!=', '=' or '+=' - confirmed locally via
    # `udevadm verify`, which is also how this exact rule was checked
    # before pushing.)
    services.udev.packages = [
      (pkgs.writeTextDir "etc/udev/rules.d/10-spoof-test-serial.rules" ''
        KERNEL=="vda", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_SERIAL_SHORT}="${testSerial}"
      '')
    ];

    # firstboot.service (icpc.nix) only orders after network-online.target,
    # which this VM reaches via eth0's DHCP alone - it says nothing about
    # eth1's static address, which stays down until the domjudge-selftest
    # subtest explicitly starts network-addresses-eth1.service (see the
    # comment there). Without this, firstboot's now-uncommented
    # set_hostname.sh call races that and near-certainly runs before eth1
    # (and therefore hostnames_api/dns_api, both only reachable over it) is
    # up - and since firstboot is a oneshot, a failed run never retries.
    systemd.services.firstboot = {
      after = [ "network-addresses-eth1.service" ];
      wants = [ "network-addresses-eth1.service" ];
    };
  };

  nodes.domjudge = import ./domjudge/module.nix {
    inherit domjudgeIp domjudgeUrl;
    cert = domjudgeCert;
    hostnamesApiUrl = hostnames_api;
    dnsApiUrl = dns_api;
    hostnamesCert = hostnamesCert;
    dnsCert = dnsCert;
  };

  # Deliberately not waiting on multi-user.target: it pulls in unrelated
  # units (firstboot self-test, cups printer detection, the GUI/login
  # chain) that don't need to succeed for these checks and have already
  # been observed to hang boot indefinitely in this VM. Each subtest waits
  # for exactly the units it needs instead.
  testScript = lib.concatMapStrings subtestScript subtests;
}
