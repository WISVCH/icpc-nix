# Vendors Debian's pre-built, Microsoft-signed shim + MokManager rather than
# trying to get our own binary through Microsoft's shim-review process
# ourselves (see docs/adr/0001-secure-boot-strategy.md). Both .debs are
# fetched with a pinned hash so this stays reproducible even if Debian
# removes the specific point release from the pool later.
{ pkgs, lib }:

let
  shimSigned = pkgs.fetchurl {
    url = "https://deb.debian.org/debian/pool/main/s/shim-signed/shim-signed_1.51~1+deb12u1+16.1-2~deb12u1_amd64.deb";
    hash = "sha256-wqz15VlmS7rbfOV4n5oyHzl1SjSFTTCXuMwDad9ROzs=";
  };

  shimHelpersSigned = pkgs.fetchurl {
    url = "https://deb.debian.org/debian/pool/main/s/shim-helpers-amd64-signed/shim-helpers-amd64-signed_1+16.1+2~deb12u1_amd64.deb";
    hash = "sha256-JqysNRM5RsFkKgnz/aNT7juEnl/GQ/rbl6jf7J4rVfs=";
  };
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "icpc-nix-shim";
  version = "1.51-16.1-2~deb12u1";

  nativeBuildInputs = [ pkgs.binutils pkgs.gnutar pkgs.xz ];

  dontUnpack = true;

  buildPhase = ''
    runHook preBuild

    mkdir -p shim-signed shim-helpers-signed
    ( cd shim-signed && ar x ${shimSigned} && tar xf data.tar.xz )
    ( cd shim-helpers-signed && ar x ${shimHelpersSigned} && tar xf data.tar.xz )

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    install -m444 shim-signed/usr/lib/shim/shimx64.efi.signed "$out/shimx64.efi"
    install -m444 shim-helpers-signed/usr/lib/shim/mmx64.efi.signed "$out/mmx64.efi"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Debian's pre-signed shim + MokManager, vendored for icpc-nix Secure Boot";
    license = licenses.bsd2;
    platforms = [ "x86_64-linux" ];
  };
}
