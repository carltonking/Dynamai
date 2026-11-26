#!/usr/bin/env python3
"""Create the Always Free A1 instance 'vertus-cloud' when Oracle has capacity.

Intended to run as a systemd oneshot on carlton-agent every few minutes.
It only launches a new instance named vertus-cloud. It never stops, starts,
or terminates any instance, including carlton-agent.
"""

from __future__ import annotations

import logging
import os
import sys
import time
from pathlib import Path

import oci
from oci.exceptions import ServiceError

LOG = logging.getLogger("vertus-retry")

DISPLAY_NAME = "vertus-cloud"
PROTECTED_NAMES = frozenset({"carlton-agent"})
SHAPE = "VM.Standard.A1.Flex"
BOOT_VOLUME_GBS = 100
# Newest non-Minimal Canonical Ubuntu 24.04 aarch64 image for VM.Standard.A1.Flex
# in us-ashburn-1 as of 2026-11-26 (Canonical-Ubuntu-24.04-aarch64-2026.11.05-0).
IMAGE_ID = "ocid1.image.oc1.iad.aaaaaaaao7fql25wdxf7vjryp7zerzwi4kpe3fefcsw62k4rhuqsbdovguoq"
SUBNET_ID = "ocid1.subnet.oc1.iad.aaaaaaaadzxjer3eg2kstj4v2ml52xv37tmvn5cvqufmbiyroautlp5vyybq"

# Carlton's Mac key first, then the box key used to verify the host later.
SSH_AUTHORIZED_KEYS = (
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIH5zynpLJDCmn1Vp5RgvZFysAgqU4xWLrMznwOaOV+c vertus-oracle\n"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIPPbFzgl7eTeN5fXEVFG/KmEJDrzWIQ/+MqAKaHn94F carlton-oracle-agent\n"
)

# Prefer the full Always Free A1 shape; fall back to half-size if 4/24 is
# unavailable in every Ashburn AD on this pass.
SHAPE_CONFIGS = (
    {"ocpus": 4, "memory_in_gbs": 24},
    {"ocpus": 2, "memory_in_gbs": 12},
)

CONFIG_FILE = os.environ.get("OCI_CONFIG_FILE", "/var/lib/vertus-retry/oci_config")
RESULT_FILE = Path(os.environ.get("VERTUS_RESULT_FILE", "/var/lib/vertus-retry/result.txt"))
LOCK_FILE = Path(os.environ.get("VERTUS_LOCK_FILE", "/var/lib/vertus-retry/vertus-retry.lock"))

# Exit 0: no instance yet (out of capacity / will try later)
# Exit 10: instance exists but public IP is still pending (keep the timer)
# Exit 0 after writing public_ip: success (wrapper disables the timer)
# Exit 1: unexpected error
EXIT_RETRY = 0
EXIT_PENDING_IP = 10
EXIT_ERROR = 1


def setup_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        stream=sys.stdout,
    )


def is_capacity_error(exc: ServiceError) -> bool:
    msg = (exc.message or str(exc)).lower()
    code = (exc.code or "").lower()
    haystack = f"{code} {msg}"
    needles = (
        "out of host capacity",
        "out of capacity",
        "outofhostcapacity",
        "insufficient capacity",
        "no host capacity",
        "host capacity",
    )
    return any(n in haystack for n in needles)


def is_rate_limited(exc: ServiceError) -> bool:
    return exc.status == 429 or (exc.code or "") == "TooManyRequests"


def format_error(exc: ServiceError) -> str:
    return f"status={exc.status} code={exc.code} msg={exc.message}"


def existing_vertus(compute: oci.core.ComputeClient, compartment_id: str):
    instances = oci.pagination.list_call_get_all_results(
        compute.list_instances,
        compartment_id=compartment_id,
    ).data
    found = []
    for inst in instances:
        if inst.display_name in PROTECTED_NAMES:
            continue
        if inst.display_name == DISPLAY_NAME and inst.lifecycle_state != "TERMINATED":
            found.append(inst)
    return found


def get_public_ip(
    compute: oci.core.ComputeClient,
    network: oci.core.VirtualNetworkClient,
    compartment_id: str,
    instance_id: str,
    timeout_s: int = 90,
) -> str | None:
    deadline = time.time() + timeout_s
    while True:
        attachments = compute.list_vnic_attachments(
            compartment_id, instance_id=instance_id
        ).data
        for att in attachments:
            if not att.vnic_id:
                continue
            vnic = network.get_vnic(att.vnic_id).data
            if vnic.public_ip:
                return vnic.public_ip
        if time.time() >= deadline:
            return None
        time.sleep(5)


def write_result(inst, public_ip: str | None) -> None:
    shape_cfg = inst.shape_config
    ocpus = getattr(shape_cfg, "ocpus", "") if shape_cfg else ""
    memory = getattr(shape_cfg, "memory_in_gbs", "") if shape_cfg else ""
    lines = [
        f"display_name={inst.display_name}",
        f"state={inst.lifecycle_state}",
        f"id={inst.id}",
        f"ad={inst.availability_domain}",
        f"shape={inst.shape}",
        f"ocpus={ocpus}",
        f"memory_in_gbs={memory}",
        f"public_ip={public_ip or 'PENDING'}",
    ]
    text = "\n".join(lines) + "\n"
    RESULT_FILE.parent.mkdir(parents=True, exist_ok=True)
    tmp = RESULT_FILE.with_suffix(".tmp")
    tmp.write_text(text)
    tmp.replace(RESULT_FILE)
    LOG.info("Wrote %s", RESULT_FILE)


