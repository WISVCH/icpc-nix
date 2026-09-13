{ lib, pkgs, ...}:

{
    # Rootful: base.nix puts the "judgehost" user in the docker group
    # specifically to reach this daemon's socket. judgehost's own
    # create_cgroups script needs real root access to the cgroup
    # hierarchy root, which rootless Docker's per-user daemon (previously
    # also enabled here) cannot grant under any docker-run flag - its
    # daemon itself runs as that unprivileged user, so it can't hand out
    # capabilities beyond what the user already has on the host.
    virtualisation.docker.enable = true;
}