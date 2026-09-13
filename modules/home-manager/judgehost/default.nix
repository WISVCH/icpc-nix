{ ... }:

# Not fleshed out yet - the judgehost account currently has no dotfiles/tool
# needs of its own, but gets a real home-manager profile (rather than being a
# bare NixOS account) so per-host wiring in hosts/console/users/judgehost.nix
# has something to import.
{
  home.username = "judgehost";
  home.homeDirectory = "/home/judgehost";
  home.stateVersion = "23.11";
  programs.home-manager.enable = true;
}
