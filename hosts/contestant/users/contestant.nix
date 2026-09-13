{ ... }:

{
  users.groups.contestant = { };
  users.users.contestant = {
    group = "contestant";
    isNormalUser = true;
    hashedPassword = "$y$j9T$nCW2iFExGkmR9WULMCX110$2Uau1ZvrtogyXplyRfScxPqQTdCf876YhEAtY6Cc3s/";
    # extraGroups = [ "teams" "lpadmin" ];
  };

  home-manager.users.contestant.imports = [
    ../../../modules/home-manager/contestant
  ];
}
