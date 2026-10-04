#!/usr/bin/env bash
set -euo pipefail

# Run inside the vault container after `terraform apply`.
# Builds Vaultwarden from source and installs it as a systemd service on port 8000.
#
# Compiling needs more than the container's normal 512MB RAM. Before running
# this, bump resources from the Proxmox host, e.g.:
#   pct set 102 -memory 2048 -cores 2
# Afterward, run `terraform apply` again to restore the declared 512MB/1-core
# sizing (memory/cores aren't in the module's ignore_changes list).

apt update
apt install -y build-essential pkgconf libssl-dev libmariadb-dev-compat libpq-dev argon2 ssl-cert curl git

curl https://sh.rustup.rs -sSf | sh -s -- -y
# shellcheck disable=SC1091
source "$HOME/.cargo/env"

VW_VERSION=$(curl -s https://api.github.com/repos/dani-garcia/vaultwarden/releases/latest | grep -oP '"tag_name": "\K[^"]+')
git clone --branch "$VW_VERSION" --depth 1 https://github.com/dani-garcia/vaultwarden.git /tmp/vaultwarden-src
cd /tmp/vaultwarden-src
cargo build --features "sqlite,mysql,postgresql" --release

addgroup --system vaultwarden
adduser --system --home /opt/vaultwarden --shell /usr/sbin/nologin --no-create-home \
  --gecos 'vaultwarden' --ingroup vaultwarden --disabled-login --disabled-password vaultwarden
mkdir -p /opt/vaultwarden/{bin,data,web-vault}
cp /tmp/vaultwarden-src/target/release/vaultwarden /opt/vaultwarden/bin/
cd ~ && rm -rf /tmp/vaultwarden-src

WEB_VAULT_VERSION=$(curl -s https://api.github.com/repos/dani-garcia/bw_web_builds/releases/latest | grep -oP '"tag_name": "\K[^"]+')
curl -fsSL -o /tmp/web-vault.tar.gz \
  "https://github.com/dani-garcia/bw_web_builds/releases/download/${WEB_VAULT_VERSION}/bw_web_${WEB_VAULT_VERSION}.tar.gz"
tar -xzf /tmp/web-vault.tar.gz -C /opt/vaultwarden/web-vault --strip-components=1
rm /tmp/web-vault.tar.gz

ADMIN_TOKEN=$(openssl rand -base64 48)
cat <<EOF >/opt/vaultwarden/.env
ADMIN_TOKEN='${ADMIN_TOKEN}'
ROCKET_ADDRESS=0.0.0.0
DATA_FOLDER=/opt/vaultwarden/data
DATABASE_MAX_CONNS=10
WEB_VAULT_FOLDER=/opt/vaultwarden/web-vault
WEB_VAULT_ENABLED=true
EOF
chown -R vaultwarden:vaultwarden /opt/vaultwarden/
chown root:root /opt/vaultwarden/bin/vaultwarden
chmod +x /opt/vaultwarden/bin/vaultwarden
chmod +r /opt/vaultwarden/.env

cat <<EOF >/etc/systemd/system/vaultwarden.service
[Unit]
Description=Bitwarden Server (Powered by Vaultwarden)
Documentation=https://github.com/dani-garcia/vaultwarden
After=network.target

[Service]
User=vaultwarden
Group=vaultwarden
EnvironmentFile=-/opt/vaultwarden/.env
ExecStart=/opt/vaultwarden/bin/vaultwarden
LimitNOFILE=65535
LimitNPROC=4096
WorkingDirectory=/opt/vaultwarden
ReadWriteDirectories=/opt/vaultwarden/data
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now vaultwarden

echo "Vaultwarden installed and listening on port 8000."
echo "ADMIN_TOKEN (also saved in /opt/vaultwarden/.env): $ADMIN_TOKEN"
