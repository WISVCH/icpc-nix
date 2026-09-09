---
status: accepted
---

# Sign images as a distinct post-build step, not inside the Nix derivation

ADR 0001 decided to sign GRUB/kernel/initrd with our own key. The obvious hook for that is nixpkgs' `boot.loader.grub.extraInstallCommands` — the `raw-efi` image build already runs it, and nixpkgs' own docs use that exact option for post-`grub-install` signing. We rejected it anyway: running inside the derivation means the private release key has to be readable as a build input, which makes it a `/nix/store/*` path — world-readable to any user on the build machine, indefinitely, with none of the access control a plain CI secret gets. That's a real regression against how `PROXMOX_SSH_KEY` is already handled (an ordinary secret consumed by a plain script, never a Nix input).

Instead: `nix build` keeps producing an unsigned `raw-efi` image exactly as before. A separate script runs afterwards, reads the release (or dev) key from a file path/env var, and writes shim, signed GRUB/kernel/initrd, and the certificate directly into the built image's ESP (FAT32) partition via `mtools`, without mounting or root. The key never enters the Nix store or any derivation closure.

This also happens to be what makes signing locally trivial: it's a file path/env var passed to a plain script, not a Nix `--impure` flag. There is no separate "dev key" — contributors who want a real signed local build get their own copy of the actual release key via their own secret manager (e.g. 1Password); a local build without the key is simply unsigned, same as any other missing local secret in this repo (see PR #11's icpcadmin dotfiles key).

## Considered options

- **`boot.loader.grub.extraInstallCommands`** — the nixpkgs-documented hook for this exact kind of thing. Rejected solely because it forces the private key into the Nix store as a build input.

## Consequences

- `nix build .#console` / `.#contestant` now produce an intentionally *unsigned* image; a wrapper (`nix run .#build-signed-console` / `.#build-signed-contestant`) chains build + sign for day-to-day use, and errors clearly if no key is configured.
- Needs documentation on generating the release key/cert and on how a contributor supplies it locally (env var/file path the sign-image script reads) — not a specific tool mandate, since key custody (e.g. 1Password) is left to each contributor.
