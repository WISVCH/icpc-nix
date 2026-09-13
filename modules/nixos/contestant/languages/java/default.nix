{ config, pkgs, lib, ... }:

let
  cfg = config.modules.contestant.languages;
in
{
  options.modules.contestant.languages.java.enable = lib.mkEnableOption "Java toolchain";

  config = lib.mkIf (cfg.enable && cfg.java.enable) {
    environment.systemPackages = [ pkgs.zulu17 ];
  };
}
