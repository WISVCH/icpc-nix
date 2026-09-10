{
  inputs = {
    # Use unstable for flakes
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Add home-manager
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      flake-utils,
      ...
    }:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      vars = import ./vars.nix { };
      pkgs = import nixpkgs { inherit system; };
      pkgs-unstable = import nixpkgs-unstable { inherit system; };

      shim = import ./packages/shim.nix {
        inherit pkgs;
        inherit (pkgs) lib;
      };

      signImage = pkgs.writeShellApplication {
        name = "sign-image";
        runtimeInputs = with pkgs; [
          mtools
          sbsigntool
          openssl
          jq
          util-linux
          gnugrep
          coreutils
        ];
        text = ''
          export SHIM_DIR="${shim}"
          export ICPC_NIX_SIGNING_CERT="''${ICPC_NIX_SIGNING_CERT:-${./keys/icpc-nix-release.cer}}"
          exec ${./scripts/sign-image.sh} "$@"
        '';
      };

      mkBuildSignedApp = image: {
        type = "app";
        program =
          toString (
            pkgs.writeShellApplication {
              name = "build-signed-${image}";
              runtimeInputs = [ signImage ];
              text = ''
                nix build ".#${image}" -L
                OUT="./${image}-signed.img"
                cp --no-preserve=mode,ownership result/nixos.img "$OUT"
                chmod +w "$OUT"
                sign-image "$OUT"
                echo "Signed image: $OUT"
              '';
            }
          )
          + "/bin/build-signed-${image}";
      };
    in

    {
      inherit lib;

      # For nixos-rebuild
      nixosConfigurations = {
        console = lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit
              self
              inputs
              system
              vars
              pkgs-unstable
              ;
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
            inherit
              self
              inputs
              system
              vars
              pkgs-unstable
              ;
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
      packages.x86_64-linux.console =
        (lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit
              self
              inputs
              system
              vars
              pkgs-unstable
              ;
          };
          modules = [
            ./images/common.nix
            ./images/console
            {
              system.stateVersion = "23.11";
              # image.baseName only exists within the per-format extended
              # eval (config.system.build.images.<format>), not the top-level
              # config, so it's set via image.modules.raw-efi rather than
              # directly - deferredModule merges this in alongside the
              # built-in raw-efi definition (nixos/modules/image/images.nix).
              image.modules.raw-efi = {
                image.baseName = "nixos";
              };
            }
          ];
        }).config.system.build.images.raw-efi;

      ## nix build .#contestant
      packages.x86_64-linux.contestant =
        (lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit
              self
              inputs
              system
              vars
              pkgs-unstable
              ;
          };
          modules = [
            ./images/common.nix
            ./images/contestant
            {
              system.stateVersion = "23.11";
              # image.baseName only exists within the per-format extended
              # eval (config.system.build.images.<format>), not the top-level
              # config, so it's set via image.modules.raw-efi rather than
              # directly - deferredModule merges this in alongside the
              # built-in raw-efi definition (nixos/modules/image/images.nix).
              image.modules.raw-efi = {
                image.baseName = "nixos";
              };
            }
          ];
        }).config.system.build.images.raw-efi;

      ## nix build .#shim
      packages.x86_64-linux.shim = shim;

      ## nix build .#contestant-vm-tests
      packages.x86_64-linux.contestant-vm-tests = import ./tests/contestant {
        inherit pkgs self inputs system vars;
      };

      ## nix run .#build-signed-console / .#build-signed-contestant
      apps.x86_64-linux.build-signed-console = mkBuildSignedApp "console";
      apps.x86_64-linux.build-signed-contestant = mkBuildSignedApp "contestant";
    };
}
