{ config, pkgs, inputs, lib, ... }:

{
  # import the HM system module *once*
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  # configure HM
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.sharedModules = [ { manual.manpages.enable = false; } ];

  # create all the individual HM users if and only if they have an "entrypoint" file under `./home`
  home-manager.users = {
    "icpctools" = {
      imports = [
        ./home/icpctools.nix
      ];
    };
    "icpcadmin" = {
      imports = [
        ./home/icpcadmin.nix
      ];
    };

  };
}
