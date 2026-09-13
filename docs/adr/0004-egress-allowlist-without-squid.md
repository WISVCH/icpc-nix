---
status: accepted
---

# Replace squid with a default-deny nftables egress allowlist

The contestant firewall's job is to stop contestants from reaching the open internet except for a small, fixed set of judge-infrastructure hostnames. The existing `modules/nixos/contestant/firewall.nix` tried to do this with an nftables NAT rule that redirected the `contestant` user's `tcp dport 80/443` to a local squid instance, which then enforced a `dstdomain` allowlist. That leaves three independent bypasses, none of which need root (the `contestant` user has no `wheel`/sudo membership): any TCP port other than 80/443 is neither redirected nor blocked and goes straight out; UDP is untouched entirely, so HTTP/3 (QUIC, UDP/443 — on by default in Firefox) skips squid altogether; and direct DNS queries to any resolver are unrestricted, which is both an info leak and a usable exfiltration/tunneling channel. These machines get public IPv4 addresses with no venue-controlled network gear in front of them (the venue firewall only blocks *unsolicited inbound*), so the host config is the entire enforcement boundary — none of this is caught anywhere else.

Separately, `modules/nixos/common` carries `nixpkgs.config.permittedInsecurePackages = [ "squid-6.10" ]` — the squid version pinned by this flake's `nixos-26.05` input has a known vulnerability nixpkgs flags by default. Running a proxy daemon with a flagged CVE, that in practice only ever needs to enforce "one IP, two ports," is a bad trade.

Before removing squid we confirmed nothing actually depends on it for authentication:

- The `submit` CLI client authenticates itself via HTTP Basic Auth from `/icpc/netrc` (written by `set_domjudge_creds.sh`), entirely independent of squid.
- Browser autologin to the DOMjudge web UI is implemented client-side by the `dj-addon` Firefox extension (`background.js`'s `webRequest.onBeforeSendHeaders` listener), which injects the `X-DOMjudge-Login`/`X-DOMjudge-Pass` headers itself, directly on the browser's own outgoing request, independent of whatever the network path does to it afterwards.
- Squid's own copy of this mechanism (`acl autologin url_regex ...` plus a generated `/etc/squid/autologin.conf` with `request_header_add` rules, wired up via #27) duplicates exactly those same two headers from the exact same credentials — it's a second, proxy-side injection of data the browser extension has already put on the request client-side. Removing squid removes the redundant copy, not the only copy.

The three allowed hostnames (`dj.chipcie.ch.tudelft.nl`, `hostnames.chipcie.ch.tudelft.nl`, `pdns.chipcie.ch.tudelft.nl`) all CNAME to `chipcie.ch.tudelft.nl`, a single dedicated GCP-hosted A record (`34.141.175.184`) — not shared CDN/multi-tenant infrastructure. Once the allowlist reduces to "one IP, two ports," squid's HTTP-layer domain parsing is pure overhead: the same restriction is expressible directly as an nftables destination-IP rule, with no proxy daemon, no CVE, and no app-layer trust to reason about.

## The new design

- `modules/nixos/contestant/firewall.nix` gets an `inet filter` `output` chain (`policy accept` — this is scoped to the `contestant` user, not the whole machine; `icpcadmin`/root keep unrestricted egress, since organizers use these same public IPs as SSH jump hosts to reach and manage sibling contestant/console machines for ansible and troubleshooting).
- Traffic from `meta skuid contestant` is allowed only to `34.141.175.184` on `tcp dport { 80, 443 }`, and to a small pinned set of Google's public NTP servers (`216.239.35.0/4/8/12`) on `udp dport 123` — DOMjudge submission timestamps depend on correct clocks, venue NTP servers are unknown ahead of time, and pinning by IP avoids reopening a DNS dependency just for time sync. Everything else from that user is dropped, closing the other-port and UDP/QUIC bypasses in one rule.
- The three allowed hostnames are pinned via `networking.hosts` to `34.141.175.184`, so the contestant machine never needs to perform DNS resolution for them. Combined with the default-drop above (which also covers port 53), direct DNS queries — the tunneling/exfiltration channel — are closed entirely rather than merely routed through squid's own resolver.
- Squid, the NAT-redirect table, `networking.proxy.*`, the dead `autologin` ACL/placeholder, and the `permittedInsecurePackages` entry for `squid-6.10` are all removed.

## Considered options

- **Keep squid, just patch its coverage** (add the missing default-deny/UDP-block/DNS-lockdown alongside it). Rejected: once the allowlist is "one pinned IP, two ports," squid's domain-parsing adds nothing, and keeping it keeps the insecure-package opt-in around for a component providing no remaining value.
- **Replace squid with a leaner SNI-aware proxy** (nginx `stream` + `ssl_preread`, or `sniproxy`) to keep an HTTP-aware layer for future URL/path-level rules. Rejected for now: there's no current or near-term need for that (the one feature that used to reference URL-level squid rules, the autologin rewrite, is already implemented client-side and was never actually wired into squid) — revisit if that need materializes.
- **Push enforcement to the network layer** (venue router/switch ACLs). Not available: organizers don't control any network gear at the venue beyond the machines themselves.

## Consequences

- If the GCP-hosted judge infrastructure's IP ever changes, or a new allowed hostname is added, `networking.hosts` and the nftables allow-rule both need updating together — there's no more dynamic domain-based ACL doing this automatically. This should be a checked step in any future infra migration for `dj`/`hostnames`/`pdns`.
- NTP is pinned to a small explicit set of Google's public time servers by IP; if those addresses ever change, clock sync silently stops working for contestants (fails safe from a security standpoint, but worth covering in `self_test`).
- `tests/contestant/squid.nix` (squid startup + proxy behavior) is replaced by a firewall-allowlist regression test asserting the pinned destination is reachable and an arbitrary other destination is not.
- Deliberately out of scope, tracked as separate follow-up issues instead: disabling SSH password auth for `icpcadmin`, and tighter USB/hotplug device control. Different attack surface (inbound access, and physical access) from the egress question this ADR addresses.
