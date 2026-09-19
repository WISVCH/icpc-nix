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
  options.modules.contestant.languages.python.enable = lib.mkEnableOption "Python toolchain";

  config = lib.mkIf (cfg.enable && cfg.python.enable) {
    environment.systemPackages =
      languages.python.packages ++ languages.python.contestantPackages ++ languages.python.commands;
  };
}
