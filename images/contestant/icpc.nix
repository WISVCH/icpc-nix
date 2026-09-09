{ pkgs, lib, ... }:
let
  on_boot_text = builtins.readFile ./files/scripts/on_boot.sh;
  on_boot = pkgs.writeShellScriptBin "on-boot" on_boot_text;
in

rec {
  environment.systemPackages = with pkgs; [
    noto-fonts-color-emoji
    imagemagick
    git
    ntp
    zip
    jq
    wget
  ];

  security.polkit.enable = true;
  # TODO Add polkit rules

  services.logind.extraConfig = ''
    KillOnlyUsers=contestant
  '';

  #TODO delete icpc workspaces
  #TODO add icpcadmin home template


  systemd.tmpfiles.rules = [
    "d /icpc 0755 icpcadmin icpcadmin -"
    # "C+ /icpc/scripts 0755 icpcadmin icpcadmin - ${environment.etc.icpc-scripts.source}"
    # "C+ /icpc/scripts/bin/disable-turboboost_ht 0755 icpcadmin icpcadmin - ${environment.etc.disable-turboboost.source}"
    # "C+ /icpc/scripts/bin/submit 0755 icpcadmin icpcadmin - ${environment.etc.submit-client.source}"
    "C+ /icpc/wallpaper.png 0755 - - - ${environment.etc.wallpaper.source}"
    "Z /icpc/scripts 755 icpcadmin icpcadmin -"
    "f /icpc/netrc 644 icpcadmin icpcadmin -"
  ];
  environment.etc = {
    # config = {
    #   source = ./files/autologin-addon/config.js;
    # target = "icpc/firefox-addon/config.js";
    # mode = "0644";
    # };

    background = {
      source = ./files/autologin-addon/background.js;
      target = "icpc/firefox-addon/background.js";
      mode = "0644";
    };

    manifest = {
      source = ./files/autologin-addon/manifest.json;
      target = "icpc/firefox-addon/manifest.json";
      mode = "0644";
    };
  };

  environment.etc =
    {
      wallpaper = {
        source = ./files/wallpaper.png;
        target = "wallpaper.png";
      };

      # Used when resetting contestant user
      contestant-home = {
        source = ./files/home_dirs/contestant;
        target = "skel";
        mode = "0644";
      };

      # For the scripts, it is not possible to create the entire folder (with it being writable, SEE: https://github.com/NixOS/nixpkgs/issues/200744)

      check_battery = {
        source = ./files/scripts/check_battery.sh;
        target = "icpc/scripts/check_battery.sh";
        mode = "0755";
      };

      deleteUser = {
        source = ./files/scripts/deleteUser.sh;
        target = "icpc/scripts/deleteUser.sh";
        mode = "0755";
      };

      desktop_checksums = {
        source = ./files/scripts/desktop_checksums.sh;
        target = "icpc/scripts/desktop_checksums.sh";
        mode = "0755";
      };

      expandPartition = {
        source = ./files/scripts/expandPartition.sh;
        target = "icpc/scripts/expandPartition.sh";
        mode = "0755";
      };

      firstLogin = {
        source = ./files/scripts/firstLogin.sh;
        target = "icpc/scripts/firstLogin.sh";
        mode = "0755";
      };

      full_reset = {
        source = ./files/scripts/full_reset.sh;
        target = "icpc/scripts/full_reset.sh";
        mode = "0755";
      };

      icpc_setup = {
        source = ./files/scripts/icpc_setup.sh;
        target = "icpc/scripts/icpc_setup.sh";
        mode = "0755";
      };

      on_boot = {
        source = ./files/scripts/on_boot.sh;
        target = "icpc/scripts/on_boot.sh";
        mode = "0755";
      };

      print_pdf = {
        source = ./files/scripts/print_pdf.py;
        target = "icpc/scripts/print_pdf.py";
        mode = "0755";
      };

      printfile = {
        source = ./files/scripts/printfile.sh;
        target = "icpc/scripts/printfile.sh";
        mode = "0755";
      };

      self_test = {
        source = ./files/scripts/self_test;
        target = "icpc/scripts/self_test";
        mode = "0755";
      };

      set_domjudge_creds = {
        source = ./files/scripts/set_domjudge_creds.sh;
        target = "icpc/scripts/set_domjudge_creds.sh";
        mode = "0755";
      };

      set_hostname = {
        source = ./files/scripts/set_hostname.sh;
        target = "icpc/scripts/set_hostname.sh";
        mode = "0755";
      };

      set_printer = {
        source = ./files/scripts/set_printer.sh;
        target = "icpc/scripts/set_printer.sh";
        mode = "0755";
      };

      set_room = {
        source = ./files/scripts/set_room.sh;
        target = "icpc/scripts/set_room.sh";
        mode = "0755";
      };

      set_teamid = {
        source = ./files/scripts/set_teamid.sh;
        target = "icpc/scripts/set_teamid.sh";
        mode = "0755";
      };

      set_teamname = {
        source = ./files/scripts/set_teamname.sh;
        target = "icpc/scripts/set_teamname.sh";
        mode = "0755";
      };

      version_check = {
        source = ./files/scripts/version_check.sh;
        target = "icpc/scripts/version_check.sh";
        mode = "0755";
      };

      vmtouch = {
        source = ./files/scripts/vmtouch.sh;
        target = "icpc/scripts/vmtouch.sh";
        mode = "0755";
      };

      disable-mounting = {
        source = ./files/99-deny-polkit-mount.pkla;
        target = "polkit-1/localauthority/50-local.d/disable-mount.pkla";
        mode = "0644";
      };

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

  systemd.services.firstboot = {
    description = "Initial self test";
    enable = true;
    before = [ "display-manager.service" ];
    wants = [ "network-online.target" "printer.target" "squid.service" ];
    after = [ "network-online.target" "cups.service" "getty@tty2.service" ];
    wantedBy = [ "graphical.target" "multi-user.target" ];

    environment = lib.mkForce {
      PATH = "/run/current-system/sw/bin";
    };

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      TimeoutSec = 0;
      TTYReset = "yes";
      TTYVHangup = "yes";
      TTYPath = "/dev/tty5";
      TTYVTDisallocate = "yes";
      StandardInput = "tty";
      StandardOutput = "tty";
      # ExecStart = "/usr/bin/env bash -c '/usr/bin/env chvt 2; /icpc/scripts/on_boot.sh'";
      # ExecStart = "/bin/sh -c '/etc/icpc/scripts/on_boot.sh'";
      ExecStart = "/run/current-system/sw/bin/bash -c '/run/current-system/sw/bin/chvt 5; ${on_boot}/bin/on-boot'";
    };
  };
  # environment.variables.SUBMITBASEURL = submitbaseurl;

  # environment.systemPackages = with pkgs; [
  # python312
  # python312Packages.requests
  # python312Packages.magic
  # ];
}
