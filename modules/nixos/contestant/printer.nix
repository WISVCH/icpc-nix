{ pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    cups
    gnomeExtensions.printers
    enscript
    cups-pdf-to-pdf
    # python312Packages.fpdf
    # python312Packages.pypdf2
  ];

  services.printing.enable = true;
  services.printing.cups-pdf.enable = true;
  # Deliberately no printers: the venue's real printer is added on the
  # machine at contest time (set_printer.sh), and nixpkgs' default cups-pdf
  # instance would otherwise show up as one. So cups runs with an empty
  # queue list, which is why self_test's "there are printers present" check
  # reports Fail on a fresh image and in the VM tests. Printing is still
  # unfinished work (WISVCH/icpc-nix#77), so don't "fix" this by dropping the
  # mkForce.
  services.printing.cups-pdf.instances = lib.mkForce { };

  environment.etc = {
    "papersize" = {
      text = ''
        A4

      '';
      mode = "0644";
    };
  };
}
