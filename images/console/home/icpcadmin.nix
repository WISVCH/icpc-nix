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
        imageDigest = "sha256:ac728a1dc41516da6772e09a285934f0400ef559eeb9fa713a14c0076decd2cf";
        sha256 = "1h2lkl1z48jn4dm1ia7ypcvj4vlrbwby8m9qbkwm8zs2202gx2bz";
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
