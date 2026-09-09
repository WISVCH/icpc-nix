{ lib, pkgs, ... }:

{
  networking = {
    wireless.enable = false;
    useDHCP = lib.mkForce true;
    hostName = "chipcie-contestant";
  };

  users = {
    mutableUsers = true;

    groups = {
      "contestant" = { };
      "icpcadmin" = { };
    };

    users = {
      "contestant" = {
        group = "contestant";
        isNormalUser = true;
        hashedPassword = "$y$j9T$nCW2iFExGkmR9WULMCX110$2Uau1ZvrtogyXplyRfScxPqQTdCf876YhEAtY6Cc3s/";
        # extraGroups = [ "teams" "lpadmin" ];
      };
      "icpcadmin" = {
        group = "icpcadmin";
        isNormalUser = true;
        hashedPassword = "$y$j9T$l1SabA/8/ZVLzqELOwFe7.$BpKkbTYtxX45kUHTCI33uBnwHfM.AMuOjeebag9hvP1";
        extraGroups = [ "wheel" "audio" ];
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIZwqjXcMDoY9uIXUyqogh2psoBLJZEqBV7uKrUS3VTN"
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC9c4U9+L1er1PFY0haDngnq4cMf79wiBZiKcvgoes4Te13U8nU8Vee5pk5FkUPj8l5ZT2kSoermajR1NcZc4WpP60Jmwoac2ymamu1OtMe78dd9KuRCjVsaNimOrWvBL0tdeouyIK6foIxxcE4NWiSRXu78VXfeytzOkwgbLNUK50gM4uKhWLWxNY35AyES+NPCFcWw9p4YuCBWkogcOzidOQTxRQyAYOFG278c4hPkvRqajCTg3zuM4jExiLXKN/5X6SNZRtlVkNJ+sQmprSzU7ASu011u/iIVtXssuarYzQJ0isl3y0M7Z77k/+1UzTgPudE91sL7HUyal4bTAY2FdEF9o2pBn43b2Ik9o4WqIA+yQvBoeX8sWoU+AyCRE6I1/tIobKjEGaj+rD2tC8uh27dPTPyW1/ZAIxvpj0atZB4bJJ8FqZK+WgzBQP1AhiplSAKfAbmj2XOe1yxFzl4cjR4LPFrNXX+7nGojbOOuMvs6GMmBJnHc5iJbBeR29M= maarten@fedora"
        ];
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
