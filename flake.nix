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

    # Secrets for the server host (modules/nixos/server/secrets.nix).
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Repo-wide formatting; config lives in ./treefmt.nix.
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      treefmt-nix,
      ...
    }:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      vars = import ./vars.nix { };
      pkgs = import nixpkgs { inherit system; };
      pkgs-unstable = import nixpkgs-unstable { inherit system; };

      treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

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
          # Run through bash explicitly: the script's /usr/bin/env shebang does not
          # resolve inside the Nix build sandbox (checks.sign-image).
          exec ${pkgs.bash}/bin/bash ${./scripts/sign-image.sh} "$@"
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
            ./hosts/console/configuration.nix
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
            ./hosts/contestant/configuration.nix
          ];
        };

        server = lib.nixosSystem {
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
            ./hosts/server/configuration.nix
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
            ./modules/nixos/common
            ./modules/nixos/console
            ./hosts/console/users/icpcadmin.nix
            ./hosts/console/users/icpctools.nix
            ./hosts/console/users/judgehost.nix
            # Shared with hosts/console/configuration.nix - deliberately not
            # importing that file, since this build path excludes
            # hardware-configuration.nix.
            ./hosts/console/image.nix
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
            ./modules/nixos/common
            ./modules/nixos/contestant
            ./hosts/contestant/users/contestant.nix
            ./hosts/contestant/users/icpcadmin.nix
            # Shared with hosts/contestant/configuration.nix (which also
            # pulls in the language/IDE inventory via image.nix) -
            # deliberately not importing that file, since this build path
            # excludes hardware-configuration.nix.
            ./hosts/contestant/image.nix
          ];
        }).config.system.build.images.raw-efi;

      ## nix build .#server
      packages.x86_64-linux.server =
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
            ./modules/nixos/common
            ./modules/nixos/server
            ./hosts/server/users/icpcadmin.nix
            # Shared with hosts/server/configuration.nix - deliberately not
            # importing that file, since this build path excludes
            # hardware-configuration.nix.
            ./hosts/server/image.nix
          ];
        }).config.system.build.images.raw-efi;

      ## nix build .#shim
      packages.x86_64-linux.shim = shim;

      ## nix build .#vm-tests
      ## All three images booted once against a single server node - what CI
      ## runs. The two suites below cover one image each and compose the same
      ## subtest fragments (see tests/lib.nix); they exist for the shorter
      ## feedback loop when iterating on one image, and are not run by CI.
      packages.x86_64-linux.vm-tests = import ./tests/all {
        inherit
          pkgs
          self
          inputs
          system
          vars
          ;
      };

      ## nix build .#contestant-vm-tests
      packages.x86_64-linux.contestant-vm-tests = import ./tests/contestant {
        inherit
          pkgs
          self
          inputs
          system
          vars
          ;
      };

      ## nix build .#console-vm-tests
      packages.x86_64-linux.console-vm-tests = import ./tests/console {
        inherit
          pkgs
          self
          inputs
          system
          vars
          ;
      };

      ## nix fmt
      formatter.x86_64-linux = treefmtEval.config.build.wrapper;

      ## Run by `nix flake check`, and buildable on its own with
      ## `just fmt-check` - unlike the rest of `nix flake check`, this
      ## derivation needs no access to the private icpc-playbooks input.
      checks.x86_64-linux.formatting = treefmtEval.config.build.check self;

      ## Runs scripts/sign-image.sh against a small fixture disk with a
      ## throwaway key, so the signing logic is exercised on every PR rather
      ## than first in the release job. See tests/sign-image.nix.
      checks.x86_64-linux.sign-image = import ./tests/sign-image.nix {
        inherit pkgs shim signImage;
      };

      ## nix run .#build-signed-console / .#build-signed-contestant / .#build-signed-server
      apps.x86_64-linux.build-signed-console = mkBuildSignedApp "console";
      apps.x86_64-linux.build-signed-contestant = mkBuildSignedApp "contestant";
      apps.x86_64-linux.build-signed-server = mkBuildSignedApp "server";
    };
}
