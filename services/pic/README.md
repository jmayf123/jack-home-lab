# Immich (pic) - VM runbook

Immich runs in a Debian 12 **VM** (VMID `104`). The NAS share is mounted **inside the VM** - nothing is installed or mounted on the Proxmox host.

| Path in VM | Purpose |
|---|---|
| `/mnt/nas` | `//<nas_ip>/nas` (CIFS) |
| `/mnt/nas/immich` | `UPLOAD_LOCATION`, read-write |
| `/mnt/nas/Photos` | existing library, mounted **read-only** into Immich at `/mnt/external-photos` |
| `/opt/immich/postgres` | Postgres data, **local disk only** (never on the NAS) |

ML runs on CPU (no GPU passthrough).

## Setup

1. **One-time template** (Telmate provider can't download images or upload snippets): on the Proxmox host run `scripts/create-template.sh` (needs `libguestfs-tools`). Creates template `debian-12-cloudinit` (ID 9000) with qemu-guest-agent baked in.
2. Add the new vars from `terraform.tfvars.example` to `secrets.tfvars`, then `terraform plan -var-file=secrets.tfvars` and `terraform apply`.
3. Copy the script over and run it (prompts for SMB user/password; they are stored only in `/root/.smbcredentials-immich` inside the VM):
   `terraform output -raw pic_setup_command | bash` - or manually: `scp scripts/setup.sh <user>@<vm-ip>:` then `ssh -t <user>@<vm-ip> 'sudo NAS_IP=<nas-ip> bash setup.sh'`
4. Open `http://<vm-ip>:2283` and create the admin account.
5. Administration -> External Libraries -> add a library with import path `/mnt/external-photos`, then scan.
6. Install the mobile app, log in, enable background backup.

## Operations

- **NAS down at VM boot:** Docker stays stopped on purpose (`RequiresMountsFor=/mnt/nas`), so photos never land on the local disk. Fix: `mount -a && systemctl start docker`, or reboot the VM.
- **Remote access:** Tailscale (or a reverse proxy with HTTPS). Never port-forward 2283.
- **Upgrades:** bump `IMMICH_RELEASE` in `scripts/setup.sh`, read the release notes, re-run the script (refreshes compose file + `IMMICH_VERSION`), then `cd /opt/immich && docker compose pull && docker compose up -d`.
- **First ML pass is CPU-heavy** (smart search, faces). GPU passthrough is a possible later upgrade (not implemented).

## Backup checklist

- [ ] `vzdump` of the VM to **separate** storage (a snapshot is not a backup).
- [ ] Immich's nightly DB dumps land in `/mnt/nas/immich/backups` - this is the real DB backup.
- [ ] Second copy / offsite of `nas/immich` and `nas/Photos`.
- [ ] `DB_PASSWORD` (in `/opt/immich/.env`) stored in a password manager.
