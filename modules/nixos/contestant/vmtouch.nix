{ pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    vmtouch
  ];

  systemd.services.warm-fs-cache = {
    description = "Warm up file system cache";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ''
        /run/current-system/sw/bin/nice -n 19 /run/current-system/sw/bin/find / -path /proc -prune -o -path /sys -prune -o -print
        /run/current-system/sw/bin/nice -n 19 /etc/icpc/scripts/vmtouch.sh
      '';
    };
    environment = lib.mkForce {
      PATH = "/run/current-system/sw/bin";
    };
  };
}
