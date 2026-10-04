# Tailscale Subnet Router — Setup Notes

## Purpose
Dedicated, minimal LXC whose only job is running Tailscale as a subnet router, so the Proxmox host itself never has Tailscale installed. Lets any device on the tailnet (laptop, phone) reach every container on the home LAN by its normal IP, without port forwarding.

## Container settings
- **Hostname:** `ts-router`
- **Template:** Debian 12 (lightweight)
- **Resources:** 1 vCPU, 512MB RAM, 2–4GB disk
- **Network:** static IP on the LAN subnet (e.g. `<lan-subnet>.0/24`) — replace with actual value used
- **Unprivileged:** yes
- **TUN/TAP device support:** enabled (required — see `lxc.conf.snippet` in this folder for the manual config lines added on the host side)

## Setup steps performed
1. Created the LXC with the settings above.
2. Enabled IP forwarding inside the container:
   ```bash
   echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
   echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
   sudo sysctl -p /etc/sysctl.d/99-tailscale.conf
   ```
3. Added the lines in `lxc.conf.snippet` to `/etc/pve/lxc/<vmid>.conf` on the **host**, then restarted the container.
4. Installed Tailscale inside the container:
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   ```
5. Brought it up as a subnet router:
   ```bash
   sudo tailscale up --advertise-routes=<lan-subnet>.0/24 --accept-dns=false
   ```
   (replace subnet with actual LAN range)
6. Approved the advertised route in the Tailscale admin console (Machines → this device).
7. Disabled key expiry for this machine in the admin console, since it's a server that should stay connected indefinitely.
8. Installed Tailscale on laptop + phone under the same account to confirm reachability.

## Gotcha: hostname changes
`/etc/hosts` inside a Proxmox-templated container has an auto-managed block:
```
# --- BEGIN PVE ---
<container-ip> tailscale.lan tailscale
# --- END PVE ---
```
Don't hand-edit this block — Proxmox regenerates it from the container's **Hostname** setting. To rename, either:
- `pct set <vmid> --hostname ts-router` on the host, then reboot the container, or
- Rename directly in the Tailscale admin console (Machines → rename) without touching the container at all.

## Verification
- `tailscale status` on the router shows it connected with the subnet route listed.
- From a device on the tailnet: `ping <container-ip>` (router itself) and `ping <gateway-ip>` (LAN gateway) both succeed, confirming routing works end-to-end, not just to the router itself.
- Tailscale admin console shows this machine tagged as **Subnet router** with the route approved.

## Known tradeoff
This container is a single point of failure for remote access — if it's down, so is away-from-home access to everything on the LAN via Tailscale. Acceptable for now; Proxmox's own web UI/console remains reachable locally regardless.
