set export
ANSIBLE_HOST_KEY_CHECKING := "False"

default:
  @just --list

# Format every file treefmt owns (config: ./treefmt.nix).
fmt:
  nix fmt

# What CI checks, without writing anything. Unlike `nix flake check`, this
# needs no access to the private icpc-playbooks input.
fmt-check:
  nix build .#checks.x86_64-linux.formatting --no-link

# Teach this clone to skip the repo-wide reformat in `git blame`. Per-clone,
# so it has to be run once by hand; GitHub's blame view reads
# .git-blame-ignore-revs on its own.
setup-blame:
  git config blame.ignoreRevsFile .git-blame-ignore-revs

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
