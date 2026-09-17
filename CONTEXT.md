# icpc-nix

NixOS configurations for the images used to run programming contests (FPC, DAPC, NWERC): the **console** and **contestant** machines contestants and staff sit at, built as flashable disk images and also tested as Proxmox VMs before release.

## Language

**Console**:
The image used by contest staff/admin workstations.
_Avoid_: admin machine, staff image

**Contestant**:
The image used by the machines contestants compete on.

**Staging VM**:
A long-lived Proxmox VM (one per image) that a release can optionally be deployed to for testing, before it goes out to real hardware.
_Avoid_: test VM

**Exam-room machine**:
A physical computer on campus, outside our administrative control, that a console/contestant USB is booted on for a contest. We can reach its BIOS/UEFI setup screen but cannot change any setting in it (Secure Boot cannot be disabled, no key management), and we cannot assume its firmware state (e.g. enrolled keys) survives between events — campus IT may reimage or swap these machines between contests.
_Avoid_: exam PC, lab machine

**Shim**:
A small, Microsoft-signed EFI binary that UEFI Secure Boot already trusts out of the box. It's the first thing Secure Boot firmware runs; shim then hooks the firmware's `LoadImage` call so it also decides whether to trust every subsequent EFI binary loaded afterwards (our GRUB, then the kernel GRUB hands off to via its EFI stub) via its own embedded vendor certificate or its MOK list. We vendor a pre-built, already-signed shim (the standard practice other minimal distros use) rather than trying to get our own binary signed by Microsoft.

**MOK (Machine Owner Key)**:
A certificate (or file hash) enrolled into a specific machine's own trust store by shim's MokManager tool, at boot time, with physical interactive confirmation. Distinct from UEFI firmware's own Setup Mode key management (`db`/`KEK`) — MOK enrollment works through shim/software, not firmware settings, which is why it may remain possible even when a machine's BIOS Setup Mode is locked down.
_Avoid_: secure boot key, enrolled key

**MOK enrollment**:
The one-time, per-machine, interactive act of adding our certificate to a machine's MOK list, via the MokManager screen shim shows at boot. Enrolling the certificate (not a file hash) means future rebuilds of our images, re-signed with the same key, are trusted automatically — no re-enrollment needed. What *does* force re-enrollment is the machine's own state getting reset (reimage, or a different physical machine), independent of whether our image changed.

**Setup window**:
A period of exam-room-machine access, without contestants present, immediately preceding a contest, on the literal machines that will be used for that contest, with no campus IT reimage happening in between. This is when per-machine MOK enrollment for that contest gets done — distinct from the DW test, which can't be assumed to share machines or persisted state with the actual contest.
_Avoid_: prep window, setup day

**DW test**:
A dress-rehearsal / venue test of booting console and contestant USBs, held separately from (and not assumed to share machines or firmware state with) the actual contest.

**Release key**:
The one private signing key (and its certificate) icpc-nix controls. Held as a CI secret for CI builds; contributors who need to sign locally get their own copy via their own secret manager (e.g. 1Password). Its certificate is what actually gets MOK-enrolled on exam-room machines.
_Avoid_: signing key

**Sign-image script**:
The post-build step that writes shim, signed GRUB, the signed kernel, and the certificate onto an already-built raw-efi image's ESP, using the release key. Not the initrd - it's never loaded via `LoadImage`, so shim never checks it; see `docs/adr/0006-sign-kernel-not-initrd.md`. `nix build` itself always produces an unsigned image; signing only happens here, and only when the release key is available.
_Avoid_: signing step, build step (this is deliberately not part of the Nix build — see `docs/adr/0002-sign-images-post-build.md`)

**Live key**:
The release key's counterpart for an already-deployed machine: a copy of the same private key placed at `/etc/icpc-nix/release.key` on that one machine, out of band, never through Nix. Its presence is what `scripts/sign-boot-live.sh` checks for on every `nixos-rebuild switch`/`boot` — present, it re-signs GRUB and every kernel in place; absent (the default, and always true inside a sandboxed `nix build`), it quietly does nothing.
_Avoid_: local key, machine key
