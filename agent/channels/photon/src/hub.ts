// SPDX-License-Identifier: GPL-3.0-or-later
/** Talk to the local Dynamai hub: POST /api/prompt, then collect SSE text. */

export type HubEvent = {
  type?: string;
  text?: string;
  message?: string;
  run_id?: string;
  approval_id?: string;
  description?: string;
  command?: string;
  decision?: string;
};

export class HubError extends Error {
  constructor(
    message: string,
    readonly kind: "unreachable" | "http" | "error" | "timeout" | "cancelled",
  ) {
    super(message);
    this.name = "HubError";
  }
}

function requiredEnv(name: string, fallback?: string): string {
  const value = (process.env[name] ?? fallback ?? "").trim();
  if (!value) {
    throw new Error(`missing ${name}`);
  }
  return value;
}

export function hubConfig(): { url: string; tokenFile: string; timeoutMs: number } {
  return {
    url: requiredEnv("DYNAMAI_HUB_URL", "http://127.0.0.1:8787").replace(/\/$/, ""),
    tokenFile: requiredEnv("DYNAMAI_TOKEN_FILE", "/var/lib/dynamai-agent/.vertus/token"),
    timeoutMs: Number(process.env.DYNAMAI_HUB_TIMEOUT_MS ?? 480_000),
  };
}

async function bearerToken(tokenFile: string): Promise<string> {
  const token = (await Bun.file(tokenFile).text()).trim();
  if (!token) throw new HubError("hub token file is empty", "http");
  return token;
}

export async function hubHealthy(url: string): Promise<boolean> {
  try {
    const res = await fetch(`${url}/health`, { signal: AbortSignal.timeout(5_000) });
    return res.ok;
  } catch {
    return false;
  }
}

export async function promptHub(
  text: string,
  conversationId: string,
  onEvent?: (event: HubEvent) => void,
): Promise<string> {
  const cfg = hubConfig();
  let token: string;
  try {
    token = await bearerToken(cfg.tokenFile);
  } catch (err) {
    throw new HubError(
      err instanceof Error ? err.message : "could not read hub token",
      "unreachable",
    );
  }

  const headers = {
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json",
    Accept: "application/json",
  };

  let accepted: { accepted?: boolean; run_id?: string };
  try {
    const res = await fetch(`${cfg.url}/api/prompt`, {
      method: "POST",
      headers,
      body: JSON.stringify({
        text,
        agent_id: "primary",
        conversation_id: conversationId,
      }),
      signal: AbortSignal.timeout(15_000),
    });
    const body = (await res.json().catch(() => ({}))) as {
      accepted?: boolean;
      run_id?: string;
      error?: string;
    };
    if (res.status !== 202 || !body.run_id) {
      throw new HubError(
        typeof body.error === "string" ? body.error : `prompt failed (${res.status})`,
        "http",
      );
    }
    accepted = body;
  } catch (err) {
    if (err instanceof HubError) throw err;
    throw new HubError("the agent hub is not reachable", "unreachable");
  }

  const runId = accepted.run_id!;
  const evRes = await fetch(`${cfg.url}/api/events?run_id=${encodeURIComponent(runId)}`, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "text/event-stream",
    },
    signal: AbortSignal.timeout(cfg.timeoutMs),
  }).catch(() => {
    throw new HubError("could not follow the hub event stream", "unreachable");
  });
  if (!evRes.ok || !evRes.body) {
    throw new HubError(`event stream failed (${evRes.status})`, "http");
  }

  const collected: string[] = [];
  const reader = evRes.body.getReader();
  const decoder = new TextDecoder();
  let buf = "";
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buf += decoder.decode(value, { stream: true });
      buf = buf.replace(/\r\n/g, "\n");
      let idx: number;
      while ((idx = buf.indexOf("\n\n")) !== -1) {
        const rawEvent = buf.slice(0, idx);
        buf = buf.slice(idx + 2);
        const line = rawEvent
          .split("\n")
          .map((l) => l.trimEnd())
          .find((l) => l.startsWith("data:"));
        if (!line) continue;
        const payload = line.slice(5).trim();
        if (!payload) continue;
        let ev: HubEvent;
        try {
          ev = JSON.parse(payload) as HubEvent;
        } catch {
          continue;
        }
        onEvent?.(ev);
        if (ev.type === "text" && ev.text) collected.push(ev.text);
        if (ev.type === "done") return collected.join("").trim();
        if (ev.type === "cancelled") {
          throw new HubError("the run was cancelled", "cancelled");
        }
        if (ev.type === "error") {
          throw new HubError(ev.message?.slice(0, 200) || "the agent reported an error", "error");
        }
      }
    }
  } catch (err) {
    if (err instanceof HubError) throw err;
    if (err instanceof DOMException && err.name === "TimeoutError") {
      throw new HubError("the agent took too long to reply", "timeout");
    }
    throw new HubError("the event stream closed unexpectedly", "unreachable");
  } finally {
    try {
      await reader.cancel();
    } catch {
      /* ignore */
    }
  }
  const reply = collected.join("").trim();
  if (reply) return reply;
  throw new HubError("the agent finished without a reply", "error");
}

export function userFacingHubError(err: unknown): string {
  if (err instanceof HubError) {
    switch (err.kind) {
      case "unreachable":
        return "The agent hub is not reachable right now. Try again in a moment.";
      case "timeout":
        return "The agent took too long to reply. Try again?";
      case "cancelled":
        return "That request was cancelled.";
      default:
        return "The agent hit an error and could not finish that reply.";
    }
  }
  return "The agent hit an error and could not finish that reply.";
}
