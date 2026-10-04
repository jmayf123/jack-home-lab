# Vaultwarden — Setup Notes

## What it is
Self-hosted, Bitwarden-compatible password manager server, running in its own LXC.

## Container (from Terraform)
- **Hostname:** `vault`
- **VMID:** `102`
- **Template:** Debian 13
- **Network:** static IPv4 on the LAN subnet (`var.vault_ip`)
- **CPU/RAM/disk:** 1 core, 512MB RAM, 4G disk — Vaultwarden itself is light; disk is sized a bit above AdGuard's to leave room for attachments/backups

## Install (after `terraform apply` brings the container up)
Run from inside the container, or via the Proxmox host's helper script repo if preferred:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/vaultwarden.sh)"
```

## Required follow-up before real use
1. Set `ADMIN_TOKEN` (long random string) in the Vaultwarden config — gates the `/admin` panel.
2. Set `SIGNUPS_ALLOWED=false` once your own account exists.
3. **HTTPS is mandatory** for the Bitwarden apps/extension to talk to the server — put a reverse proxy (Caddy or Nginx Proxy Manager) in front before pointing any client at it. Do not expose this container directly to the internet; access over Tailscale or via the reverse proxy's HTTPS only.
4. Create your user account via the normal login page, then lock down signups (step 2).

## Backup
- [ ] Proxmox snapshot once configured.
- [ ] Back up the Vaultwarden data directory (`/var/lib/vaultwarden` or equivalent inside the container) regularly — this is the only copy of every stored password/attachment.
