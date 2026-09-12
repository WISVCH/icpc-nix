{ pkgs, lib, vars, self, ... }:
let
  on_boot_text = builtins.readFile ./files/scripts/on_boot.sh;
  on_boot = pkgs.writeShellScriptBin "on-boot" on_boot_text;

  icpc_commit = self.shortRev or self.dirtyShortRev or "unknown";
  # self.lastModifiedDate is "YYYYMMDDHHMMSS" (UTC); reformat to "YYYY-MM-DD HH:MM:SS UTC".
  icpc_committed =
    let
      d = self.lastModifiedDate or "00000000000000";
      part = start: len: builtins.substring start len d;
    in
    "${part 0 4}-${part 4 2}-${part 6 2} ${part 8 2}:${part 10 2}:${part 12 2} UTC";

  self_test = pkgs.replaceVars ./files/scripts/self_test {
    inherit (vars) icpc_timezone domjudge_url;
    inherit icpc_commit icpc_committed;
  };
  set_domjudge_creds = pkgs.replaceVars ./files/scripts/set_domjudge_creds.sh {
    inherit (vars) domjudge_url;
  };
  set_hostname = pkgs.replaceVars ./files/scripts/set_hostname.sh {
    inherit (vars) hostnames_api dns_api dns_zone;
  };

  # set_teamname.sh needs Pango-markup escaping (gi.repository.GLib), but
  # scripts.nix's plain `python3` in environment.systemPackages has no
  # site-packages wired up for the separate python3Packages.* entries listed
  # alongside it (a common NixOS pitfall - they don't merge into a bare
  # interpreter's importable packages), so `import gi` fails there. Giving
  # this script its own self-contained wrapped interpreter sidesteps that
  # entirely, without touching the shared systemPackages python3 (avoiding a
  # bin/python3 collision with compilers.nix's separate plain `python3`).
  escapeMarkup = pkgs.writers.writePython3Bin "escape-markup" {
    libraries = [ pkgs.python3Packages.pygobject3 ];
  } ''
    from gi.repository import GLib
    import sys
    print(GLib.markup_escape_text(" ".join(sys.argv[1:])).replace("&", "\\&"))
  '';
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

  # services.logind.extraConfig = ''
  #   KillOnlyUsers=contestant
  # '';

  #TODO delete icpc workspaces
  #TODO add icpcadmin home template

  systemd.tmpfiles.rules = [
    "d /icpc 0755 icpcadmin icpcadmin -"
    # /icpc/scripts is a symlink to /etc/icpc/scripts, where each script is actually
    # installed (see environment.etc.* below). Without this, Exec=/icpc/scripts/... in
    # the desktop-permissions autostart entry (gui.nix) pointed at nothing and the
    # Desktop launchers were never marked trusted.
    "L+ /icpc/scripts - - - - /etc/icpc/scripts"
    "C+ /icpc/wallpaper.png 0755 - - - ${environment.etc.wallpaper.source}"
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

  environment.etc = {
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

    escape_markup = {
      source = "${escapeMarkup}/bin/escape-markup";
      target = "icpc/scripts/bin/escape-markup";
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
      source = self_test;
      target = "icpc/scripts/self_test";
      mode = "0755";
    };

    set_domjudge_creds = {
      source = set_domjudge_creds;
      target = "icpc/scripts/set_domjudge_creds.sh";
      mode = "0755";
    };

    set_hostname = {
      source = set_hostname;
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
        sha256 = "sha256-qi8ETjPiXeWU/24i+s6mYAcUi8R+mUo8ut9JbzNEBx4=";
      };
    };
  };

  environment.variables.PATH = "/icpc/scripts/bin:$PATH";

  systemd.services.firstboot = {
    description = "Initial self test";
    enable = true;
    before = [ "display-manager.service" ];
    wants = [
      "network-online.target"
      "printer.target"
      "squid.service"
    ];
    after = [
      "network-online.target"
      "cups.service"
      "getty@tty2.service"
    ];
    wantedBy = [
      "graphical.target"
      "multi-user.target"
    ];

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
