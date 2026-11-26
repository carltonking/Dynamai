#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Talk to a running hub. Token is read from a file, never printed."""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


def _load_token(path: Path) -> str:
    token = path.read_text(encoding="utf-8").strip()
    if not token:
        raise SystemExit(f"empty token file: {path}")
    return token


def _request(base: str, token: str, method: str, path: str, body: dict | None = None, timeout: float = 30):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        base + path,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read()
            return resp.status, json.loads(raw.decode()) if raw else {}
    except urllib.error.HTTPError as exc:
        raw = exc.read()
        try:
            parsed = json.loads(raw.decode()) if raw else {}
        except json.JSONDecodeError:
            parsed = {"error": raw.decode(errors="replace")}
        return exc.code, parsed


def _stream(base: str, token: str, path: str, timeout: float = 180) -> list[dict]:
    req = urllib.request.Request(
        base + path,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "text/event-stream",
        },
    )
    events: list[dict] = []
    start = time.time()
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        buf = b""
        while True:
            chunk = resp.read(256)
            if not chunk:
                break
            buf += chunk
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                text = line.decode("utf-8", errors="replace").strip("\r")
                if not text.startswith("data:"):
                    continue
                payload = text[5:].strip()
                if not payload:
                    continue
                try:
                    ev = json.loads(payload)
                except json.JSONDecodeError:
                    continue
                events.append(ev)
                typ = ev.get("type")
                if typ in {"done", "cancelled", "error"}:
                    return events
            if time.time() - start > timeout:
                break
    return events


def _text_of(events: list[dict]) -> str:
    return "".join(ev.get("text", "") for ev in events if ev.get("type") == "text")


def _errors_of(events: list[dict]) -> list[str]:
    return [ev.get("message") or ev.get("type") for ev in events if ev.get("type") == "error"]


def _tools_of(events: list[dict]) -> list[str]:
    names = []
    for ev in events:
        if ev.get("type") == "activity":
            t = ev.get("text") or ""
            if t.startswith("running "):
                names.append(t[len("running "):].strip("…. "))
    return names


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="http://127.0.0.1:8787")
    parser.add_argument("--token-file", required=True)
    args = parser.parse_args()
    token = _load_token(Path(args.token_file))
    base = args.base.rstrip("/")

    status, health = _request(base, token, "GET", "/health")
    print(f"health {status} ok={health.get('ok')} model={health.get('model')}")

    prompt = "What's the VM's hostname and free memory? Then remember that my name is Carlton."
    status, body = _request(base, token, "POST", "/api/prompt", {"text": prompt, "agent_id": "primary"})
    print(f"prompt1 {status} run_id={body.get('run_id')}")
    if status >= 300 or not body.get("run_id"):
        print("prompt failed:", body)
        return 1
    evs = _stream(base, token, f"/api/events?run_id={body['run_id']}")
    reply = _text_of(evs)
    tools = _tools_of(evs)
    terminal = evs[-1]["type"] if evs else "none"
    print(f"prompt1 tools={tools} terminal={terminal} errors={_errors_of(evs)}")
    print("--- prompt1 reply ---")
    print(reply)
    print("--- end ---")

    status, body2 = _request(
        base, token, "POST", "/api/prompt",
        {"text": "What is my name?", "agent_id": "primary"},
    )
    print(f"prompt2 {status} run_id={body2.get('run_id')}")
    evs2 = _stream(base, token, f"/api/events?run_id={body2['run_id']}")
    reply2 = _text_of(evs2)
    tools2 = _tools_of(evs2)
    terminal2 = evs2[-1]["type"] if evs2 else "none"
    print(f"prompt2 tools={tools2} terminal={terminal2} errors={_errors_of(evs2)}")
    print("--- prompt2 reply ---")
    print(reply2)
    print("--- end ---")

    status, routine = _request(
        base, token, "POST", "/api/routines",
        {
            "name": "v1 smoke",
            "prompt": "Reply with exactly: routine-ok",
            "once_after_seconds": 4,
            "agent_id": "primary",
        },
    )
    print(f"routine create {status} id={routine.get('routine_id')} next={routine.get('next_fire_at')}")
    if status >= 300:
        print("routine failed:", routine)
        return 1

    # Watch the fleet stream until routine_fired (and then that run's done).
    fired = None
    deadline = time.time() + 45
    while time.time() < deadline and fired is None:
        since = 0
        # Short fleet poll via /api/routines last_run_id rather than a long SSE,
        # so this script stays simple if the routine already fired.
        time.sleep(2)
        st, listing = _request(base, token, "GET", f"/api/routines?agent_id=primary")
        for row in listing.get("routines", []):
            if row.get("routine_id") == routine.get("routine_id") and row.get("last_run_id"):
                fired = row["last_run_id"]
                break
    if not fired:
        print("routine did not fire within 45s")
        return 1
    evs3 = _stream(base, token, f"/api/events?run_id={fired}")
    reply3 = _text_of(evs3)
    print(f"routine fired run_id={fired} terminal={evs3[-1]['type'] if evs3 else 'none'}")
    print("--- routine reply ---")
    print(reply3)
    print("--- end ---")

    ok_name = "carlton" in reply2.lower()
    used_shell = "shell" in tools
    used_memory = any(t in tools for t in ("remember", "recall")) or any(t in tools2 for t in ("remember", "recall"))
    print(f"checks: shell={used_shell} name_recalled={ok_name} memory_tool={used_memory} routine_fired=True")
    return 0 if (used_shell and ok_name) else 1


if __name__ == "__main__":
    sys.exit(main())
