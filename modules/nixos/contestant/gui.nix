{ pkgs, lib, ... }:
{
  services.xserver = {
    enable = true;
    desktopManager = {
      xterm.enable = true;
      xfce.enable = true;
    };
    displayManager = {
      lightdm = {
        enable = true;
        autoLogin.timeout = 0;
        greeter.enable = true;
      };

    };
  };

  services.displayManager = {
    autoLogin = {
      enable = true;
      user = "contestant";
    };
  };

  environment.etc = {
    "desktop-permissions" = {
      text = ''
        [Desktop Entry]
              Encoding=UTF-8
              Version=0.9.4
              Type=Application
              Name=Desktop icon permissions
              Comment=Writes checksums to the desktop entries
              Exec=/icpc/scripts/desktop_checksums.sh
              StartupNotify=false
              Terminal=false
              Hidden=false
      '';
      target = "xdg/autostart/desktop-permissions.desktop";
    };
  };
}
