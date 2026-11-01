#!/usr/bin/env bash
set -euo pipefail

# Run INSIDE the pic VM as root (sudo), after `terraform apply`:
#   sudo NAS_IP=<nas-ip> bash setup.sh
# Optional: SMB_USER / SMB_PASS env vars (otherwise prompted on first run).
#
# Mounts the NAS share at /mnt/nas, installs Docker, and brings up a pinned
# Immich release. Idempotent: safe to re-run (also the upgrade path after
# bumping IMMICH_RELEASE below).

# ---- Pinned Immich release (bump deliberately; read the release notes) ----
IMMICH_RELEASE="v3.3.5"
# ----------------------------------------------------------------------------

NAS_IP="${NAS_IP:?Set NAS_IP, e.g. sudo NAS_IP=192.168.1.20 bash setup.sh}"
TZ_NAME="${TZ_NAME:-America/Chicago}"
CREDS=/root/.smbcredentials-immich
APP_DIR=/opt/immich
BASE_URL="https://github.com/immich-app/immich/releases/download/${IMMICH_RELEASE}"

[ "$(id -u)" -eq 0 ] || { echo "ERROR: run as root (sudo)." >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl gnupg openssl cifs-utils qemu-guest-agent
systemctl enable --now qemu-guest-agent || true

# ---- Docker Engine + compose plugin (official apt repo) ----
if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    >/etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# ---- SMB credentials (never committed; created only if missing) ----
if [ ! -f "$CREDS" ]; then
  if [ -z "${SMB_USER:-}" ]; then read -r -p "SMB username: " SMB_USER; fi
  if [ -z "${SMB_PASS:-}" ]; then read -r -s -p "SMB password: " SMB_PASS; echo; fi
  umask 077
  printf 'username=%s\npassword=%s\n' "$SMB_USER" "$SMB_PASS" >"$CREDS"
  chmod 600 "$CREDS"
  unset SMB_USER SMB_PASS
else
  chmod 600 "$CREDS"
  echo "Existing $CREDS found, keeping it."
fi

# ---- Mount the share ----
mkdir -p /mnt/nas
FSTAB_LINE="//${NAS_IP}/nas /mnt/nas cifs credentials=${CREDS},iocharset=utf8,_netdev,nofail 0 0"
if ! grep -qE '^[^#]*[[:space:]]/mnt/nas[[:space:]]' /etc/fstab; then
  echo "$FSTAB_LINE" >>/etc/fstab
  echo "Added /mnt/nas to /etc/fstab."
fi
systemctl daemon-reload
mount -a || true

if ! mountpoint -q /mnt/nas; then
  echo "ERROR: /mnt/nas is not mounted. Check NAS_IP, credentials and 'dmesg | tail'." >&2
  exit 1
fi
for d in /mnt/nas/immich /mnt/nas/Photos; do
  [ -d "$d" ] || { echo "ERROR: $d does not exist on the share. Create it on the NAS (immich/ empty, Photos/ = your library)." >&2; exit 1; }
done

# ---- Refuse to start Docker unless the share is mounted ----
install -d /etc/systemd/system/docker.service.d
cat >/etc/systemd/system/docker.service.d/require-nas.conf <<'UNIT'
[Unit]
RequiresMountsFor=/mnt/nas
UNIT
systemctl daemon-reload
systemctl enable --now docker

# ---- Immich files (pinned release) ----
install -d "$APP_DIR" "$APP_DIR/postgres"
cd "$APP_DIR"
curl -fsSL -o docker-compose.yml "${BASE_URL}/docker-compose.yml"

NEW_PASSWORD=""
if [ ! -f .env ]; then
  curl -fsSL -o .env "${BASE_URL}/example.env"
  NEW_PASSWORD=$(openssl rand -hex 16)  # alphanumeric (A-Za-z0-9) only
  sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=${NEW_PASSWORD}|" .env
  chmod 600 .env
else
  echo "Existing $APP_DIR/.env found, preserving DB_PASSWORD."
fi
set_env() {  # set_env KEY VALUE (replace, uncomment, or append)
  if grep -qE "^#? *$1=" .env; then sed -i -E "s|^#? *$1=.*|$1=$2|" .env; else echo "$1=$2" >>.env; fi
}
set_env UPLOAD_LOCATION /mnt/nas/immich
set_env DB_DATA_LOCATION "$APP_DIR/postgres"
set_env TZ "$TZ_NAME"
set_env IMMICH_VERSION "$IMMICH_RELEASE"

# External library: read-only bind of the existing Photos folder (override file,
# so the upstream compose file stays untouched).
cat >docker-compose.override.yml <<'YML'
services:
  immich-server:
    volumes:
      - /mnt/nas/Photos:/mnt/external-photos:ro
YML

# ---- Pre-flight, then start ----
mountpoint -q /mnt/nas || { echo "ERROR: /mnt/nas is not an active mount; refusing to start Immich." >&2; exit 1; }
if ! touch /mnt/nas/immich/.write-test 2>/dev/null; then
  echo "ERROR: /mnt/nas/immich is not writable. Check share permissions." >&2
  exit 1
fi
rm -f /mnt/nas/immich/.write-test

docker compose up -d

echo
echo "Immich ${IMMICH_RELEASE} is starting: http://$(hostname -I | awk '{print $1}'):2283"
echo "  docker compose -f $APP_DIR/docker-compose.yml ps"
if [ -n "$NEW_PASSWORD" ]; then
  echo "DB_PASSWORD (also in $APP_DIR/.env) - save it in your password manager: $NEW_PASSWORD"
fi
