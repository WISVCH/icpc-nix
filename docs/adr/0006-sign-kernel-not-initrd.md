---
status: accepted
---

# Extend sbsign to the kernel; deliberately exclude the initrd

ADR 0001/0002 describe signing "GRUB/kernel/initrd" as one bundle. In practice `sbsign` (X.509/PE-Authenticode) only applies to PE/COFF EFI executables - `grubx64.efi` and the kernel (built with an EFI stub, handed to firmware via `LoadImage`). The initrd is a plain cpio blob that GRUB's `initrd` command reads as data and passes to the kernel directly; it's never handed to `LoadImage`, so shim's hook never inspects it. Signing it with `sbsign` would be a no-op - there's nothing in the Secure Boot chain that would ever check that signature.

This was caught investigating the real-hardware failure in the comment on #7 (2026-09-14) and its follow-up fix (PR #67): GRUB was signed but the kernel wasn't, so shim accepted GRUB and then rejected the kernel it tried to load via the same `LoadImage` hook. `scripts/sign-image.sh` now also signs the kernel it finds under `/kernels` on the ESP (named by `install-grub.pl`'s `copyToKernelsDir`, identified by the literal `bzImage` substring in its filename - the naming has no other distinguishing extension).

Initrd integrity is a real gap, but it's `grub.cfg`'s gap too: an attacker with disk access can edit `grub.cfg` to point at any initrd (or kernel, or config) they like, unless GRUB verifies what it reads from disk itself. That's exactly the mechanism ADR 0003 already defers to issue #21 (`grub-install --pubkey` + `check_signatures=enforce`), which gates `grub.cfg`, the kernel, *and* the initrd together as one thing GRUB reads from disk. Bolting an unenforceable `sbsign` signature onto the initrd wouldn't close that gap or wait less on #21; it would just be dead weight.

## Consequences

- `sign-image.sh` requires the ESP to already have a working GRUB install (a `/kernels` directory with exactly one `*bzImage*` file) - a good sanity check in its own right, since PR #67 exists precisely because that wasn't true before.
- Initrd protection stays entirely deferred to issue #21, as ADR 0003 already says. This ADR doesn't change that gap, only clarifies that `sbsign` was never going to close it.
- Live re-signing after `nixos-rebuild switch` (as opposed to the offline image `sign-image.sh` already handles) is out of scope here - `switch-to-configuration boot` runs unsandboxed, so unlike ADR 0002's build-time rejection of `boot.loader.grub.extraInstallCommands`, a runtime key path (e.g. `/etc/icpc-nix/release.key`, convention not yet provisioned anywhere) is safe to read there. Tracked as separate follow-up work under #7.
