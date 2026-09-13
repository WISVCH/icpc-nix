{ lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    jq
    htop
    curl
    wget
    unzip
    firefox
    git
    vscode
    temurin-jre-bin
    ansible
  ];
}
