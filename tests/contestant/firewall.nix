{ ... }:

# Subtest fragment for tests/contestant/default.nix.
#
# Regression test for the contestant egress allowlist (docs/adr/0004): the
# `contestant` user must be default-denied at the nftables output chain
# except loopback and the pinned judge-infrastructure/NTP destinations,
# while other users (icpcadmin/root) keep unrestricted egress - the whole
# point of replacing squid was to close the gaps (other TCP ports, UDP,
# direct DNS) that the old NAT-redirect-only rule left wide open.
{
  name = "firewall";
  script = ''
    machine.wait_for_unit("multi-user.target", timeout=120)

    # The generated ruleset actually loaded, with the shape we expect -
    # catches Nix-level mistakes (bad syntax, a rule silently missing)
    # independent of what the sandboxed test network can actually reach.
    ruleset = machine.succeed("nft list ruleset")
    assert "meta skuid contestant" in ruleset, "contestant scoping rule missing from nftables ruleset"
    assert "drop" in ruleset, "no default-drop rule found in nftables ruleset"

    # contestant can still reach an allowed same-host service (the
    # "oif lo accept" rule) - a policy mistake that drops everything would
    # fail this, distinct from the pinned judge IP itself, which the
    # sandboxed test network can't reach at all.
    machine.succeed(
        "python3 -m http.server 8000 --directory /tmp >/tmp/http-server.log 2>&1 &"
    )
    machine.wait_for_open_port(8000)
    machine.succeed(
        "su - contestant -c 'curl --fail --silent --show-error --max-time 5 "
        "http://localhost:8000/' >/dev/null"
    )

    # contestant cannot reach an arbitrary off-box destination at all: the
    # default-deny drops the packet silently, so curl times out (exit 28).
    # icpcadmin/root keep unrestricted egress, so the same request instead
    # reaches the test network's gateway and is actively refused (exit 7,
    # since nothing listens on this port there) - the different failure
    # mode is what proves this is the firewall dropping it, not simply
    # "nothing is there."
    gateway = machine.succeed("ip route show default | awk '{print $3}'").strip()

    status, _ = machine.execute(
        f"su - contestant -c 'curl --silent --max-time 3 http://{gateway}:9999/'"
    )
    assert status == 28, f"expected contestant's request to the gateway to be silently dropped (curl exit 28), got {status}"

    status, _ = machine.execute(
        f"curl --silent --max-time 3 http://{gateway}:9999/"
    )
    assert status == 7, f"expected icpcadmin/root's request to reach the gateway and be refused (curl exit 7), got {status}"

    # set_domjudge_creds.sh lost its squid-specific tail (mkdir/cat into
    # /etc/squid/autologin.conf, chown, systemctl restart squid) when squid
    # was removed - confirm it still runs cleanly and still writes the
    # netrc credentials icpc_setup.sh and the submit CLI both rely on.
    machine.succeed("/icpc/scripts/set_domjudge_creds.sh testteam testpass")
    machine.succeed("grep -q 'login testteam password testpass' /icpc/netrc")
  '';
}
