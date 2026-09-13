{ lib, pkgs, ... }:

let

  files = {
    "icpc-nix" = {
      source = builtins.fetchGit {
        url = "ssh://git@github.com/wisvch/icpc-nix.git";
        ref = "contestant";
        rev = "941cab71c329ed70abd49e9480356461f2dfcf7f";
        submodules = true;
      };
      target = "ro/icpc-nix";
      onChange = ''
        cp -rL /home/icpcadmin/ro/icpc-nix /home/icpcadmin/icpc-nix
        chmod -R +w /home/icpcadmin/icpc-nix
      '';
    };

    "icpc-playbooks" = {
      source = builtins.fetchGit {
        url = "ssh://git@github.com-playbooks/wisvch/icpc-playbooks.git";
        ref = "main";
        rev = "0a1399bd61dec66836c834815b1f448ce6609f1c";
        submodules = true;
      };
      target = "ro/icpc-playbooks";
      onChange = ''
        cp -rL /home/icpcadmin/ro/icpc-playbooks /home/icpcadmin/icpc-playbooks
        chmod -R +w /home/icpcadmin/icpc-playbooks
      '';
    };

    "judgehost" = {
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
  };
in
{
  home.username = "icpcadmin";
  home.homeDirectory = "/home/icpcadmin";
  home.stateVersion = "23.11";
  programs.home-manager.enable = true;
  home.file = files;
}
