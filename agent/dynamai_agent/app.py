# SPDX-License-Identifier: GPL-3.0-or-later
"""FastAPI surface matching Dynamai's NotchVertusHubClient."""

from __future__ import annotations

import json
import logging
import time
import uuid
from contextlib import asynccontextmanager
from typing import Any

from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import BaseModel, Field

from dynamai_agent import __version__
from dynamai_agent.auth import check_approver, ensure_tokens, require_bearer
from dynamai_agent.channels.sendblue import SendblueChannel
from dynamai_agent.config import AGENT_ID, AGENT_NAME, DATA_DIR, MODEL, WORKSPACE, sendblue_configured
from dynamai_agent.db import Database
from dynamai_agent.engine import Engine
from dynamai_agent.events import EventBus
from dynamai_agent.scheduler import Scheduler, parse_schedule

log = logging.getLogger("dynamai_agent")
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")


class PromptBody(BaseModel):
    text: str
    agent_id: str = AGENT_ID


class ApprovalBody(BaseModel):
    choice: str


class RoutineBody(BaseModel):
    name: str
    prompt: str
    agent_id: str = AGENT_ID
    every_seconds: float | None = None
    once_after_seconds: float | None = None
    cron: str | None = None
    enabled: bool = True


db: Database
bus: EventBus
engine: Engine
scheduler: Scheduler


@asynccontextmanager
async def lifespan(_app: FastAPI):
    global db, bus, engine, scheduler
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    WORKSPACE.mkdir(parents=True, exist_ok=True)
    ensure_tokens()
    db = Database()
    bus = EventBus(db)
    engine = Engine(db, bus)
    scheduler = Scheduler(db, engine.start_run)
    scheduler.start()
    log.info("hub ready model=%s data=%s", MODEL, DATA_DIR)
    try:
        yield
    finally:
        await scheduler.stop()
        db.close()


app = FastAPI(title="Dynamai Agent Hub", version=__version__, lifespan=lifespan)


def _error(status: int, message: str) -> JSONResponse:
    return JSONResponse({"error": message}, status_code=status)


@app.get("/health")
async def health() -> dict[str, Any]:
    return {"ok": True, "agent": AGENT_NAME, "model": MODEL, "version": __version__}


@app.get("/api/agents")
async def list_agents(_auth: str = Depends(require_bearer)) -> dict[str, Any]:
    return {"agents": [{"id": AGENT_ID, "model": MODEL, "name": AGENT_NAME}]}


@app.post("/api/prompt")
async def prompt(body: PromptBody, _auth: str = Depends(require_bearer)) -> JSONResponse:
    text = body.text.strip()
    if not text:
        return _error(400, "text is required")
    try:
        run_id = await engine.start_run(text=text, agent_id=body.agent_id, run_kind="user")
    except ValueError as exc:
        return _error(400, str(exc))
    return JSONResponse({"accepted": True, "run_id": run_id}, status_code=202)


