{ inputs, ... }:

# The "server" host: DOMjudge's domserver, its MariaDB, chipcie-dns
# (hostnames_api + PowerDNS) and the nginx that terminates TLS in front of
# all three. Production's third machine ("peter"), which today is a
# hand-managed Ubuntu VM - see docs/adr/0006.
#
# This is the real host config, not a test fixture: tests/ imports this same
# module with overrides rather than mirroring it, so the two can't drift.
# CDS is deliberately not here yet (issue TBD).
{
  imports = [
    inputs.sops-nix.nixosModules.sops
    ./base.nix
    ./secrets.nix
    ./containers.nix
    ./nginx.nix
  ];
}
