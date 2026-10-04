# AdGuard Home — Setup Notes

## What it is
Network-wide DNS filtering (ads/trackers) + local DNS server, running in its own LXC.

## How it was installed
Helper script from the current, maintained repo:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/adguard.sh)"
```
Run from the Proxmox host shell (**Node → Shell**), Advanced setup mode (needed to set a static IP instead of DHCP).

## Container settings used
- **Hostname:** `adguard`
- **Network:** Static IPv4 on the LAN subnet (e.g. `<lan-subnet>.0/24`)
- **IPv6:** Disabled ("None") — not using IPv6 on the LAN, no need to add complexity
- **TUN/TAP device support:** Disabled — only needed for containers that create their own VPN tunnels (e.g. the Tailscale router), not for a plain DNS server
- **CPU/RAM/disk:** left at script defaults — AdGuard is very light

## Gotcha hit during install
Script failed on the first attempt with:
```
✗ This version of Proxmox Virtual Environment is not supported
Requires Proxmox Virtual Environment Version 8.1 or later.
```
...despite running Proxmox 9.2.20 (newer, not older). Root cause: the command that was run pointed at the old, archived `tteck/Proxmox` repo, whose version-check regex hasn't been updated for newer Proxmox point releases. Fix: use the current maintained repo's command (above), sourced fresh from https://community-scripts.github.io/ProxmoxVE/ rather than an old bookmark/tutorial link.

## Configuration after install
1. Opened `http://<container-ip>:3000` and completed the first-run setup wizard (admin account, DNS on port 53, web UI port).
2. **Blocklists added** (Filters → DNS blocklists): defaults plus additional lists — record exact lists added here once finalized (e.g. OISD, Steven Black's hosts).
3. **Upstream DNS** (Settings → DNS settings → Upstream DNS servers): switched to DNS-over-HTTPS upstreams for speed + privacy:
   ```
   https://dns.quad9.net/dns-query
   https://cloudflare-dns.com/dns-query
   ```
4. **Caching**: confirmed enabled under DNS settings.
5. **Parallel requests**: enabled so AdGuard queries multiple upstreams at once and uses the fastest response.
6. **Network-wide rollout**: set AdGuard's IP as the primary DNS server in the router's DHCP settings, so every device on the network picks it up automatically without per-device configuration. Left secondary DNS blank/duplicate (not a public fallback), so a fallback failure is visible rather than silently bypassing AdGuard.

## Known limitations
- DNS-level blocking does not stop in-content ads (e.g. YouTube/Twitch ads served from the same domains as content). A browser extension like uBlock Origin complements this, it doesn't replace it.
- Per-client stats/rules require AdGuard to also run DHCP (not yet enabled) — currently all queries appear to come from the router's IP rather than individual devices.

## Backup
- [ ] Take a Proxmox snapshot of the `adguard` container now that it's configured and working.
- [ ] Back up `/opt/AdGuardHome/AdGuardHome.yaml` from inside the container periodically — this holds all filter/config settings (contains the admin password hash, so keep this file out of git or redact before committing — see `configs/adguard/AdGuardHome.example.yaml`).
