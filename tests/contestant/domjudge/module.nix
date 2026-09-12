# NixOS module for the ephemeral "domjudge" node used by
# tests/contestant/domjudge.nix: a real DOMjudge (domserver + mariadb, via
# the same WISVCH packaging images used elsewhere in this repo - see
# images/console/home/icpcadmin.nix's judgehost pull) running as containers,
# fronted by a native nginx that terminates TLS with a test-only cert (see
# cert.nix) so self_test's unmodified `https://` autologin check can trust it.
#
# Also hosts hostnames_api and pdns (see tests/contestant/hostname.nix) -
# production co-locates all three behind the same judge_ip (see
# images/contestant/firewall.nix and vars.nix), so this ephemeral node
# mirrors that instead of standing up separate test nodes for them.
{ domjudgeIp, domjudgeUrl, cert, hostnamesApiUrl, hostnamesCert, dnsApiUrl, dnsCert }:
{ pkgs, lib, ... }:
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
  # were made public independently so no registry credentials are needed
  # here, same as the domserver image above.
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

  # The real chipcie-dns image bakes a production PowerDNS API key into
  # /etc/powerdns/pdns.conf. set_hostname.sh hardcodes API_KEY=changeme
  # (see the TODO next to it in images/contestant/files/scripts -
  # the real key can't be baked into this public repo until proper
  # secrets handling exists), so this test-only config just matches that
  # stub instead of touching the script. Everything else here mirrors
  # chipcie-dns/powerdns/pdns.conf, including the zone already baked into
  # the image's sqlite database at build time.
  pdnsConf = pkgs.writeText "pdns.conf" ''
    launch=gsqlite3
    gsqlite3-database=/var/lib/powerdns/pdns.sqlite3
    default-soa-content=chipcie.ch.tudelft.nl dnsmaster.@ 0 10800 3600 604800 3600
    api=yes
    webserver=yes
    webserver-address=0.0.0.0
    webserver-allow-from=0.0.0.0/0
    api-key=changeme
  '';

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

  # nixosTest's ~1GB default is nowhere near enough to run mariadb and a
  # PHP-FPM/nginx DOMjudge stack at the same time - CI observed mariadb's own
  # startup healthcheck timing out and exiting under that default, taking
  # podman-domserver.service down with it (dependsOn). Bumped further after
  # adding hostnames/pdns alongside them - CI observed the (otherwise
  # trivial) hostnames image taking well over two minutes just to load
  # under contention from mariadb/domserver's own migration work.
  virtualisation.memorySize = 6144;
  virtualisation.cores = 3;
  virtualisation.diskSize = 8192;

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
      "${pdnsConf}:/etc/powerdns/pdns.conf:ro"
    ];
  };

  services.nginx = {
    enable = true;
    virtualHosts = {
      ${domjudgeUrl} = {
        onlySSL = true;
        sslCertificate = cert.cert;
        sslCertificateKey = cert.key;
        locations."/".proxyPass = "http://127.0.0.1:80";
      };
      ${hostnamesApiUrl} = {
        onlySSL = true;
        sslCertificate = hostnamesCert.cert;
        sslCertificateKey = hostnamesCert.key;
        # hostnames_api runs with DEBUG=False and ALLOWED_HOSTS =
        # ["chipcie.ch.tudelft.nl", "127.0.0.1"] (see chipcie-dns/hostnames/
        # hostnames/settings.py) - Django validates the Host header it
        # actually receives, so this must match "127.0.0.1" regardless of
        # what nginx's own default Host-forwarding behavior would send.
        locations."/" = {
          proxyPass = "http://127.0.0.1:8000";
          extraConfig = "proxy_set_header Host 127.0.0.1;";
        };
      };
      ${dnsApiUrl} = {
        onlySSL = true;
        sslCertificate = dnsCert.cert;
        sslCertificateKey = dnsCert.key;
        locations."/".proxyPass = "http://127.0.0.1:8081";
      };
    };
  };
}
