{ ... }:

# Subtest fragment for tests/contestant/default.nix.
#
# Regression test for the squid.service startup failure caused by
# firewall.nix's `include /etc/squid/autologin.conf` referencing a file
# that environment.etc never created (see images/contestant/firewall.nix).
{
  name = "squid";
  script = ''
    machine.wait_for_unit("squid.service")
    machine.wait_for_open_port(3128)

    # Confirm squid actually proxies traffic, not just that the unit is
    # "active" - firewall.nix's ACL allows dstdomain "localhost", so a
    # local HTTP server doubles as an in-VM stand-in for an allowed
    # upstream without needing real internet access.
    machine.succeed(
        "python3 -m http.server 8000 --directory /tmp >/tmp/http-server.log 2>&1 &"
    )
    machine.wait_for_open_port(8000)
    machine.succeed(
        "curl --fail --silent --show-error --max-time 5 "
        "-x http://localhost:3128 http://localhost:8000/ >/dev/null"
    )

    # Regression test for the write-path conflict that the previous fix
    # attempt introduced: set_domjudge_creds.sh writes real credentials to
    # the same path (/etc/squid/autologin.conf) that firewall.nix seeds a
    # placeholder into via systemd.tmpfiles.rules, then chowns/chmods it and
    # restarts squid. That must not break squid.
    machine.succeed("/icpc/scripts/set_domjudge_creds.sh testteam testpass")
    machine.wait_for_unit("squid.service")
    machine.wait_for_open_port(3128)
  '';
}
