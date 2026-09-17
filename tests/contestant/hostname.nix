{ dns_zone, testHostname }:

# Subtest fragment. Composed by tests/lib.nix into the merged tests/all
# suite that CI runs, and into the per-image suite for iteration - it is
# not tied to either one.
#
# Regression test for set_hostname.sh actually running at boot (icpc.nix's
# firstboot.service now runs it via the on_boot.sh call that used to be
# commented out) and doing both of its jobs: fetching this machine's
# hostname from hostnames_api by its (spoofed - see the udev rule on
# "machine" in default.nix) USB serial, and publishing an A record for it
# on pdns. Both services run as containers on the "domjudge" node (see
# domjudge/module.nix) - production co-locates all three behind the same
# judge_ip, so this mirrors that instead of standing up separate nodes.
#
# Also covers self_test's hostname indicator either side of that: flagged
# while the machine is still on the hostname the image ships with, plain once
# a real one has been fetched. It is the one self_test check with a test,
# because it is the one that tells an operator at the firstboot gate that
# this machine never registered.
#
# Deliberately not waiting on firstboot.service itself: on_boot.sh ends in
# an interactive "Do you want to run icpc_setup?" prompt with no TTY input
# in this VM, so the unit never reaches "active (exited)" (see the hang
# this test suite already avoids elsewhere). Poll for the actual effect
# (the hostname changing) instead.
{
  name = "hostname";
  script = ''
    import json

    def self_test_hostname_line(node):
        """The "Hostname" row of self_test's System Configuration block.

        self_test only emits colour when stdout is a terminal (see its tput
        block), and `succeed` gives it a pipe - so the indicator has to be
        read from the text, which is also what icpc_setup.sh captures into
        /icpc/self_test_report and prints for the team.
        """
        out = node.succeed("/icpc/scripts/self_test")
        lines = [line for line in out.splitlines() if line.startswith("Hostname")]
        assert len(lines) == 1, (
            f"expected exactly one Hostname row in self_test output, got {lines}"
        )
        return lines[0]

    print("Checking self_test flags the hostname before firstboot has applied one")
    # firstboot's own first run at boot is expected to have failed (see the
    # comment further down), so the machine is still on the hostname the
    # image ships with - which is what icpc.nix templates in as
    # @icpc_default_hostname@ for self_test to compare against.
    unset_line = self_test_hostname_line(contestant)
    assert "not set" in unset_line, (
        f"expected self_test to flag the unset hostname, got: {unset_line!r}"
    )

    print("Checking the test-only udev rule actually spoofed the root disk's serial")
    root_mnt = contestant.succeed("findmnt -n -o SOURCE /").strip()
    # The root block device's udev database entry is populated once, very
    # early in boot (before/around switch-root) - force a fresh "add" event
    # for it explicitly rather than relying on whatever coldplug pass ran
    # during boot having already picked up the rule.
    contestant.succeed(f"udevadm trigger --action=add --name-match={root_mnt}")
    contestant.succeed("udevadm settle")
    udev_info = contestant.succeed(f"udevadm info --name={root_mnt}")

    assert "ID_SERIAL_SHORT=" in udev_info, (
        f"expected a spoofed ID_SERIAL_SHORT on {root_mnt} (see the "
        "services.udev.packages entry on the machine node in default.nix), "
        f"got udevadm info:\n{udev_info}"
    )

    # eth1 (machine <-> domjudge) is enabled but only gets pulled in via
    # multi-user.target/network-setup.target, which this test deliberately
    # never waits for (see domjudge.nix and the comment at the bottom of
    # default.nix) - start it directly rather than depend on it, same as
    # domjudge-selftest does.
    contestant.succeed("systemctl start network-addresses-eth1.service")

    # firstboot.service (icpc.nix) is a oneshot with no retry, and its own
    # organic first run happens within seconds of boot - long before
    # hostnames_api finishes migrating/loading fixtures (~3 minutes) or
    # pdns is listening. That first run's set_hostname.sh call is expected
    # to fail; wait for both services to actually be ready, then force a
    # clean second run instead of racing the first one.
    print("Waiting for hostnames_api and pdns to actually be ready on the domjudge node")
    server.wait_for_unit("podman-hostnames.service")
    server.wait_for_unit("podman-pdns.service")
    server.wait_until_succeeds(
        "curl --fail --silent http://127.0.0.1:8000/hostnames/", timeout=240
    )
    server.wait_until_succeeds(
        "curl --fail --silent -H 'X-API-Key: changeme' "
        "http://127.0.0.1:8081/api/v1/servers/localhost",
        timeout=60,
    )

    print("Re-running firstboot now that its dependencies are actually ready")
    # --no-block: on_boot.sh ends in the same interactive prompt mentioned
    # above, so ExecStart never returns - `systemctl restart` without this
    # would hang here forever waiting for the job to finish.
    contestant.succeed("systemctl restart --no-block firstboot.service")

    print("Waiting for set_hostname.sh to apply the fetched hostname")
    try:
        contestant.wait_until_succeeds(
            'test "$(hostname)" = "${testHostname}"', timeout=60
        )
    except Exception:
        print(f"current hostname: {contestant.succeed('hostname').strip()}")
        print(contestant.succeed("hostnamectl status 2>&1 || true"))
        raise

    print("Checking self_test now reports the fetched hostname with no warning")
    set_line = self_test_hostname_line(contestant)
    assert "${testHostname}" in set_line, (
        f"expected self_test to report the fetched hostname, got: {set_line!r}"
    )
    assert "not set" not in set_line and "not registered" not in set_line, (
        f"expected no hostname warning once one was fetched, got: {set_line!r}"
    )

    print("Checking pdns actually got the A record set_hostname.sh PATCHed in")
    zone = server.succeed(
        "curl --fail --silent -H 'X-API-Key: changeme' "
        "http://127.0.0.1:8081/api/v1/servers/localhost/zones/${dns_zone}."
    )
    rrsets = json.loads(zone)["rrsets"]
    matching = [
        rrset for rrset in rrsets
        if rrset["name"] == "${testHostname}.${dns_zone}." and rrset["type"] == "A"
    ]
    assert matching, \
        f"expected an A record for ${testHostname}.${dns_zone}. in pdns, got rrsets: {rrsets}"
    assert matching[0]["records"], \
        "A record for ${testHostname}.${dns_zone}. has no content"
  '';
}
