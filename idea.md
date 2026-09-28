# Service Rollout Plan: AdGuard Home, Vaultwarden, Immich, Ollama, Dashboard

**Prerequisite:** GPU passthrough undone, `/dev/dri/renderD128` present on the host (see previous steps). All services below are LXC containers unless noted.

**General approach for each:** use the **Proxmox VE Helper Scripts** (community-scripts.github.io/ProxmoxVE) where available — they create a correctly-sized LXC, install the service, and configure it in one command run from the Proxmox shell. Faster and less error-prone than building each container by hand.

---

## 0. Before You Start

- [ ] Pick a static IP range or DHCP reservations for your containers so they don't change address on reboot
- [ ] Decide on a domain naming scheme, e.g. `adguard.home.local`, `vault.home.local` — even without real DNS yet, this makes reverse proxy setup easier later
- [ ] Install **Tailscale** on the Proxmox host or a small dedicated LXC now, if you haven't — several services below (Vaultwarden especially) should not be exposed directly to the internet

---

## 1. AdGuard Home

**What it does:** blocks ads/trackers network-wide and gives you a DNS server with query logs — usually the first "aha" moment of a homelab.

**Steps:**
1. From the Proxmox shell, run the AdGuard Home helper script.
2. Give the container a static IP.
3. Open `http://<container-ip>:3000` and complete the setup wizard (admin user, DNS listen port 53, web UI port 80/3000).
4. Add blocklists — the default lists are fine to start; add more from the AdGuard community list if you want.
5. On your router (or each device, to start safer), set the DNS server to the container's IP.
6. Test: visit a known ad-heavy site and confirm ads are blocked, then check the AdGuard **Query Log** to see requests flowing through.

**Notes:**
- Keep the container's IP static — every device on your network points to it.
- Back it up before big changes (Proxmox snapshot) since a DNS outage takes down your whole network's browsing.

---

## 2. Vaultwarden

**What it does:** a lightweight, self-hosted server compatible with the Bitwarden apps — your own password manager.

