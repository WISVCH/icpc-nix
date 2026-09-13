{ config, pkgs, lib, ... }:

let
  cfg = config.modules.contestant.ides;
in
{
  options.modules.contestant.ides.clion.enable = lib.mkEnableOption "JetBrains CLion";

  config = lib.mkIf (cfg.enable && cfg.clion.enable && cfg.jetbrains.enable) {
    environment.systemPackages = [ pkgs.jetbrains.clion ];
  };
}
