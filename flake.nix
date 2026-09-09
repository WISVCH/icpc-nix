{
  inputs = {
    # Use unstable for flakes
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    # Add home-manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Use nixos generators for generating UEFI-bootable disk images
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";


  };

  outputs = inputs@{ self, nixpkgs, home-manager, flake-utils, ... }:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      vars = import ./vars.nix;
    in

    {
      inherit lib;

      # For nixos-rebuild
      nixosConfigurations = {
        console = lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit self inputs system vars;
          };
          modules = [
            ./images/console
            ./images/common.nix
            ./hosts/console/hardware-configuration.nix
            {
              system.stateVersion = "23.11";
            }
          ];
        };

        contestant = lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit self inputs system vars;
          };
          modules = [
            ./images/contestant
            ./images/common.nix
            ./hosts/contestant/hardware-configuration.nix
            {
              system.stateVersion = "23.11";
            }
          ];
        };
      };

      ## nix build .#console
      packages.x86_64-linux.console = inputs.nixos-generators.nixosGenerate {
        system = "x86_64-linux";
        format = "raw-efi";
        specialArgs = {
          inherit self inputs system vars;
          diskSize = 20 * 1024;
        };
        modules = [
          ./images/common.nix
          ./images/console
          {
            system.stateVersion = "23.11";
          }
        ];
      };

      ## nix build .#contestant
      packages.x86_64-linux.contestant = inputs.nixos-generators.nixosGenerate {
        system = "x86_64-linux";
        format = "raw-efi";
        specialArgs = {
          inherit self inputs system vars;
          diskSize = 20 * 1024;
        };
        modules = [
          ./images/common.nix
          ./images/contestant
          {
            system.stateVersion = "23.11";
          }
        ];
      };
    };
}
