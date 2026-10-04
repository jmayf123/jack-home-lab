#!/usr/bin/env bash
set -euo pipefail

# Run inside the ts-router container after `terraform apply` AND after
# applying lxc.conf.snippet on the Proxmox host (TUN/TAP device access).
#
# Usage: ./setup.sh <lan-subnet-cidr>   e.g. ./setup.sh 192.168.1.0/24

SUBNET="${1:?Usage: $0 <lan-subnet-cidr>}"

echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' | tee -a /etc/sysctl.d/99-tailscale.conf
sysctl -p /etc/sysctl.d/99-tailscale.conf

curl -fsSL https://tailscale.com/install.sh | sh

tailscale up --advertise-routes="$SUBNET" --accept-dns=false

echo "Tailscale is up. Approve the advertised route ($SUBNET) in the admin console: Machines -> this device."
