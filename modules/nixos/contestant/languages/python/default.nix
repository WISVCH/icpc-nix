{ config, pkgs, lib, ... }:

let
  cfg = config.modules.contestant.languages;
in
{
  options.modules.contestant.languages.python.enable = lib.mkEnableOption "Python toolchain";

  config = lib.mkIf (cfg.enable && cfg.python.enable) {
    environment.systemPackages = with pkgs; [
      python3
      pypy3
    ];
  };
}
