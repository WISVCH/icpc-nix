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
  options.modules.contestant.languages.kotlin.enable = lib.mkEnableOption "Kotlin toolchain";

  config = lib.mkIf (cfg.enable && cfg.kotlin.enable) {
    environment.systemPackages = languages.kotlin.packages ++ languages.kotlin.commands;
  };
}
