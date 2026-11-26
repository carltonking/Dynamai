# SPDX-License-Identifier: GPL-3.0-or-later
"""Shell tool: timeout, output cap, optional approval for destructive commands."""

from __future__ import annotations

import asyncio
import os
import re
import shlex
from typing import Any

from dynamai_agent.config import SHELL_TIMEOUT, SHELL_TIMEOUT_MAX, TOOL_OUTPUT_CAP, WORKSPACE

# First tokens (or patterns) that must be approved before they run.
_DANGEROUS = re.compile(
    r"""(?ix)
    ^(sudo|su|doas|shutdown|reboot|poweroff|halt|mkfs|fdisk|parted|wipefs|
      dd|userdel|passwd|chpasswd|visudo)\b
    | \brm\s+(-[^\s]*\s+)*-r
    | \bmkfs\.
    | /dev/sd
    | \bchmod\s+(-[^\s]*\s+)*777\b
    | \bcurl\b.*\|\s*(ba)?sh
    | \bwget\b.*\|\s*(ba)?sh
    """
)


def needs_approval(command: str) -> bool:
    text = command.strip()
    if not text:
        return False
    return _DANGEROUS.search(text) is not None


def describe(command: str) -> tuple[str, str]:
    """(action, target) as the Vertus approval ledger expects."""
    return (f"The agent wants to run a shell command: {command}", command)


async def run(args: dict[str, Any]) -> str:
    command = (args.get("command") or "").strip()
    if not command:
        return "error: no command"
    timeout = args.get("timeout")
    try:
        timeout_s = int(timeout) if timeout is not None else SHELL_TIMEOUT
    except (TypeError, ValueError):
        timeout_s = SHELL_TIMEOUT
    timeout_s = max(1, min(SHELL_TIMEOUT_MAX, timeout_s))

    WORKSPACE.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    # Keep the tool from inheriting nothing useful, but do not dump secrets into the output.
    proc = await asyncio.create_subprocess_shell(
        command,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT,
        cwd=str(WORKSPACE),
        env=env,
        limit=TOOL_OUTPUT_CAP + 4096,
    )
    try:
        out, _ = await asyncio.wait_for(proc.communicate(), timeout=timeout_s)
    except TimeoutError:
        proc.kill()
        try:
            await proc.communicate()
        except Exception:
            pass
        return f"error: timed out after {timeout_s}s"
    text = out.decode("utf-8", errors="replace")
    truncated = False
    if len(text.encode("utf-8")) > TOOL_OUTPUT_CAP:
        text = text.encode("utf-8")[:TOOL_OUTPUT_CAP].decode("utf-8", errors="replace")
        truncated = True
    status = proc.returncode
    suffix = "\n[truncated]" if truncated else ""
    if not text.strip():
        return f"(exit {status}, no output){suffix}"
    # Prefer quoting the command only in metadata, not echoed back unless useful.
    return f"(exit {status})\n{text}{suffix}"


def preview(command: str) -> str:
    try:
        return shlex.join(shlex.split(command))
    except ValueError:
        return command
