set export
ANSIBLE_HOST_KEY_CHECKING := "False"

default:
  @just --list

run BUILD:
  qemu-system-x86_64 -drive file={{BUILD}}.img,index=0,media=disk,format=raw -m 4G -smp 4 -enable-kvm -vga virtio -display default -net user,hostfwd=tcp::10022-:22 -net nic

build BUILD:
  rm -f {{BUILD}}.img
  nix build .#{{BUILD}}
  cp result/nixos.img {{BUILD}}.img
  chmod +rw {{BUILD}}.img

ansible PLAYBOOK:
  export ANSIBLE_HOST_KEY_CHECKING=False
  ansible-playbook -i ./localinventory --diff --become -u icpcadmin {{PLAYBOOK}}
