#!/usr/bin/env bash
set -euo pipefail

# Run inside the adguard container after `terraform apply`.
# Installs AdGuard Home via its official install script (systemd service).

curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v

echo "AdGuard Home installed. Open http://<container-ip>:3000 to finish the setup wizard."
