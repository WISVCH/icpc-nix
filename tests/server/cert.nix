# A test-only self-signed TLS cert for the "server" node.
#
# One certificate covering every name the server serves, rather than one per
# name: modules/nixos/server/nginx.nix uses a single cert across all three
# vhosts (its own first-boot self-signed default does the same, with the same
# SAN list), so issuing three here would be testing a shape production doesn't
# have.
#
# self_test's DOMjudge autologin check hardcodes `curl https://@domjudge_url@/...`
# with no `-k`, so rather than weakening that production script for tests, the
# client nodes are made to trust this cert instead (see ../lib.nix).
{ pkgs, names }:
let
  generated =
    pkgs.runCommand "server-test-cert"
      {
        nativeBuildInputs = [ pkgs.openssl ];
      }
      ''
        mkdir -p $out
        openssl req -x509 -newkey rsa:2048 -nodes \
          -keyout $out/key.pem -out $out/cert.pem \
          -days 3650 -subj "/CN=${builtins.head names}" \
          -addext "subjectAltName=${pkgs.lib.concatMapStringsSep "," (n: "DNS:${n}") names}"
      '';
in
{
  cert = "${generated}/cert.pem";
  key = "${generated}/key.pem";
}
