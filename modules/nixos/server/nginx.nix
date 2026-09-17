{
  config,
  lib,
  pkgs,
  vars,
  ...
}:

let
  cfg = config.modules.server.tls;
in
{
  options.modules.server.tls = {
    certificate = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/server-tls/cert.pem";
      description = ''
        TLS certificate nginx serves for all three vhosts.

        The default is generated on first boot as a self-signed cert covering
        every name below (see the server-tls-cert unit). That is right for
        VM 303, which has no public DNS and so can't complete an ACME
        challenge; production points this at a real certificate instead.
      '';
    };

    certificateKey = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/server-tls/key.pem";
      description = "Private key for modules.server.tls.certificate.";
    };

    selfSign = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Generate a self-signed certificate at the paths above on first boot if
        one isn't already there. Turn this off when supplying a real
        certificate, so nothing can quietly overwrite it.
      '';
    };
  };

  config = {
    # Every deploy to VM 303 overwrites the whole disk (docs/adr/0006), so
    # this regenerates each time and clients see a new cert. That's expected
    # for a staging box; it's also why this is an option rather than
    # hardcoded.
    systemd.services.server-tls-cert = lib.mkIf cfg.selfSign {
      description = "Generate a self-signed TLS certificate for nginx";
      requiredBy = [ "nginx.service" ];
      before = [ "nginx.service" ];
      path = [ pkgs.openssl ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        mkdir -p "$(dirname ${cfg.certificate})"
        if [ ! -s ${cfg.certificate} ]; then
          openssl req -x509 -newkey rsa:2048 -nodes \
            -keyout ${cfg.certificateKey} -out ${cfg.certificate} \
            -days 3650 -subj "/CN=${vars.domjudge_url}" \
            -addext "subjectAltName=DNS:${vars.domjudge_url},DNS:${vars.hostnames_api},DNS:${vars.dns_api}"
        fi
        chmod 0640 ${cfg.certificateKey}
        chgrp ${config.services.nginx.group} ${cfg.certificateKey}
      '';
    };

    services.nginx = {
      enable = true;
      virtualHosts = {
        ${vars.domjudge_url} = {
          onlySSL = true;
          sslCertificate = cfg.certificate;
          sslCertificateKey = cfg.certificateKey;
          locations."/".proxyPass = "http://127.0.0.1:80";
        };

        ${vars.hostnames_api} = {
          onlySSL = true;
          sslCertificate = cfg.certificate;
          sslCertificateKey = cfg.certificateKey;
          # hostnames_api runs with DEBUG=False and ALLOWED_HOSTS =
          # ["chipcie.ch.tudelft.nl", "127.0.0.1"] (see chipcie-dns/hostnames/
          # hostnames/settings.py) - Django validates the Host header it
          # actually receives, so this must match "127.0.0.1" regardless of
          # what nginx's default Host-forwarding would send.
          locations."/" = {
            proxyPass = "http://127.0.0.1:8000";
            extraConfig = "proxy_set_header Host 127.0.0.1;";
          };
        };

        ${vars.dns_api} = {
          onlySSL = true;
          sslCertificate = cfg.certificate;
          sslCertificateKey = cfg.certificateKey;
          locations."/".proxyPass = "http://127.0.0.1:8081";
        };
      };
    };
  };
}
