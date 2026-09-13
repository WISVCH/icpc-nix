{ ... }:

{
  home.username = "icpcadmin";
  home.homeDirectory = "/home/icpcadmin";
  home.stateVersion = "23.11";
  programs.home-manager.enable = true;

  home.file."icpc-nix" = {
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
}
