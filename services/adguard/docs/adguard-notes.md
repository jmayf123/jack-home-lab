# AdGuard Home — Notes

## What it is
Network-wide DNS filtering (ads/trackers) and a local DNS server.

## After `terraform apply`
1. `pct enter 101`, then run `scripts/setup.sh` — installs AdGuard Home as a systemd service. If running it straight from GitHub, use the **raw** URL, not a `blob` URL:
   ```
   bash <(curl -sL https://raw.githubusercontent.com/jmayf123/jack-home-lab/main/services/adguard/scripts/setup.sh)
   ```
2. Open `http://<container-ip>:3000` and complete the setup wizard (admin account, DNS on port 53, web UI port).
3. Add blocklists (Filters → DNS blocklists) and set upstream DNS to DoH (e.g. Quad9, Cloudflare) under Settings → DNS settings.
4. Point your router's DHCP DNS setting at this container's IP so the whole network picks it up automatically.

## Backup
- [ ] Proxmox snapshot once configured.
- [ ] Back up `/opt/AdGuardHome/AdGuardHome.yaml` periodically — contains the admin password hash, so keep it out of git (see `AdGuardHome.example.yaml` for a redacted template).
