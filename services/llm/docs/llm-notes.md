# Ollama + Open WebUI — Notes

## What it is
Local, private LLM inference. Ollama runs open models (Llama, Qwen, Mistral, …) on the host's RX 6700 XT via ROCm; Open WebUI gives a ChatGPT-style chat interface on top of it. Both run natively (no Docker) in one unprivileged LXC.

## After `terraform apply`
1. Apply `lxc.conf.snippet` to `/etc/pve/lxc/105.conf` on the Proxmox host, then `pct restart 105` — passes `/dev/dri/renderD128` and `/dev/kfd` into the container. Needs Proxmox VE 8.2+ and the host's `amdgpu` driver loaded (`ls /dev/kfd /dev/dri/renderD128` on the host should succeed first).
2. `pct enter 105`, then run `scripts/setup.sh` — installs Ollama (ROCm bundle, systemd, port 11434) and Open WebUI (uv-managed Python 3.11 venv, systemd, port 8080). The Open WebUI pip install pulls several GB and takes a few minutes.
   ```
   bash <(curl -sL https://raw.githubusercontent.com/jmayf123/jack-home-lab/main/services/llm/scripts/setup.sh)
   ```
3. Pull and test a model:
   ```
   ollama pull llama3.1:8b
   ollama run llama3.1:8b "hi"
   ollama ps
   ```
   `ollama ps` should show `100% GPU`. If it says `CPU`, the GPU wasn't picked up — check `journalctl -u ollama | grep -iE 'amdgpu|gfx|rocm'` and that step 1's devices exist inside the container. On the host, `cat /sys/class/drm/card0/device/gpu_busy_percent` climbs during a prompt.
4. Open `http://<container-ip>:8080`, create your account (the first one becomes admin), then Admin Panel → Settings → General → turn off **Enable New Sign Ups**.
5. Ollama's API is on `http://<container-ip>:11434` for anything else on the LAN (dashboard tiles, editors, scripts). LAN + Tailscale only; don't expose either port to the internet.

## Model guidance (12GB VRAM)
Pick models that fit entirely in VRAM; spill-over to system RAM works but is much slower.
- 7B–8B at Q4 (~5GB) — plenty of headroom, long contexts fine.
- 12B–14B at Q4 (~8–9GB) — fits, less room for long contexts.
- 20B+ — only with aggressive quantization; expect CPU spill.

## Growing later
- **RAM / cores:** edit `cores` / `memory` in `main.tf`, `terraform apply`. Resizes in place.
- **Disk:** `pct resize 105 rootfs +20G` on the host, then update `size` in `main.tf` so the file matches (rootfs is in `ignore_changes`, so Terraform won't fight it). Disk can't shrink.

## Backup
- [ ] Proxmox snapshot once configured.
- [ ] Back up `/opt/open-webui/data` — users, chat history, settings.
- [ ] Models in `/usr/share/ollama/.ollama` are re-downloadable; no need to back them up.
