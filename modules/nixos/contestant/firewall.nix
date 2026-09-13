{ vars, lib, ... }:
let
  inherit (vars) domjudge_url hostnames_api dns_api judge_ip;

  # Small, explicit, pinned-by-IP set of Google's public NTP servers.
  # DOMjudge submission timestamps depend on a correct clock, and venue NTP
  # servers can't be assumed ahead of time - pinning by IP (rather than
  # hostname) avoids reopening a DNS dependency just for time sync.
  ntp_ips = [ "216.239.35.0" "216.239.35.4" "216.239.35.8" "216.239.35.12" ];
in
{
  # No DNS lookups needed for the judge infrastructure at all - the
  # nftables rule below only ever needs to know judge_ip anyway, and this
  # keeps the contestant machine from having to trust any DNS resolution
  # for these names. See vars.nix for what judge_ip actually points at.
  networking.hosts = {
    "${judge_ip}" = [ domjudge_url hostnames_api dns_api ];
  };

  networking.nftables = {
    enable = true;
    checkRuleset = false;
    ruleset = ''
      #!/usr/sbin/nft -f

      table inet filter {
        chain output {
          # Scoped to the contestant user only: icpcadmin/root keep
          # unrestricted egress, since organizers use these same
          # public-IP machines as SSH jump hosts to reach and manage
          # sibling contestant/console machines (ansible, troubleshooting).
          type filter hook output priority 0; policy accept;

          oif lo accept
          ct state established,related accept

          meta skuid contestant ip daddr ${judge_ip} tcp dport { 80, 443 } accept
          meta skuid contestant ip daddr { ${lib.concatStringsSep ", " ntp_ips} } udp dport 123 accept

          # Everything else from the contestant user is dropped: any other
          # TCP port, all other UDP (including HTTP/3 QUIC on 443, which
          # a plain tcp-only redirect would otherwise miss), and any direct
          # DNS query (closing DNS tunneling/exfiltration as a bypass).
          meta skuid contestant drop
        }
      }
    '';
  };
}
