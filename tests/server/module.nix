{ serverIp, cert }:
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# The "server" node for every suite under tests/.
#
# This imports modules/nixos/server - the *production* module (docs/adr/0006)
# - and only overrides what a throwaway VM genuinely needs: an address, a
# resource budget, and a certificate that exists at build time so the client
# nodes can be made to trust it. It replaces tests/domjudge/module.nix, which
# restated domserver/mariadb/hostnames/pdns/nginx by hand and could drift from
# the real host without anything noticing. That drift is what issue #61 is
# about.
#
# Everything not overridden here - the container digests, the nginx vhosts,
# the sops decryption path, the firewall - is exercised exactly as production
# has it.
let
  images = import ../../modules/nixos/server/images.nix { inherit pkgs inputs; };

in
{
  imports = [ ../../modules/nixos/server ];

  # nixosTest's default eth1 auto-addressing (virtualisation.vlans = [1])
  # assigns IPs by alphabetical node-name order, not by the IPs the suites
  # pass in here - so a node can end up owning an address it's trying to
  # reach, and route to itself (the kernel's local table wins) instead of
  # across the virtual LAN. Declaring eth1 explicitly (assignIP defaults
  # false) opts out of that entirely, so only the address below applies.
  virtualisation.interfaces.eth1.vlan = 1;

  # modules/nixos/server/base.nix forces networking.useDHCP = true globally,
  # exactly as the console and contestant base modules do. Left at its
  # default (null -> inherits that global true) for eth1, the static address
  # below silently never gets applied at all - no network-addresses-eth1 unit
  # even runs. The old tests/domjudge/module.nix needed no such override
  # because it wasn't built on a base module that forced DHCP; this one is.
  networking.interfaces.eth1.useDHCP = lib.mkForce false;
  networking.interfaces.eth1.ipv4.addresses = [
    {
      address = serverIp;
      prefixLength = 24;
    }
  ];

  # Was 6144 while this node was a bespoke test fixture. Lowered deliberately
  # when the suites merged and three VMs became co-resident; if mariadb's
  # startup healthcheck starts timing out, or domserver's mariadb "goes away"
  # mid-request, that is this number and not a real regression.
  virtualisation.memorySize = 2048;
  virtualisation.cores = 2;
  virtualisation.diskSize = 8192;

  # Schema and default data only, skipping DOMjudge's example data - the demo
  # contest, its example problems and their jury solutions. The domserver
  # image ships DJ_DB_INSTALL_BARE=0, and importing all of that is the bulk of
  # the ~100s this node spends in podman-domserver's first start (it is also
  # where every "Annotated result ... does not match directory" and
  # "unknown language" warning in the logs comes from).
  #
  # Nothing under tests/ uses it: each suite creates its own icpcnixtest
  # contest, sum problem and submissions. The testteam account both suites
  # seed with "team_id": "1" still resolves, because DOMjudge's *default*
  # fixtures create team 1 themselves ("DOMjudge", in the system category -
  # webapp/src/DataFixtures/DefaultData/TeamFixture.php); example data only
  # adds a second team next to it.
  #
  # This is the one place these suites deliberately stop exercising the
  # production install path, so it is worth knowing that is the trade: the
  # real server still installs with example data, and nothing tests that.
  virtualisation.oci-containers.containers.domserver.environment.DJ_DB_INSTALL_BARE = "1";

  # Load each image in its own unit, up front, instead of letting the
  # container units load them in preStart.
  #
  # The problem being fixed is an ordering one, not a throughput one:
  # oci-containers puts `podman load` in preStart, and containers.nix orders
  # podman-domserver after podman-mariadb (deliberately - domserver's startup
  # only retries mariadb for ~90s). So domserver's *image load* inherited a
  # constraint only its *container start* needs, and did not begin until
  # t=152, finishing at t=237 - which is when the unit the whole suite waits
  # on could finally start. Loading here decouples the two.
  #
  # One unit per image, deliberately concurrent. A single unit loading all
  # four sequentially was measured and is worse on both counts: the loads are
  # I/O-latency-bound and overlap productively, so serialising them took the
  # total from ~203s to ~309s, and making every container wait on one unit
  # meant domserver could not start until hostnames and pdns - which nothing
  # waits on - had loaded too, pushing container start from t=237 out to
  # t=340. Each container now waits only for its own image.
  systemd.services =
    lib.mapAttrs' (
      name: image:
      lib.nameValuePair "preload-image-${name}" {
        description = "Load the ${name} container image into podman storage";
        wantedBy = [ "multi-user.target" ];
        path = [ config.virtualisation.podman.package ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = "podman load -i ${image}";
      }
    ) images
    // lib.mapAttrs' (
      name: _:
      lib.nameValuePair "podman-${name}" {
        requires = [ "preload-image-${name}.service" ];
        after = [ "preload-image-${name}.service" ];
      }
    ) images;

  # With imageFile unset, oci-containers' preStart neither loads nor pulls -
  # its only network call is an optional registry login, which this module does
  # not configure. pull = "never" then makes the reliance on those units
  # explicit: if a preload ever fails, the container fails loudly instead of
  # quietly reaching for a registry that a test VM cannot route to anyway.
  #
  # Unsetting imageFile does make the module add network-online.target to each
  # container unit (it assumes an unset imageFile means "pull at runtime"),
  # which is harmless here but is why these units gained that dependency.
  virtualisation.oci-containers.containers.domserver.imageFile = lib.mkForce null;
  virtualisation.oci-containers.containers.domserver.pull = "never";
  virtualisation.oci-containers.containers.mariadb.imageFile = lib.mkForce null;
  virtualisation.oci-containers.containers.mariadb.pull = "never";
  virtualisation.oci-containers.containers.hostnames.imageFile = lib.mkForce null;
  virtualisation.oci-containers.containers.hostnames.pull = "never";
  virtualisation.oci-containers.containers.pdns.imageFile = lib.mkForce null;
  virtualisation.oci-containers.containers.pdns.pull = "never";

  # A cert generated at first boot (the module's own default) can't be known
  # at build time, so the client nodes would have nothing to trust. Supply
  # one from the store instead and turn the generator off.
  modules.server.tls.selfSign = false;
  modules.server.tls.certificate = cert.cert;
  modules.server.tls.certificateKey = cert.key;
}
