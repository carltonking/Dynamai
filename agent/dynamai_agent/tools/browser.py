# SPDX-License-Identifier: GPL-3.0-or-later
"""Browser tool stub. Chromium is skipped on the 1 GB Always Free VM."""

from __future__ import annotations

from typing import Any

SCHEMA = {
    "name": "browser",
    "description": (
        "Control a headless browser (click, type, screenshot, read a rendered page). "
        "Not available on this host: the Oracle Always Free VM has ~1 GB of RAM, "
        "which is not enough for Chromium. Use web_fetch for static pages. "
        "This tool always returns an explanation rather than driving a browser."
    ),
    "input_schema": {
        "type": "object",
        "properties": {
            "action": {
                "type": "string",
                "description": "What you would like to do, e.g. open, click, type, screenshot.",
            },
            "url": {"type": "string", "description": "URL, when opening a page."},
            "instruction": {"type": "string", "description": "Further detail for the action."},
        },
        "required": ["action"],
    },
}


async def run(args: dict[str, Any]) -> str:
    action = (args.get("action") or "").strip() or "open"
    url = (args.get("url") or "").strip()
    return (
        "Browser is not available on this VM (about 1 GB RAM; Chromium was skipped for v1). "
        f"Requested action={action!r}" + (f" url={url}" if url else "") + ". "
        "Use web_fetch for static HTML, or run the hub on a larger machine later."
    )
