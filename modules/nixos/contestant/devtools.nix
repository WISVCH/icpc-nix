{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    gnome-terminal
    xterm
    perl
    ddd
    gdb
    valgrind
    git
    screen
    tmux

    # Just for Josh :)
    just
    nh
  ];
}
