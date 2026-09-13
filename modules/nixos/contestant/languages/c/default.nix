{ config, pkgs, lib, ... }:

let
  cfg = config.modules.contestant.languages;
in
{
  options.modules.contestant.languages.c.enable = lib.mkEnableOption "C toolchain";

  config = lib.mkIf (cfg.enable && cfg.c.enable) {
    environment.systemPackages = [ pkgs.gcc ];
  };
}
