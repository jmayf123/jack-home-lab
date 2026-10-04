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

**The community-scripts one-liner does NOT work here — see Gotcha below.** Install manually instead:

1. **Temporarily bump container resources for the build.** Compiling Vaultwarden with `cargo build --release` needs more than the container's normal 512MB. In the Proxmox GUI (or `pct set 102 -memory 2048 -cores 2`), bump memory to ~2048MB and cores to 2. No Terraform change needed — after the build you just run `terraform apply` again and it'll snap `memory`/`cores` back to the declared 512MB/1-core values, since those attributes aren't in the module's `ignore_changes` list.

2. **Enter the container and install build deps:**
   ```bash
   pct enter 102
   apt update && apt install -y build-essential pkgconf libssl-dev libmariadb-dev-compat libpq-dev argon2 ssl-cert curl git
   ```

3. **Install Rust:**
   ```bash
   curl https://sh.rustup.rs -sSf | sh -s -- -y
   source "$HOME/.cargo/env"
   ```

4. **Fetch and build Vaultwarden from source (latest release tag):**
   ```bash
   VW_VERSION=$(curl -s https://api.github.com/repos/dani-garcia/vaultwarden/releases/latest | grep -oP '"tag_name": "\K[^"]+')
   git clone --branch "$VW_VERSION" --depth 1 https://github.com/dani-garcia/vaultwarden.git /tmp/vaultwarden-src
   cd /tmp/vaultwarden-src
   cargo build --features "sqlite,mysql,postgresql" --release
   ```

5. **Install the binary and web vault UI:**
   ```bash
   addgroup --system vaultwarden
   adduser --system --home /opt/vaultwarden --shell /usr/sbin/nologin --no-create-home \
     --gecos 'vaultwarden' --ingroup vaultwarden --disabled-login --disabled-password vaultwarden
   mkdir -p /opt/vaultwarden/{bin,data,web-vault}
   cp /tmp/vaultwarden-src/target/release/vaultwarden /opt/vaultwarden/bin/
   cd ~ && rm -rf /tmp/vaultwarden-src

   WEB_VAULT_VERSION=$(curl -s https://api.github.com/repos/dani-garcia/bw_web_builds/releases/latest | grep -oP '"tag_name": "\K[^"]+')
   curl -fsSL -o /tmp/web-vault.tar.gz \
     "https://github.com/dani-garcia/bw_web_builds/releases/download/${WEB_VAULT_VERSION}/bw_web_${WEB_VAULT_VERSION}.tar.gz"
   tar -xzf /tmp/web-vault.tar.gz -C /opt/vaultwarden/web-vault --strip-components=1
   rm /tmp/web-vault.tar.gz
   ```

6. **Configure** — skip `ROCKET_TLS` here; the reverse proxy (step 3 below) terminates real TLS, so Vaultwarden just serves plain HTTP on 8000 internally:
   ```bash
   cat <<EOF >/opt/vaultwarden/.env
   ADMIN_TOKEN=''
   ROCKET_ADDRESS=0.0.0.0
   DATA_FOLDER=/opt/vaultwarden/data
   DATABASE_MAX_CONNS=10
   WEB_VAULT_FOLDER=/opt/vaultwarden/web-vault
   WEB_VAULT_ENABLED=true
   EOF
   chown -R vaultwarden:vaultwarden /opt/vaultwarden/
   chown root:root /opt/vaultwarden/bin/vaultwarden
   chmod +x /opt/vaultwarden/bin/vaultwarden
   chmod +r /opt/vaultwarden/.env
   ```

7. **Create and start the systemd service:**
   ```bash
   cat <<EOF >/etc/systemd/system/vaultwarden.service
   [Unit]
   Description=Bitwarden Server (Powered by Vaultwarden)
   Documentation=https://github.com/dani-garcia/vaultwarden
   After=network.target

   [Service]
   User=vaultwarden
   Group=vaultwarden
   EnvironmentFile=-/opt/vaultwarden/.env
   ExecStart=/opt/vaultwarden/bin/vaultwarden
   LimitNOFILE=65535
   LimitNPROC=4096
   WorkingDirectory=/opt/vaultwarden
   ReadWriteDirectories=/opt/vaultwarden/data
   AmbientCapabilities=CAP_NET_BIND_SERVICE

   [Install]
   WantedBy=multi-user.target
   EOF
   systemctl daemon-reload
   systemctl enable --now vaultwarden
   ```
   Confirm it's listening: `ss -tlnp | grep 8000`.

8. **Scale the container back down** — exit the container (`exit`), then from your Terraform checkout: `terraform apply`. This reverts memory/cores to 512MB/1-core without touching anything else (everything that would otherwise drift is in `ignore_changes`).

### Gotcha: why the community-scripts one-liner doesn't apply
`ct/vaultwarden.sh` is an all-in-one script — it creates its *own* new LXC via `build.func` and only then installs into it. Run against a Proxmox host where `vault`/vmid 102 already exists (ours, from Terraform), it either collides on the vmid/hostname or just spins up an unwanted second container. The companion `install/vaultwarden-install.sh` can't be piped in standalone either — it opens with `source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"`, which depends on helper functions (`msg_info`, `$STD`, `fetch_and_deploy_gh_release`, ...) that only exist because `build.func` injects them into the container's environment before running it. Outside that pipeline it just errors on the first helper call. The steps above are the same install logic from that script, run by hand.

## Required follow-up before real use
1. Set `ADMIN_TOKEN` (long random string) in the Vaultwarden config — gates the `/admin` panel.
2. Set `SIGNUPS_ALLOWED=false` once your own account exists.
3. **HTTPS is mandatory** for the Bitwarden apps/extension to talk to the server — put a reverse proxy (Caddy or Nginx Proxy Manager) in front before pointing any client at it. Do not expose this container directly to the internet; access over Tailscale or via the reverse proxy's HTTPS only.
4. Create your user account via the normal login page, then lock down signups (step 2).

## Backup
- [ ] Proxmox snapshot once configured.
- [ ] Back up the Vaultwarden data directory (`/var/lib/vaultwarden` or equivalent inside the container) regularly — this is the only copy of every stored password/attachment.
