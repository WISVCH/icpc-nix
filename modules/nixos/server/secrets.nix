{ config, lib, ... }:

let
  cfg = config.modules.server.secrets;
in
{
  options.modules.server.secrets = {
    file = lib.mkOption {
      type = lib.types.path;
      default = ../../../secrets/dev.yaml;
      description = ''
        The sops file this host's secrets are read from.

        Defaults to the dev file, whose key ships in the image and whose
        values are throwaway - see secrets/README.md. Production overrides
        this (together with ageKeyFile and shipDevKey) to point at a file
        encrypted to a key that never enters this repo.
      '';
    };

    shipDevKey = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install secrets/dev-age-key.txt at ageKeyFile.

        On by default because the dev key is public by design and the whole
        point of shipping it is that the real decryption path runs on VM 303
        and in CI rather than being stubbed out. Production turns this off
        and places its own key out of band.
      '';
    };

    ageKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/sops/dev-age-key.txt";
      description = ''
        Path to the age identity that decrypts `file`.

        sops-nix types this as `pathNotInStore` and rejects a store path
        outright, which is the right guard even here: it refuses to let a
        decryption key sit in the world-readable Nix store, whether or not
        this particular key is worthless. So the dev key is copied out of the
        store to /etc at activation (see shipDevKey) rather than referenced
        where it lies.
      '';
    };
  };

  config = {
    # mode makes this a real copy at /etc rather than the default symlink
    # into the store - which is what gets it past sops-nix's pathNotInStore
    # check, and incidentally stops it being world-readable on the running
    # host.
    environment.etc."sops/dev-age-key.txt" = lib.mkIf cfg.shipDevKey {
      source = ../../../secrets/dev-age-key.txt;
      mode = "0400";
    };

    # sops-nix orders setupSecrets after specialfs/users/groups but says
    # nothing about NixOS's own "etc" script, which is what writes the key
    # above. Today that works out anyway - activation scripts with equal
    # dependencies run in attribute-name order and "etc" sorts before
    # "setupSecrets" - but relying on alphabetical luck for "the decryption
    # key exists before we decrypt" is not a thing to leave implicit.
    system.activationScripts.setupSecrets.deps = lib.mkIf cfg.shipDevKey [ "etc" ];

    sops.defaultSopsFile = cfg.file;
    sops.age.keyFile = cfg.ageKeyFile;
    # Without this sops-nix invents a key on first boot when none is found,
    # which would silently produce a host that can't read the secrets it was
    # built with.
    sops.age.generateKey = false;

    # Container credentials go through env files rather than
    # `environment = { ... }` on the container: oci-containers writes that
    # straight into the systemd unit, which lands world-readable in the Nix
    # store. These land in /run/secrets at 0400 root instead.
    sops.secrets.mariadb_env = { };
    sops.secrets.domserver_env = { };
    sops.secrets.pdns_api_key = { };

    # PowerDNS wants its API key inline in a config file, so the file has to
    # be rendered at activation with the decrypted value spliced in -
    # pkgs.writeText would put the key in the store. Mirrors chipcie-dns's
    # own powerdns/pdns.conf, including the zone already baked into the
    # image's sqlite database at build time.
    sops.templates."pdns.conf" = {
      content = ''
        launch=gsqlite3
        gsqlite3-database=/var/lib/powerdns/pdns.sqlite3
        default-soa-content=chipcie.ch.tudelft.nl dnsmaster.@ 0 10800 3600 604800 3600
        api=yes
        webserver=yes
        webserver-address=0.0.0.0
        webserver-allow-from=0.0.0.0/0
        api-key=${config.sops.placeholder.pdns_api_key}
      '';
      # Read by the pdns container, which runs as root with --network=host.
      mode = "0400";
    };
  };
}
