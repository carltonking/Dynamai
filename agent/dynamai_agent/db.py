# SPDX-License-Identifier: GPL-3.0-or-later
"""SQLite store: events, runs, conversation, notes, routines, approvals."""

from __future__ import annotations

import json
import sqlite3
import threading
import time
from pathlib import Path
from typing import Any, Iterable

from dynamai_agent.config import DB_PATH

_SCHEMA = """
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;

CREATE TABLE IF NOT EXISTS meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS events (
    seq INTEGER PRIMARY KEY AUTOINCREMENT,
    ts REAL NOT NULL,
    run_id TEXT,
    agent_id TEXT,
    type TEXT NOT NULL,
    payload TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS runs (
    run_id TEXT PRIMARY KEY,
    agent_id TEXT NOT NULL,
    run_kind TEXT NOT NULL,
    routine_id TEXT,
    source TEXT,
    prompt TEXT,
    status TEXT NOT NULL,
    error TEXT,
    created_at REAL NOT NULL,
    finished_at REAL
);

CREATE TABLE IF NOT EXISTS messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    agent_id TEXT NOT NULL,
    run_id TEXT,
    role TEXT NOT NULL,
    content TEXT NOT NULL,
    ts REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT,
    content TEXT NOT NULL,
    created_at REAL NOT NULL,
    updated_at REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS routines (
    routine_id TEXT PRIMARY KEY,
    agent_id TEXT NOT NULL,
    name TEXT NOT NULL,
    prompt TEXT NOT NULL,
    schedule TEXT NOT NULL,
    enabled INTEGER NOT NULL DEFAULT 1,
    last_fired_at REAL,
    last_run_id TEXT,
    next_fire_at REAL,
    created_at REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS approvals (
    approval_id TEXT PRIMARY KEY,
    run_id TEXT,
    agent_id TEXT NOT NULL,
    action TEXT,
    target TEXT,
    choices TEXT NOT NULL,
    decision TEXT,
    created_at REAL NOT NULL,
    decided_at REAL
);
"""


