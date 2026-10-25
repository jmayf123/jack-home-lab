# Immich — Notes

## What it is
Self-hosted Google Photos alternative (server + Postgres + Redis + ML service, via Docker Compose) — phone auto-backup, face recognition, timeline view, shared albums. Photo/video data lives on the `macnas.local` CIFS share, not on the container's local disk.

## Before `terraform apply`
Mount the network share on the **Proxmox host** (not inside the container):

1. Create a credentials file on the host, e.g. `/root/.smbcredentials-immich` (mode `600`):
   ```
   username=<smb-user>
   password=<smb-password>
   ```
2. Add to `/etc/fstab` on the host:
   ```
   //macnas.local/nas /mnt/pve/immich-photos cifs credentials=/root/.smbcredentials-immich,uid=100000,gid=100000,iocharset=utf8,vers=3.0,_netdev 0 0
   ```
   - This mounts the `nas` share itself; `Photos` is a subfolder inside it (`/mnt/pve/immich-photos/Photos`), which is what `lxc.mount.entry` (below) bridges into the container — not the `nas` share root.
   - `uid=100000,gid=100000` maps the mount to the unprivileged LXC's root (uid 0 in the container maps to 100000 on the host) so the container can write to it.
3. `mkdir -p /mnt/pve/immich-photos && mount -a` and confirm it mounted: `mount | grep immich-photos`. Confirm `/mnt/pve/immich-photos/Photos` exists before moving on.

## After `terraform apply`
1. Apply `lxc.conf.snippet` to `/etc/pve/lxc/104.conf` on the Proxmox host, then restart the container (`pct restart 104`) — bridges the host's mounted share into the container at `/mnt/photos`.
2. `pct enter 104`, then run `scripts/setup.sh` — installs Docker, pulls Immich's official `docker-compose.yml`/`.env`, sets `UPLOAD_LOCATION=/mnt/photos`, and brings the stack up.
   ```
   bash <(curl -sL https://raw.githubusercontent.com/jmayf123/jack-home-lab/main/services/pic/scripts/setup.sh)
   ```
3. Open `http://<container-ip>:2283`, create the admin account.
4. Install the Immich mobile app, log in, enable background backup.
5. Let the ML service (face/object recognition) index the library once — CPU-intensive on first pass; GPU acceleration for AMD exists but is less mature than Nvidia's, CPU fallback is fine at a smaller scale. Revisit if indexing is too slow.

## Backup
- [ ] Proxmox snapshot once configured (covers the container/DB, not the photos — those live on the share).
- [ ] Back up the `macnas.local` share itself like you'd back up actual photos, because it is your actual photos.
- [ ] `/opt/immich/.env` has the generated `DB_PASSWORD` — note it somewhere before it's lost with the container.
