{ ... }:

# USB/hotplug device control for contestant machines - see
# docs/adr/0005-usb-hotplug-device-control.md for the rationale.
{
  services.usbguard = {
    enable = true;

    # Devices already connected when the daemon starts (the fixed venue
    # keyboard/mouse/hub) are trusted unconditionally - enforcement below
    # only applies to devices plugged in after boot.
    presentDevicePolicy = "allow";

    # Default-deny (services.usbguard.implicitPolicyTarget already defaults
    # to "block"): only allow the interface classes a contestant machine
    # actually needs. Everything else - USB mass storage, and
    # network-interface-class devices (USB-Ethernet/Wi-Fi/cellular
    # dongles) in particular - falls through to the implicit block. This
    # also catches the vendor-specific (class ff) dongles that most
    # real-world Wi-Fi/cellular adapters actually enumerate as, which a
    # denylist of "network" classes alone would miss.
    rules = ''
      allow with-interface one-of { 03:*:* 09:*:* }
    '';
  };
}