def finish_existing(compute, network, compartment_id, inst) -> int:
    LOG.info(
        "Found existing %s state=%s ad=%s shape=%s id=%s",
        inst.display_name,
        inst.lifecycle_state,
        inst.availability_domain,
        inst.shape,
        inst.id,
    )
    timeout = 90 if inst.lifecycle_state in {"PROVISIONING", "CREATING", "STARTING"} else 20
    public_ip = get_public_ip(compute, network, compartment_id, inst.id, timeout_s=timeout)
    write_result(inst, public_ip)
    if public_ip:
        LOG.info("vertus-cloud public IP is %s", public_ip)
        return EXIT_RETRY  # 0; wrapper disables the timer when public_ip is set
    LOG.warning("vertus-cloud exists but public IP is not assigned yet; will check again")
    return EXIT_PENDING_IP


def launch_instance(compute, compartment_id: str, ad: str, shape_cfg: dict):
    details = oci.core.models.LaunchInstanceDetails(
        compartment_id=compartment_id,
        availability_domain=ad,
        display_name=DISPLAY_NAME,
        shape=SHAPE,
        shape_config=oci.core.models.LaunchInstanceShapeConfigDetails(
            ocpus=shape_cfg["ocpus"],
            memory_in_gbs=shape_cfg["memory_in_gbs"],
        ),
        source_details=oci.core.models.InstanceSourceViaImageDetails(
            source_type="image",
            image_id=IMAGE_ID,
            boot_volume_size_in_gbs=BOOT_VOLUME_GBS,
        ),
        create_vnic_details=oci.core.models.CreateVnicDetails(
            subnet_id=SUBNET_ID,
            assign_public_ip=True,
            display_name=f"{DISPLAY_NAME}-vnic",
        ),
        metadata={"ssh_authorized_keys": SSH_AUTHORIZED_KEYS},
    )
    # Disable SDK retries so a 500 "out of capacity" does not stall this AD.
    return compute.launch_instance(
        details, retry_strategy=oci.retry.NoneRetryStrategy()
    ).data


def acquire_lock(path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    fh = open(path, "a+")
    try:
        import fcntl

        fcntl.flock(fh.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        fh.close()
        LOG.info("Another vertus-retry run is in progress; exiting")
        sys.exit(EXIT_RETRY)
    return fh


def main() -> int:
    setup_logging()
    lock_fh = acquire_lock(LOCK_FILE)
    try:
        return run()
    finally:
        lock_fh.close()


def run() -> int:
    if not Path(CONFIG_FILE).is_file():
        LOG.error("Missing OCI config at %s", CONFIG_FILE)
        return EXIT_ERROR

    config = oci.config.from_file(file_location=CONFIG_FILE)
    oci.config.validate_config(config)
    compartment_id = config["tenancy"]

    compute = oci.core.ComputeClient(config)
    network = oci.core.VirtualNetworkClient(config)
    identity = oci.identity.IdentityClient(config)

    existing = existing_vertus(compute, compartment_id)
    if existing:
        if len(existing) > 1:
            LOG.warning("Found %d non-terminated instances named %s", len(existing), DISPLAY_NAME)
        return finish_existing(compute, network, compartment_id, existing[0])

    ads = [ad.name for ad in identity.list_availability_domains(compartment_id).data]
    if not ads:
        LOG.error("No availability domains returned for this tenancy")
        return EXIT_ERROR
    LOG.info("No existing %s instance; trying ADs: %s", DISPLAY_NAME, ", ".join(ads))

    backoff = 20
    last_error = None
    for shape_cfg in SHAPE_CONFIGS:
        for ad in ads:
            # A few 429 retries for this AD/shape, then move on.
            for _rate_try in range(4):
                existing = existing_vertus(compute, compartment_id)
                if existing:
                    LOG.info("Instance appeared before launch; not creating another")
                    return finish_existing(compute, network, compartment_id, existing[0])

                label = f"{shape_cfg['ocpus']} OCPU / {shape_cfg['memory_in_gbs']} GB in {ad}"
                LOG.info("Attempting launch: %s", label)
                try:
                    inst = launch_instance(compute, compartment_id, ad, shape_cfg)
                except ServiceError as exc:
                    last_error = exc
                    if is_rate_limited(exc):
                        LOG.warning("Rate limited (%s); sleeping %ss", format_error(exc), backoff)
                        time.sleep(backoff)
                        backoff = min(backoff * 2, 180)
                        continue
                    if is_capacity_error(exc):
                        LOG.info("No capacity for %s (%s)", label, format_error(exc))
                        # Brief pause so a six-launch pass is less likely to hit 429.
                        time.sleep(8)
                        break
                    LOG.error("Launch failed for %s: %s", label, format_error(exc))
                    break

                LOG.info(
                    "Launch accepted: state=%s ad=%s shape=%s id=%s",
                    inst.lifecycle_state,
                    inst.availability_domain,
                    inst.shape,
                    inst.id,
                )
                return finish_existing(compute, network, compartment_id, inst)
            else:
                # rate-try loop exhausted
                LOG.warning("Still rate-limited after retries in %s; will try again later", ad)

    if last_error and not is_capacity_error(last_error) and not is_rate_limited(last_error):
        LOG.error("All attempts failed; last error: %s", format_error(last_error))
        return EXIT_ERROR

    LOG.info("No A1 capacity this pass; will try again later")
    return EXIT_RETRY


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        LOG.exception("Unexpected failure")
        sys.exit(EXIT_ERROR)
