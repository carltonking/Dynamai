#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Install or upgrade the Photon iMessage bridge on this Ubuntu VM.
# Requires /etc/dynamai-photon.env (root-owned, mode 0600) with
# SPECTRUM_PROJECT_ID and SPECTRUM_PROJECT_SECRET already written.
# This script never prints secret values.
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="${DYNAMAI_PREFIX:-/opt/dynamai-agent}"
ENV_FILE="${DYNAMAI_PHOTON_ENV_FILE:-/etc/dynamai-photon.env}"
SERVICE_USER="${DYNAMAI_USER:-ubuntu}"
PHOTON_DIR="${PREFIX}/channels/photon"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "re-running install-photon with sudo…"
  exec sudo DYNAMAI_PREFIX="$PREFIX" DYNAMAI_PHOTON_ENV_FILE="$ENV_FILE" DYNAMAI_USER="$SERVICE_USER" "$0" "$@"
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "missing $ENV_FILE — write SPECTRUM_PROJECT_ID and SPECTRUM_PROJECT_SECRET into it (mode 0600, root-owned) and re-run." >&2
  exit 1
fi
chmod 600 "$ENV_FILE"
chown root:root "$ENV_FILE"
# Confirm required keys exist without printing values.
python3 - "$ENV_FILE" <<'ENDCHECK'
import sys
from pathlib import Path
needed = ("SPECTRUM_PROJECT_ID", "SPECTRUM_PROJECT_SECRET")
text = Path(sys.argv[1]).read_text(encoding="utf-8")
present = set()
for line in text.splitlines():
    line = line.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    key, _, value = line.partition("=")
    if key.strip() in needed and value.strip():
        present.add(key.strip())
missing = [k for k in needed if k not in present]
if missing:
    print("missing or empty in env file: " + ", ".join(missing), file=sys.stderr)
    sys.exit(1)
print("photon env file has the required keys")
ENDCHECK

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq ca-certificates curl unzip >/dev/null

if [[ ! -x /usr/local/bin/bun ]]; then
  echo "installing bun to /usr/local…"
  curl -fsSL https://bun.sh/install | BUN_INSTALL=/usr/local bash
fi
if [[ ! -x /usr/local/bin/bun ]]; then
  echo "bun is not at /usr/local/bin/bun after install" >&2
  exit 1
fi

if [[ ! -d "$PHOTON_DIR" ]]; then
  echo "missing $PHOTON_DIR — run scripts/install.sh first so the agent tree is synced." >&2
  exit 1
fi

chown -R "$SERVICE_USER:$SERVICE_USER" "$PHOTON_DIR"
echo "installing spectrum-ts packages with bun (production)…"
# Keep the working set down on the 1 GB VM; swap covers the install spike.
sudo -u "$SERVICE_USER" bash -lc "cd '$PHOTON_DIR' && bun install --production"

install -m 644 "$PREFIX/systemd/dynamai-photon.service" /etc/systemd/system/dynamai-photon.service
systemctl daemon-reload
systemctl enable dynamai-photon
systemctl restart dynamai-photon
sleep 3
systemctl --no-pager --full status dynamai-photon || true
echo "install-photon complete. the bridge uses an outbound Spectrum connection; no public webhook."
