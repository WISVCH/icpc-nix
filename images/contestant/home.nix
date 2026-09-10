{ inputs, vars, ... }:

{
  imports = [ inputs.home-manager.nixosModules.home-manager ];
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = { inherit vars; };

  home-manager.users = {
    "contestant" = {
      imports = [ ./home/contestant.nix ];
    };

    "icpcadmin" = {
      imports = [ ./home/icpcadmin.nix ];
    };
  };
}
