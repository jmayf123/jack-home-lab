# Vaultwarden — Notes

## What it is
Self-hosted, Bitwarden-compatible password manager server.

## After `terraform apply`
1. Bump container resources for the build — compiling needs more than the normal 512MB: `pct set 102 -memory 2048 -cores 2` from the Proxmox host.
2. `pct enter 102`, then run `scripts/setup.sh` — builds Vaultwarden from source, installs it as a systemd service on port 8000, and prints a generated `ADMIN_TOKEN`.
3. Exit the container and run `terraform apply` again to restore the declared 512MB/1-core sizing.
4. Put a reverse proxy (Caddy or Nginx Proxy Manager) in front for HTTPS — required for the Bitwarden apps/extension to connect. Don't expose this container directly to the internet; Tailscale or the proxy's HTTPS only.
5. Create your account via the normal login page, then set `SIGNUPS_ALLOWED=false` in `/opt/vaultwarden/.env` and restart the service.

## Backup
- [ ] Proxmox snapshot once configured.
- [ ] Back up `/opt/vaultwarden/data` regularly — it's the only copy of every stored password/attachment.
