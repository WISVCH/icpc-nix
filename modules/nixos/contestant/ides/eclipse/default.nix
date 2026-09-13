{ config, pkgs, lib, ... }:

let
  cfg = config.modules.contestant.ides;
in
{
  options.modules.contestant.ides.eclipse.enable = lib.mkEnableOption "Eclipse (Java)";

  config = lib.mkIf (cfg.enable && cfg.eclipse.enable) {
    environment.systemPackages = [ pkgs.eclipses.eclipse-java ];
  };
}
