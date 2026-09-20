{
  config,
  lib,
  languages,
  ...
}:

let
  cfg = config.modules.contestant.languages;
in
{
  options.modules.contestant.languages.java.enable = lib.mkEnableOption "Java toolchain";

  config = lib.mkIf (cfg.enable && cfg.java.enable) {
    environment.systemPackages = languages.java.packages ++ languages.java.commands;
  };
}
