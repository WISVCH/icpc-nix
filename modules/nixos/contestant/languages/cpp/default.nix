{
  config,
  pkgs,
  lib,
  languages,
  ...
}:

let
  cfg = config.modules.contestant.languages;
in
{
  options.modules.contestant.languages.cpp.enable = lib.mkEnableOption "C++ toolchain";

  config = lib.mkIf (cfg.enable && cfg.cpp.enable) {
    environment.systemPackages =
      languages.cpp.packages
      ++ languages.cpp.commands
      # Contestant-only libraries/tooling - not judged, so from the system
      # nixpkgs rather than languages.nix.
      ++ (with pkgs; [
        boost
        catch2
        cmake
      ]);
  };
}
