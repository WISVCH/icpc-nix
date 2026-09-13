{ lib, pkgs, ... }:

{
  networking = {
    wireless.enable = false;
    useDHCP = lib.mkForce true;
    hostName = "chipcie-console";
  };

  users.mutableUsers = true;

  # Enable SSH
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "no";
  services.openssh.settings.PasswordAuthentication = true;

  # Disable sudo password requirement
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };
}