class Database:
    def __init__(self, path: Path = DB_PATH) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        self.path = path
        self._lock = threading.Lock()
        self._conn = sqlite3.connect(str(path), check_same_thread=False)
        self._conn.row_factory = sqlite3.Row
        with self._lock:
            self._conn.executescript(_SCHEMA)
            self._conn.commit()
        self._migrate()


    def _migrate(self) -> None:
        """Additive, idempotent schema updates for existing hub databases."""
        cols = {row["name"] for row in self.query("PRAGMA table_info(messages)")}
        if "conversation_id" not in cols:
            self.execute("ALTER TABLE messages ADD COLUMN conversation_id TEXT")
        self.execute(
            "CREATE INDEX IF NOT EXISTS idx_messages_conversation "
            "ON messages(agent_id, conversation_id, id)"
        )

    def close(self) -> None:
        with self._lock:
            self._conn.close()

    @staticmethod
    def _bind(params: Iterable[Any] | dict[str, Any]) -> Iterable[Any] | dict[str, Any]:
        # Named placeholders need a mapping; tuple(dict) would bind the keys as values.
        return params if isinstance(params, dict) else tuple(params)

    def execute(self, sql: str, params: Iterable[Any] | dict[str, Any] = ()) -> sqlite3.Cursor:
        with self._lock:
            cur = self._conn.execute(sql, self._bind(params))
            self._conn.commit()
            return cur

    def query(self, sql: str, params: Iterable[Any] | dict[str, Any] = ()) -> list[sqlite3.Row]:
        with self._lock:
            return list(self._conn.execute(sql, self._bind(params)))

    def query_one(self, sql: str, params: Iterable[Any] | dict[str, Any] = ()) -> sqlite3.Row | None:
        with self._lock:
            return self._conn.execute(sql, self._bind(params)).fetchone()

    # --- events ---

    def append_event(self, payload: dict[str, Any]) -> int:
        run_id = payload.get("run_id")
        agent_id = payload.get("agent_id")
        typ = payload.get("type") or "unknown"
        with self._lock:
            cur = self._conn.execute(
                "INSERT INTO events (ts, run_id, agent_id, type, payload) VALUES (?, ?, ?, ?, ?)",
                (time.time(), run_id, agent_id, typ, json.dumps(payload, ensure_ascii=False)),
            )
            self._conn.commit()
            seq = int(cur.lastrowid)
        return seq

    def events_since(self, since: int, run_id: str | None = None, limit: int = 2000) -> list[dict[str, Any]]:
        if run_id:
            rows = self.query(
                "SELECT seq, payload FROM events WHERE seq > ? AND run_id = ? ORDER BY seq ASC LIMIT ?",
                (since, run_id, limit),
            )
        else:
            rows = self.query(
                "SELECT seq, payload FROM events WHERE seq > ? ORDER BY seq ASC LIMIT ?",
                (since, limit),
            )
        out: list[dict[str, Any]] = []
        for row in rows:
            try:
                obj = json.loads(row["payload"])
            except json.JSONDecodeError:
                continue
            obj["seq"] = row["seq"]
            out.append(obj)
        return out

    def prune_events(self, keep: int) -> None:
        with self._lock:
            row = self._conn.execute("SELECT MAX(seq) AS m FROM events").fetchone()
            if not row or row["m"] is None:
                return
            cutoff = int(row["m"]) - keep
            if cutoff > 0:
                self._conn.execute("DELETE FROM events WHERE seq <= ?", (cutoff,))
                self._conn.commit()

    def last_seq(self) -> int:
        row = self.query_one("SELECT MAX(seq) AS m FROM events")
        return int(row["m"] or 0) if row else 0

    # --- runs ---

    def insert_run(
        self,
        run_id: str,
        agent_id: str,
        run_kind: str,
        prompt: str,
        routine_id: str | None = None,
        source: str | None = None,
    ) -> None:
        self.execute(
            """INSERT INTO runs (run_id, agent_id, run_kind, routine_id, source, prompt, status, created_at)
               VALUES (?, ?, ?, ?, ?, ?, 'queued', ?)""",
            (run_id, agent_id, run_kind, routine_id, source, prompt, time.time()),
        )

    def set_run_status(self, run_id: str, status: str, error: str | None = None) -> None:
        finished = time.time() if status in {"done", "cancelled", "error"} else None
        self.execute(
            "UPDATE runs SET status = ?, error = ?, finished_at = COALESCE(?, finished_at) WHERE run_id = ?",
            (status, error, finished, run_id),
        )

    def get_run(self, run_id: str) -> sqlite3.Row | None:
        return self.query_one("SELECT * FROM runs WHERE run_id = ?", (run_id,))

    # --- messages / notes ---

    def add_message(
        self,
        agent_id: str,
        role: str,
        content: str,
        run_id: str | None = None,
        conversation_id: str | None = None,
    ) -> None:
        self.execute(
            """INSERT INTO messages (agent_id, run_id, role, content, ts, conversation_id)
               VALUES (?, ?, ?, ?, ?, ?)""",
            (agent_id, run_id, role, content, time.time(), conversation_id),
        )

    def recent_messages(
        self,
        agent_id: str,
        limit: int,
        conversation_id: str | None = None,
    ) -> list[sqlite3.Row]:
        # A missing conversation_id is the island/default thread. Channel
        # conversations (e.g. iMessage per sender) are stored separately.
        if conversation_id:
            rows = self.query(
                """SELECT role, content, ts FROM messages
                   WHERE agent_id = ? AND conversation_id = ?
                   ORDER BY id DESC LIMIT ?""",
                (agent_id, conversation_id, limit),
            )
        else:
            rows = self.query(
                """SELECT role, content, ts FROM messages
                   WHERE agent_id = ? AND conversation_id IS NULL
                   ORDER BY id DESC LIMIT ?""",
                (agent_id, limit),
            )
        return list(reversed(rows))

    def add_note(self, content: str, title: str | None = None) -> int:
        now = time.time()
        cur = self.execute(
            "INSERT INTO notes (title, content, created_at, updated_at) VALUES (?, ?, ?, ?)",
            (title, content, now, now),
        )
        return int(cur.lastrowid)

    def search_notes(self, query: str, limit: int = 12) -> list[sqlite3.Row]:
        like = f"%{query}%"
        return self.query(
            """SELECT id, title, content, created_at, updated_at FROM notes
               WHERE content LIKE ? OR IFNULL(title, '') LIKE ?
               ORDER BY updated_at DESC LIMIT ?""",
            (like, like, limit),
        )

    def recent_notes(self, limit: int = 12) -> list[sqlite3.Row]:
        return self.query(
            "SELECT id, title, content, created_at, updated_at FROM notes ORDER BY updated_at DESC LIMIT ?",
            (limit,),
        )

    def delete_note(self, note_id: int) -> bool:
        cur = self.execute("DELETE FROM notes WHERE id = ?", (note_id,))
        return cur.rowcount > 0

    # --- routines ---

    def upsert_routine(self, rec: dict[str, Any]) -> None:
        self.execute(
            """INSERT INTO routines (routine_id, agent_id, name, prompt, schedule, enabled, last_fired_at,
                                     last_run_id, next_fire_at, created_at)
               VALUES (:routine_id, :agent_id, :name, :prompt, :schedule, :enabled, :last_fired_at,
                       :last_run_id, :next_fire_at, :created_at)
               ON CONFLICT(routine_id) DO UPDATE SET
                   name=excluded.name, prompt=excluded.prompt, schedule=excluded.schedule,
                   enabled=excluded.enabled, next_fire_at=excluded.next_fire_at""",
            rec,
        )

    def list_routines(self, agent_id: str | None = None) -> list[sqlite3.Row]:
        if agent_id:
            return self.query("SELECT * FROM routines WHERE agent_id = ? ORDER BY created_at ASC", (agent_id,))
        return self.query("SELECT * FROM routines ORDER BY created_at ASC")

    def get_routine(self, routine_id: str) -> sqlite3.Row | None:
        return self.query_one("SELECT * FROM routines WHERE routine_id = ?", (routine_id,))

    def due_routines(self, now: float) -> list[sqlite3.Row]:
        return self.query(
            "SELECT * FROM routines WHERE enabled = 1 AND next_fire_at IS NOT NULL AND next_fire_at <= ?",
            (now,),
        )

    def mark_routine_fired(self, routine_id: str, run_id: str, next_fire_at: float | None) -> None:
        enabled = 0 if next_fire_at is None else 1
        self.execute(
            """UPDATE routines SET last_fired_at = ?, last_run_id = ?, next_fire_at = ?, enabled = ?
               WHERE routine_id = ?""",
            (time.time(), run_id, next_fire_at, enabled, routine_id),
        )

    def delete_routine(self, routine_id: str) -> bool:
        cur = self.execute("DELETE FROM routines WHERE routine_id = ?", (routine_id,))
        return cur.rowcount > 0

    # --- approvals ---

    def insert_approval(
        self,
        approval_id: str,
        run_id: str,
        agent_id: str,
        action: str,
        target: str,
        choices: list[str],
    ) -> None:
        self.execute(
            """INSERT INTO approvals (approval_id, run_id, agent_id, action, target, choices, created_at)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (approval_id, run_id, agent_id, action, target, json.dumps(choices), time.time()),
        )

    def pending_approvals(self, agent_id: str, limit: int) -> list[sqlite3.Row]:
        return self.query(
            """SELECT * FROM approvals WHERE agent_id = ? AND decision IS NULL
               ORDER BY created_at DESC LIMIT ?""",
            (agent_id, limit),
        )

    def get_approval(self, approval_id: str) -> sqlite3.Row | None:
        return self.query_one("SELECT * FROM approvals WHERE approval_id = ?", (approval_id,))

    def decide_approval(self, approval_id: str, decision: str) -> None:
        self.execute(
            "UPDATE approvals SET decision = ?, decided_at = ? WHERE approval_id = ?",
            (decision, time.time(), approval_id),
        )
