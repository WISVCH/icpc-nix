{}:
{
  domjudge_url = "dj.chipcie.ch.tudelft.nl";
  icpc_timezone = "Europe/Amsterdam";
  hostnames_api = "hostnames.chipcie.ch.tudelft.nl";
  dns_api = "pdns.chipcie.ch.tudelft.nl";
  dns_zone = "local.chipcie.mawey.be";

  # domjudge_url / hostnames_api / dns_api all CNAME to chipcie.ch.tudelft.nl,
  # a single dedicated GCP A record - not shared/CDN infrastructure. This is
  # what images/contestant/firewall.nix's nftables egress allowlist is
  # pinned to (see docs/adr/0004); tests/contestant/default.nix overrides
  # this to the ephemeral test DOMjudge node's IP.
  judge_ip = "34.141.175.184";
}
