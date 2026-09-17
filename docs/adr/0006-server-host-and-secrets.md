# 6. The server host, and how its secrets are handled

Date: 2026-09-17

## Status

Accepted.

## Context

icpc-nix has declared two machines so far: `console` and `contestant`. The
third machine at every contest — "peter", running DOMjudge's domserver, its
MariaDB, chipcie-dns (hostnames_api + PowerDNS) and eventually CDS — has never
been in here. It is a hand-managed Ubuntu VM.

That gap is what issue #61 is about: language versions, DOMjudge versions and
chipcie-dns behaviour can drift between the machines because only two of the
three are declared anywhere. It also means the DOMjudge our VM tests run
against is a test-only fixture (`tests/domjudge/module.nix`) that mirrors
production by hand, with nothing keeping the mirror honest.

Two things made this awkward to just do:

1. **The image deploy model destroys state.** `console` and `contestant` are
   flashed onto disposable machines, and `deploy/proxmox/ci-deploy-image.sh`
   deploys by writing raw bytes over the target VM's whole disk. A domserver
   is not disposable — it holds a live contest.
2. **This repo is public and the images are published.** A server config needs
   a MariaDB password, a PowerDNS API key and more. `vars.nix` and
   `set_hostname.sh` currently ship `changeme` with a TODO, and issue #43 has
   been open on exactly this since before the images existed.

## Decision

### The server is declared here; peter is not migrated yet

`modules/nixos/server/` is the real host configuration, and both
`nixosConfigurations.server` and `packages.server` (a raw-efi image, signed
like the other two) are built from it.

The image is deployed **only** to a new Proxmox staging VM, **303**. Peter
stays on Ubuntu. Whether peter ever moves to NixOS is a later decision that
303 exists to inform.

### The test node will be this module, not a copy of it

`tests/` imports `modules/nixos/server` with test-only overrides rather than
restating it. A test-only mirror is the exact drift #61 exists to kill. (The
test suites are merged onto this module in a follow-up PR; this one adds the
module.)

### 303 is wipe-on-deploy, and that has a known cost

303 gets a single 20 GB scsi0 disk, and a deploy overwrites it — database
included. No separate state disk.

The cost is explicit: **303 can never tell us whether an update preserves a
live contest.** It validates the shape of the services, not the upgrade path.
Anyone reading this before deciding to move peter off Ubuntu should know that
the decision rests on the former and not the latter.

### Secrets: sops-nix, with two keys that must never be confused

sops-nix, with the secret file and age identity exposed as
`modules.server.secrets.{file,ageKeyFile}` so production can swap both without
touching any service definition.

- `secrets/dev.yaml` is encrypted to `secrets/dev-age-key.txt`, and **that
  private key is committed and ships inside the published image**. Every value
  in it is a throwaway that was already in this repo in plaintext
  (`domjudge`/`djpw` from the test fixture, `changeme` from
  `set_hostname.sh`). Decrypting it reveals nothing.
- `secrets/prod.yaml` does not exist yet. When it does, its key lives only on
  the production host, is never committed, and is never referenced by an image
  build.

The point of shipping a real-but-worthless key rather than stubbing secrets
out in tests is that the production decryption path — sops-nix activation,
`sops.templates`, the systemd wiring — actually runs on 303 and in CI. A
stubbed path is one that gets discovered broken the first time it matters.

This makes the public artifact safe **by construction**: the only key it
carries opens only public values. What it does not do is make the repo immune
to a careless commit. A real secret encrypted to the dev key is public from
the next release build and cannot be unpublished. `check.yml` fails if
anything under `modules/nixos/server` or `hosts/server` references
`prod.yaml`; nothing can mechanically catch a real password typed into
`dev.yaml`.

Issue #43 (the contestant image's DNS API key) is **not** closed by this. A
contestant image is physically handled by untrusted contestants, which is a
different threat model than a Proxmox VM, and it deserves its own decision
rather than inheriting this one.

## Consequences

- Three images now, three staging VMs, three release targets.
  `PROXMOX_SERVER_VMID` joins the repository variables.
- `build-image.yml`'s deploy target was chosen by a binary ternary
  (`image == 'console' && CONSOLE_VMID || CONTESTANT_VMID`), which sent
  everything that wasn't `console` to the contestant VM. Adding a third image
  would have silently overwritten the contestant staging disk. It is now an
  explicit map that fails loudly on an unmapped image.
- `modules.server.tls` defaults to a self-signed certificate generated on
  first boot, because 303 has no public DNS and cannot complete an ACME
  challenge. Production supplies a real certificate and sets
  `selfSign = false`.
- Contest content — `contest.yaml`, problems, teams, judgehost passwords,
  `cds_password` — stays in icpc-playbooks. This module owns services and
  their configuration, nothing that changes per contest.
- CDS is not here yet. It is the one service in the original scope with no
  packaging anywhere in this repo, and it is tracked separately.
