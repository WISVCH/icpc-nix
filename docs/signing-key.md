# The release key

See `docs/adr/0001-secure-boot-strategy.md` and `docs/adr/0002-sign-images-post-build.md` for why this exists. This is the operational how-to: generating it, storing it, and using it locally. It does not cover MOK enrollment on exam-room machines — that's a separate, not-yet-written runbook.

There is exactly one release key. There is no separate "dev key" (see `CONTEXT.md`) — a local build without access to the release key is simply unsigned, same as any other missing local secret in this repo (e.g. the `icpcadmin` home-manager deploy key).

## Generating it

This is a one-time operation (see "Rotation" below for why). Generate a long-lived self-signed X.509 keypair:

```sh
openssl req -newkey rsa:4096 -nodes -new -x509 -sha256 -days 9125 \
  -subj "/CN=icpc-nix Secure Boot/O=WISVCH" \
  -keyout icpc-nix-release.key \
  -out icpc-nix-release.cer
```

`-days 9125` is ~25 years. Per `docs/adr/0001-secure-boot-strategy.md`, MOK enrollment trusts this certificate on each exam-room machine, and re-enrollment is only forced by a machine's own state resetting — not by our release cadence. A cert that outlives the project avoids ever forcing a re-enrollment pass across ~100 machines for key-rotation reasons alone. If you ever do need to rotate (compromise, mistake), treat it like a new project: every previously-enrolled machine needs re-enrollment against the new cert.

This produces two files:

- `icpc-nix-release.key` — the private key. **Never commit this.** Store it as the `ICPC_NIX_SIGNING_KEY` secret in this repo's GitHub Actions settings (Settings → Secrets and variables → Actions), and keep your own copy in whatever secret manager you use locally (e.g. 1Password via devenv) — same pattern as `PROXMOX_SSH_KEY`.
- `icpc-nix-release.cer` — the public certificate (PEM). This is not sensitive. It's committed to the repo at `keys/icpc-nix-release.cer`, and the sign-image step converts a copy to DER and ships it on each image's ESP so it's available for MOK enrollment straight off the USB.

## Using it locally

`nix run .#build-signed-console` (or `.#build-signed-contestant`) builds and signs an image in one step. It reads the key from two environment variables:

- `ICPC_NIX_SIGNING_KEY` — path to your local copy of the private key file. Required; the script fails loudly if it's unset or the file doesn't exist.
- `ICPC_NIX_SIGNING_CERT` — path to the certificate. Defaults to the committed `keys/icpc-nix-release.cer` if unset, so you normally only need to set the key path.

```sh
ICPC_NIX_SIGNING_KEY=~/.secrets/icpc-nix-release.key nix run .#build-signed-console
```

However you get that file onto your disk (1Password CLI, devenv, a plain copy) is up to you — the script only cares about the path.

Plain `nix build .#console` / `.#contestant` still works and produces an intentionally *unsigned* image; it never needs the key.

## CI

`.github/workflows/build-image.yml` reads the same private key from the `ICPC_NIX_SIGNING_KEY` repository secret and runs the same `scripts/sign-image.sh` step as the local flow, materializing it to a temp file for the duration of the job.
