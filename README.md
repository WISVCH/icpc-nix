# CHipCie NixOS Configurations

This repo contains the NixOS configuration for CHipCie images, used in prorgramming contests such as FPC, DAPC and NWERC.

This configuration is kickstarted by [this](https://discourse.nixos.org/t/creating-a-nixos-live-cd-for-whole-system/35638/2) post on the Nix community forum.

## Building the images

Building the console image is as easy as running the following command:

```bash
nix build .#console
```

After a succesful build, the image can be found in `result/nixos.img`.

## Testing the images locally

Images are UEFI-only (no legacy BIOS boot), so `qemu` needs OVMF firmware. Use the following command to do so:

```bash
OVMF_CODE=$(nix eval --raw nixpkgs#OVMF.fd)/FV/OVMF_CODE.fd
qemu-system-x86_64 -drive if=pflash,format=raw,unit=0,readonly=on,file="$OVMF_CODE" -drive file=result/nixos.img,index=0,media=disk,format=raw -m 4G -smp 4 -enable-kvm -vga virtio -display default
```

The image can also be tested in Proxmox: import `result/nixos.img` as a VM disk (`qm importdisk`, or attach it directly), set the VM's BIOS to **OVMF**, and boot — no ISO/CD-ROM step needed since it's a bootable disk image, not installation media.

## Building the docs

Docs live under `docs/public/` and are built with [zensical](https://zensical.org/). Preview them locally:

```bash
pip install zensical
zensical serve
```

Pushes to `main` that touch `docs/public/` or `zensical.toml` are deployed automatically to GitHub Pages by `.github/workflows/docs.yml`.

## Releasing and deploying

Releases are built by manually running the **Release image** workflow (Actions tab > "Release image" > Run workflow), which lets you pick the image, a version, whether it's a prerelease, and whether to deploy the result to that image's Proxmox staging VM afterwards. See `.github/workflows/build-image.yml` for the required repository variables/secrets.

One-time setup on the Proxmox host, in order:
1. `deploy/proxmox/create-vms.sh` — creates the two staging VMs (OVMF/UEFI bios, EFI disk, initial disk imported from a raw image you built).
2. `deploy/proxmox/setup.sh` — creates the scoped `ci-deploy` user, its sudoers rule, and the SSH key that goes in the `PROXMOX_SSH_KEY` GitHub secret.