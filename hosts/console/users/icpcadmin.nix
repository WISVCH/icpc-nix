{ ... }:

{
  users.users.icpcadmin = {
    isNormalUser = true;
    hashedPassword = "$y$j9T$l1SabA/8/ZVLzqELOwFe7.$BpKkbTYtxX45kUHTCI33uBnwHfM.AMuOjeebag9hvP1";
    extraGroups = [ "wheel" "audio" ];
  };

  home-manager.users.icpcadmin.imports = [
    ../../../modules/home-manager/icpcadmin
    ../../../modules/home-manager/icpcadmin/playbooks.nix
    ../../../modules/home-manager/icpcadmin/judgehost-image.nix
  ];
}
