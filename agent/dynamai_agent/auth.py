# SPDX-License-Identifier: GPL-3.0-or-later
"""Bearer and approver tokens on disk, 0600, generated once."""

from __future__ import annotations

import secrets
from pathlib import Path

from fastapi import Header, HTTPException

from dynamai_agent.config import APPROVER_TOKEN_PATH, TOKEN_PATH, VERTUS_DIR


def _read_secret(path: Path) -> str | None:
    try:
        raw = path.read_text(encoding="utf-8")
    except OSError:
        return None
    token = raw.strip()
    return token or None


def _write_secret(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.touch(mode=0o600, exist_ok=True)
    path.chmod(0o600)
    path.write_text(value + "\n", encoding="utf-8")
    path.chmod(0o600)


def ensure_tokens() -> None:
    VERTUS_DIR.mkdir(parents=True, exist_ok=True)
    VERTUS_DIR.chmod(0o700)
    if _read_secret(TOKEN_PATH) is None:
        _write_secret(TOKEN_PATH, secrets.token_urlsafe(32))
    if _read_secret(APPROVER_TOKEN_PATH) is None:
        _write_secret(APPROVER_TOKEN_PATH, secrets.token_urlsafe(32))


def bearer_token() -> str:
    token = _read_secret(TOKEN_PATH)
    if not token:
        raise RuntimeError(f"hub token missing at {TOKEN_PATH}")
    return token


def approver_token() -> str:
    token = _read_secret(APPROVER_TOKEN_PATH)
    if not token:
        raise RuntimeError(f"approver token missing at {APPROVER_TOKEN_PATH}")
    return token


async def require_bearer(authorization: str | None = Header(default=None)) -> str:
    expected = bearer_token()
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail={"error": "missing bearer token"})
    offered = authorization.split(" ", 1)[1].strip()
    if not offered or not secrets.compare_digest(offered, expected):
        raise HTTPException(status_code=401, detail={"error": "invalid bearer token"})
    return offered


def check_approver(header_value: str | None) -> bool:
    expected = approver_token()
    if not header_value:
        return False
    return secrets.compare_digest(header_value.strip(), expected)
