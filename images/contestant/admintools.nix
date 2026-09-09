{ pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    htop
    dstat
    iotop
    sysstat
    nettools
    curl
    ncdu
    tree
    unzip
  ];
}
