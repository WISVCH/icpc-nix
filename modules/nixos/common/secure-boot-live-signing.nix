# Re-signs GRUB + every kernel on THIS machine's live ESP after
# `switch-to-configuration boot` installs a fresh, unsigned GRUB - i.e. on
# every `nixos-rebuild switch`/`boot`. See scripts/sign-boot-live.sh for the
# full mechanism and docs/adr/0007-live-resigning-after-nixos-rebuild.md for
# why this needs a separate mechanism from scripts/sign-image.sh (which only
# ever touches an offline, already-built .img file).
#
# Always wired in, no option to disable: it's always safe to run, since it
# no-ops quietly whenever /etc/icpc-nix/release.key isn't present - which is
# every `nix build`/image-build invocation (sandboxed, can't see that path)
# and every machine nobody has provisioned with the live key.
{ pkgs, ... }:

let
  shim = import ../../../packages/shim.nix {
    inherit pkgs;
    inherit (pkgs) lib;
  };

  signBootLive = pkgs.writeShellApplication {
    name = "sign-boot-live";
    runtimeInputs = with pkgs; [
      sbsigntool
      openssl
      coreutils
    ];
    text = ''
      export SHIM_DIR="${shim}"
      export ICPC_NIX_SIGNING_CERT="${../../../keys/icpc-nix-release.cer}"
      exec ${../../../scripts/sign-boot-live.sh}
    '';
  };
in
{
  boot.loader.grub.extraInstallCommands = ''
    ${signBootLive}/bin/sign-boot-live
  '';
}
