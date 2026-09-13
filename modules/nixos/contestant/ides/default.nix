{ lib, ... }:

{
  options.modules.contestant.ides.enable = lib.mkEnableOption "graphical editors and IDEs";

  imports = [
    ./vscode
    ./neovim
    ./eclipse
    ./jetbrains
    ./idea
    ./pycharm
    ./clion
  ];
}
