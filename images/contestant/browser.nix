{ lib, pkgs, ... }:
let
  domjudge_url = "dj.chipcie.ch.tudelft.nl";
in
{


  programs.firefox = {
    enable = true;
    package = pkgs.firefox-esr;
    profiles = {
      default = {
        extensions = [ ];

        bookmarks = [
          {
            name = "Sites";
            toolbar = true;
            bookmarks =
              [
                {
                  name = "DOMjudge";
                  url = "http://${domjudge_url}";
                  # "Favicon" = "http://${domjudge_url}/favicon.ico";
                }
                {
                  name = "DOMjudge team manual";
                  url = "http://${domjudge_url }/doc/manual/domjudge-team-manual.pdf";
                  # "Favicon" = "http://${domjudge_url}/favicon.ico";
                }
                {
                  name = "Jury Advice";
                  url = "http://localhost:8080/jury-advice.pdf";
                }
                {
                  name = "Documentation";
                  url = "http://localhost:8080";
                }
              ];
          }
        ];
        # settings = {
        #   "browser.startup.homepage" = "${domjudge_url}|${domjudge_url}/doc/manual/domjudge-team-manual.pdf|localhost:8080";
        #   "browser.shell.checkDefaultBrowser" = false;
        #   "browser.startup.homepage_override.mstone" = "ignore";
        #   "app.update.enabled" = false;
        #   "browser.rights.3.shown" = true;
        #   "toolkit.telemetry.prompted" = 2;
        #   "toolkit.telemetry.rejected" = true;
        #   "browser.newtabpage.enabled" = false;
        #   "browser.urlbar.suggest.bookmark" = true;
        #   "browser.urlbar.suggest.history" = true;
        #   "browser.urlbar.suggest.openpage" = true;
        #   "browser.urlbar.suggest.searches" = false;
        #   "browser.urlbar.suggest.topsites" = false;
        #   "browser.urlbar.suggest.engines" = false;
        #   "browser.urlbar.suggest.quicksuggest" = false;
        #   "browser.urlbar.suggest.calculator" = true;
        #   "datareporting.policy.firstRunURL" = "";
        #   "datareporting.healthreport.service.enabled" = false;
        #   "datareporting.healthreport.uploadEnabled" = false;
        #   "datareporting.policy.dataSubmissionEnabled" = false;
        #   "toolkit.telemetry.unified" = false;
        #   "app.shield.optoutstudies.enabled" = false;
        #
        #   "browser.places.smartBookmarksVersion" = -1;
        #   "browser.bookmarks.restore_default_bookmarks" = false;
        #
        #   "browser.toolbars.bookmarks.visibility" = "always";
        #
        #   "network.captive-portal-service.enabled" = false;
        # };
      };
    };
    policies = {
      # NoDefaultBookmarks = true;
      # DisableProfileImport = true;
      Preferences = {
        "browser.startup.homepage" = {
          Value = "${domjudge_url}|${domjudge_url}/doc/manual/domjudge-team-manual.pdf|localhost:8080";
          Status = "locked";
        };

        "browser.shell.checkDefaultBrowser" = {
          Value = false;
          Status = "locked";
        };

        "browser.startup.homepage_override.mstone" = {
          Value = "ignore";
          Status = "locked";
        };

        "app.update.enabled" = {
          Value = false;
          Status = "locked";
        };

        "browser.rights.3.shown" = {
          Value = true;
          Status = "locked";
        };

        "toolkit.telemetry.prompted" = {
          Value = 2;
          Status = "locked";
        };

        "toolkit.telemetry.rejected" = {
          Value = true;
          Status = "locked";
        };

        "browser.newtabpage.enabled" = {
          Value = false;
          Status = "locked";
        };

        "browser.urlbar.suggest.bookmark" = {
          Value = true;
          Status = "locked";
        };

        "browser.urlbar.suggest.history" = {
          Value = true;
          Status = "locked";
        };

        "browser.urlbar.suggest.openpage" = {
          Value = true;
          Status = "locked";
        };

        "browser.urlbar.suggest.searches" = {
          Value = false;
          Status = "locked";
        };

        "browser.urlbar.suggest.topsites" = {
          Value = false;
          Status = "locked";
        };

        "browser.urlbar.suggest.engines" = {
          Value = false;
          Status = "locked";
        };

        "browser.urlbar.suggest.quicksuggest" = {
          Value = false;
          Status = "locked";
        };

        "browser.urlbar.suggest.calculator" = {
          Value = true;
          Status = "locked";
        };

        "datareporting.policy.firstRunURL" = {
          Value = "";
          Status = "locked";
        };

        "datareporting.healthreport.service.enabled" = {
          Value = false;
          Status = "locked";
        };

        "datareporting.healthreport.uploadEnabled" = {
          Value = false;
          Status = "locked";
        };

        "datareporting.policy.dataSubmissionEnabled" = {
          Value = false;
          Status = "locked";
        };

        "toolkit.telemetry.unified" = {
          Value = false;
          Status = "locked";
        };

        "app.shield.optoutstudies.enabled" = {
          Value = false;
          Status = "locked";
        };

        "browser.places.smartBookmarksVersion" = {
          Value = -1;
          Status = "locked";
        };

        "browser.bookmarks.restore_default_bookmarks" = {
          Value = false;
          Status = "locked";
        };

        "browser.toolbars.bookmarks.visibility" = {
          Value = "always";
          Status = "locked";
        };

        "network.captive-portal-service.enabled" = {
          Value = false;
          Status = "locked";
        };

        "xpinstall.signatures.required" = {
          Value = false;
          Status = "locked";
        };
        "extensions.installDistroAddons" = {
          Value = true;
          Status = "locked";
        };
        "extensions.autoDisableScopes" = {
          Value = 0;
          Status = "locked";
        };

      };
      ExtensionSettings = lib.mkForce {
        "dj-addon@chipcie.ch.tudelft.nl" = {
          "installation_mode" = "force_installed";
          "install_url" = "file:///etc/icpc/dj-addon@chipcie.ch.tudelft.nl.xpi";
        };
      };
    };
  };
}
