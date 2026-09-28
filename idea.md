# Homelab Build Plan
**Platform:** Proxmox VE with single-GPU passthrough to a Windows gaming VM
**Hardware:** Ryzen 7 5800X · 32GB RAM · RX 6700 XT (12GB) · ~530GB free storage

---

## Part 1: Before You Start

**The core constraint:** the 5800X has no integrated graphics, so the RX 6700 XT is your only display output. During setup, the GPU stays on the Proxmox host (you'll see output on a monitor); once passthrough is configured, the GPU only shows video when it's bound to the Windows VM. The rest of the time, you manage Proxmox entirely through its web UI from your MacBook or any browser on the network — no monitor needed on the server itself.

**Checklist before touching anything:**
- [ ] Back up anything on the current Windows install you care about (this will be wiped)
- [ ] Have a spare USB drive (8GB+) for the Proxmox installer
- [ ] Confirm your motherboard BIOS supports **IOMMU** (AMD calls this "SVM Mode" + "IOMMU" — check under CPU/Advanced settings, varies by board vendor)
- [ ] Have your Windows 11 license key handy if you want it activated in the VM
- [ ] Decide on drive layout: ideally one SSD for Proxmox + VM disks, and separate drive(s) for bulk storage/NAS data

---

## Part 2: Proxmox Installation & Base Config

1. **BIOS setup** — Enable SVM Mode (AMD-V) and IOMMU. Disable CSM/legacy boot if present; use UEFI.
2. **Install Proxmox VE** — Flash the ISO to USB (Rufus or balenaEtcher), boot from it, install to your primary SSD. Set a static IP during install if you can.
3. **Post-install cleanup** — Proxmox nags about the paid "enterprise" repo. Switch to the free no-subscription repo:
   ```bash
   sed -i 's/^deb/#deb/g' /etc/apt/sources.list.d/pve-enterprise.list
   echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list
   apt update && apt full-upgrade -y
   ```
4. **Access the web UI** — `https://<server-ip>:8006` from your MacBook. This becomes your main control panel from here on.
5. **Storage setup** — Under Datacenter → Storage, add your second drive as a directory or ZFS pool for VM disks/backups, separate from the OS drive.

---

## Part 3: GPU Passthrough Setup

This is the trickiest part but well-trodden ground for the 5800X + Radeon combo.

1. **Enable IOMMU in Proxmox** — Edit `/etc/default/grub`, add to `GRUB_CMDLINE_LINUX_DEFAULT`:
   ```
   amd_iommu=on iommu=pt
   ```
   Then `update-grub` and reboot.
2. **Load VFIO modules** — Add to `/etc/modules`:
   ```
   vfio
   vfio_iommu_type1
   vfio_pci
   vfio_virqfd
   ```
3. **Check IOMMU groups** — Run a group-listing script (widely available on the Proxmox forums) to confirm your GPU and its audio device sit in their own isolated group. Most consumer boards handle this fine for a single dGPU.
4. **Blacklist the GPU driver on the host** so Proxmox doesn't grab it at boot — add to `/etc/modprobe.d/blacklist.conf`:
   ```
   blacklist amdgpu
   blacklist radeon
   ```
5. **Bind the GPU to vfio-pci** using its PCI IDs (found via `lspci -nn`), added to `/etc/modprobe.d/vfio.conf`.
6. **Create the Windows 11 VM** — Machine type `q35`, BIOS `OVMF (UEFI)`, add a TPM state device (Windows 11 requires it), CPU type `host`. Add the GPU and its audio function as PCI devices, both with "All Functions" and "PCI-Express" checked.
7. **Install Windows + VirtIO drivers** — Use the VirtIO driver ISO for disk/network performance inside the VM.
8. **Test** — Boot the VM, confirm the GPU drives an actual monitor plugged into it, install Radeon drivers inside Windows, benchmark a game to confirm you're getting close to bare-metal performance (expect single-digit % overhead, not a big hit).

**Day-to-day workflow:** shut down the Windows VM when you're not gaming — the GPU sits idle/available, and your other VMs/containers keep running uninterrupted the whole time. No live-switching hassle needed unless you want it. See Part 4 for local-monitor and laptop-streaming setup.

---

## Part 4: Gaming Setup (Local Monitor + Streaming to Laptop)

Both goals work at the same time. The Windows VM owns the GPU, so it can drive the physical monitor and stream to your laptop simultaneously.

### 4.1 Playing on the monitor attached to the GPU

Once the GPU is passed through, the monitor plugged into the 6700 XT behaves like a normal Windows PC. The catch is **keyboard, mouse, and audio**, which are attached to the host, not the VM:

- **Option 1: Pass individual USB devices.** In Proxmox: VM → Hardware → Add → USB Device. Simple, but those devices are dedicated to the VM while it runs.
- **Option 2: Pass through a whole USB controller** (a PCIe USB card, or a motherboard controller in its own IOMMU group). Cleaner long-term: anything plugged into those ports (controllers, headsets, VR gear) just works and hot-plugs normally. **Recommended.**
- **Audio:** use the monitor's HDMI/DisplayPort audio through the GPU, or a USB headset on the passed-through ports.

### 4.2 Streaming to your laptop (Sunshine + Moonlight)

1. Install **Sunshine** (server) inside the Windows VM and pair it with the **Moonlight** client on your laptop. Moonlight has a macOS client, so the MacBook works.
2. In Sunshine, use the **AMD AMF** encoder (H.264 or HEVC). The RX 6700 XT has no AV1 encoding.
3. Use wired Ethernet on the server and decent Wi-Fi 5/6 on the laptop. That's plenty for 1080p/1440p at 60+ fps.
4. For streaming from outside your home, install **Tailscale** on the VM and the laptop. No port forwarding needed, and Moonlight works over it.
5. If you want to stream with the local monitor off or unplugged, add an inexpensive **HDMI dummy plug** so Windows keeps a display active for Sunshine to capture.

Notes: you can play locally while streaming is available, but two people can't play the same session at once. Each additional player needs their own session.

### 4.3 Always-on vs on-demand

Streaming only works while the Windows VM is running, and while it runs it holds the GPU.

| Mode | How | Tradeoff |
|---|---|---|
| **On-demand (start here)** | Start the VM from the Proxmox web UI or app before you game | GPU is free for other services when Windows is off |
| **Start at boot** | Enable "Start at boot" in the VM's Options | Always ready to stream, but the GPU is permanently claimed and Jellyfin/Ollama fall back to CPU |

If you stream a lot, a small script or web button that starts the VM (and optionally waits for Sunshine to come up) is an easy add-on.

### 4.4 Caveats

- **Anti-cheat:** some competitive games (Valorant's Vanguard, some EA/Battlefield titles, others) block or ban VMs. Check the games you care most about first. Single-player and most Steam games are fine.
- **AMD reset behavior:** RDNA2 cards are generally well behaved, but some AMD cards fail to reset cleanly when the VM shuts down, which can require a host reboot. If it happens, community workarounds exist.
- **No bare-metal Windows anymore:** to play, even locally, the VM must be running. Expect the monitor to light up about a minute after starting it.

---

## Part 5: Service Stack (VMs + Containers)

Recommended mix of Proxmox LXC containers (lightweight, share host kernel) and full VMs (isolated OS) for each service:

| Service | Type | Purpose |
|---|---|---|
| TrueNAS | VM (disk passthrough) | Real NAS to replace/absorb your external HD setup |
| Home Assistant OS | VM | Smart home hub |
| Docker host (Debian/Ubuntu) | LXC or VM | Runs Jellyfin, *arr stack (Sonarr/Radarr/Prowlarr), Immich, qBittorrent as containers |
| Ollama | LXC/VM w/ GPU passthrough (ROCm) | Local LLMs |
| Frigate | VM/LXC w/ GPU passthrough | AI-powered NVR, if you add cameras |
| AdGuard Home | LXC | Network-wide ad blocking |
| Nginx Proxy Manager | LXC | Clean URLs/HTTPS for all your services |
| Tailscale | LXC or installed per-VM | Secure remote access without port forwarding |
| Gitea | LXC | Self-hosted git |
| Uptime Kuma | LXC | Dashboard monitoring all the above |

Since the GPU is time-shared with gaming, plan for Ollama/Jellyfin/Frigate to run on CPU when Windows has the GPU, and get GPU acceleration back when Windows VM is off — or accept CPU-only fallback for those services while gaming.

**Suggested resource split (32GB RAM total):**
- Windows gaming VM: 16GB (only when running)
- TrueNAS: 8GB
- Everything else combined: 8GB (LXC containers are cheap — most use under 1GB each)

---

## Part 6: Future Builds & Expansion Ideas

Once the base platform is stable, natural next projects on this same box:

- **Migrate your NAS** — move data off the Mac-attached external HD onto TrueNAS properly, with RAID/snapshots for actual redundancy
- **Proxmox Backup Server** — a second small VM or separate cheap device dedicated to backing up all your other VMs automatically
- **VLANs** — segment IoT/smart home devices from your main network for security
- **UPS + NUT** — add a UPS and configure Proxmox to auto-shutdown gracefully on power loss
- **Coral TPU** — cheap USB accelerator that makes Frigate's object detection much faster without touching the GPU
- **k3s (lightweight Kubernetes)** — spin up a 2-3 node cluster inside VMs on this box, good for learning container orchestration beyond Docker Compose
- **Headscale** — self-hosted Tailscale control server if you want to own that layer too
- **Second Proxmox node** — pick up a cheap used mini PC (Optiplex/ThinkCentre) later to build an actual Proxmox cluster with high availability, using this desktop as the powerful "main" node
- **Second GPU** — if single-GPU passthrough friction ever bugs you, a cheap used low-power card (even something old) dedicated to the Proxmox host frees the 6700 XT for gaming/AI full-time

---

## Quick Reference Links
- Proxmox VE documentation: proxmox.com/en/proxmox-virtual-environment/documentation
- Proxmox GPU passthrough guide (community wiki): pve.proxmox.com/wiki/Pci_passthrough
- r/homelab and r/Proxmox — good for troubleshooting IOMMU group quirks specific to your motherboard
