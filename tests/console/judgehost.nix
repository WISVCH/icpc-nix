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
{ domjudgeIp }:
{
  name = "judgehost-connect";
  script = ''
    import re

    # Avoid images/console's own desktop/display-manager chain the same way
    # tests/contestant/default.nix avoids its GUI/printer chain: wait for
    # exactly the unit this subtest needs (systemd-logind, for
    # `loginctl enable-linger`) rather than multi-user.target.
    console.wait_for_unit("systemd-logind.service")

    # virtualisation.docker.rootless (images/console/docker.nix) runs a
    # separate per-user docker daemon as a systemd --user unit, which needs
    # a lingering login session to start without an interactive login - see
    # nixpkgs' own nixos/tests/docker-rootless.nix, which this follows.
    console.succeed("loginctl enable-linger judgehost")

    # isNormalUser accounts get their uid assigned at system activation, not
    # visible in the static Nix config (nodes.console.config...uid is null
    # there) - read it back from the running system instead.
    judgehost_uid = console.succeed("id -u judgehost").strip()
    sudo = (
        f"XDG_RUNTIME_DIR=/run/user/{judgehost_uid} "
        f"DOCKER_HOST=unix:///run/user/{judgehost_uid}/docker.sock "
        "sudo --preserve-env=XDG_RUNTIME_DIR,DOCKER_HOST -u judgehost"
    )
    console.wait_until_succeeds(f"{sudo} systemctl --user is-active docker.service")

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

    print("Extracting the judgehost REST password domserver generated on first boot")
    password = domjudge.succeed(
        "grep -v '^#' /opt/domjudge/domserver/etc/restapi.secret | cut -f4"
    ).strip()

    print("Starting judgehost against the domjudge node (same flags as chipcie-startup-scripts/start-judgehost.sh)")
    console.succeed(
        f"{sudo} docker run -d --privileged -v /sys/fs/cgroup:/sys/fs/cgroup "
        f"-e DOMSERVER_BASEURL=http://${domjudgeIp}/ -e JUDGEDAEMON_PASSWORD={password} -e DAEMON_ID=0 "
        f"--hostname judgedaemon-0 --name judgehost-0 {judgehost_image}"
    )

    print("Waiting for domserver to see the judgehost register")
    admin_password = domjudge.succeed(
        "cat /opt/domjudge/domserver/etc/initial_admin_password.secret"
    ).strip()
    domjudge.wait_until_succeeds(
        f"curl --fail --silent -u admin:{admin_password} "
        "http://127.0.0.1/api/v4/judgehosts | grep -q judgedaemon-0"
    )
  '';
}
