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