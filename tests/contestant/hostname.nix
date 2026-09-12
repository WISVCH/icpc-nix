{ dns_zone, testHostname }:

# Subtest fragment for tests/contestant/default.nix.
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
# Deliberately not waiting on firstboot.service itself: on_boot.sh ends in
# an interactive "Do you want to run icpc_setup?" prompt with no TTY input
# in this VM, so the unit never reaches "active (exited)" (see the hang
# this test suite already avoids elsewhere). Poll for the actual effect
# (the hostname changing) instead.
{
  name = "hostname";
  script = ''
    import json

    print("Checking the test-only udev rule actually spoofed the root disk's serial")
    root_mnt = machine.succeed("findmnt -n -o SOURCE /").strip()
    udev_info = machine.succeed(f"udevadm info --name={root_mnt}")
    assert "ID_SERIAL_SHORT=" in udev_info, (
        f"expected a spoofed ID_SERIAL_SHORT on {root_mnt} (see the "
        "services.udev.extraRules on the machine node in default.nix), "
        f"got udevadm info:\n{udev_info}"
    )

    # eth1 (machine <-> domjudge) is enabled but only gets pulled in via
    # multi-user.target/network-setup.target, which this test deliberately
    # never waits for (see domjudge.nix and the comment at the bottom of
    # default.nix) - start it directly rather than depend on it, same as
    # domjudge-selftest does.
    machine.succeed("systemctl start network-addresses-eth1.service")

    # firstboot.service (icpc.nix) is a oneshot with no retry, and its own
    # organic first run happens within seconds of boot - long before
    # hostnames_api finishes migrating/loading fixtures (~3 minutes) or
    # pdns is listening. That first run's set_hostname.sh call is expected
    # to fail; wait for both services to actually be ready, then force a
    # clean second run instead of racing the first one.
    print("Waiting for hostnames_api and pdns to actually be ready on the domjudge node")
    domjudge.wait_for_unit("podman-hostnames.service")
    domjudge.wait_for_unit("podman-pdns.service")
    domjudge.wait_until_succeeds(
        "curl --fail --silent http://127.0.0.1:8000/hostnames/", timeout=240
    )
    domjudge.wait_until_succeeds(
        "curl --fail --silent -H 'X-API-Key: changeme' "
        "http://127.0.0.1:8081/api/v1/servers/localhost",
        timeout=60,
    )

    print("Re-running firstboot now that its dependencies are actually ready")
    # --no-block: on_boot.sh ends in the same interactive prompt mentioned
    # above, so ExecStart never returns - `systemctl restart` without this
    # would hang here forever waiting for the job to finish.
    machine.succeed("systemctl restart --no-block firstboot.service")

    print("Waiting for set_hostname.sh to apply the fetched hostname")
    machine.wait_until_succeeds(
        'test "$(hostname)" = "${testHostname}"', timeout=60
    )

    print("Checking pdns actually got the A record set_hostname.sh PATCHed in")
    zone = domjudge.succeed(
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
