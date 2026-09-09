---
status: accepted
---

# Secure Boot strategy: our own shim + signing key, trusted via per-machine MOK enrollment

Exam-room machines have Secure Boot permanently on: we can reach BIOS setup but can't change anything in it (no disabling Secure Boot, no key management), and we're planning around getting no cooperation from campus IT either (we may still ask opportunistically, but nothing depends on it). NixOS ships no Microsoft- or vendor-signed bootloader/kernel, so a stock image is rejected outright today.

We will vendor a pre-signed, already-Microsoft-trusted shim (the same approach other minimal distros use — reusing e.g. Debian's `shim-signed` binary), generate our own signing key, and sign GRUB/kernel/initrd for both `console` and `contestant` after each image is built (see `docs/adr/0002-sign-images-post-build.md` for why signing is a distinct post-build step rather than a build-time hook). Trust is established per physical machine via shim's MOK enrollment (a one-time, interactive, pre-OS step — distinct from UEFI firmware Setup Mode key management, and so plausible even where Setup Mode itself is locked down). Because we enroll our *certificate* rather than a file hash, future image rebuilds signed with the same key need no re-enrollment — only a machine's own state resetting (reimage, or a different machine) forces re-enrollment, independent of our release cadence.

Since these machines are reimaged or unknown between contests, MOK enrollment can't be front-loaded once and forgotten — it has to happen inside each contest's own no-contestants setup window, on the literal machines used for that contest.

## Considered options

- **`lanzaboote`** — NixOS's more mature Secure Boot project, but built around enrolling your own keys via UEFI Setup Mode. That's the one thing we've confirmed we can't do here.
- **`nixos-shim`** — the native NixOS effort to get a Microsoft-signed shim. Early-stage, blocked on Microsoft's own shim-review approval; not usable on our timeline.
- **Disabling Secure Boot outright** — already declined by campus IT in prior discussions.
- **Falling back to the Ubuntu-based `icpc-env` pipeline** — proven to work here before (`shim-signed` + `grub-efi-amd64-signed`, both Canonical-signed, needing zero MOK/IT involvement), but only because it's genuinely Ubuntu end-to-end. Rejected: staying on NixOS is non-negotiable.
- **Chainloading Ubuntu's already-signed kernel into a custom NixOS initrd/rootfs** — a theoretical way to reuse Ubuntu's zero-touch trust without becoming Ubuntu. Rejected: still unsigned code (our initrd/config) needs *some* trust anchor, so it doesn't remove the MOK/IT requirement; it would also pin the whole running system to Ubuntu's kernel build, a coupling risk with no offsetting benefit. Not prototyped.

## Consequences

- Needs a signing key generated and stored (mirroring how `PROXMOX_SSH_KEY` is already handled as a CI secret), a vendored shim, and a post-build step that signs GRUB/kernel/initrd for both images (ADR 0002).
- Needs a documented, drilled runbook for per-machine MOK enrollment at ~100-machine scale, sized to fit inside each contest's setup window.
- The DW dress-rehearsal likely needs its own (smaller) enrollment pass, since it can't be assumed to share machines or state with the actual contest — useful for validating the *procedure*, not for pre-enrolling the real machines.
