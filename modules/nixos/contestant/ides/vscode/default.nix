{ config, pkgs, lib, ... }:

let
  cfg = config.modules.contestant.ides;
in
{
  options.modules.contestant.ides.vscode.enable = lib.mkEnableOption "VS Code";

  config = lib.mkIf (cfg.enable && cfg.vscode.enable) {
    environment.systemPackages = [ pkgs.vscode ];
  };
}
