{
  pkgs,
  inputs,
  languages,
  ...
}:

# console-only: stages the judgehost container image for icpcadmin to load
# (see hosts/console/users/icpcadmin.nix). What is in that image, and why it
# is built rather than pulled, is in ./judgehost.nix.
let
  judgehost = import ./judgehost.nix { inherit pkgs inputs languages; };
in
{
  home.file."judgehost" = {
    source = judgehost.image;
    target = "judgehost/judgehost.tar.gz";
  };
}
