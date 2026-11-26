# SPDX-License-Identifier: GPL-3.0-or-later
"""Cron-style routines stored in SQLite; due jobs start a prompt run."""

from __future__ import annotations

import asyncio
import json
import time
from datetime import datetime, timezone
from typing import TYPE_CHECKING, Any, Callable, Awaitable

from dynamai_agent.db import Database

if TYPE_CHECKING:
    from dynamai_agent.engine import Engine

StartRun = Callable[..., Awaitable[str]]


def parse_schedule(spec: dict[str, Any], now: float | None = None) -> dict[str, Any]:
    """Normalize a schedule dict and compute the next fire time."""
    now = time.time() if now is None else now
    if "once_after_seconds" in spec:
        seconds = max(0, float(spec["once_after_seconds"]))
        return {"kind": "once", "after": seconds, "next": now + seconds}
    if "every_seconds" in spec:
        seconds = max(1, float(spec["every_seconds"]))
        return {"kind": "interval", "every": seconds, "next": now + seconds}
    if "cron" in spec:
        expr = str(spec["cron"]).strip()
        nxt = next_cron(expr, now)
        return {"kind": "cron", "cron": expr, "next": nxt}
    raise ValueError("schedule must include once_after_seconds, every_seconds, or cron")


def next_from_existing(schedule: dict[str, Any], now: float) -> float | None:
    kind = schedule.get("kind")
    if kind == "once":
        return None
    if kind == "interval":
        return now + float(schedule["every"])
    if kind == "cron":
        return next_cron(str(schedule["cron"]), now)
    return None


def next_cron(expr: str, now: float) -> float:
    """Next fire after `now` for a 5-field cron (min hour dom mon dow), in UTC."""
    parts = expr.split()
    if len(parts) != 5:
        raise ValueError("cron must have 5 fields: min hour day month weekday")
    fields = [_cron_field(p, lo, hi) for p, (lo, hi) in zip(parts, ((0, 59), (0, 23), (1, 31), (1, 12), (0, 6)))]
    # Walk minute by minute, cap at 366 days.
    t = datetime.fromtimestamp(now, tz=timezone.utc).replace(second=0, microsecond=0)
    from datetime import timedelta

    cursor = t + timedelta(minutes=1)
    deadline = cursor + timedelta(days=366)
    while cursor <= deadline:
        if (
            cursor.minute in fields[0]
            and cursor.hour in fields[1]
            and cursor.day in fields[2]
            and cursor.month in fields[3]
            and cursor.weekday() in _cron_weekday(fields[4])  # Monday=0 in datetime
        ):
            return cursor.timestamp()
        cursor += timedelta(minutes=1)
    raise ValueError(f"no upcoming time for cron {expr!r}")


def _cron_weekday(allowed: set[int]) -> set[int]:
    # Cron weekday 0 = Sunday, 1 = Monday ... 6 = Saturday.
    # datetime.weekday() is Monday=0 ... Sunday=6.
    out = set()
    for d in allowed:
        out.add(6 if d == 0 else d - 1)
    return out


def _cron_field(token: str, lo: int, hi: int) -> set[int]:
    values: set[int] = set()
    for chunk in token.split(","):
        chunk = chunk.strip()
        if chunk == "*":
            values.update(range(lo, hi + 1))
            continue
        step = 1
        if "/" in chunk:
            chunk, step_s = chunk.split("/", 1)
            step = int(step_s)
        if chunk == "*":
            start, end = lo, hi
        elif "-" in chunk:
            a, b = chunk.split("-", 1)
            start, end = int(a), int(b)
        else:
            start = end = int(chunk)
        values.update(range(start, end + 1, step))
    return {v for v in values if lo <= v <= hi}


class Scheduler:
    def __init__(self, db: Database, start_run: StartRun) -> None:
        self.db = db
        self.start_run = start_run
        self._task: asyncio.Task[None] | None = None
        self._stop = asyncio.Event()

    def start(self) -> None:
        if self._task is None or self._task.done():
            self._stop.clear()
            self._task = asyncio.create_task(self._loop(), name="routines")

    async def stop(self) -> None:
        self._stop.set()
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
            self._task = None

    async def _loop(self) -> None:
        while not self._stop.is_set():
            try:
                await self.tick()
            except Exception:
                # Never let a bad routine kill the scheduler.
                pass
            try:
                await asyncio.wait_for(self._stop.wait(), timeout=1.0)
            except TimeoutError:
                continue

    async def tick(self, now: float | None = None) -> list[str]:
        now = time.time() if now is None else now
        started: list[str] = []
        for row in self.db.due_routines(now):
            schedule = json.loads(row["schedule"])
            run_id = await self.start_run(
                text=row["prompt"],
                agent_id=row["agent_id"],
                run_kind="routine",
                routine_id=row["routine_id"],
                source=f"routine:{row['routine_id']}",
            )
            started.append(run_id)
            nxt = next_from_existing(schedule, now)
            self.db.mark_routine_fired(row["routine_id"], run_id, nxt)
        return started
