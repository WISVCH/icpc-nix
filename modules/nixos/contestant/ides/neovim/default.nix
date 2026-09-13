{ config, pkgs, lib, ... }:

let
  cfg = config.modules.contestant.ides;
in
{
  options.modules.contestant.ides.neovim.enable = lib.mkEnableOption "Neovim";

  config = lib.mkIf (cfg.enable && cfg.neovim.enable) {
    environment.systemPackages = with pkgs; [
      neovim-gtk # replaces vim-gtk3?
      neovim
    ];
  };
}
