# SPDX-License-Identifier: GPL-3.0-or-later
"""Run manager: queue a prompt, stream Anthropic tool-use turns as Vertus events."""

from __future__ import annotations

import asyncio
import logging
import uuid
from typing import Any

import anthropic

from dynamai_agent import tools as toolset
from dynamai_agent.config import (
    AGENT_ID,
    AGENT_NAME,
    APPROVAL_TIMEOUT,
    HISTORY_TURNS,
    MODEL,
    anthropic_api_key,
)
from dynamai_agent.db import Database
from dynamai_agent.events import EventBus
from dynamai_agent.tools import shell as shell_tool

log = logging.getLogger("dynamai_agent")

SYSTEM = f"""You are {AGENT_NAME}, Carlton's personal agent. You run on an Ubuntu VM
in Oracle Cloud (Always Free). You can use tools to inspect the machine, search
and fetch the web, and store lasting facts.

Guidelines:
- Be concise and direct. Prefer a short useful answer over a long one.
- For questions about this machine (hostname, memory, disk, processes), use the shell tool.
- When the user asks you to remember something, call the remember tool with a clear sentence.
- When asked about something they told you earlier, call recall. You may also use recent chat.
- Do not print API keys, tokens, passwords, or the contents of environment files.
- The browser tool is a stub on this VM (not enough RAM for Chromium); use web_fetch instead.
- If a tool fails, say so briefly and try another approach when one exists.
"""


