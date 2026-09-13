{ ... }:

{
  users.users.judgehost = {
    isNormalUser = true;
    hashedPassword = "$y$j9T$oBQfoLBoXOlsKEKgxe/Ey/$yKesOZABOJCwwQzwbGApTR8sau7Yd0aZ2UbUdzSYD2B";
    extraGroups = [ "docker" ];
  };

  home-manager.users.judgehost.imports = [
    ../../../modules/home-manager/judgehost
  ];
}
