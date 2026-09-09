{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    vscode
    neovim-gtk # replaces vim-gtk3?
    # emacs
    # gedit
    # nano
    # codeblocks
    # geany
    # kate
    neovim
    # jetbrains.pycharm-community
    # jetbrains.idea-community
    # jetbrains.clion
    # eclipses.eclipse-java # ?
    # byobu
    gnome-terminal
    xterm
    # python3Full
    perl
    ddd
    gdb
    # junit # no clue
    valgrind
    git
    screen
    tmux

    # Just for Josh :)
    just
    nh
  ];
}
