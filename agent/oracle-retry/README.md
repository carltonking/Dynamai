# vertus-cloud capacity retry

A lightweight systemd timer that runs on `carlton-agent` and creates the
Always Free Arm instance `vertus-cloud` as soon as Oracle has A1 capacity
in `us-ashburn-1`.

It does **not** start, stop, or terminate any other instance (including
`carlton-agent`). It will not launch a second `vertus-cloud` if one already
exists in a non-`TERMINATED` state.

## What it creates

- Display name: `vertus-cloud`
- Shape: `VM.Standard.A1.Flex`, 4 OCPU / 24 GB RAM (falls back to 2 OCPU /
  12 GB if every availability domain rejects 4/24 on that pass)
- Image: newest non-Minimal Canonical Ubuntu 24.04 aarch64 for A1.Flex
  (pinned in `vertus_retry.py`)
- Boot volume: 100 GB
- Regional subnet used by `carlton-agent`, with a public IP
- SSH keys: Carlton's Mac key (`vertus-oracle`) and the box key used to
  verify the host

## Install (on carlton-agent)

1. Copy this directory and the OCI API **private** key to the VM. Never
   commit the key.
2. Write `/var/lib/vertus-retry/oci_config` from `oci_config.example`
   (user, fingerprint, tenancy, region, `key_file=` path).
3. Run:

   ```bash
   sudo ./install.sh /path/to/oci_api_key.pem
   sudo systemctl start vertus-retry.service
   ```

The timer fires about 5 minutes after each run finishes (`OnUnitInactiveSec`).

## Status

```bash
systemctl status vertus-retry.timer vertus-retry.service
journalctl -u vertus-retry -n 100 --no-pager
cat /var/lib/vertus-retry/result.txt
```

On success, `result.txt` contains the public IP and the timer is disabled.
Until then, `result.txt` is absent (or has `public_ip=PENDING` if the
instance was accepted but the VNIC is still coming up).
