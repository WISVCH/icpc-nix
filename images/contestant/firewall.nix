{ pkgs, lib, vars, ... }:
let
  inherit (vars) domjudge_url;
in
{
  networking.proxy.default = "http://127.0.0.1:3128";
  networking.proxy.noProxy = "localhost,127.0.0.1";

  boot.kernelParams = [ "net.ipv4.ip_forward=1" "net.ipv6.conf.all.forwarding=1" "net.ipv4.conf.all.send_redirects=0" ];

  # Seed a real, writable placeholder so squid's `include` below can always
  # parse, even before set_domjudge_creds.sh has ever run. Type "f" only
  # creates the file if it's missing, so a later rebuild never clobbers
  # credentials set_domjudge_creds.sh has already written. A NixOS-managed
  # environment.etc entry here would make this path a read-only Nix-store
  # symlink, which conflicts with set_domjudge_creds.sh's runtime `cat >` /
  # chmod / chown on this same path (see
  # images/contestant/files/scripts/set_domjudge_creds.sh) - that conflict
  # is why the include below was previously commented out instead of fixed.
  systemd.tmpfiles.rules = [
    "f /etc/squid/autologin.conf 0640 squid squid - #placeholder"
  ];

  networking.nftables = {
    enable = true;
    # preCheckRuleset = "sed 's/skuid contestant/skuid nouser/g' -i ruleset.conf";
    checkRuleset = false;
    ruleset = ''
      #!/usr/sbin/nft -f

      # Define table and chains
      # table inet filter {
      #     chain input {
      #         # type filter hook input priority 0; policy drop;
      #
      #         # Allow incoming SSH
      #         tcp dport 22 accept
      #     }
      #
      #     chain output {
      #         type filter hook output priority 0; policy accept;
      #
      #         # Allow localhost communication for IntelliJ/Eclipse
      #         ip saddr 127.0.0.1 ip daddr 127.0.0.1 accept
      #
      #         # Allow DNS communication to 127.0.0.53
      #         ip saddr 127.0.0.1 ip daddr 127.0.0.53 accept
      #     }
      # }
      
      table inet nat {
        chain output {
          type nat hook output priority 100;
          meta skuid contestant tcp dport 80 redirect to :3128
          meta skuid contestant tcp dport 443 redirect to :3128
        }
      }
      # Disable logging
      # table inet filter {
      #     chain input {
      #         log level off 
      #     }
      # }

    '';
  };

  systemd.services.squid.after = [ "resolvconf.service" ];
  services.squid = {
    enable = true;
    configText = ''
      http_port 3128
      
      pid_filename /run/squid.pid

      cache_log       syslog
      access_log      stdio:/var/log/squid/access.log
      cache_store_log stdio:/var/log/squid/store.log

      cache_effective_user squid squid

      dns_nameservers 8.8.8.8 1.1.1.1

      acl SSL_ports port 443
      acl Safe_ports port 8080
      acl Safe_ports port 80          # http
      acl Safe_ports port 21          # ftp
      acl Safe_ports port 443         # https
      acl Safe_ports port 70          # gopher
      acl Safe_ports port 210         # wais
      acl Safe_ports port 1025-65535  # unregistered ports
      acl Safe_ports port 280         # http-mgmt
      acl Safe_ports port 488         # gss-http
      acl Safe_ports port 591         # filemaker
      acl Safe_ports port 777         # multiling http
      acl CONNECT method CONNECT

      http_access deny !Safe_ports
      http_access deny CONNECT !SSL_ports

      #
      http_access deny manager
      # http_access allow all
      
      shutdown_lifetime 1 second

      acl allowed_urls dstdomain .${domjudge_url}
      acl allowed_urls dstdomain .hostnames.chipcie.ch.tudelft.nl
      acl allowed_urls dstdomain .pdns.chipcie.ch.tudelft.nl
      acl allowed_urls dstdomain localhost

      acl autologin url_regex ^http://${domjudge_url}/login
      acl autologin url_regex ^https://${domjudge_url}/login

      include /etc/squid/autologin.conf

      http_access allow allowed_urls
      http_access deny all

      deny_info http://localhost:8080/block.html all
    '';
  };
}
