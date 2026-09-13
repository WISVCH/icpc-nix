{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/common
    ../../modules/nixos/contestant
    ./users/contestant.nix
    ./users/icpcadmin.nix
  ];

  system.stateVersion = "23.11";

  # Explicit inventory of what this image ships - mirrors today's behavior
  # exactly (everything below was previously unconditional). Toggle any of
  # these off to build a lighter/smaller contestant image.
  modules.contestant.languages.enable = true;
  modules.contestant.languages.c.enable = true;
  modules.contestant.languages.cpp.enable = true;
  modules.contestant.languages.python.enable = true;
  modules.contestant.languages.java.enable = true;
  modules.contestant.languages.kotlin.enable = true;

  modules.contestant.ides.enable = true;
  modules.contestant.ides.vscode.enable = true;
  modules.contestant.ides.neovim.enable = true;
  modules.contestant.ides.eclipse.enable = false;
  modules.contestant.ides.jetbrains.enable = false;
  modules.contestant.ides.idea.enable = false;
  modules.contestant.ides.pycharm.enable = false;
  modules.contestant.ides.clion.enable = false;
}
