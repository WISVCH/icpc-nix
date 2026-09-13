{ config, pkgs, lib, ... }:

let
  cfg = config.modules.contestant.ides;
in
{
  options.modules.contestant.ides.idea.enable = lib.mkEnableOption "JetBrains IDEA (Community)";

  config = lib.mkIf (cfg.enable && cfg.idea.enable && cfg.jetbrains.enable) {
    environment.systemPackages = [ pkgs.jetbrains.idea-community ];
  };
}
