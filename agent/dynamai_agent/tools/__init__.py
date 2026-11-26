# SPDX-License-Identifier: GPL-3.0-or-later
"""Anthropic tool definitions and dispatch."""

from __future__ import annotations

from typing import Any, Callable, Awaitable

from dynamai_agent.db import Database
from dynamai_agent.tools import browser, memory, shell, web

ToolHandler = Callable[[dict[str, Any]], Awaitable[str]]


def schemas() -> list[dict[str, Any]]:
    return [
        {
            "name": "shell",
            "description": (
                "Run a shell command on this Ubuntu VM as the agent user. "
                "Use for system facts (hostname, memory, disk), files in the "
                "workspace, and other inspection. Destructive commands may be held "
                "for approval. Output is truncated."
            ),
            "input_schema": {
                "type": "object",
                "properties": {
                    "command": {"type": "string", "description": "The command to run, including arguments."},
                    "timeout": {
                        "type": "integer",
                        "description": "Seconds to wait before killing the process (optional).",
                    },
                },
                "required": ["command"],
            },
        },
        {
            "name": "web_search",
            "description": (
                "Search the public web (free DuckDuckGo instant-answer and HTML results). "
                "Use for current facts you do not already know. Follow interesting URLs with web_fetch."
            ),
            "input_schema": {
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "Search query."},
                },
                "required": ["query"],
            },
        },
        {
            "name": "web_fetch",
            "description": "Fetch a public HTTP(S) URL and return extracted text.",
            "input_schema": {
                "type": "object",
                "properties": {
                    "url": {"type": "string", "description": "The URL to fetch."},
                },
                "required": ["url"],
            },
        },
        {
            "name": "remember",
            "description": (
                "Store a durable fact about the user or their world in long-term memory. "
                "Use this when they ask you to remember something, or when you learn a stable preference or identity."
            ),
            "input_schema": {
                "type": "object",
                "properties": {
                    "fact": {"type": "string", "description": "The fact to store, in a complete sentence."},
                    "title": {"type": "string", "description": "Optional short label, e.g. 'user name'."},
                },
                "required": ["fact"],
            },
        },
        {
            "name": "recall",
            "description": "Search long-term memory for facts previously stored with remember.",
            "input_schema": {
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "What to look up, e.g. 'name'."},
                },
                "required": ["query"],
            },
        },
        {
            "name": "forget",
            "description": "Delete a memory note by its numeric id, from recall results.",
            "input_schema": {
                "type": "object",
                "properties": {
                    "id": {"type": "integer", "description": "The note id to delete."},
                },
                "required": ["id"],
            },
        },
        browser.SCHEMA,
    ]


def handlers(db: Database) -> dict[str, ToolHandler]:
    return {
        "shell": shell.run,
        "web_search": web.search,
        "web_fetch": web.fetch,
        "remember": memory.make_remember(db),
        "recall": memory.make_recall(db),
        "forget": memory.make_forget(db),
        "browser": browser.run,
    }
