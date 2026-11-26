#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Install or upgrade the hub on this Ubuntu VM. Run as a sudoer.
# The Anthropic API key is NOT written here; it must already be in
# /etc/dynamai-agent.env (root-owned, mode 0600).
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="${DYNAMAI_PREFIX:-/opt/dynamai-agent}"
DATA="${DYNAMAI_DATA_DIR:-/var/lib/dynamai-agent}"
ENV_FILE="${DYNAMAI_ENV_FILE:-/etc/dynamai-agent.env}"
SERVICE_USER="${DYNAMAI_USER:-ubuntu}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "re-running install with sudo…"
  exec sudo DYNAMAI_PREFIX="$PREFIX" DYNAMAI_DATA_DIR="$DATA" DYNAMAI_ENV_FILE="$ENV_FILE" DYNAMAI_USER="$SERVICE_USER" "$0" "$@"
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq python3 python3-venv python3-pip >/dev/null

mkdir -p "$PREFIX" "$DATA" "$DATA/.vertus" "$DATA/workspace"
rsync -a --delete --exclude '.venv' --exclude '__pycache__' --exclude '*.sqlite' --exclude '.data' "$SRC/" "$PREFIX/"
chown -R "$SERVICE_USER:$SERVICE_USER" "$PREFIX" "$DATA"
chmod 700 "$DATA" "$DATA/.vertus"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "missing $ENV_FILE — write ANTHROPIC_API_KEY into it (mode 0600, root-owned) and re-run." >&2
  exit 1
fi
chmod 600 "$ENV_FILE"
chown root:root "$ENV_FILE"

sudo -u "$SERVICE_USER" python3 -m venv "$PREFIX/.venv"
sudo -u "$SERVICE_USER" "$PREFIX/.venv/bin/pip" install --upgrade pip
sudo -u "$SERVICE_USER" "$PREFIX/.venv/bin/pip" install -r "$PREFIX/requirements.txt"

# Generate bearer/approver tokens if they do not already exist. Do not print them.
sudo -u "$SERVICE_USER" env DYNAMAI_DATA_DIR="$DATA" PYTHONPATH="$PREFIX" "$PREFIX/.venv/bin/python" - <<'PY'
from dynamai_agent.auth import ensure_tokens
from dynamai_agent.config import APPROVER_TOKEN_PATH, TOKEN_PATH
ensure_tokens()
print(f"token file: {TOKEN_PATH}")
print(f"approver token file: {APPROVER_TOKEN_PATH}")
PY

install -m 644 "$PREFIX/systemd/dynamai-agent.service" /etc/systemd/system/dynamai-agent.service
systemctl daemon-reload
systemctl enable dynamai-agent
systemctl restart dynamai-agent
# Give uvicorn a moment, then show status without env contents.
sleep 2
systemctl --no-pager --full status dynamai-agent || true
echo "install complete. the hub listens on 127.0.0.1:8787."
