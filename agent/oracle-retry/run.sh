#!/bin/bash
# Root wrapper: run the retry as user vertus-retry, then disable the timer
# once a public IP has been written.
set -u
export PYTHONUNBUFFERED=1
runuser -u vertus-retry -- /opt/vertus-retry/venv/bin/python /opt/vertus-retry/vertus_retry.py
rc=$?

result=/var/lib/vertus-retry/result.txt
if [[ -s "$result" ]] && grep -qE '^public_ip=[0-9]' "$result"; then
  if systemctl is-enabled --quiet vertus-retry.timer 2>/dev/null \
     || systemctl is-active --quiet vertus-retry.timer 2>/dev/null; then
    echo "Public IP recorded; disabling vertus-retry.timer"
    systemctl disable --now vertus-retry.timer
  fi
fi
exit "$rc"
