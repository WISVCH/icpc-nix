{ config, pkgs, ... }:

# domserver + mariadb + chipcie-dns as OCI containers, pinned by digest.
#
# Containers rather than native NixOS services because WISVCH/domjudge-packaging
# already owns this packaging and is where the judgehost/contestant language
# versions are kept in step (issue #61) - repackaging DOMjudge in nixpkgs would
# compete with it. The follow-up there is to build these images *from* that
# repo as a flake input instead of pulling fixed digests; the digests below are
# the same ones tests/domjudge/module.nix already pulls.
let
  mariadbImage = pkgs.dockerTools.pullImage {
    imageName = "mariadb";
    imageDigest = "sha256:a75328dabed542a3b704efe54086071cb3f99e6a640cc8a18d7273bc4de2e5e7";
    sha256 = "sha256-TN7daYQGIFfIpTd0Hq1K+M3sq2ZtvfkvL/UA+SA9CLo=";
    finalImageName = "mariadb";
    finalImageTag = "11";
  };

  domserverImage = pkgs.dockerTools.pullImage {
    imageName = "ghcr.io/wisvch/domjudge-packaging/domserver";
    imageDigest = "sha256:00b90f5e84b04aeb2cad4ed27a61e64c624c771a2687badfd5e1b09e3fc08a46";
    sha256 = "sha256-DmYsEara2YM++kz60qfuCwkXZRrBwW7tcajYK5Sc+yE=";
    finalImageName = "ghcr.io/wisvch/domjudge-packaging/domserver";
    finalImageTag = "packaging-e8150e1";
  };

  # Built from chipcie-dns's own Dockerfiles by its build-images workflow
  # (WISVCH/chipcie-dns#10) - that repo is private, but these two packages
  # were made public independently so no registry credentials are needed here,
  # same as the domserver image above.
  hostnamesImage = pkgs.dockerTools.pullImage {
    imageName = "ghcr.io/wisvch/chipcie-dns/hostnames";
    imageDigest = "sha256:55903382833d5127b9a464f3086a029fb44222d856e3d32263f1c2977c29fbb5";
    sha256 = "sha256-/w2ZBJYz9rjy4xgHrMf+Ewyu3DHpeSsCXjYwN0GuhWE=";
    finalImageName = "ghcr.io/wisvch/chipcie-dns/hostnames";
    finalImageTag = "latest";
  };

  pdnsImage = pkgs.dockerTools.pullImage {
    imageName = "ghcr.io/wisvch/chipcie-dns/pdns";
    imageDigest = "sha256:bfcbd99767aade60ab4579365df7c036af2bd069e142caabd5a528c21cf5c0df";
    sha256 = "sha256-NN4Q6MW0EWC4znN+TEW867VCbCnv7xlKPt8545W58FE=";
    finalImageName = "ghcr.io/wisvch/chipcie-dns/pdns";
    finalImageTag = "latest";
  };
in
{
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  # Host networking (rather than a podman bridge/pod) so mariadb and domserver
  # reach each other over 127.0.0.1 with no extra network setup, and so nginx
  # on the host can proxy to all of them the same way.
  virtualisation.oci-containers.containers.mariadb = {
    imageFile = mariadbImage;
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
    imageFile = domserverImage;
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
    imageFile = hostnamesImage;
    image = "ghcr.io/wisvch/chipcie-dns/hostnames:latest";
    extraOptions = [ "--network=host" ];
  };

  virtualisation.oci-containers.containers.pdns = {
    imageFile = pdnsImage;
    image = "ghcr.io/wisvch/chipcie-dns/pdns:latest";
    extraOptions = [
      "--network=host"
      "-v"
      "${config.sops.templates."pdns.conf".path}:/etc/powerdns/pdns.conf:ro"
    ];
  };
}
