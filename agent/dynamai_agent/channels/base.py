# SPDX-License-Identifier: GPL-3.0-or-later
"""Channel adapter interface. iMessage providers plug in here."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Protocol


@dataclass
class InboundMessage:
    sender: str
    text: str
    channel: str
    message_id: str | None = None
    attachments: list[str] = field(default_factory=list)
    raw: dict | None = None


class Channel(Protocol):
    name: str
    enabled: bool

    async def send(self, to: str, text: str, attachments: list[str] | None = None) -> None:
        """Deliver a reply back to the person who texted."""
        ...

    def parse_webhook(self, headers: dict[str, str], body: bytes) -> InboundMessage | None:
        """Turn an inbound webhook into a message, or None if it should be ignored."""
        ...
