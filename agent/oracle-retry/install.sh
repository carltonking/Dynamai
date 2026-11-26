#!/bin/bash
# Install the vertus-cloud capacity retry on this host (expected: carlton-agent).
# Copies the API private key from a path you pass; does not print it.
set -euo pipefail

SRC_DIR=$(cd "$(dirname "$0")" && pwd)
KEY_SRC=${1:-}
if [[ -z "$KEY_SRC" || ! -f "$KEY_SRC" ]]; then
  echo "Usage: sudo $0 /path/to/oci_api_key.pem" >&2
  echo "Also provide /var/lib/vertus-retry/oci_config (see oci_config.example)." >&2
  exit 2
fi

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root" >&2
  exit 2
fi

id vertus-retry >/dev/null 2>&1 || useradd --system --home-dir /var/lib/vertus-retry \
  --create-home --shell /usr/sbin/nologin --comment "vertus-cloud A1 retry" vertus-retry

install -d -m 0755 /opt/vertus-retry
install -m 0755 "$SRC_DIR/vertus_retry.py" /opt/vertus-retry/vertus_retry.py
install -m 0755 "$SRC_DIR/run.sh" /opt/vertus-retry/run.sh
install -m 0644 "$SRC_DIR/systemd/vertus-retry.service" /etc/systemd/system/vertus-retry.service
install -m 0644 "$SRC_DIR/systemd/vertus-retry.timer" /etc/systemd/system/vertus-retry.timer

install -d -m 0750 -o vertus-retry -g vertus-retry /var/lib/vertus-retry
install -m 0600 -o vertus-retry -g vertus-retry "$KEY_SRC" /var/lib/vertus-retry/oci_api_key.pem

if [[ ! -f /var/lib/vertus-retry/oci_config ]]; then
  echo "Missing /var/lib/vertus-retry/oci_config — write it before starting the timer." >&2
  exit 2
fi
chown vertus-retry:vertus-retry /var/lib/vertus-retry/oci_config
chmod 0600 /var/lib/vertus-retry/oci_config

if [[ ! -x /opt/vertus-retry/venv/bin/python ]]; then
  python3 -m venv /opt/vertus-retry/venv
fi
# Keep memory use down on the 1 GB VM.
nice -n 15 /opt/vertus-retry/venv/bin/pip install --no-cache-dir 'oci==2.193.0'
chown -R root:root /opt/vertus-retry
# The service wrapper runs the python as root? No: we should run python as vertus-retry.
# run.sh is invoked as root and should drop privileges.
chmod 0755 /opt/vertus-retry/run.sh /opt/vertus-retry/vertus_retry.py

systemctl daemon-reload
systemctl enable --now vertus-retry.timer
echo "Installed. Check: journalctl -u vertus-retry -n 50 --no-pager"
echo "Result file (after success): /var/lib/vertus-retry/result.txt"
