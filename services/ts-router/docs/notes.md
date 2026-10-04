# Tailscale Subnet Router — Notes

## What it is
Dedicated, minimal LXC running Tailscale as a subnet router, so devices on the tailnet can reach every container on the home LAN without port forwarding or installing Tailscale on the Proxmox host itself.

## After `terraform apply`
1. Apply `lxc.conf.snippet` to `/etc/pve/lxc/<vmid>.conf` on the Proxmox host, then restart the container — required for Tailscale's tunnels in an unprivileged LXC.
2. `pct enter 100`, then run `scripts/setup.sh <lan-subnet-cidr>` (e.g. `scripts/setup.sh 192.168.1.0/24`) — enables IP forwarding, installs Tailscale, and advertises the subnet route.
   ```
   bash <(curl -sL https://raw.githubusercontent.com/jmayf123/jack-home-lab/main/services/ts-router/scripts/setup.sh) 192.168.1.0/24
   ```
3. Approve the advertised route in the Tailscale admin console (Machines → this device), and disable key expiry for this machine since it should stay connected indefinitely.

## Backup
- [ ] Proxmox snapshot once configured.
