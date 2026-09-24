{
  inputs,
  vars,
  languages,
  ...
}:

{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  # languages/inputs reach icpcadmin's judgehost image the same way the
  # NixOS modules get them (see flake.nix's specialArgs).
  home-manager.extraSpecialArgs = { inherit inputs vars languages; };

  # Applied to every home-manager user on every host.
  home-manager.sharedModules = [ ../../home-manager/common ];
}
