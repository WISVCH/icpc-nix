{ lib, pkgs, ... }:

{
  networking = {
    wireless.enable = false;
    useDHCP = lib.mkForce true;
    hostName = "chipcie-console";
  };

  users = {
    mutableUsers = true;
    users = {
      "icpcadmin" = {
        isNormalUser = true;
        hashedPassword = "$y$j9T$l1SabA/8/ZVLzqELOwFe7.$BpKkbTYtxX45kUHTCI33uBnwHfM.AMuOjeebag9hvP1";
        extraGroups = [ "wheel" "audio" ];
      };
      "icpctools" = {
        isNormalUser = true;
        hashedPassword = "$y$j9T$WKPftiKUOrUjjvxzUS76o/$tS8nd3ja5WZK.AAmFjiF87ihOWrDmjIaX61Bf1J7H7B";
        extraGroups = [ "audio" ];
      };
      "judgehost" = {
        isNormalUser = true;
        hashedPassword = "$y$j9T$oBQfoLBoXOlsKEKgxe/Ey/$yKesOZABOJCwwQzwbGApTR8sau7Yd0aZ2UbUdzSYD2B";
        extraGroups = [ "docker" ];
      };
    };
  };

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
