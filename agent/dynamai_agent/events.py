# SPDX-License-Identifier: GPL-3.0-or-later
"""In-process event bus: persist, assign seq, fan out to SSE subscribers."""

from __future__ import annotations

import asyncio
import json
from typing import Any, AsyncIterator

from dynamai_agent.config import EVENT_RETAIN
from dynamai_agent.db import Database


def format_sse(payload: dict[str, Any]) -> str:
    return f"data: {json.dumps(payload, ensure_ascii=False, separators=(',', ':'))}\n\n"


class EventBus:
    def __init__(self, db: Database) -> None:
        self.db = db
        self._subs: set[asyncio.Queue[dict[str, Any] | None]] = set()
        self._lock = asyncio.Lock()
        self._seq = db.last_seq()

    @property
    def seq(self) -> int:
        return self._seq

    async def publish(self, payload: dict[str, Any]) -> dict[str, Any]:
        # seq is assigned by SQLite AUTOINCREMENT so a watch can resume after restart.
        seq = self.db.append_event(payload)
        payload = dict(payload)
        payload["seq"] = seq
        # Rewrite the stored row so replay includes seq (append already stored without it).
        # Cheaper to include seq in the JSON we fan out; replay path also injects seq.
        self._seq = seq
        async with self._lock:
            dead: list[asyncio.Queue[dict[str, Any] | None]] = []
            for queue in self._subs:
                try:
                    queue.put_nowait(payload)
                except asyncio.QueueFull:
                    dead.append(queue)
            for queue in dead:
                self._subs.discard(queue)
        if seq % 200 == 0:
            self.db.prune_events(EVENT_RETAIN)
        return payload

    def subscribe(self, maxsize: int = 256) -> asyncio.Queue[dict[str, Any] | None]:
        queue: asyncio.Queue[dict[str, Any] | None] = asyncio.Queue(maxsize=maxsize)
        self._subs.add(queue)
        return queue

    def unsubscribe(self, queue: asyncio.Queue[dict[str, Any] | None]) -> None:
        self._subs.discard(queue)

    async def stream(
        self,
        *,
        run_id: str | None,
        since: int | None,
        stop_when_terminal: bool,
        already_terminal: bool = False,
    ) -> AsyncIterator[str]:
        """
        Yield SSE lines. With run_id, only that run's events. With since, replay
        stored events after that seq, then follow live. Terminal types end a
        per-run stream.
        """
        terminal = {"done", "cancelled", "error"}
        last = since or 0
        replay = self.db.events_since(last, run_id=run_id)
        ended = already_terminal
        for ev in replay:
            last = max(last, int(ev.get("seq") or 0))
            yield format_sse(ev)
            if stop_when_terminal and ev.get("type") in terminal:
                ended = True
                break
        if ended:
            return

        queue = self.subscribe()
        try:
            # Catch anything persisted between replay and subscribe.
            for ev in self.db.events_since(last, run_id=run_id):
                last = max(last, int(ev.get("seq") or 0))
                yield format_sse(ev)
                if stop_when_terminal and ev.get("type") in terminal:
                    return
            while True:
                try:
                    ev = await asyncio.wait_for(queue.get(), timeout=15.0)
                except TimeoutError:
                    yield ": ping\n\n"
                    continue
                if ev is None:
                    return
                if run_id and ev.get("run_id") and ev.get("run_id") != run_id:
                    continue
                if ev.get("seq") and int(ev["seq"]) <= last:
                    continue
                last = max(last, int(ev.get("seq") or 0))
                yield format_sse(ev)
                if stop_when_terminal and ev.get("type") in terminal:
                    return
        finally:
            self.unsubscribe(queue)
