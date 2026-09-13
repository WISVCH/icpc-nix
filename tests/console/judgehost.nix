# Subtest fragment for tests/console/default.nix, covering issue #54's
# "ensure console judgehost can connect with judgehost" checklist item: the
# console image's own pre-staged judgehost image (the same tarball
# images/console/home/icpcadmin.nix stages for real contests) is loaded and
# started, and domserver sees it register.
#
# Real contests start judgehost via chipcie-startup-scripts/start-judgehost.sh
# (invoked by icpc-playbooks' start_judgehosts.yml), neither of which is
# vendored in this repo. This reimplements just enough of that script's
# `docker run` invocation to exercise the same judgehost<->domserver
# handshake - kept test-only rather than promoted into images/console (see
# the design discussion on issue #54: that would newly make icpc-nix, not
# icpc-playbooks, responsible for judgehost startup, a bigger change than
# this test needs).
{ domjudgeIp, domjudgeUrl, domjudgeCert }:
{
  name = "judgehost-connect";
  script = ''
    import re

    # Avoid images/console's own desktop/display-manager chain the same way
    # tests/contestant/default.nix avoids its GUI/printer chain: wait for
    # exactly the unit this subtest needs (docker.service) rather than
    # multi-user.target.
    console.wait_for_unit("docker.service")

    # base.nix puts "judgehost" in the docker group specifically to reach
    # this (rootful) daemon's socket - no special env vars needed, unlike
    # the per-user rootless daemon this used to go through (see
    # images/console/docker.nix for why rootless can't run judgehost at
    # all: its create_cgroups script needs real root on the cgroup
    # hierarchy root, which a rootless daemon can never grant).
    sudo = "sudo -u judgehost"

    print("Loading the judgehost image staged in icpcadmin's home (same tarball shipped to real consoles)")
    # -g omitted: isNormalUser accounts default to primary group "users",
    # not a same-named group - see nixos/modules/config/users-groups.nix.
    console.succeed(
        "install -o judgehost "
        "/home/icpcadmin/judgehost/judgehost.tar.gz /tmp/judgehost.tar.gz"
    )
    load_output = console.succeed(f"{sudo} docker load -i /tmp/judgehost.tar.gz")
    loaded_image_match = re.search(r"Loaded image: (\S+)", load_output)
    assert loaded_image_match, f"unexpected `docker load` output: {load_output!r}"
    judgehost_image = loaded_image_match.group(1)

    # This is the first subtest to touch "domjudge" in this suite (unlike
    # tests/contestant, where domjudge.nix already does this wait before
    # firewall.nix runs) - restapi.secret doesn't exist until domserver has
    # finished its first-boot database install, so wait for that first.
    print("Waiting for DOMjudge's database install/migration to finish...")
    domjudge.wait_for_unit("podman-mariadb.service")
    domjudge.wait_for_unit("podman-domserver.service")
    # nginx.service (the native reverse proxy judgehost's own HTTPS
    # registration goes through - see below) is a separate systemd unit
    # from the podman containers above, with no ordering dependency on
    # them - tests/contestant/domjudge.nix already waits for it
    # explicitly for the same reason.
    domjudge.wait_for_unit("nginx.service")
    domjudge.wait_until_succeeds(
        "curl --fail --silent http://127.0.0.1/api/v4/version", timeout=600
    )

    print("Extracting the judgehost REST password domserver generated on first boot")
    # restapi.secret lives inside the domserver *container* - module.nix's
    # `--network=host` only shares networking with the "domjudge" node, not
    # its filesystem, so this has to go through `podman exec`, same as the
    # api:call invocations in tests/contestant/domjudge.nix.
    #
    # podman-domserver.service could in principle also crash/restart
    # part-way through its first-boot install (this repo has seen it happen
    # from an under-sized mariadb max_allowed_packet - see module.nix), which
    # would leave restapi.secret briefly missing or (if it then sees an
    # already-installed DB with no matching secret file) written with a
    # "NOTE(password-mismatch)" placeholder instead of a real password - wait
    # for a clean, freshly-generated file rather than a one-shot read.
    secret = "/opt/domjudge/domserver/etc/restapi.secret"
    domjudge.wait_until_succeeds(
        f"podman exec domserver sh -c "
        f"'test -s {secret} && ! grep -q \"^# NOTE\" {secret}'",
        timeout=120,
    )
    password = domjudge.succeed(
        f"podman exec domserver sh -c \"grep -v '^#' {secret} | cut -f4\""
    ).strip()

    print("Starting judgehost against the domjudge node (same flags as chipcie-startup-scripts/start-judgehost.sh)")
    # Diverges from that script in a few ways:
    #  - --cgroupns=host: upstream DOMjudge's create_cgroups
    #    (judge/create_cgroups.in) now requires cgroup v2 and explicitly
    #    checks /proc/self/cgroup for a real hierarchy prefix, which a
    #    container only sees with its cgroup namespace set to the host's.
    #  - --network=host: "console" and "domjudge" are separate VMs on a
    #    virtual LAN here (unlike a real contest, where judgehost and
    #    domserver are just two machines on the venue's own network) -
    #    Docker's default bridge network needs NAT/iptables plumbing to
    #    reach across that LAN. Host networking sidesteps that, matching
    #    how module.nix already avoids the same complexity for
    #    domserver/mariadb.
    #  - https:// + --add-host + a mounted CA cert, not plain http://
    #    <domjudgeIp>/: domserver's own bundled webserver only binds
    #    127.0.0.1 inside its container (confirmed in CI - judgehost got
    #    "Couldn't connect to server" on port 80 even with host networking
    #    reaching the domjudge VM just fine) - module.nix's native nginx on
    #    443 is the only thing actually reachable from elsewhere on the
    #    network, same path self_test's own autologin check already uses.
    #    curl (which judgedaemon shells out to, per its log messages)
    #    respects CURL_CA_BUNDLE/SSL_CERT_FILE for a custom trusted CA.
    console.succeed(
        f"{sudo} docker run -d --privileged --cgroupns=host --network=host "
        f"-v /sys/fs/cgroup:/sys/fs/cgroup "
        f"-v ${domjudgeCert.cert}:/domjudge-test-ca.pem:ro "
        f"--add-host ${domjudgeUrl}:${domjudgeIp} "
        f"-e DOMSERVER_BASEURL=https://${domjudgeUrl}/ -e JUDGEDAEMON_PASSWORD={password} -e DAEMON_ID=0 "
        f"-e CURL_CA_BUNDLE=/domjudge-test-ca.pem -e SSL_CERT_FILE=/domjudge-test-ca.pem "
        f"--hostname judgedaemon-0 --name judgehost-0 {judgehost_image}"
    )

    print("Waiting for domserver to see the judgehost register")
    admin_password = domjudge.succeed(
        "podman exec domserver cat /opt/domjudge/domserver/etc/initial_admin_password.secret"
    ).strip()
    try:
        # `docker run -d` only confirms the container *started* - it says
        # nothing about the judgedaemon process inside staying up or
        # actually reaching domserver, so a real failure here (crash,
        # unreachable network, wrong credentials, ...) would otherwise show
        # up only as a silent timeout. Fail fast with a real timeout instead
        # of wait_until_succeeds' 900s default, and dump the container's own
        # logs/status on failure so CI actually explains what happened.
        domjudge.wait_until_succeeds(
            f"curl --fail --silent -u admin:{admin_password} "
            "http://127.0.0.1/api/v4/judgehosts | grep -q judgedaemon-0",
            timeout=90,
        )
    except Exception:
        print("judgehost never registered - dumping its container logs/status for diagnosis")
        print(console.succeed(f"{sudo} docker ps -a"))
        print(console.succeed(f"{sudo} docker logs judgehost-0"))
        raise
  '';
}
