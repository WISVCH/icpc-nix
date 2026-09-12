{ ... }:

# Subtest fragment for tests/contestant/default.nix.
#
# Regression test for the contestant USB/hotplug device allowlist
# (docs/adr/0005): a HID device (keyboard/mouse) plugged in after boot must
# be allowed, while mass-storage and network-interface-class (USB-Ethernet)
# devices - the out-of-band exfiltration/egress-bypass vectors issue #51 is
# about - must be blocked. Matches devices by interface class via
# usbguard's own `with-interface { cc:ss:pp }` listing rather than by QEMU's
# product-string names, since that's what the policy actually decides on.
{
  name = "usbguard";
  script = ''
    # Not multi-user.target: see tests/contestant/default.nix for why.
    machine.wait_for_unit("usbguard.service", timeout=60)

    # A HID device (keyboard, interface class 03) plugged in after boot is
    # allowed - contestant machines need to keep working with real
    # keyboards/mice/hubs.
    machine.send_monitor_command("device_add usb-kbd,id=kbd0")
    machine.wait_until_succeeds("usbguard list-devices | grep -E 'with-interface.*03:'")
    machine.succeed("usbguard list-devices | grep -E 'allow.*with-interface.*03:'")

    # A mass-storage device (interface class 08) plugged in after boot is
    # blocked - not on the allowlist, and USB drives are a direct
    # data-exfiltration path.
    with open(machine.state_dir / "usbstick.img", "wb") as stick:
        stick.write(b"\x00" * (1024 * 1024))
    machine.send_monitor_command(
        f"drive_add 0 id=stick,if=none,file={stick.name},format=raw"
    )
    machine.send_monitor_command("device_add usb-storage,id=stick,drive=stick")
    machine.wait_until_succeeds("usbguard list-devices | grep -E 'with-interface.*08:'")
    machine.succeed("usbguard list-devices | grep -E 'block.*with-interface.*08:'")

    # A network-interface-class device (USB-Ethernet/CDC, interface class
    # 02) plugged in after boot is blocked - the exact bypass this policy
    # exists to close (see docs/adr/0004 for why no host firewall config
    # can catch this instead).
    machine.send_monitor_command("netdev_add user,id=usbnet0")
    machine.send_monitor_command("device_add usb-net,id=usbnet_dev,netdev=usbnet0")
    machine.wait_until_succeeds("usbguard list-devices | grep -E 'with-interface.*02:'")
    machine.succeed("usbguard list-devices | grep -E 'block.*with-interface.*02:'")
  '';
}
