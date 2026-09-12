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

    # This subtest runs before squid.nix (which also exercises squid), so it
    # can't rely on that subtest having already waited for the unit.
    machine.wait_for_unit("squid.service")

    domjudge.wait_for_unit("podman-mariadb.service")
    domjudge.wait_for_unit("podman-domserver.service")
    domjudge.wait_for_unit("nginx.service")

    print("Waiting for DOMjudge's database install/migration to finish...")
    domjudge.wait_until_succeeds(
        "curl --fail --silent http://127.0.0.1/api/v4/version", timeout=600
    )

    print("DOMjudge is up - seeding a test team account via users/accounts")
    domjudge.succeed(
        "printf 'accounts\\t1\\nteam\\tTest Team\\ttestteam\\ttestpass\\n' "
        "> /tmp/accounts.tsv"
    )
    domjudge.succeed("podman cp /tmp/accounts.tsv domserver:/tmp/accounts.tsv")
    domjudge.succeed(
        "podman exec domserver "
        "/opt/domjudge/domserver/webapp/bin/console api:call "
        "-m POST -f tsv=/tmp/accounts.tsv users/accounts"
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

    print("Checking the proxy allow-list independently of self_test's own wording")
    machine.succeed(
        "curl --fail --silent --show-error --max-time 5 "
        "-x http://127.0.0.1:3128 https://${domjudgeUrl}/ >/dev/null"
    )
    code = machine.succeed(
        "curl -s -o /dev/null -w '%{http_code}' "
        "-x http://127.0.0.1:3128 http://example.com"
    ).strip()
    assert code == "403", \
        f"expected squid to reject a non-allow-listed host with 403, got {code}"

    print("Checking direct (non-proxied) internet access is blocked for contestant")
    machine.fail(
        "su - contestant -c "
        "'curl --fail --silent --max-time 5 http://example.com'"
    )
  '';
}
