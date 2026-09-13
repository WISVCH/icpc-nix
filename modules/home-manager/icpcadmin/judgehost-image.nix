{ pkgs, ... }:

# console-only: stages the judgehost container image for icpcadmin to load
# (see hosts/console/users/icpcadmin.nix).
{
  home.file."judgehost" = {
    source = pkgs.dockerTools.pullImage {
      imageName = "ghcr.io/wisvch/domjudge-packaging/judgehost";
      imageDigest = "sha256:ac728a1dc41516da6772e09a285934f0400ef559eeb9fa713a14c0076decd2cf";
      sha256 = "1h2lkl1z48jn4dm1ia7ypcvj4vlrbwby8m9qbkwm8zs2202gx2bz";
      finalImageName = "ghcr.io/wisvch/domjudge-packaging/judgehost";
      finalImageTag = "latest";
    };
    target = "judgehost/judgehost.tar.gz";
  };
}
