{
  pkgs,
  self,
  inputs,
  system,
  vars,
  languages,
}:

# Shared wiring for every suite under tests/: the node definitions, the
# addresses they reach each other on, the test certificate, and the runner
# that turns a list of subtest fragments into a nixosTest.
#
# Three suites are built from this:
#   tests/all       - server + console + contestant, what CI runs
#   tests/console   - server + console, for iterating on one image
#   tests/contestant - server + contestant, likewise
#
# The per-image suites exist because the merged one takes roughly twice as
# long to fail: when you're debugging one image you want the short loop back.
# They compose the *same* fragments as the merged suite, so there's one
# definition of each check, not two.
let
  lib = pkgs.lib;

  domjudgeUrl = "domjudge.icpc-nix.test";
  serverIp = "192.168.1.1";
  consoleIp = "192.168.1.2";
  contestantIp = "192.168.1.3";

  inherit (vars) hostnames_api dns_api dns_zone;

  # The contestant image bakes vars.domjudge_url and vars.judge_ip into the
  # egress allowlist, the self_test script, etc; modules/nixos/server derives
  # its nginx vhost names from the same vars. Overriding both here points the
  # whole allowlist/autologin/vhost path at the ephemeral "server" node
  # instead of the real production host.
  #
  # firewall.nix resolves vars.hostnames_api/vars.dns_api to vars.judge_ip
  # (see modules/nixos/contestant/firewall.nix) exactly the same way it
  # resolves domjudge_url, so overriding judge_ip routes those at the server
  # node too, with no separate vars needed.
  testVars = vars // {
    domjudge_url = domjudgeUrl;
    judge_ip = serverIp;
  };

  # One cert, three names - see server/cert.nix.
  cert = import ./server/cert.nix {
    inherit pkgs;
    names = [
      domjudgeUrl
      hostnames_api
      dns_api
    ];
  };

  # A real serial/hostname pair from chipcie-dns's own
  # hostnames_api/fixtures/sticks.yaml, baked into the hostnames image the
  # server node pulls - see tests/contestant/hostname.nix.
  testSerial = "050157c4c93bb6047912ac42cfb1d3f4e02d2b78412d9bec99236cad3693ef69b2b700000000000000000000f5642fe4ff8c1310815581077faa8e76";
  testHostname = "pc1";

  serverNode = import ./server/module.nix { inherit serverIp cert; };

  consoleNode = { config, lib, ... }: {
    imports = [
      ../modules/nixos/console
      ../modules/nixos/common
      ../hosts/console/users/icpcadmin.nix
      ../hosts/console/users/icpctools.nix
      ../hosts/console/users/judgehost.nix
    ];

    # Was 4096 while this suite ran on its own. See the note on the server
    # node's memorySize: three co-resident VMs, deliberately lower budgets.
    virtualisation.memorySize = 2048;
    virtualisation.cores = 2;

    # Previously inherited from modules/nixos/common's boot.nix; that pin
    # moved to hosts/<host>/image.nix, so it's stated explicitly here rather
    # than falling back to nixosTest's "auto" sizing, which sizes only for
    # the closure - this node writes a container image and compiled
    # submissions at runtime.
    virtualisation.diskSize = 20 * 1024;

    virtualisation.interfaces.eth1.vlan = 1;
    networking.interfaces.eth1.useDHCP = lib.mkForce false;
    networking.interfaces.eth1.ipv4.addresses = [
      {
        address = consoleIp;
        prefixLength = 24;
      }
    ];
    # judgehost.nix's container uses --network=host, so it resolves
    # domjudgeUrl through whatever this VM itself resolves it to.
    networking.extraHosts = "${serverIp} ${domjudgeUrl}\n";

    # Load the judgehost image that icpcadmin's home stages
    # (modules/home-manager/icpcadmin/judgehost-image.nix) during boot rather
    # than from the test script. It was the single most expensive thing the
    # suite did: 1.2 GiB compressed, and dockerTools.pullImage writes a
    # docker-archive, which is uncompressed - so the script spent 143s copying
    # it into the VM and another 75s unpacking it, 218s of a 621s run, with
    # both already-booted nodes sitting idle throughout.
    #
    # As a boot unit it overlaps the server node's database install instead
    # (see start_all() in mkSuite). Test-only on purpose: issue #54 settled
    # that judgehost startup belongs to icpc-playbooks rather than this repo,
    # so the real console image deliberately does not do this.
    systemd.services.load-judgehost-image = {
      description = "Load the staged judgehost container image";
      requires = [ "docker.service" ];
      # The tarball is read through the path home-manager stages it at, not
      # its store path directly, so this still covers that staging actually
      # happened - which is part of what judgehost-connect is about.
      wants = [ "home-manager-icpcadmin.service" ];
      after = [
        "docker.service"
        "home-manager-icpcadmin.service"
      ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # No private copy first: the subtest used to `install -o judgehost`
        # one on the assumption that the judgehost user needed to own the
        # file, but /nix/store is world-readable and this loads into the
        # rootful daemon anyway.
        ExecStart = "${config.virtualisation.docker.package}/bin/docker load -i /home/icpcadmin/judgehost/judgehost.tar.gz";
      };
    };
  };

  contestantNode = { lib, pkgs, ... }: {
    imports = [
      ../modules/nixos/contestant
      ../modules/nixos/common
      ../hosts/contestant/users/contestant.nix
      ../hosts/contestant/users/icpcadmin.nix
      # The same language/IDE inventory the image ships - imported rather
      # than restated here, so this test can't silently drift from what
      # hosts/contestant/image.nix actually builds. Deliberately not
      # image.nix itself: its disk size and image.baseName mean nothing
      # inside a nixosTest VM.
      ../hosts/contestant/inventory.nix
    ];

    # The heaviest of the three: a full XFCE desktop plus five language
    # toolchains. It ran on nixosTest's default before, which is the smallest
    # budget of the three nodes for the largest image.
    virtualisation.memorySize = 4096;

    # Previously inherited from modules/nixos/common's boot.nix - see the
    # console node's identical comment.
    virtualisation.diskSize = 20 * 1024;

    # vmtouch.nix's warm-fs-cache service does `find / ... -print` to warm
    # the page cache on real hardware - pointless (and, empirically, slow
    # enough to keep multi-user.target from ever becoming active) in a
    # single-boot test VM.
    systemd.services.warm-fs-cache.enable = lib.mkForce false;

    # base.nix forces networking.useDHCP = true globally; left at its default
    # (null -> inherits that global true) for eth1, the static address below
    # silently never gets applied at all (no network-addresses-eth1 unit even
    # runs) - confirmed by CI, where the server node got its static IP fine
    # and this one never did, leaving it with no route to the server
    # whatsoever.
    virtualisation.interfaces.eth1.vlan = 1;
    networking.interfaces.eth1.useDHCP = lib.mkForce false;
    networking.interfaces.eth1.ipv4.addresses = [
      {
        address = contestantIp;
        prefixLength = 24;
      }
    ];
    networking.extraHosts = "${serverIp} ${domjudgeUrl}\n";

    # Trust the server node's test-only cert, so self_test's and
    # set_hostname.sh's unmodified, `-k`-less `curl https://...` calls
    # succeed against all three services it fronts.
    security.pki.certificateFiles = [ cert.cert ];

    # runNixOSTest hardcodes the root disk's own QEMU serial to the literal
    # string "root" (nixos/modules/virtualisation/qemu-vm.nix builds that
    # drives list itself, with no per-test override point), so
    # set_hostname.sh's `udevadm info | grep ID_SERIAL_SHORT` would otherwise
    # always read "root" here. Force it to a real serial from chipcie-dns's
    # fixtures instead - test-only, no production code changes needed.
    services.udev.packages = [
      (pkgs.writeTextDir "etc/udev/rules.d/10-spoof-test-serial.rules" ''
        KERNEL=="vda", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_SERIAL_SHORT}="${testSerial}"
      '')
    ];

    # firstboot.service (icpc.nix) only orders after network-online.target,
    # which this VM reaches via eth0's DHCP alone - it says nothing about
    # eth1's static address, which stays down until the domjudge-selftest
    # subtest explicitly starts network-addresses-eth1.service (see the
    # comment there). Without this, firstboot's set_hostname.sh call races
    # that and near-certainly runs before eth1 (and therefore
    # hostnames_api/dns_api, both only reachable over it) is up - and since
    # firstboot is a oneshot, a failed run never retries.
    systemd.services.firstboot = {
      after = [ "network-addresses-eth1.service" ];
      wants = [ "network-addresses-eth1.service" ];
    };
  };

  indent =
    script:
    lib.concatMapStrings (line: "    " + line + "\n") (
      lib.splitString "\n" (lib.removeSuffix "\n" script)
    );

  subtestScript = t: ''
    with subtest("${t.name}"):
    ${indent t.script}
  '';

  # Subtest fragments, in the one order that satisfies every constraint they
  # document between them:
  #
  #  - contestant's domjudge-selftest must precede firewall, which leaves
  #    DOMjudge credentials configured on the contestant node as a side
  #    effect and would break domjudge-selftest's "not configured yet"
  #    assertion.
  #  - console's judgehost must precede submissions, which needs a registered
  #    judgehost to judge anything.
  #
  # Contestant first, then console: both now share a single domserver, and
  # contestant's assertions are about a DOMjudge nothing else has touched.
  contestantSubtests = [
    (import ./contestant/domjudge.nix { inherit domjudgeUrl; })
    (import ./contestant/hostname.nix { inherit dns_zone testHostname; })
    (import ./contestant/firewall.nix {
      inherit
        pkgs
        self
        inputs
        system
        vars
        ;
    })
    (import ./contestant/usbguard.nix {
      inherit
        pkgs
        self
        inputs
        system
        vars
        ;
    })
    (import ./contestant/languages.nix { inherit languages; })
  ];

  consoleSubtests = [
    (import ./console/judgehost.nix {
      inherit domjudgeUrl;
      domjudgeIp = serverIp;
      domjudgeCert = cert;
    })
    (import ./console/submissions.nix { inherit pkgs; })
  ];

  mkSuite =
    {
      name,
      nodes,
      subtests,
      globalTimeout,
    }:
    pkgs.testers.runNixOSTest {
      inherit name globalTimeout nodes;

      node.specialArgs = {
        inherit
          self
          inputs
          system
          languages
          ;
        vars = testVars;
      };
      # modules/nixos/common sets nixpkgs.config.allowUnfree, which
      # runNixOSTest's default node.pkgs would otherwise make read-only.
      node.pkgsReadOnly = false;

      # Deliberately not waiting on multi-user.target anywhere: it pulls in
      # units (firstboot self-test, cups printer detection, the GUI/login
      # chain) that don't need to succeed for these checks and have been
      # observed to hang boot indefinitely. Each subtest waits for exactly
      # the units it needs instead.
      testScript = ''
        # The driver otherwise boots a node lazily, on the first command
        # addressed to it - so the three boots ran back to back (31s + 87s +
        # 40s of a 621s suite), and the console node did not start at all
        # until every contestant subtest had finished. Booting them together
        # overlaps that, and lets the console's judgehost image load (see
        # its node definition above) run while the server node is still
        # installing DOMjudge's database.
        #
        # Peak memory is unchanged - all three nodes were already co-resident
        # from judgehost-connect onwards, which is what the budgets above are
        # sized for. Peak *CPU* during boot does rise: if mariadb's startup
        # healthcheck starts timing out, this and that memorySize note are
        # where to look, not a real regression.
        start_all()
      ''
      + lib.concatMapStrings subtestScript subtests;
    };
in
{
  inherit
    serverNode
    consoleNode
    contestantNode
    contestantSubtests
    consoleSubtests
    mkSuite
    ;
}
