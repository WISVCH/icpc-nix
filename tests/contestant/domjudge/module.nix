# NixOS module for the ephemeral "domjudge" node used by
# tests/contestant/domjudge.nix: a real DOMjudge (domserver + mariadb, via
# the same WISVCH packaging images used elsewhere in this repo - see
# images/console/home/icpcadmin.nix's judgehost pull) running as containers,
# fronted by a native nginx that terminates TLS with a test-only cert (see
# cert.nix) so self_test's unmodified `https://` autologin check can trust it.
#
# NOTE: the `sha256` fields below are placeholders (lib.fakeSha256). Building
# this node for the first time will fail with a hash mismatch error that
# reports the correct value - paste it in and rebuild. This is the standard
# way to pin a `dockerTools.pullImage` fixed-output derivation; it wasn't
# done here because fetching ~250MB of image layers wasn't possible in this
# environment (see the PR description for details).
{ domjudgeIp, domjudgeUrl, cert }:
{ pkgs, lib, ... }:
let
  mariadbImage = pkgs.dockerTools.pullImage {
    imageName = "mariadb";
    imageDigest = "sha256:a75328dabed542a3b704efe54086071cb3f99e6a640cc8a18d7273bc4de2e5e7";
    sha256 = lib.fakeSha256;
    finalImageName = "mariadb";
    finalImageTag = "11";
  };

  domserverImage = pkgs.dockerTools.pullImage {
    imageName = "ghcr.io/wisvch/domjudge-packaging/domserver";
    imageDigest = "sha256:00b90f5e84b04aeb2cad4ed27a61e64c624c771a2687badfd5e1b09e3fc08a46";
    sha256 = lib.fakeSha256;
    finalImageName = "ghcr.io/wisvch/domjudge-packaging/domserver";
    finalImageTag = "packaging-e8150e1";
  };

  # Matches WISVCH/domjudge-packaging's docker/docker-compose.yml example.
  mysqlRootPassword = "domjudge";
  mysqlUser = "domjudge";
  mysqlPassword = "djpw";
  mysqlDatabase = "domjudge";
in
{
  networking.interfaces.eth1.ipv4.addresses = [
    { address = domjudgeIp; prefixLength = 24; }
  ];
  networking.firewall.allowedTCPPorts = [ 443 ];

  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  # Host networking (rather than a podman bridge/pod) so mariadb and
  # domserver can reach each other over 127.0.0.1 with no extra network
  # setup - simplest option for a single-VM, throwaway test instance.
  virtualisation.oci-containers.containers.mariadb = {
    imageFile = mariadbImage;
    image = "mariadb:11";
    environment = {
      MYSQL_ROOT_PASSWORD = mysqlRootPassword;
      MYSQL_USER = mysqlUser;
      MYSQL_PASSWORD = mysqlPassword;
      MYSQL_DATABASE = mysqlDatabase;
    };
    extraOptions = [ "--network=host" ];
  };

  virtualisation.oci-containers.containers.domserver = {
    imageFile = domserverImage;
    image = "ghcr.io/wisvch/domjudge-packaging/domserver:packaging-e8150e1";
    environment = {
      MYSQL_HOST = "127.0.0.1";
      MYSQL_DATABASE = mysqlDatabase;
      MYSQL_USER = mysqlUser;
      MYSQL_PASSWORD = mysqlPassword;
      MYSQL_ROOT_PASSWORD = mysqlRootPassword;
    };
    extraOptions = [ "--network=host" ];
    dependsOn = [ "mariadb" ];
  };

  # dependsOn (above) may not be honored for the podman backend in every
  # nixpkgs release - pin the ordering explicitly too, since domserver's own
  # startup script only retries connecting to mariadb for ~90s.
  systemd.services."podman-domserver" = {
    after = [ "podman-mariadb.service" ];
    wants = [ "podman-mariadb.service" ];
  };

  services.nginx = {
    enable = true;
    virtualHosts.${domjudgeUrl} = {
      onlySSL = true;
      sslCertificate = cert.cert;
      sslCertificateKey = cert.key;
      locations."/".proxyPass = "http://127.0.0.1:80";
    };
  };
}
