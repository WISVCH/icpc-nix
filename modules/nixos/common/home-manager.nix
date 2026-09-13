{ inputs, vars, ... }:

{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = { inherit vars; };

  # Applied to every home-manager user on every host.
  home-manager.sharedModules = [ ../../home-manager/common ];
}
