{ lib, pkgs, ... }:

let
  toolsVersion = "2.5.1056";
  zipFiles = [
    {
      name = "presentations-${toolsVersion}";
      sha256 = "sha256-/YpuxLPL2bRWL9hvXCk/kwoM1I06UDnIO1kagD8gBls=";
      extractTo = "tools/presentations-${toolsVersion}";
    }
    {
      name = "presentationAdmin-${toolsVersion}";
      sha256 = "sha256-RwXRRpWrltZPwVlNfgFTu732KSzIx1nhDnTzoSmT9t4=";
      extractTo = "tools/presentationAdmin-${toolsVersion}";
    }
    {
      name = "resolver-${toolsVersion}";
      sha256 = "sha256-clAT3w67TP1YmtO3qNVXzRSDmlD5GfnL3giDoJEY4v0=";
      extractTo = "tools/resolver-${toolsVersion}";
    }
  ];

  generateFiles = zip: {
    "tools/${zip.name}" = {
      source = pkgs.fetchzip {
        url = "https://github.com/icpctools/icpctools/releases/download/v${toolsVersion}/${zip.name}.zip";
        sha256 = zip.sha256;
        stripRoot = false;
      };
      target = "ro/${zip.extractTo}";
      onChange = ''
        mkdir -p /home/icpctools/tools
        cp -rL /home/icpctools/ro/${zip.extractTo} /home/icpctools/${zip.extractTo}
        chmod -R +w /home/icpctools/tools
      '';
    };
  };
  filesList = map generateFiles zipFiles;
  files = lib.mkMerge filesList;
in
{
  home.username = "icpctools";
  home.homeDirectory = "/home/icpctools";
  home.stateVersion = "23.11";
  programs.home-manager.enable = true;

  home.file = files;
}
