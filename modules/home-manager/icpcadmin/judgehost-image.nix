{ pkgs, ... }:

# console-only: stages the judgehost container image for icpcadmin to load
# (see hosts/console/users/icpcadmin.nix).
{
  home.file."judgehost" = {
    source = pkgs.dockerTools.pullImage {
      imageName = "ghcr.io/wisvch/domjudge-packaging/judgehost";
      # Bumped 2026-09-13: the previous pin predated upstream DOMjudge
      # removing cgroup v1 support entirely (all judgehosts are cgroup v2
      # now) - the old image's create_cgroups script tried to mount
      # legacy per-controller paths like /sys/fs/cgroup/cpuset, which
      # don't exist under NixOS's default unified cgroup v2 hierarchy and
      # made judgehost exit immediately. Caught by tests/console's
      # judgehost-connect subtest (issue #54).
      imageDigest = "sha256:ae97fc2492ee446e3dfedd30515f0aed06fab3148849aa24bf219db8ddbab4d3";
      sha256 = "sha256-/AciCstPbAsSdBWENvnhBCJEypX1Q1yrJRKcuWO/Kbc=";
      finalImageName = "ghcr.io/wisvch/domjudge-packaging/judgehost";
      finalImageTag = "latest";
    };
    target = "judgehost/judgehost.tar.gz";
  };
}
