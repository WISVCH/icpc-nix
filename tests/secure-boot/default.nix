{
  pkgs,
  lib,
  system,
  shim,
  signImage,
}:

# Boots a signed raw-efi image under Secure Boot and checks that the whole
# chain holds: firmware (Microsoft keys) -> Debian's shim -> our GRUB (trusted
# through a MokList entry) -> our kernel -> userspace.
#
# It uses a throwaway key: virt-fw-vars writes its certificate straight into
# MokList in the OVMF variable store, which stands in for enrolling
# EFI/keys/icpc-nix.cer through MokManager on real hardware.
#
# Three boots of the same image:
#   - signed:          sign-image output as-is, on a virtio disk - what the
#                      Proxmox staging VMs are; must reach userspace with
#                      SecureBoot=1.
#   - signed-usb:      the same image behind an emulated xHCI controller as a
#                      USB mass-storage device - what a flashed contest stick
#                      is; must also reach userspace. This is what covers the
#                      initrd's usb_storage/uas modules
#                      (modules/nixos/common/boot.nix): without them stage 1
#                      never finds the root label on a stick, which is how #7
#                      failed on real hardware while every virtio boot passed.
#   - unsigned-kernel: GRUB still signed, the original unsigned kernel put
#                      back; must NOT start the kernel. This is the claim
#                      behind signing the kernel at all (0fd70fa,
#                      docs/adr/0006-sign-kernel-not-initrd.md).
# The signed boot is the control for the unsigned one: if it fails, the
# unsigned result says nothing, so the test fails before looking at it.
let
  image =
    (lib.nixosSystem {
      inherit system;
      modules = [
        ../../modules/nixos/common/boot.nix
        # Brings in the patched cptofs that make-disk-image uses.
        ../../modules/nixos/common/overlays.nix
        ./image.nix
      ];
    }).config.system.build.images.raw-efi;

  ovmf = pkgs.OVMFFull;

  # Any GUID works as the owner of the MokList entry; this is shim's own.
  mokOwner = "605dab50-e046-4300-abb6-3dd810dd8b23";
in
pkgs.runCommand "secure-boot-test"
  {
    nativeBuildInputs = with pkgs; [
      jq
      mtools
      openssl
      python3Packages.virt-firmware
      qemu_kvm
      util-linux
      signImage
    ];
    requiredSystemFeatures = [ "kvm" ];
  }
  ''
    export MTOOLS_SKIP_CHECK=1

    openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj "/CN=secure-boot test" \
      -keyout test.key -out test.crt 2>/dev/null
    export ICPC_NIX_SIGNING_KEY="$PWD/test.key"
    export ICPC_NIX_SIGNING_CERT="$PWD/test.crt"

    # Microsoft-enrolled OVMF variables (Secure Boot on) plus our MokList
    # entry. --set-shim-verbose makes shim log its decisions to the console.
    virt-fw-vars --input ${ovmf.variablesMs} --output vars.fd \
      --secure-boot --add-mok ${mokOwner} test.crt --set-shim-verbose

    cp --sparse=always ${image}/nixos.img signed.img
    chmod +w signed.img

    ESP_OFFSET="$(sfdisk -J signed.img | jq -r '
      .partitiontable as $t
      | ($t.partitions[] | select((.type | ascii_downcase) == "c12a7328-f81f-11d2-ba4b-00a0c93ec93b") | .start)
        * ($t.sectorsize // 512)')"
    KERNEL_PATH="$(mdir -i "signed.img@@$ESP_OFFSET" -b ::/kernels | grep -i bzimage)"
    mcopy -i "signed.img@@$ESP_OFFSET" "$KERNEL_PATH" kernel.unsigned

    sign-image signed.img

    cp --sparse=always signed.img unsigned-kernel.img
    mdel -i "unsigned-kernel.img@@$ESP_OFFSET" "$KERNEL_PATH"
    mcopy -i "unsigned-kernel.img@@$ESP_OFFSET" kernel.unsigned "$KERNEL_PATH"

    # Boots $2 with its own copy of vars.fd, recording the serial console to
    # $1.log. $4 picks how the disk is attached - virtio (the default) or usb,
    # which is the only difference between the signed and signed-usb boots. A
    # successful boot powers itself off. A boot the firmware or kernel has
    # given up on is stopped as soon as that shows up in the log, rather than
    # left to the timeout. -snapshot keeps the disk images untouched between
    # boots.
    boot_vm() {
      local name="$1" disk="$2" secs="$3" attach="''${4:-virtio}" waited=0
      local -a diskargs
      case "$attach" in
        virtio)
          diskargs=(-drive "if=virtio,format=raw,file=$disk")
          ;;
        usb)
          diskargs=(
            -device qemu-xhci,id=xhci
            -drive "if=none,id=usbdisk,format=raw,file=$disk"
            -device usb-storage,bus=xhci.0,drive=usbdisk
          )
          ;;
        *)
          echo "boot_vm: unknown disk attachment: $attach" >&2
          exit 1
          ;;
      esac
      cp vars.fd "$name-vars.fd"
      : > "$name.log"
      qemu-system-x86_64 \
        -enable-kvm -machine q35,smm=on -m 1024 \
        -global driver=cfi.pflash01,property=secure,value=on \
        -drive if=pflash,format=raw,unit=0,readonly=on,file=${ovmf.firmware} \
        -drive if=pflash,format=raw,unit=1,file="$name-vars.fd" \
        "''${diskargs[@]}" -snapshot \
        -display none -vga none -monitor none -no-reboot \
        -serial file:"$name.log" &
      local pid=$!
      while kill -0 "$pid" 2>/dev/null; do
        if grep -q -e "No bootable option or device was found" -e "Kernel panic" "$name.log"; then
          echo "$name: boot gave up, stopping the VM" >&2
          kill "$pid"
          break
        fi
        if [ "$waited" -ge "$secs" ]; then
          echo "$name: no result after ''${secs}s, stopping the VM" >&2
          kill "$pid"
          break
        fi
        sleep 2
        waited=$((waited + 2))
      done
      wait "$pid" || true
      echo "===== serial console: $name =====" >&2
      cat -v "$name.log" >&2
      echo "===== end: $name =====" >&2
    }

    boot_vm signed signed.img 600
    if ! grep -q "SECURE-BOOT-TEST: reached userspace" signed.log; then
      echo "FAIL: the signed image did not reach userspace under Secure Boot" >&2
      exit 1
    fi
    if ! grep -q "SECURE-BOOT-TEST: reached userspace, SecureBoot=1" signed.log; then
      echo "FAIL: the signed image booted, but Secure Boot was not enabled, so the test proves nothing" >&2
      exit 1
    fi

    # Same signed image, same Secure Boot chain, attached the way a flashed
    # stick is. Runs after the virtio boot so a failure here points at the USB
    # path specifically rather than at the image.
    boot_vm signed-usb signed.img 600 usb
    if ! grep -q "SECURE-BOOT-TEST: reached userspace, SecureBoot=1" signed-usb.log; then
      echo "FAIL: the signed image did not reach userspace when attached as a USB mass-storage device" >&2
      exit 1
    fi

    boot_vm unsigned-kernel unsigned-kernel.img 180
    if grep -q -e "SECURE-BOOT-TEST" -e "Linux version" unsigned-kernel.log; then
      echo "FAIL: an unsigned kernel behind a signed GRUB was started under Secure Boot" >&2
      exit 1
    fi

    mkdir -p "$out"
    cp signed.log signed-usb.log unsigned-kernel.log "$out"/
  ''
