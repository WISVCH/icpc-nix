{ lib, pkgs, ... }:

{
  networking = {
    wireless.enable = false;
    useDHCP = lib.mkForce true;
    hostName = "chipcie-server";

    # 443 is nginx, which terminates TLS in front of domserver, hostnames_api
    # and the pdns HTTP API. 80 is domserver's own container (it binds the
    # host port directly, --network=host): judgehosts register over plain
    # HTTP and have no reason to deal with this host's certificate. 53 is
    # PowerDNS. The pdns API port (8081) and hostnames_api's port (8000) are
    # deliberately not opened - they're reachable only through nginx.
    firewall.allowedTCPPorts = [
      80
      443
      53
    ];
    firewall.allowedUDPPorts = [ 53 ];
  };

  users.mutableUsers = true;

  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "no";
  services.openssh.settings.PasswordAuthentication = true;

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  # sops is here so a human on the box can inspect/edit secrets/dev.yaml with
  # the same tooling CI and the module use, rather than guessing.
  environment.systemPackages = with pkgs; [
    jq
    htop
    curl
    wget
    unzip
    git
    sops
  ];
}
