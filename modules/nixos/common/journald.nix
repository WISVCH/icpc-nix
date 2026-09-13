{ ... }:

{
  services.journald.console = "tty1";
  services.journald.forwardToSyslog = false;
  services.journald.extraConfig = ''
    ForwardToKMsg=no
    ForwardToConsole=yes
    ForwardToWall=no
    TTYPath=/dev/tty1
    Storage=volatile
  '';
}
