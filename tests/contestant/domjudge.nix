{ domjudgeUrl }:

# Subtest fragment for tests/contestant/default.nix.
#
# By the time this runs, the "domjudge" node (domjudge/module.nix) has
# already booted a real DOMjudge (domserver + mariadb). This subtest seeds a
# team account via DOMjudge's own accounts-import REST endpoint
# (users/accounts - see doc/manual/import.rst upstream), then drives
# self_test through both the "not configured yet" and "configured" states,
# covering issue #20's DOMjudge/autologin/team/room/proxy checklist items.
#
# The workstation is "configured" by calling set_teamname.sh/set_room.sh/
# set_domjudge_creds.sh directly rather than icpc_setup.sh (dead code - real
# configuration happens remotely via icpc-playbooks' configure_workstation
# Ansible playbook, which isn't available to this test and which itself just
# drives these same scripts).
{
  name = "domjudge-selftest";
  script = ''
    import re

    # This subtest runs before firewall.nix (which also exercises the
    # ruleset), so it can't rely on that subtest having already waited for
    # the unit.
    machine.wait_for_unit("nftables.service")

    # network-addresses-eth1.service (which actually assigns eth1 its static
    # IP - see default.nix) is enabled but only gets pulled in via
    # multi-user.target/network-setup.target, which this test deliberately
    # never waits for (see the comment at the bottom of default.nix - the
    # firstboot/cups/GUI chain hangs boot indefinitely in this VM). Confirmed
    # via CI: the unit exists but sits "inactive (dead)" with zero journal
    # entries indefinitely, leaving eth1 itself DOWN. Start it directly
    # rather than depend on ever reaching that target.
    machine.succeed("systemctl start network-addresses-eth1.service")
    print(machine.succeed("ip -4 addr show eth1"))

    domjudge.wait_for_unit("podman-mariadb.service")
    domjudge.wait_for_unit("podman-domserver.service")
    domjudge.wait_for_unit("nginx.service")

    print("Waiting for DOMjudge's database install/migration to finish...")
    domjudge.wait_until_succeeds(
        "curl --fail --silent http://127.0.0.1/api/v4/version", timeout=600
    )

    print("DOMjudge is up - seeding a test team account via users/accounts")
    # The TSV accounts format requires the username to encode an existing
    # team's numeric ID (CCS accounts.tsv spec - e.g. "team1"), which fails
    # to parse for a plain username and refuses to auto-create a team. The
    # JSON variant of the same endpoint takes an explicit team_id and, per
    # ImportExportService::importAccountData, auto-creates that team if it
    # doesn't exist yet - no pre-existing team or digit-encoded username
    # needed.
    domjudge.succeed(
        "printf '%s' "
        "'[{\"id\":\"testteam\",\"username\":\"testteam\",\"name\":\"Test Team\","
        "\"password\":\"testpass\",\"type\":\"team\",\"team_id\":\"1\"}]' "
        "> /tmp/accounts.json"
    )
    domjudge.succeed("podman cp /tmp/accounts.json domserver:/tmp/accounts.json")
    domjudge.succeed(
        "podman exec domserver "
        "/opt/domjudge/domserver/webapp/bin/console api:call "
        "-m POST -f json=/tmp/accounts.json users/accounts"
    )

    print("Running self_test before the workstation is configured")
    before = machine.succeed("/icpc/scripts/self_test")
    print(before)
    assert re.search(r"DOMjudge Autologin Configured\s+No", before), \
        "self_test should report autologin as not configured yet"
    assert re.search(r"Team Name\s+Not Set", before), \
        "self_test should report no team name yet"
    assert re.search(r"Room\s+Not Set", before), \
        "self_test should report no room yet"

    print("Configuring the workstation (team name, room, DOMjudge creds)")
    machine.succeed("/icpc/scripts/set_teamname.sh 'Test Team'")
    machine.succeed("/icpc/scripts/set_room.sh 'TZ-1'")
    machine.succeed("/icpc/scripts/set_domjudge_creds.sh testteam testpass")

    print("Running self_test after the workstation is configured")
    after = machine.succeed("/icpc/scripts/self_test")
    print(after)
    assert re.search(r"DOMjudge Autologin Configured\s+Yes", after), \
        "self_test should report a successful DOMjudge autologin"
    assert re.search(r"Team Login\s+testteam", after), \
        "self_test should report the configured DOMjudge team login"
    assert re.search(r"Team Name\s+Test Team", after), \
        "self_test should report the configured team name"
    assert re.search(r"Room\s+TZ-1", after), \
        "self_test should report the configured room"

    print("Checking the judge-infrastructure allow-list independently of self_test's own wording")
    machine.succeed(
        "su - contestant -c 'curl --fail --silent --show-error --max-time 5 "
        "https://${domjudgeUrl}/' >/dev/null"
    )

    # firewall.nix's nftables ruleset default-denies the contestant user to
    # everything except the pinned judge IP/NTP servers - there's no
    # HTTP-aware proxy left to redirect a disallowed request to a block
    # page (that only existed under the old squid-based design). A
    # non-allow-listed host like example.com doesn't even resolve, since
    # contestant has no DNS access at all - check curl's own exit status
    # (6 = couldn't resolve host) rather than a status code for that reason.
    print("Checking direct internet access is blocked for contestant")
    status, _ = machine.execute(
        "su - contestant -c 'curl -s --max-time 5 http://example.com'"
    )
    assert status == 6, \
        f"expected contestant's DNS lookup for a non-allow-listed host to fail (curl exit 6), got {status}"
  '';
}
