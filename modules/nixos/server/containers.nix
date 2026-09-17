{ config, pkgs, ... }:

# domserver + mariadb + chipcie-dns as OCI containers.
#
# Containers rather than native NixOS services because WISVCH/domjudge-packaging
# already owns this packaging and is where the judgehost/contestant language
# versions are kept in step (issue #61) - repackaging DOMjudge in nixpkgs would
# compete with it.
#
# The images themselves, with their pinned digests, live in ./images.nix so
# tests/ can reference the same derivations without restating a digest.
let
  images = import ./images.nix { inherit pkgs; };
in
{
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  # Host networking (rather than a podman bridge/pod) so mariadb and domserver
  # reach each other over 127.0.0.1 with no extra network setup, and so nginx
  # on the host can proxy to all of them the same way.
  virtualisation.oci-containers.containers.mariadb = {
    imageFile = images.mariadb;
    image = "mariadb:11";
    environmentFiles = [ config.sops.secrets.mariadb_env.path ];
    # mariadb's own default max_allowed_packet is too small for one of the
    # example problems (boolfind/fltcmp) domserver's first-boot install seeds
    # into its "demo" contest, which otherwise disconnects mid-import ("Got a
    # packet bigger than 'max_allowed_packet' bytes") and crashes domserver's
    # startup into a restart loop.
    cmd = [
      "--max-connections=1000"
      "--max-allowed-packet=512M"
      "--innodb_snapshot_isolation=OFF"
    ];
    extraOptions = [ "--network=host" ];
  };

  virtualisation.oci-containers.containers.domserver = {
    imageFile = images.domserver;
    image = "ghcr.io/wisvch/domjudge-packaging/domserver:packaging-e8150e1";
    environmentFiles = [ config.sops.secrets.domserver_env.path ];
    extraOptions = [ "--network=host" ];
    dependsOn = [ "mariadb" ];
  };

  # dependsOn may not be honored for the podman backend in every nixpkgs
  # release - pin the ordering explicitly too, since domserver's own startup
  # script only retries connecting to mariadb for ~90s.
  systemd.services."podman-domserver" = {
    after = [ "podman-mariadb.service" ];
    wants = [ "podman-mariadb.service" ];
  };

  # hostnames_api's own container CMD runs migrate + loaddata sticks +
  # runserver on every start, so all of chipcie-dns's real sticks.yaml
  # mappings are loaded with no extra provisioning here.
  virtualisation.oci-containers.containers.hostnames = {
    imageFile = images.hostnames;
    image = "ghcr.io/wisvch/chipcie-dns/hostnames:latest";
    extraOptions = [ "--network=host" ];
  };

  virtualisation.oci-containers.containers.pdns = {
    imageFile = images.pdns;
    image = "ghcr.io/wisvch/chipcie-dns/pdns:latest";
    extraOptions = [
      "--network=host"
      "-v"
      "${config.sops.templates."pdns.conf".path}:/etc/powerdns/pdns.conf:ro"
    ];
  };
}
