{ config, pkgs, lib, ... }:

let
  cfg = config.modules.contestant.languages;
in
{
  options.modules.contestant.languages.cpp.enable = lib.mkEnableOption "C++ toolchain";

  config = lib.mkIf (cfg.enable && cfg.cpp.enable) {
    environment.systemPackages = with pkgs; [
      gcc
      boost
      catch2
      cmake
    ];
  };
}