@app.get("/api/events")
async def events(
    request: Request,
    run_id: str | None = Query(default=None),
    since: int | None = Query(default=None),
    _auth: str = Depends(require_bearer),
) -> StreamingResponse:
    already = False
    if run_id:
        run = db.get_run(run_id)
        if run is None:
            return _error(404, f"run not found: {run_id}")
        already = run["status"] in {"done", "cancelled", "error"} and since is not None
        # A finished run still replays; the stream ends after the terminal event.
        already = False
    stream = bus.stream(
        run_id=run_id,
        since=since,
        stop_when_terminal=bool(run_id),
    )
    return StreamingResponse(
        stream,
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache, no-transform",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@app.get("/api/runs/{run_id}")
async def get_run(run_id: str, _auth: str = Depends(require_bearer)) -> Any:
    run = db.get_run(run_id)
    if run is None:
        return _error(404, f"run not found: {run_id}")
    return {
        "run": {
            "run_id": run["run_id"],
            "agent_id": run["agent_id"],
            "run_kind": run["run_kind"],
            "routine_id": run["routine_id"],
            "source": run["source"],
            "status": run["status"],
            "error": run["error"],
            "created_at": run["created_at"],
            "finished_at": run["finished_at"],
        }
    }


@app.post("/api/runs/{run_id}/cancel")
async def cancel_run(run_id: str, _auth: str = Depends(require_bearer)) -> Any:
    if not engine.cancel(run_id):
        run = db.get_run(run_id)
        if run is None:
            return _error(404, f"run not found: {run_id}")
        return {"ok": True, "status": run["status"]}
    return {"ok": True, "status": "cancelling"}


@app.get("/api/approvals")
async def list_approvals(
    state: str = Query(default="pending"),
    limit: int = Query(default=50, ge=1, le=200),
    _auth: str = Depends(require_bearer),
) -> dict[str, Any]:
    if state != "pending":
        return {"approvals": []}
    rows = db.pending_approvals(AGENT_ID, limit)
    approvals = []
    for row in rows:
        approvals.append(
            {
                "approval_id": row["approval_id"],
                "agent_id": row["agent_id"],
                "run_id": row["run_id"],
                "action": row["action"],
                "target": row["target"],
                "decision": row["decision"],
            }
        )
    return {"approvals": approvals}


@app.post("/api/approvals/{approval_id}")
async def answer_approval(
    approval_id: str,
    body: ApprovalBody,
    _auth: str = Depends(require_bearer),
    x_vertus_approver: str | None = Header(default=None, alias="X-Vertus-Approver"),
) -> Any:
    if not check_approver(x_vertus_approver):
        return _error(401, "missing or invalid approver token")
    choice = body.choice.strip()
    if not choice:
        return _error(400, "choice is required")
    result = engine.resolve_approval(approval_id, choice)
    if result is None:
        return _error(404, f"approval not found: {approval_id}")
    if result != "pending":
        return JSONResponse({"error": f"approval already settled: {result}"}, status_code=409)
    return {"ok": True, "decision": choice}


@app.get("/api/routines")
async def list_routines(
    agent_id: str | None = Query(default=None),
    _auth: str = Depends(require_bearer),
) -> dict[str, Any]:
    rows = db.list_routines(agent_id or AGENT_ID)
    routines = []
    for row in rows:
        item = {
            "routine_id": row["routine_id"],
            "agent_id": row["agent_id"],
            "name": row["name"],
            "prompt": row["prompt"],
            "enabled": bool(row["enabled"]),
            "last_fired_at": row["last_fired_at"],
            "last_run_id": row["last_run_id"],
            "next_fire_at": row["next_fire_at"],
        }
        try:
            item["schedule"] = json.loads(row["schedule"])
        except json.JSONDecodeError:
            item["schedule"] = row["schedule"]
        routines.append(item)
    return {"routines": routines}


@app.post("/api/routines")
async def create_routine(body: RoutineBody, _auth: str = Depends(require_bearer)) -> Any:
    if body.agent_id != AGENT_ID:
        return _error(400, f"unknown agent: {body.agent_id}")
    try:
        if body.once_after_seconds is not None:
            spec: dict[str, Any] = {"once_after_seconds": body.once_after_seconds}
        elif body.every_seconds is not None:
            spec = {"every_seconds": body.every_seconds}
        elif body.cron:
            spec = {"cron": body.cron}
        else:
            return _error(400, "provide once_after_seconds, every_seconds, or cron")
        parsed = parse_schedule(spec)
    except ValueError as exc:
        return _error(400, str(exc))
    routine_id = uuid.uuid4().hex[:12]
    now = time.time()
    db.upsert_routine(
        {
            "routine_id": routine_id,
            "agent_id": body.agent_id,
            "name": body.name.strip() or "Untitled",
            "prompt": body.prompt,
            "schedule": json.dumps(parsed),
            "enabled": 1 if body.enabled else 0,
            "last_fired_at": None,
            "last_run_id": None,
            "next_fire_at": parsed["next"] if body.enabled else None,
            "created_at": now,
        }
    )
    return {"routine_id": routine_id, "name": body.name, "next_fire_at": parsed["next"], "schedule": parsed}


@app.post("/api/routines/{routine_id}/run")
async def run_routine_now(routine_id: str, _auth: str = Depends(require_bearer)) -> Any:
    row = db.get_routine(routine_id)
    if row is None:
        return _error(404, f"routine not found: {routine_id}")
    run_id = await engine.start_run(
        text=row["prompt"],
        agent_id=row["agent_id"],
        run_kind="routine",
        routine_id=routine_id,
        source="manual",
    )
    return JSONResponse({"accepted": True, "run_id": run_id, "routine_id": routine_id}, status_code=202)


@app.delete("/api/routines/{routine_id}")
async def delete_routine(routine_id: str, _auth: str = Depends(require_bearer)) -> Any:
    if not db.delete_routine(routine_id):
        return _error(404, f"routine not found: {routine_id}")
    return {"ok": True}


@app.post("/hooks/sendblue")
async def sendblue_hook(request: Request) -> Any:
    """Inbound iMessage webhook. Disabled until Sendblue env vars are set."""
    if not sendblue_configured():
        return _error(503, "Sendblue is not configured")
    adapter = SendblueChannel()
    body = await request.body()
    headers = {k.lower(): v for k, v in request.headers.items()}
    inbound = adapter.parse_webhook(headers, body)
    if inbound is None:
        return {"ok": True, "ignored": True}
    run_id = await engine.start_run(
        text=inbound.text,
        run_kind="user",
        channel="sendblue",
        reply_to=inbound.sender,
        source="sendblue",
    )
    return JSONResponse({"accepted": True, "run_id": run_id}, status_code=202)
