# SPDX-License-Identifier: GPL-3.0-or-later
"""
Sendblue iMessage adapter — skeleton only until SENDBLUE_API_KEY and
SENDBLUE_API_SECRET are set. Do not sign up from this module.

When configured, inbound webhooks land on POST /hooks/sendblue and replies
are posted to Sendblue's send-message API. The agent can then have its own
iMessage number, which matters because Carlton's MacBook is often not at home.
"""

from __future__ import annotations

import json
import os
from typing import Any

import httpx

from dynamai_agent.channels.base import InboundMessage
from dynamai_agent.config import sendblue_configured

SENDBLUE_SEND_URL = os.environ.get("SENDBLUE_SEND_URL", "https://api.sendblue.co/api/send-message")


class SendblueChannel:
    name = "sendblue"

    @property
    def enabled(self) -> bool:
        return sendblue_configured()

    def _headers(self) -> dict[str, str]:
        # Sendblue documents these header names; values come only from env.
        return {
            "sb-api-key-id": os.environ.get("SENDBLUE_API_KEY", ""),
            "sb-api-secret-key": os.environ.get("SENDBLUE_API_SECRET", ""),
            "Content-Type": "application/json",
        }

    async def send(self, to: str, text: str, attachments: list[str] | None = None) -> None:
        if not self.enabled:
            raise RuntimeError("Sendblue is not configured (SENDBLUE_API_KEY / SENDBLUE_API_SECRET unset)")
        payload: dict[str, Any] = {"number": to, "content": text}
        if attachments:
            payload["media_url"] = attachments[0]
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(SENDBLUE_SEND_URL, headers=self._headers(), json=payload)
            resp.raise_for_status()

    def parse_webhook(self, headers: dict[str, str], body: bytes) -> InboundMessage | None:
        # Official Sendblue webhooks are JSON with from_number / content.
        # Signature verification should be added when a real account is wired up.
        if not self.enabled:
            return None
        try:
            data = json.loads(body.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            return None
        if not isinstance(data, dict):
            return None
        sender = str(data.get("from_number") or data.get("number") or "").strip()
        text = str(data.get("content") or data.get("text") or "").strip()
        if not sender or not text:
            return None
        # Outbound echo / status callbacks should not start a new run.
        if str(data.get("status") or "").lower() in {"sent", "queued", "delivered"} and not data.get("is_inbound", True):
            return None
        return InboundMessage(
            sender=sender,
            text=text,
            channel=self.name,
            message_id=str(data.get("message_handle") or data.get("id") or "") or None,
            raw=data,
        )
