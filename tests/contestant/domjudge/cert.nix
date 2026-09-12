# A test-only self-signed TLS cert for the ephemeral "domjudge" node.
#
# self_test's DOMjudge autologin check hardcodes `curl https://@domjudge_url@/...`
# with no `-k`, so rather than weakening that production script for tests,
# the client node is made to trust this cert instead (see default.nix).
{ pkgs, commonName }:
let
  generated = pkgs.runCommand "domjudge-test-cert" {
    nativeBuildInputs = [ pkgs.openssl ];
  } ''
    mkdir -p $out
    openssl req -x509 -newkey rsa:2048 -nodes \
      -keyout $out/key.pem -out $out/cert.pem \
      -days 3650 -subj "/CN=${commonName}" \
      -addext "subjectAltName=DNS:${commonName}"
  '';
in
{
  cert = "${generated}/cert.pem";
  key = "${generated}/key.pem";
}
