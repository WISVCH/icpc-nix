{ config, pkgs, lib, ... }:

let
  cfg = config.modules.contestant.ides;
in
{
  options.modules.contestant.ides.pycharm.enable = lib.mkEnableOption "JetBrains PyCharm (Community)";

  config = lib.mkIf (cfg.enable && cfg.pycharm.enable && cfg.jetbrains.enable) {
    environment.systemPackages = [ pkgs.jetbrains.pycharm-community ];
  };
}