class Engine:
    def __init__(self, db: Database, bus: EventBus) -> None:
        self.db = db
        self.bus = bus
        self._handlers = toolset.handlers(db)
        self._cancel: set[str] = set()
        self._approvals: dict[str, asyncio.Future[str]] = {}
        self._tasks: dict[str, asyncio.Task[None]] = {}
        self._client: anthropic.AsyncAnthropic | None = None

    def _anthropic(self) -> anthropic.AsyncAnthropic:
        if self._client is None:
            self._client = anthropic.AsyncAnthropic(api_key=anthropic_api_key())
        return self._client

    def is_cancelled(self, run_id: str) -> bool:
        return run_id in self._cancel

    def cancel(self, run_id: str) -> bool:
        run = self.db.get_run(run_id)
        if run is None:
            return False
        if run["status"] in {"done", "cancelled", "error"}:
            return False
        self._cancel.add(run_id)
        task = self._tasks.get(run_id)
        if task and not task.done():
            task.cancel()
        return True

    def resolve_approval(self, approval_id: str, decision: str) -> str | None:
        """
        Returns None if the id is unknown, 'pending' if it was waiting,
        or the existing decision if already settled.
        """
        row = self.db.get_approval(approval_id)
        if row is None:
            return None
        if row["decision"]:
            return str(row["decision"])
        self.db.decide_approval(approval_id, decision)
        fut = self._approvals.get(approval_id)
        if fut and not fut.done():
            fut.set_result(decision)
        return "pending"

    async def start_run(
        self,
        *,
        text: str,
        agent_id: str = AGENT_ID,
        run_kind: str = "user",
        routine_id: str | None = None,
        source: str | None = None,
        channel: str | None = None,
        reply_to: str | None = None,
    ) -> str:
        if agent_id != AGENT_ID:
            raise ValueError(f"unknown agent: {agent_id}")
        run_id = uuid.uuid4().hex[:16]
        self.db.insert_run(run_id, agent_id, run_kind, text, routine_id=routine_id, source=source)
        if run_kind == "user":
            self.db.add_message(agent_id, "user", text, run_id=run_id)
        if run_kind == "routine":
            await self.bus.publish(
                {
                    "type": "routine_fired",
                    "routine_id": routine_id,
                    "agent_id": agent_id,
                    "run_id": run_id,
                    "manual": source == "manual",
                }
            )
        task = asyncio.create_task(
            self._execute(run_id, text, agent_id, run_kind, channel, reply_to),
            name=f"run-{run_id}",
        )
        self._tasks[run_id] = task
        task.add_done_callback(lambda _t: self._tasks.pop(run_id, None))
        return run_id

    async def emit(self, run_id: str, typ: str, **fields: Any) -> None:
        payload = {"type": typ, "run_id": run_id, "agent_id": AGENT_ID}
        payload.update(fields)
        await self.bus.publish(payload)

    async def _execute(
        self,
        run_id: str,
        text: str,
        agent_id: str,
        run_kind: str,
        channel: str | None,
        reply_to: str | None,
    ) -> None:
        self.db.set_run_status(run_id, "running")
        collected: list[str] = []
        try:
            await self.emit(run_id, "activity", text="thinking…")
            messages = self._history(agent_id, text, run_kind)
            client = self._anthropic()
            while not self.is_cancelled(run_id):
                try:
                    async with client.messages.stream(
                        model=MODEL,
                        max_tokens=4096,
                        system=SYSTEM,
                        tools=toolset.schemas(),
                        messages=messages,
                    ) as stream:
                        async for chunk in stream.text_stream:
                            if self.is_cancelled(run_id):
                                break
                            if chunk:
                                collected.append(chunk)
                                await self.emit(run_id, "text", text=chunk)
                        final = await stream.get_final_message()
                except asyncio.CancelledError:
                    raise
                except anthropic.APIError as exc:
                    # Don't include request bodies or headers; the message is enough.
                    await self.emit(run_id, "error", message=str(exc)[:500] or "Anthropic API error")
                    self.db.set_run_status(run_id, "error", error=str(exc)[:500])
                    return

                if self.is_cancelled(run_id):
                    break

                tool_uses = [b for b in final.content if b.type == "tool_use"]
                # If the stream didn't emit text events (some SDK versions only finalize),
                # emit any leftover text blocks once.
                if not collected:
                    for block in final.content:
                        if block.type == "text" and block.text:
                            collected.append(block.text)
                            await self.emit(run_id, "text", text=block.text)

                if not tool_uses or final.stop_reason != "tool_use":
                    break

                messages.append({"role": "assistant", "content": _content_for_history(final)})
                results: list[dict[str, Any]] = []
                for block in tool_uses:
                    if self.is_cancelled(run_id):
                        break
                    name = block.name
                    args = block.input if isinstance(block.input, dict) else {}
                    await self.emit(run_id, "activity", text=f"running {name}…")
                    output = await self._call_tool(run_id, name, args)
                    results.append(
                        {
                            "type": "tool_result",
                            "tool_use_id": block.id,
                            "content": output,
                        }
                    )
                messages.append({"role": "user", "content": results})

            if self.is_cancelled(run_id):
                await self.emit(run_id, "cancelled")
                self.db.set_run_status(run_id, "cancelled")
                return

            reply = "".join(collected).strip()
            if reply:
                self.db.add_message(agent_id, "assistant", reply, run_id=run_id)
            await self.emit(run_id, "done")
            self.db.set_run_status(run_id, "done")
            if channel and reply_to and reply:
                await self._channel_reply(channel, reply_to, reply)
        except asyncio.CancelledError:
            if self.is_cancelled(run_id):
                await self.emit(run_id, "cancelled")
                self.db.set_run_status(run_id, "cancelled")
            else:
                await self.emit(run_id, "cancelled")
                self.db.set_run_status(run_id, "cancelled")
        except Exception as exc:
            log.exception("run failed")
            await self.emit(run_id, "error", message=type(exc).__name__)
            self.db.set_run_status(run_id, "error", error=type(exc).__name__)
        finally:
            self._cancel.discard(run_id)

    def _history(self, agent_id: str, text: str, run_kind: str) -> list[dict[str, Any]]:
        rows = self.db.recent_messages(agent_id, HISTORY_TURNS * 2)
        # The current user prompt was just stored for user runs; keep it as the last turn.
        messages: list[dict[str, Any]] = []
        for row in rows:
            role = row["role"]
            if role not in {"user", "assistant"}:
                continue
            content = row["content"]
            if not content:
                continue
            # Skip the message we just inserted; we append it below so it is definitely last.
            messages.append({"role": role, "content": content})
        if run_kind == "user":
            if not messages or messages[-1] != {"role": "user", "content": text}:
                messages.append({"role": "user", "content": text})
        else:
            messages.append(
                {
                    "role": "user",
                    "content": (
                        f"[Scheduled routine] {text}\n"
                        "If there is nothing useful to say, reply with exactly NOTHING_TO_REPORT."
                    ),
                }
            )
        # Bound the context we send: last HISTORY_TURNS user/assistant pairs, ending on user.
        if len(messages) > HISTORY_TURNS * 2:
            messages = messages[-(HISTORY_TURNS * 2) :]
        if messages and messages[0]["role"] != "user":
            messages = messages[1:]
        return messages

    async def _call_tool(self, run_id: str, name: str, args: dict[str, Any]) -> str:
        handler = self._handlers.get(name)
        if handler is None:
            return f"error: unknown tool {name}"
        if name == "shell":
            command = str(args.get("command") or "")
            if shell_tool.needs_approval(command):
                allowed = await self._ask_approval(run_id, *shell_tool.describe(command))
                if not allowed:
                    return "error: the user denied this command"
        try:
            return await handler(args)
        except Exception as exc:
            return f"error: {type(exc).__name__}: {exc}"

    async def _ask_approval(self, run_id: str, action: str, target: str) -> bool:
        approval_id = uuid.uuid4().hex[:16]
        choices = ["once", "deny"]
        self.db.insert_approval(approval_id, run_id, AGENT_ID, action, target, choices)
        loop = asyncio.get_running_loop()
        fut: asyncio.Future[str] = loop.create_future()
        self._approvals[approval_id] = fut
        await self.emit(
            run_id,
            "approval_request",
            approval_id=approval_id,
            description=action,
            command=target,
            choices=choices,
        )
        try:
            decision = await asyncio.wait_for(asyncio.shield(fut), timeout=APPROVAL_TIMEOUT)
        except TimeoutError:
            decision = "expired"
            if not self.db.get_approval(approval_id)["decision"]:
                self.db.decide_approval(approval_id, decision)
        finally:
            self._approvals.pop(approval_id, None)
        await self.emit(run_id, "approval_resolved", approval_id=approval_id, decision=decision)
        return decision in {"once", "session", "always", "allow"}

    async def _channel_reply(self, channel: str, to: str, text: str) -> None:
        from dynamai_agent.channels.sendblue import SendblueChannel

        if channel != "sendblue":
            return
        adapter = SendblueChannel()
        if not adapter.enabled:
            return
        try:
            await adapter.send(to, text)
        except Exception:
            log.exception("channel reply failed")


def _content_for_history(message: Any) -> list[dict[str, Any]]:
    """Round-trip Anthropic content blocks without SDK-only fields."""
    out: list[dict[str, Any]] = []
    for block in message.content:
        if block.type == "text":
            out.append({"type": "text", "text": block.text})
        elif block.type == "tool_use":
            out.append({"type": "tool_use", "id": block.id, "name": block.name, "input": block.input})
    return out