**Steps:**
1. Run the Vaultwarden helper script, or deploy via Docker in an existing Docker LXC if you'd rather keep it containerized that way.
2. Set environment variables on first run: `ADMIN_TOKEN` (a long random string — generates access to the admin panel) and `SIGNUPS_ALLOWED=false` once your account exists, so no one else can register.
3. **HTTPS is required** for the Bitwarden browser extension/apps to work, not optional. Put a reverse proxy in front of it (see Nginx Proxy Manager, or Caddy, which handles Let's Encrypt certs automatically) — this is worth doing even before you set one up for other services.
4. Access the admin panel at `/admin` with your token, and create your user account from the normal login page.
5. Install the Bitwarden app/extension on your devices, point the server URL at your Vaultwarden instance instead of Bitwarden's cloud.
6. Import existing passwords if you're migrating from another manager (most support a CSV/JSON export).

**Notes:**
- This holds your passwords — access it only over Tailscale or HTTPS, never over plain HTTP from outside your LAN.
- Set up automatic backups of its data volume immediately; losing this container without a backup means losing every saved password.

---

## 3. Immich

**What it does:** self-hosted Google Photos alternative — phone auto-backup, face recognition, timeline view, shared albums.

**Steps:**
1. Immich is best run via **Docker Compose** rather than the lighter helper-script LXCs, since it's several coordinated containers (server, database, ML service, Redis). Create a Docker-capable LXC (privileged, or a small Ubuntu VM if you hit permission issues with GPU access) or use the Immich-specific helper script if the version in the repo is current.
2. Download Immich's official `docker-compose.yml` and `.env` file from their GitHub, set a `UPLOAD_LOCATION` pointing at a mounted drive with real capacity — this fills up fast with photos/videos.
3. Run `docker compose up -d` and access the web UI on the configured port.
4. Install the Immich mobile app, log in, and enable background backup — this is the main daily-use feature.
5. Let the ML service (face/object recognition) index your library once; it's CPU/GPU intensive the first pass.

**Notes:**
- Storage is the real constraint here, not compute — plan for this to grow continuously with your photo library.
- If you want GPU-accelerated ML (faster face recognition), the `.env` file has a hardware-acceleration section — AMD support exists but is less mature than Nvidia's; CPU fallback works fine at a smaller scale.
- Back up the `UPLOAD_LOCATION` directory like you'd back up actual photos, because it is your actual photos.

---

## 4. Local AI with Ollama

**What it does:** runs open LLMs (Llama, Mistral, Qwen, etc.) locally, privately, no API costs.

**Steps:**
1. Create the LXC (helper script exists) or a small VM — for GPU acceleration, an **unprivileged LXC with GPU passthrough of `/dev/dri`** is the lightest option.
2. Share the GPU into the container: in the LXC's config (`/etc/pve/lxc/<vmid>.conf`), add the render device passthrough lines (the helper script for Ollama with GPU support typically does this for you — accept that option if prompted).
3. Install **ROCm** inside the container if the helper script didn't already, since the 6700 XT needs it for GPU-accelerated inference. Check Ollama's docs for the current supported ROCm version, as this changes across releases.
4. Install Ollama, then pull a model to test:
   ```
   ollama pull llama3.1:8b
   ollama run llama3.1:8b
   ```
5. Install **Open WebUI** (separate container or Docker on the same one) for a ChatGPT-style chat interface instead of the command line.
6. Confirm GPU usage during inference with `rocm-smi` or `radeontop` — if it's not being used, the model silently falls back to CPU, which is much slower but still works.

**Notes:**
- With 12GB VRAM, models in the 7B-14B range run comfortably; larger quantized models (20B+) may also fit depending on quantization level.
- ROCm support for consumer AMD cards has improved but is behind Nvidia/CUDA in polish — expect to troubleshoot driver versions if something doesn't detect the GPU.

---

## 5. Dashboard for All Services

**What it does:** one homepage with links, health/status, and sometimes live stats for everything you've deployed.

**Options:** **Homepage** (config-file-based, very customizable, widgets show live data from your other services) or **Homarr** (more UI-driven setup, drag-and-drop). Either is a fine choice — Homepage rewards a bit of YAML editing, Homarr is friendlier if you'd rather click through a UI.

**Steps:**
1. Deploy via helper script or Docker.
2. Add an entry (bookmark/tile) for each running service: AdGuard, Vaultwarden, Immich, Ollama/Open WebUI, plus Jellyfin/Proxmox itself if you want them all in one place.
3. Add API keys where supported (AdGuard, for example) to show live stats like queries blocked today, directly on the dashboard tile.
4. Pair with **Uptime Kuma** (separate small container) for actual uptime monitoring/alerting — Homepage/Homarr show links and stats, Uptime Kuma tells you when something's actually down and can notify you (email, Discord, etc.).
5. Set this dashboard as your browser homepage or a bookmark on your laptop and phone — this is what makes the lab feel like "one thing" instead of a list of IP addresses to remember.

---

## Suggested Order

1. **AdGuard Home** — fastest to see working, low risk
2. **Dashboard + Uptime Kuma** — do this early so every service you add afterward gets a tile and a health check immediately
3. **Vaultwarden** — set up the reverse proxy/HTTPS piece now, since you'll reuse it for later services too
4. **Ollama + Open WebUI** — GPU is fully free now, good next win
5. **Immich** — most storage-hungry and most involved (multi-container), save for once you're comfortable with Docker Compose

## Resource Notes (32GB RAM host)

| Service | Typical RAM | Notes |
|---|---|---|
| AdGuard Home | 512MB | LXC default is generous |
| Vaultwarden | 512MB | Very light |
| Dashboard + Uptime Kuma | 512MB combined | Light |
| Ollama | 2-8GB+ depending on model loaded | Scales with model size, not fixed |
| Immich (all containers) | 4-6GB | Database + ML service add up |

Plenty of headroom left for everything else in the original plan (Jellyfin, Home Assistant, TrueNAS, etc.).