{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    icinga2-agent
  ];
}
