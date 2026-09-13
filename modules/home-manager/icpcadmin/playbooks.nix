{ ... }:

# console-only: pulls the ops playbooks repo alongside icpc-nix (see
# hosts/console/users/icpcadmin.nix).
{
  home.file."icpc-playbooks" = {
    source = builtins.fetchGit {
      url = "ssh://git@github.com-playbooks/wisvch/icpc-playbooks.git";
      ref = "main";
      rev = "0a1399bd61dec66836c834815b1f448ce6609f1c";
      submodules = true;
    };
    target = "ro/icpc-playbooks";
    onChange = ''
      cp -rL /home/icpcadmin/ro/icpc-playbooks /home/icpcadmin/icpc-playbooks
      chmod -R +w /home/icpcadmin/icpc-playbooks
    '';
  };
}
