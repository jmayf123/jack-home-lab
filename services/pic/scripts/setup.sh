#!/usr/bin/env bash
set -euo pipefail

# Run inside the pic container after `terraform apply`, after applying
# lxc.conf.snippet on the host and restarting the container.
#
# Installs Docker + Compose, pulls Immich's official docker-compose.yml/.env,
# points UPLOAD_LOCATION at the CIFS share bind-mounted at /mnt/photos, and
# brings the stack up. Safe to re-run: it keeps an existing .env (and its
# DB_PASSWORD) in place instead of regenerating it.

TZ_NAME="${TZ_NAME:-America/Chicago}"

if [ ! -d /mnt/photos ] || ! mountpoint -q /mnt/photos; then
  echo "ERROR: /mnt/photos is not mounted. Apply lxc.conf.snippet on the" >&2
  echo "Proxmox host and restart this container before running this script." >&2
  exit 1
fi

if ! touch /mnt/photos/.write-test 2>/dev/null; then
  echo "ERROR: /mnt/photos is not writable. Check that the host's CIFS" >&2
  echo "fstab entry for the share has uid=100000,gid=100000 set." >&2
  exit 1
fi
rm -f /mnt/photos/.write-test

apt update
apt install -y ca-certificates curl gnupg openssl

if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    >/etc/apt/sources.list.d/docker.list
  apt update
  apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi
systemctl enable --now docker

mkdir -p /opt/immich
cd /opt/immich
curl -fsSL -o docker-compose.yml https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml

DB_PASSWORD=""
if [ ! -f .env ]; then
  curl -fsSL -o .env https://github.com/immich-app/immich/releases/latest/download/example.env

  DB_PASSWORD=$(openssl rand -hex 24)
  sed -i \
    -e "s|^UPLOAD_LOCATION=.*|UPLOAD_LOCATION=/mnt/photos|" \
    -e "s|^DB_DATA_LOCATION=.*|DB_DATA_LOCATION=./postgres|" \
    -e "s|^DB_PASSWORD=.*|DB_PASSWORD=${DB_PASSWORD}|" \
    -e "s|^# *TZ=.*|TZ=${TZ_NAME}|" \
    .env
  chmod 600 .env
else
  echo "Existing /opt/immich/.env found, keeping it as-is."
fi

docker compose up -d

echo "Immich is starting. Web UI will be on port 2283 once containers are up:"
echo "  docker compose -f /opt/immich/docker-compose.yml ps"
if [ -n "$DB_PASSWORD" ]; then
  echo "DB_PASSWORD (also saved in /opt/immich/.env): $DB_PASSWORD"
fi
