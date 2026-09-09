{ pkgs, lib, ... }:
let
  submitbaseurl = "https://dj.chipcie.ch.tudelft.nl";
in
rec {
  systemd.tmpfiles.rules = [
    "d /icpc 0755 icpcadmin icpcadmin -"
    # "C+ /icpc/scripts 0755 icpcadmin icpcadmin - ${environment.etc.icpc-scripts.source}"
    "C+ /icpc/scripts/bin/disable-turboboost_ht 0755 icpcadmin icpcadmin - ${environment.etc.disable-turboboost.source}"
    "C+ /icpc/scripts/bin/submit 0755 icpcadmin icpcadmin - ${environment.etc.submit-client.source}"
    "Z /icpc/scripts 755 icpcadmin icpcadmin -"
    "f /icpc/netrc 644 icpcadmin icpcadmin -"
  ];

  environment.etc = {
    # icpc-scripts = {
    #   source = ./files/scripts;
    #   target = "icpc/scripts";
    # };

    disable-turboboost = {
      source = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/DOMjudge/domjudge-scripts/main/provision-contest/disable-turboboost_ht";
                  sha256 = "sha256-XtOV0DCfF5OfMz+R0rOJc58gM2nrcvWnCHS4WJLt2UQ=";
      };
      target = "disable-turboboost_ht";
    };
    submit-client = {
      source = pkgs.fetchurl {
        url = "https://github.com/DOMjudge/domjudge/raw/main/submit/submit";
        sha256 = "112pnchxl8x01prxam88928m1cabl1yjipmdki3747diq9k2nihb";
      };
    };
  };


  environment.variables.PATH = "/icpc/scripts/bin:$PATH";
  environment.variables.SUBMITBASEURL = submitbaseurl;

  environment.systemPackages = with pkgs; [
    python312
    python312Packages.requests
    python312Packages.magic
  ];
}
