# Secrets

Two sops files, two keys, one rule that must never be broken.

## `dev.yaml` — fake values, key ships in the image

`dev.yaml` is encrypted to the age key in `dev-age-key.txt`, and **that private
key is committed to this public repo on purpose**. It is baked into the
`server` image (`modules/nixos/server/secrets.nix`), which is published as a
GitHub release artifact — so anyone who downloads a release can decrypt
`dev.yaml`. That is fine, and it is the design: every value in `dev.yaml` is a
throwaway that was already sitting in plaintext in this repo
(`tests/domjudge/module.nix`'s `domjudge`/`djpw`, `set_hostname.sh`'s
`changeme`). Decrypting it tells an attacker nothing they couldn't already
read.

It buys the thing that matters: the production decryption path — sops-nix
activation, `sops.templates`, systemd credential wiring — runs for real on
VM 303 and in CI, instead of being stubbed out and discovered broken the first
time a real secret is loaded.

## `prod.yaml` — real values, key never leaves peter

Does not exist yet, and is deliberately not created by the PR that introduced
this directory. When it does exist it will be encrypted to a key that lives
only on the production host, is never committed, and is never referenced by
any image build.

## The rule

> **Never add a real secret to `dev.yaml`, and never encrypt anything to the
> dev key that you would not paste into a public GitHub issue.**

A real secret encrypted to the dev key is public from the moment the next
release builds, and it cannot be unpublished — the artifact carries the key
that opens it. `.github/workflows/check.yml` fails the build if anything under
`modules/nixos/server` or `hosts/server` references `prod.yaml`, but nothing
can mechanically catch a real password typed into `dev.yaml`. That one is on
the author.

## Editing

```bash
sops secrets/dev.yaml          # decrypts, opens $EDITOR, re-encrypts on save
```

`.sops.yaml` in the repo root routes the file to the right key automatically.
