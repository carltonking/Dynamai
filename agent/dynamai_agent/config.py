# SPDX-License-Identifier: GPL-3.0-or-later
"""Environment-driven settings. Secret values are never logged."""

from __future__ import annotations

import os
from pathlib import Path


def _env(name: str, default: str) -> str:
    value = os.environ.get(name)
    if value is None or value == "":
        return default
    return value


HOST = _env("DYNAMAI_HOST", "127.0.0.1")
PORT = int(_env("DYNAMAI_PORT", "8787"))
# Current Claude Sonnet from Anthropic's /v1/models list (2026-11-26).
MODEL = _env("ANTHROPIC_MODEL", "claude-sonnet-5-5")
AGENT_ID = _env("DYNAMAI_AGENT_ID", "primary")
AGENT_NAME = _env("DYNAMAI_AGENT_NAME", "Dynamai")

DATA_DIR = Path(_env("DYNAMAI_DATA_DIR", "/var/lib/dynamai-agent"))
VERTUS_DIR = Path(_env("DYNAMAI_VERTUS_DIR", str(DATA_DIR / ".vertus")))
TOKEN_PATH = VERTUS_DIR / "token"
APPROVER_TOKEN_PATH = VERTUS_DIR / "approver-token"
DB_PATH = Path(_env("DYNAMAI_DB_PATH", str(DATA_DIR / "hub.sqlite")))
WORKSPACE = Path(_env("DYNAMAI_WORKSPACE", str(DATA_DIR / "workspace")))

SHELL_TIMEOUT = int(_env("DYNAMAI_SHELL_TIMEOUT", "30"))
SHELL_TIMEOUT_MAX = int(_env("DYNAMAI_SHELL_TIMEOUT_MAX", "120"))
TOOL_OUTPUT_CAP = int(_env("DYNAMAI_TOOL_OUTPUT_CAP", str(32 * 1024)))
HISTORY_TURNS = int(_env("DYNAMAI_HISTORY_TURNS", "24"))
EVENT_RETAIN = int(_env("DYNAMAI_EVENT_RETAIN", "8000"))
FETCH_TIMEOUT = int(_env("DYNAMAI_FETCH_TIMEOUT", "20"))
FETCH_CAP = int(_env("DYNAMAI_FETCH_CAP", str(200_000)))
APPROVAL_TIMEOUT = int(_env("DYNAMAI_APPROVAL_TIMEOUT", "600"))

# Set by systemd EnvironmentFile. Read only when calling Anthropic.
def anthropic_api_key() -> str:
    key = os.environ.get("ANTHROPIC_API_KEY", "").strip()
    if not key:
        raise RuntimeError("ANTHROPIC_API_KEY is not set")
    return key


def sendblue_configured() -> bool:
    return bool(os.environ.get("SENDBLUE_API_KEY", "").strip() and os.environ.get("SENDBLUE_API_SECRET", "").strip())
