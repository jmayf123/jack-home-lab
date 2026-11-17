#!/usr/bin/env bash
set -euo pipefail

# Run inside the llm container after `terraform apply` AND after applying
# lxc.conf.snippet on the Proxmox host (GPU device passthrough).
#
# Installs:
#   - Ollama (official tarballs, ROCm runtime bundled) as a systemd service on :11434
#   - Open WebUI natively (uv-managed Python 3.11 venv) as a systemd service on :8080
#
# No separate ROCm install is needed: Ollama ships its own ROCm libraries, and
# only the host's amdgpu driver has to expose /dev/kfd and /dev/dri/renderD128.
# The RX 6700 XT is gfx1031, which ROCm doesn't officially support, so Ollama
# needs HSA_OVERRIDE_GFX_VERSION=10.3.0 to use it.

########## preflight ##########

for dev in /dev/kfd /dev/dri/renderD128; do
  if [[ ! -e "$dev" ]]; then
    echo "ERROR: $dev is missing inside the container." >&2
    echo "Apply services/llm/lxc.conf.snippet to /etc/pve/lxc/105.conf on the Proxmox host, restart the container, then re-run." >&2
    exit 1
  fi
done

apt update
apt install -y curl ca-certificates tar zstd

########## Ollama ##########

# Manual install (https://docs.ollama.com/linux) rather than install.sh, so the
# ROCm bundle is always installed instead of depending on lspci GPU detection,
# which is unreliable inside an LXC. Archives are .tar.zst (Ollama dropped .tgz).
curl -fsSL https://ollama.com/download/ollama-linux-amd64.tar.zst | zstd -d | tar -C /usr -xf -
curl -fsSL https://ollama.com/download/ollama-linux-amd64-rocm.tar.zst | zstd -d | tar -C /usr -xf -

getent group render >/dev/null || groupadd --system render
getent group video  >/dev/null || groupadd --system video
if ! id ollama >/dev/null 2>&1; then
  useradd --system --user-group --create-home --home-dir /usr/share/ollama --shell /bin/false ollama
fi
usermod -a -G render,video ollama

cat <<'EOF' >/etc/systemd/system/ollama.service
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
ExecStart=/usr/bin/ollama serve
User=ollama
Group=ollama
Restart=always
RestartSec=3
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
# Listen on the LAN, not just localhost, so other hosts/dashboards can use the API.
Environment="OLLAMA_HOST=0.0.0.0"
# RX 6700 XT (gfx1031) is unsupported by ROCm; pretend to be gfx1030.
Environment="HSA_OVERRIDE_GFX_VERSION=10.3.0"

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now ollama

########## Open WebUI ##########

# Open WebUI supports Python 3.11/3.12 only; Debian 13 ships 3.13, so uv
# downloads and manages a 3.11 interpreter for the venv.
curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin INSTALLER_NO_MODIFY_PATH=1 sh

if ! id open-webui >/dev/null 2>&1; then
  useradd --system --user-group --create-home --home-dir /opt/open-webui --shell /usr/sbin/nologin open-webui
fi
mkdir -p /opt/open-webui/data
chown -R open-webui:open-webui /opt/open-webui

# Run as the service user so the venv and uv's python cache are owned by it.
runuser -u open-webui -- /usr/local/bin/uv venv --python 3.11 /opt/open-webui/venv
runuser -u open-webui -- /usr/local/bin/uv pip install --python /opt/open-webui/venv/bin/python open-webui

cat <<'EOF' >/opt/open-webui/.env
DATA_DIR=/opt/open-webui/data
OLLAMA_BASE_URL=http://127.0.0.1:11434
EOF
chown open-webui:open-webui /opt/open-webui/.env

cat <<'EOF' >/etc/systemd/system/open-webui.service
[Unit]
Description=Open WebUI
After=network-online.target ollama.service
Wants=ollama.service

[Service]
User=open-webui
Group=open-webui
WorkingDirectory=/opt/open-webui
EnvironmentFile=/opt/open-webui/.env
ExecStart=/opt/open-webui/venv/bin/open-webui serve --host 0.0.0.0 --port 8080
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now open-webui

########## done ##########

cat <<EOF

Ollama API:  http://$(hostname -I | awk '{print $1}'):11434
Open WebUI:  http://$(hostname -I | awk '{print $1}'):8080  (first account created becomes admin)

Next:
  ollama pull llama3.1:8b
  ollama run llama3.1:8b "hi"
  ollama ps            # should show "100% GPU"; "CPU" means the GPU wasn't picked up
  journalctl -u ollama | grep -iE 'amdgpu|gfx|rocm'
EOF
