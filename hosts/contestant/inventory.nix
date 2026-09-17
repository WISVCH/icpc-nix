{ ... }:

# Explicit inventory of what the contestant image ships - everything here
# was unconditional before the module options existed. Toggle any of these
# off to build a lighter/smaller contestant image.
#
# Kept separate from image.nix so tests/contestant can pull in the same
# inventory without also inheriting the image-only settings (disk size,
# image.baseName) that mean nothing inside a nixosTest VM.
{
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
