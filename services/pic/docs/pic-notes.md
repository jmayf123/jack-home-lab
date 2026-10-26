# Immich — Notes

## What it is
Self-hosted Google Photos alternative (server + Postgres + Redis + ML service, via Docker Compose) — phone auto-backup, face recognition, timeline view, shared albums. Photo/video data lives on the `macnas.local` CIFS share, not on the container's local disk.

## Before `terraform apply`
Mount the network share on the **Proxmox host** (not inside the container):

0. `apt install cifs-utils` on the host — stock Proxmox doesn't have CIFS mount support installed. Then check `getent hosts macnas.local` resolves; if it doesn't, install `libnss-mdns` or just use the NAS's IP in the fstab line below.
1. Create a credentials file on the host, e.g. `/root/.smbcredentials-immich` (mode `600`):
   ```
   username=<smb-user>
   password=<smb-password>
   ```
2. Add to `/etc/fstab` on the host:
   ```
   //macnas.local/nas /mnt/pve/immich-photos cifs credentials=/root/.smbcredentials-immich,uid=100000,gid=100000,iocharset=utf8,vers=3.0,_netdev,nofail 0 0
   ```
   - This mounts the `nas` share itself; `Photos` is a subfolder inside it (`/mnt/pve/immich-photos/Photos`), which is what `lxc.mount.entry` (below) bridges into the container — not the `nas` share root.
   - `uid=100000,gid=100000` maps the mount to the unprivileged LXC's root (uid 0 in the container maps to 100000 on the host) so the container can write to it.
   - `nofail` means the host still boots if the NAS is unreachable. If the share isn't mounted, the `Photos` path won't exist and container 104 will refuse to start rather than silently writing photos to local disk — that's intended.
3. `mkdir -p /mnt/pve/immich-photos && mount -a` and confirm it mounted: `mount | grep immich-photos`. Confirm `/mnt/pve/immich-photos/Photos` exists before moving on.

## After `terraform apply`
1. Apply `lxc.conf.snippet` to `/etc/pve/lxc/104.conf` on the Proxmox host, then restart the container (`pct restart 104`) — bridges the host's mounted share into the container at `/mnt/photos`.
2. `pct enter 104`, then run `scripts/setup.sh` — installs Docker, pulls Immich's official `docker-compose.yml`/`.env`, sets `UPLOAD_LOCATION=/mnt/photos`, `TZ`, and a random alphanumeric `DB_PASSWORD`, and brings the stack up. Safe to re-run — it keeps an existing `.env` (and its `DB_PASSWORD`) in place instead of regenerating it.
   ```
   bash <(curl -sL https://raw.githubusercontent.com/jmayf123/jack-home-lab/main/services/pic/scripts/setup.sh)
   ```
3. Open `http://<container-ip>:2283`, create the admin account.
4. Install the Immich mobile app, log in, enable background backup.
5. Let the ML service (face/object recognition) index the library once — CPU-intensive on first pass; GPU acceleration for AMD exists but is less mature than Nvidia's, CPU fallback is fine at a smaller scale. Revisit if indexing is too slow.

## Troubleshooting
- If Docker containers fail to start with a `sysctl`/permission-denied error, that's a known Docker-in-unprivileged-LXC issue with newer runc/containerd builds. Upgrade the Proxmox host's packages first, and check the Proxmox forum for the current workaround — don't disable AppArmor as a fix.
- To upgrade: `cd /opt/immich && docker compose pull && docker compose up -d`. `IMMICH_VERSION` in `.env` is pinned to a major version, so read the release notes before bumping it.

## Backup
- [ ] Proxmox snapshot once configured (covers the container/DB, not the photos — those live on the share).
- [ ] Back up the `macnas.local` share itself like you'd back up actual photos, because it is your actual photos.
- [ ] `/opt/immich/.env` has the generated `DB_PASSWORD` — note it somewhere before it's lost with the container.
