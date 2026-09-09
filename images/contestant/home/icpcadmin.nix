{ ... }:
let
  files = {
    "chipcie-nix" = {
      source = builtins.fetchGit {
        url = "ssh://git@github.com/07joshua03/chipcie-nix.git";
        ref = "contestant";
        rev = "941cab71c329ed70abd49e9480356461f2dfcf7f";
        submodules = true;
      };
      target = "ro/chipcie-nix";
      onChange = ''
        cp -rL /home/icpcadmin/ro/chipcie-nix /home/icpcadmin/chipcie-nix
        chmod -R +w /home/icpcadmin/chipcie-nix
      '';
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
