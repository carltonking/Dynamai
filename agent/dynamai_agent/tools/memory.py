# SPDX-License-Identifier: GPL-3.0-or-later
"""Durable notes in SQLite, exposed as remember / recall / forget tools."""

from __future__ import annotations

from typing import Any, Callable, Awaitable

from dynamai_agent.db import Database


def make_remember(db: Database) -> Callable[[dict[str, Any]], Awaitable[str]]:
    async def remember(args: dict[str, Any]) -> str:
        fact = (args.get("fact") or "").strip()
        title = (args.get("title") or "").strip() or None
        if not fact:
            return "error: empty fact"
        note_id = db.add_note(fact, title=title)
        return f"Remembered #{note_id}" + (f" ({title})" if title else "") + "."

    return remember


def make_recall(db: Database) -> Callable[[dict[str, Any]], Awaitable[str]]:
    async def recall(args: dict[str, Any]) -> str:
        query = (args.get("query") or "").strip()
        rows = db.search_notes(query, limit=12) if query else db.recent_notes(12)
        if not rows:
            return "No matching memories."
        lines = []
        for row in rows:
            title = (row["title"] or "").strip()
            prefix = f"#{row['id']}" + (f" {title}" if title else "")
            lines.append(f"{prefix}: {row['content']}")
        return "\n".join(lines)

    return recall


def make_forget(db: Database) -> Callable[[dict[str, Any]], Awaitable[str]]:
    async def forget(args: dict[str, Any]) -> str:
        try:
            note_id = int(args.get("id"))
        except (TypeError, ValueError):
            return "error: id must be an integer"
        if db.delete_note(note_id):
            return f"Forgot #{note_id}."
        return f"error: no note #{note_id}"

    return forget
