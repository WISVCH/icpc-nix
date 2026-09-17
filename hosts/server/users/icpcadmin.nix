{ ... }:

# Same operator account as the other two hosts, but without console's
# home-manager extras (icpc-playbooks, the staged judgehost image) - the
# server neither runs playbooks nor hosts judgehosts.
{
  users.users.icpcadmin = {
    isNormalUser = true;
    hashedPassword = "$y$j9T$l1SabA/8/ZVLzqELOwFe7.$BpKkbTYtxX45kUHTCI33uBnwHfM.AMuOjeebag9hvP1";
    extraGroups = [ "wheel" ];
  };
}
