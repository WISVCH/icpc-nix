---
status: accepted
---

# Ship shim→GRUB trust first; defer GRUB→grub.cfg/kernel/initrd trust to a follow-up

ADR 0001 said we'd "sign GRUB/kernel/initrd." In practice these are two independent trust mechanisms: `sbsign` (X.509/PE-Authenticode) gates shim→GRUB, verified via MOK; a completely separate mechanism — a GPG keypair embedded in GRUB's core image via `grub-install --pubkey`, plus `--disable-shim-lock` and `check_signatures=enforce` — gates everything GRUB itself loads afterwards: `grub.cfg`, the kernel, and the initrd. Without the second mechanism, `grub.cfg` is loaded unsigned from disk, so an attacker with USB/disk access can still edit it to boot arbitrary code even once shim only trusts our signed GRUB.

This PR implements only the first mechanism (shim/MOK, ADR 0002). The second is deferred to a follow-up (issue #21), not bundled in here, because:

- It's a second, independent keypair with its own custody story, not a small addition to the first.
- `check_signatures=enforce` risks bricking boot into GRUB rescue mode if misconfigured — on exam-room machines with no console access, that failure mode deserves its own isolated testing pass, not to ship bundled with (and risk blocking) the shim/MOK work.
- Landing shim/MOK first gives us a real, testable milestone (USB boot + MOK enrollment working at all) before adding the riskier layer on top.

## Consequences

- Until issue #21 lands, `grub.cfg`/kernel/initrd integrity is **not** protected — this is a known, deliberate, tracked gap, not an oversight. Don't treat this PR as "Secure Boot done"; it's the first of two layers.
- The public GPG key for the second layer can be embedded at ordinary build time (public data, no custody concern); only the signing step for grub.cfg/kernel/initrd needs the same out-of-Nix-store handling as the release key (ADR 0002).
