# Homelab

Proxmox VE homelab running on a repurposed gaming PC.

**Hardware:** AMD Ryzen 7 5800X · 32GB RAM · AMD Radeon RX 6700 XT (12GB) · ~530GB free storage

**Approach:** LXC containers per service, built with the [Proxmox VE Helper Scripts](https://community-scripts.github.io/ProxmoxVE/) where available. GPU stays on the Proxmox host (not passed through to any VM) so it can be shared across multiple containers — e.g. Jellyfin transcoding and Ollama inference at the same time.

## Status

| Service | Status | Notes |
|---|---|---|
| Tailscale subnet router | ✅ Done | Dedicated LXC, see `configs/tailscale-router/` |
| AdGuard Home | ✅ Done | See `docs/adguard-notes.md` |
| Vaultwarden | ⬜ Not started | |
| Immich | ⬜ Not started | |
| Ollama + Open WebUI | ⬜ Not started | |
| Dashboard (Homepage/Homarr) + Uptime Kuma | ⬜ Not started | |

## Repo structure

```
.
├── README.md
├── docs/                  — planning docs and per-service notes
│   ├── services-plan.md        (AdGuard, Vaultwarden, Immich, Ollama, Dashboard rollout plan)
│   └── adguard-notes.md        (what was actually done + gotchas hit)
├── services/               — actual config snippets from working containers
│   ├── adguard/
│   │   └── AdGuardHome.example.yaml   (redacted template — see note below)
│   └── ts-router/
│       ├── lxc.conf.snippet           (host-side config lines for TUN/TAP passthrough)
│       └── notes.md
└── .gitignore
```

