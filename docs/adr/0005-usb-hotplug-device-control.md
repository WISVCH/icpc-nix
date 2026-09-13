---
status: accepted
---

# Contestant USB/hotplug device allowlist

## Context

Issue #51, surfaced while reviewing the contestant egress firewall/proxy redesign (docs/adr/0004-egress-allowlist-without-squid.md): that ADR explicitly treats physical/out-of-band exfiltration - a contestant plugging in a personal USB Wi-Fi/cellular dongle, or tethering a phone over USB - as out of scope, since no host firewall/nftables config can prevent it (the traffic never touches the machine's own network stack at all).

Per team discussion, venue computers are currently set up such that it's "not easy" to plug in USB devices, but that has only ever been an informal property of chassis/port placement at the venue, never something enforced by the NixOS config itself. That means the actual guarantee depends on venue-specific physical setup that this repo has no visibility into and can't verify.

## The new design

`images/contestant/usbguard.nix` enables `services.usbguard` with a default-deny allowlist, rather than a denylist of "network" device classes:

- Only interface class `03` (HID - keyboard/mouse) and `09` (Hub) are explicitly allowed.
- `services.usbguard.implicitPolicyTarget` is left at its NixOS-module default of `"block"`: anything not explicitly allowed - USB mass storage, USB-Ethernet/CDC adapters, and everything else - is blocked with no separate rule needed.
- `presentDevicePolicy = "allow"`: devices already connected when the daemon starts (the fixed venue keyboard/mouse/hub) are trusted unconditionally. Enforcement only applies to devices plugged in after boot (`insertedDevicePolicy` stays at its default `"apply-policy"`), keeping boot deterministic and independent of USB enumeration order/timing.
- Rules are declared inline via `services.usbguard.rules` (NixOS-managed, immutable, baked into the image at build time) rather than the mutable `/var/lib/usbguard/rules.conf` default, consistent with this repo's already-declarative approach to firewall/system config.
- Scoped to the contestant image only. Console machines are organizer-operated (already trusted with `wheel`/sudo) - a different trust boundary than contestant.

## Considered options

- **Denylist of network-interface-class devices** (block class `02`/`0a` CDC-Ethernet, matching the issue's literal proposed-fix wording). Rejected: most real-world USB Wi-Fi and cellular dongles (Realtek, MediaTek, etc.) actually enumerate as vendor-specific class `ff`, not a standard "network" class, since the driver interface is proprietary rather than USB-IF-standardized. A denylist keyed on network classes would miss exactly the devices issue #51 is worried about; a default-deny allowlist closes that gap for free.
- **Also block USB mass storage** (chosen, folded into the allowlist by omission rather than an explicit rule). Issue #51's *Context* section frames the problem as physical/out-of-band exfiltration broadly, not just network egress bypass - a USB flash drive is as direct an exfiltration path as a cellular dongle, and costs nothing extra once we're default-denying.
- **`presentDevicePolicy = "apply-policy"`** (evaluate the rule set against devices already connected at boot too, rather than trusting them unconditionally). More strictly correct in principle, but rejected here in favor of `"allow"`: it would make first-boot success depend on USB enumeration/detection timing versus rule evaluation for hardware we already physically control (the venue keyboard/mouse/hub), for no real security gain against an attacker who doesn't yet have physical access before boot.

## Consequences

- Physical security at boot time (i.e., what's plugged in before the machine starts) is still not enforced by this config - only devices plugged in after boot are policed. If a venue's physical chassis/port access needs to be audited or tightened further, that remains the informal, venue-specific property this ADR's Context section describes; this change narrows but does not close that gap.
- Legitimate post-boot USB access for troubleshooting (e.g., an organizer plugging in a USB drive) isn't wired into `services.usbguard.IPCAllowedUsers`/`IPCAllowedGroups` beyond the module's own default (`root`), but `icpcadmin` already has passwordless sudo (`images/contestant/base.nix`), so `sudo usbguard allow-device ...` works without further config.
- `tests/contestant/usbguard.nix` adds a VM regression test (wired into `tests/contestant/default.nix`) asserting the allow/block outcome for a HID, a mass-storage, and a USB-Ethernet device plugged in after boot - the same class of check `tests/contestant/firewall.nix` does for the egress allowlist.
