{ ... }:

{
  imports = [
    ../browser.nix
  ];
  home.file = {
    # "wallpaper" = {
    #   source = builtins.readFile "../files/wallpaper.png";
    #   target = "./.background-image";
    # };
    "home-dir" = {
      source = ../files/home_dirs/contestant;
      target = "fake/..";
      recursive = true;
    };

  };

  home.username = "contestant";
  home.homeDirectory = "/home/contestant";
  home.stateVersion = "23.11";
  programs.home-manager.enable = false;
}
