{ pkgs, lib, ... }:
let
  submitbaseurl = "https://dj.chipcie.ch.tudelft.nl";

  # DOMjudge's submit client, run by its own interpreter with the libraries
  # it imports. Not a system-wide python3: that would compete for
  # bin/python3 with languages.nix's pinned contestant python3.
  submitPython = pkgs.python3.withPackages (ps: [
    ps.requests
    ps.magic
  ]);
  submitClient = pkgs.fetchurl {
    url = "https://github.com/DOMjudge/domjudge/raw/main/submit/submit";
    sha256 = "sha256-qi8ETjPiXeWU/24i+s6mYAcUi8R+mUo8ut9JbzNEBx4=";
  };
in
rec {
  systemd.tmpfiles.rules = [
    "d /icpc 0755 icpcadmin icpcadmin -"
    "C+ /icpc/scripts/bin/disable-turboboost_ht 0755 icpcadmin icpcadmin - ${environment.etc.disable-turboboost.source}"
    "C+ /icpc/scripts/bin/submit 0755 icpcadmin icpcadmin - ${environment.etc.submit-client.source}"
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
      source = pkgs.writeShellScript "submit" ''
        exec ${submitPython}/bin/python3 ${submitClient} "$@"
      '';
    };
  };

  environment.variables.PATH = "/icpc/scripts/bin:$PATH";
  environment.variables.SUBMITBASEURL = submitbaseurl;
}
