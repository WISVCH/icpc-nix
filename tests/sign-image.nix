{
  pkgs,
  shim,
  signImage,
}:

# Runs scripts/sign-image.sh (through the same signImage wrapper the release
# workflow uses) against a small fixture disk laid out like a raw-efi image's
# ESP, signed with a throwaway key made at build time. Without this, the
# script's first run on real input is the release job itself: the doubled
# "::/kernels/::/kernels/..." path from 0fd70fa was only found there.
#
# What it covers is the script's own logic, not the image layout (that is
# install-grub.pl's, and the VM tests boot it) nor whether the signed chain
# actually boots under Secure Boot (nothing automates that yet).
#
# The fixture's EFI binaries are real PE files, because sbsign refuses
# anything else: systemd-boot stands in for the unsigned GRUB at
# EFI/BOOT/BOOTX64.EFI, and pkgs.linux's bzImage is the kernel, named the way
# install-grub.pl's copyToKernelsDir names it.
pkgs.runCommand "sign-image-check"
  {
    nativeBuildInputs = with pkgs; [
      dosfstools
      mtools
      openssl
      sbsigntool
      util-linux
      signImage
    ];
  }
  ''
    export MTOOLS_SKIP_CHECK=1

    openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj "/CN=sign-image test" \
      -keyout test.key -out test.crt 2>/dev/null
    export ICPC_NIX_SIGNING_KEY="$PWD/test.key"
    export ICPC_NIX_SIGNING_CERT="$PWD/test.crt"

    cp ${pkgs.systemd}/lib/systemd/boot/efi/systemd-bootx64.efi bootloader.efi
    cp ${pkgs.linux}/bzImage kernel.orig
    echo "not a kernel" > initrd.orig
    KERNEL="$(basename ${pkgs.linux})-bzImage"
    INITRD="0000000000000000000000000000000-initrd-linux-initrd"

    # 64 MiB FAT ESP at 1 MiB into a GPT disk, with a 1 MiB tail for the
    # backup GPT.
    mkfs.vfat -n ESP -C esp.img $((64 * 1024)) >/dev/null
    mmd -i esp.img ::/EFI ::/EFI/BOOT ::/kernels
    mcopy -i esp.img bootloader.efi ::/EFI/BOOT/BOOTX64.EFI
    mcopy -i esp.img kernel.orig "::/kernels/$KERNEL"
    mcopy -i esp.img initrd.orig "::/kernels/$INITRD"

    truncate -s 66M disk.img
    echo "start=2048, size=$((64 * 2048)), type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B" \
      | sfdisk --quiet --label gpt disk.img
    dd if=esp.img of=disk.img bs=1M seek=1 conv=notrunc status=none

    sign-image disk.img

    # Check the result independently of the script's own verification.
    ESP="disk.img@@$((1024 * 1024))"
    mcopy -i "$ESP" ::/EFI/BOOT/BOOTX64.EFI out-bootx64.efi
    mcopy -i "$ESP" ::/EFI/BOOT/grubx64.efi out-grubx64.efi
    mcopy -i "$ESP" ::/EFI/BOOT/mmx64.efi out-mmx64.efi
    mcopy -i "$ESP" ::/EFI/keys/icpc-nix.cer out-icpc-nix.cer
    mcopy -i "$ESP" "::/kernels/$KERNEL" out-kernel
    mcopy -i "$ESP" "::/kernels/$INITRD" out-initrd

    cmp out-bootx64.efi ${shim}/shimx64.efi
    cmp out-mmx64.efi ${shim}/mmx64.efi
    openssl x509 -in test.crt -outform DER | cmp - out-icpc-nix.cer
    cmp out-initrd initrd.orig

    # Guard against a vacuous pass: the inputs must not already verify.
    if sbverify --cert test.crt bootloader.efi 2>/dev/null; then
      echo "fixture bootloader is already signed with the test key" >&2
      exit 1
    fi
    if sbverify --cert test.crt kernel.orig 2>/dev/null; then
      echo "fixture kernel is already signed with the test key" >&2
      exit 1
    fi
    sbverify --cert test.crt out-grubx64.efi
    sbverify --cert test.crt out-kernel

    touch "$out"
  ''
