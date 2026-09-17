---
status: accepted
---

# Re-sign GRUB/kernel on every switch, via extraInstallCommands, keyed off a runtime path

ADR 0002 signs images as a distinct post-build step (`scripts/sign-image.sh`), specifically to keep the release private key out of the Nix store. That step only ever touches an offline, already-built `.img` file via `mtools` - it has no bearing on `nixos-rebuild switch`/`boot` run directly against a live machine. `switch-to-configuration boot` calls NixOS's own `install-grub.pl` directly, which writes a fresh, unsigned GRUB to the removable-media fallback path and copies the current kernel(s) into `/boot/kernels` - every time, unconditionally. On a machine where shim/MOK is actually enforcing signatures, that unsigned output would leave the machine unable to boot itself until someone re-signs it by hand.

ADR 0002 rejected `boot.loader.grub.extraInstallCommands` for the image-build case because `make-disk-image.nix` runs GRUB install inside a *sandboxed* Nix derivation - anything that hook's shell text reads has to be a build input, forcing the key into the world-readable Nix store. That constraint is specific to the sandbox. `switch-to-configuration boot` on a live machine runs unsandboxed, with ordinary filesystem access - so the same `extraInstallCommands` hook can safely read a key from a plain runtime path there (`/etc/icpc-nix/release.key`, a new convention - nothing provisions it yet, it has to be placed on a machine out of band, the same way the release key already reaches contributors' laptops per `docs/signing-key.md`).

Since `extraInstallCommands` is the *same* shell text spliced into `system.build.installBootLoader`, and that script also runs inside the sandboxed image build (`packages.x86_64-linux.console`/`.contestant` import the same module), the hook has to degrade gracefully rather than assume the key exists: `scripts/sign-boot-live.sh` checks for `/etc/icpc-nix/release.key` first and exits 0 quietly if it's missing. That keeps `nix build .#console`/`.#contestant` producing an unsigned image exactly as before (unaffected - `sign-image.sh` remains the actual signer for a fresh image) and keeps an ordinary `nixos-rebuild switch` on an unprovisioned machine (e.g. the Proxmox staging VMs, where Secure Boot isn't enforced) a no-op.

A live system differs from a freshly built image in one more way: it can have several old generations' kernels sitting in `/boot/kernels` at once, all still listed in the GRUB menu. `sign-boot-live.sh` signs every `*bzImage*` file found there on every run (idempotent - re-`sbsign`ing an already-signed file just replaces the signature), not just whichever one this switch just added, so every generation in the menu stays bootable under enforcement.

## Considered options

- **Reuse `scripts/sign-image.sh`'s `mtools` approach against a live mount** - rejected: `/boot` on a running machine is already a normal mounted filesystem; going through `mtools` there would be pointless indirection, not a shared code path with the offline script (the two operate on fundamentally different representations - a raw partition-in-a-file vs. a live mount).
- **A separate `systemd.services.*` oneshot ordered after boot-loader install** - rejected in favor of `extraInstallCommands`: NixOS's own boot-loader-install step isn't a systemd service you can order against from a live-switch context, and `extraInstallCommands` already runs in exactly the right place, at the right time, for free.
- **Gate this behind an explicit NixOS module option** - rejected: the script is always safe to run (it only acts when the key file is actually present), so an option would just be one more knob nobody needs to touch.

## Consequences

- Needs a documented, out-of-band way to place `/etc/icpc-nix/release.key` on a machine that should get live-resigned - not yet written; today the only documented key-distribution path (`docs/signing-key.md`) covers contributors' own laptops for local builds, not a deployed machine's `/etc`.
- `modules/nixos/common/secure-boot-live-signing.nix` is unconditionally imported by `modules/nixos/common/default.nix`, so both `console` and `contestant` - and both `nixosConfigurations.*` (for `nixos-rebuild`) and `packages.x86_64-linux.*` (for `nix build`) - get this hook, uniformly.
- MOK enrollment itself is still untouched by any of this: this ADR only covers re-signing already-installed-and-trusted GRUB/kernel binaries after they change, not first-time trust establishment on a machine.
