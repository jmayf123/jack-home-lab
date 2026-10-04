# Homelab

Proxmox VE homelab running on a repurposed gaming PC.

**Hardware:** AMD Ryzen 7 5800X · 32GB RAM · AMD Radeon RX 6700 XT (12GB) · ~530GB free storage

**Approach:** LXC containers per service, built with the [Proxmox VE Helper Scripts](https://community-scripts.github.io/ProxmoxVE/) where available. GPU stays on the Proxmox host (not passed through to any VM) so it can be shared across multiple containers — e.g. Jellyfin transcoding and Ollama inference at the same time.

## Status

| Service | Status | Notes |
|---|---|---|
| Tailscale subnet router | ✅ Done | Dedicated LXC, see `services/ts-router/docs/notes.md` |
| AdGuard Home | ✅ Done | See `services/adguard/docs/adguard-notes.md` |
| Vaultwarden | ✅ Done | LXC created via Terraform, see `services/vault/docs/vault-notes.md`; Vaultwarden install + HTTPS reverse proxy still manual |
| Immich | ⬜ Not started | |
| Ollama + Open WebUI | ⬜ Not started | |
| Dashboard (Homepage/Homarr) + Uptime Kuma | ⬜ Not started | |

## Repo structure

Each service is its own Terraform module, called from the root `main.tf`. There's a single shared state and provider config at the root; each `services/<name>/` directory owns its resource definition, its own variables, a `scripts/` folder with the setup script(s) to run inside the container once Terraform brings it up, and a `docs/` folder with a short summary of the service plus the steps to take after the container exists.

```
.
├── README.md
├── main.tf                 — provider config + module blocks for each service
├── vars.tf                 — shared vars (API creds, gateway IP) + per-service vars passed into modules
├── secrets.tfvars          — actual values for the above (not committed)
├── docs/
│   └── services-plan.md        (AdGuard, Vaultwarden, Immich, Ollama, Dashboard rollout plan)
└── services/                — one directory per service, each a Terraform module
    ├── ts-router/
    │   ├── main.tf              (proxmox_lxc resource + required_providers)
    │   ├── variables.tf
    │   ├── lxc.conf.snippet     (host-side config lines for TUN/TAP passthrough)
    │   ├── scripts/
    │   │   └── setup.sh
    │   └── docs/
    │       └── notes.md
    ├── adguard/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── AdGuardHome.example.yaml   (redacted template — see note below)
    │   ├── scripts/
    │   │   └── setup.sh
    │   └── docs/
    │       └── adguard-notes.md
    └── vault/
        ├── main.tf
        ├── variables.tf
        ├── scripts/
        │   └── setup.sh
        └── docs/
            └── vault-notes.md
```

Adding a new service means adding `services/<name>/{main.tf, variables.tf, scripts/, docs/}` and a matching `module` block in the root `main.tf`.

