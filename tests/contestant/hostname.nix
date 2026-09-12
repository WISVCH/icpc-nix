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

    print("Waiting for set_hostname.sh to run as part of firstboot.service")
    machine.wait_until_succeeds(
        'test "$(hostname)" = "${testHostname}"', timeout=120
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
