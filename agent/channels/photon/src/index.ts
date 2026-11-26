// SPDX-License-Identifier: GPL-3.0-or-later
/**
 * Photon / Spectrum iMessage bridge for the Dynamai agent hub.
 *
 * Uses the Stable Spectrum SDK outbound gRPC connection
 * (https://photon.codes/docs/spectrum-ts/getting-started). No public webhook
 * is required. Inbound DMs from an allowlisted sender are posted to the local
 * hub; the collected reply is sent back over iMessage.
 *
 * This process never initiates a conversation. It only replies to inbound
 * allowlisted messages.
 */

import { Spectrum } from "@spectrum-ts/core";
import { imessage } from "@spectrum-ts/imessage";
import { hubHealthy, hubConfig, promptHub, userFacingHubError, type HubEvent } from "./hub";
import { isAllowed, parseAllowlist } from "./phone";

const DEFAULT_ALLOWLIST = "+19142632426";
const CHUNK = 3500;

function requiredEnv(name: string): string {
  const value = (process.env[name] ?? "").trim();
  if (!value) {
    console.error(`missing ${name}`);
    process.exit(1);
  }
  return value;
}

function log(message: string, extra?: Record<string, unknown>): void {
  const payload = extra ? ` ${JSON.stringify(extra)}` : "";
  console.log(`${new Date().toISOString()} ${message}${payload}`);
}

function chunkText(text: string, max = CHUNK): string[] {
  if (text.length <= max) return [text];
  const parts: string[] = [];
  let rest = text;
  while (rest.length > max) {
    let cut = rest.lastIndexOf("\n", max);
    if (cut < max / 2) cut = rest.lastIndexOf(" ", max);
    if (cut < max / 2) cut = max;
    parts.push(rest.slice(0, cut).trimEnd());
    rest = rest.slice(cut).trimStart();
  }
  if (rest) parts.push(rest);
  return parts;
}

function senderRaw(message: { sender?: { id?: string; address?: string } | null }): string {
  return (message.sender?.id || message.sender?.address || "").trim();
}

async function sendChunks(space: { send: (text: string) => Promise<unknown> }, text: string): Promise<void> {
  for (const part of chunkText(text)) {
    await space.send(part);
  }
}

function main(): void {
  const projectId = requiredEnv("SPECTRUM_PROJECT_ID");
  requiredEnv("SPECTRUM_PROJECT_SECRET");
  const allowlist = parseAllowlist(process.env.PHOTON_ALLOWLIST ?? DEFAULT_ALLOWLIST);
  if (allowlist.size === 0) {
    console.error("PHOTON_ALLOWLIST is empty");
    process.exit(1);
  }

  const queues = new Map<string, Promise<void>>();
  const enqueue = (key: string, job: () => Promise<void>): void => {
    const prev = queues.get(key) ?? Promise.resolve();
    const next = prev.then(job, job).catch((err) => {
      log("queued job failed", { error: err instanceof Error ? err.message : "unknown" });
    });
    queues.set(key, next);
  };

  void (async () => {
    const cfg = hubConfig();
    const healthy = await hubHealthy(cfg.url);
    log("starting photon bridge", {
      projectId,
      hub: cfg.url,
      hubHealthy: healthy,
      allowlist: allowlist.size,
    });

    const app = await Spectrum({
      projectId,
      projectSecret: process.env.SPECTRUM_PROJECT_SECRET!,
      providers: [imessage.config()],
      options: { logLevel: (process.env.SPECTRUM_LOG_LEVEL as "info" | "debug" | undefined) ?? "info" },
    });

    log("spectrum connected, waiting for inbound iMessages");

    const shutdown = async (signal: string) => {
      log("shutting down", { signal });
      try {
        await app.stop();
      } catch (err) {
        log("stop failed", { error: err instanceof Error ? err.message : "unknown" });
      }
      process.exit(0);
    };
    process.on("SIGTERM", () => void shutdown("SIGTERM"));
    process.on("SIGINT", () => void shutdown("SIGINT"));

    for await (const [space, message] of app.messages) {
      if (message.direction === "outbound") continue;
      if (message.platform !== "imessage") continue;

      let spaceType: string | undefined;
      try {
        spaceType = imessage(space).type;
      } catch {
        spaceType = undefined;
      }
      if (spaceType && spaceType !== "dm") {
        log("ignored non-dm space", { type: spaceType });
        continue;
      }

      const sender = isAllowed(senderRaw(message), allowlist);
      if (!sender) {
        log("ignored sender not on allowlist");
        continue;
      }

      if (message.content.type !== "text") {
        log("ignored non-text inbound", { sender, contentType: message.content.type });
        continue;
      }
      const text = message.content.text.trim();
      if (!text) continue;

      const conversationId = `imessage:${sender}`;
      log("inbound text", { sender, chars: text.length });

      enqueue(sender, async () => {
        const notified = { approval: false };
        const onEvent = async (event: HubEvent) => {
          if (event.type === "approval_request" && !notified.approval) {
            notified.approval = true;
            const detail = [event.description, event.command].filter(Boolean).join(": ");
            const note = detail
              ? `I need approval in the Dynamai app before I can run: ${detail}`
              : "I need approval in the Dynamai app before I can continue.";
            try {
              await space.send(note);
            } catch (err) {
              log("failed to send approval notice", {
                error: err instanceof Error ? err.message : "unknown",
              });
            }
          }
        };

        try {
          await space.responding(async () => {
            const reply = await promptHub(text, conversationId, (ev) => {
              void onEvent(ev);
            });
            if (reply) await sendChunks(space, reply);
          });
          log("replied", { sender });
        } catch (err) {
          log("reply failed", { sender, error: err instanceof Error ? err.message : "unknown" });
          try {
            await space.send(userFacingHubError(err));
          } catch (sendErr) {
            log("failed to send error reply", {
              error: sendErr instanceof Error ? sendErr.message : "unknown",
            });
          }
        }
      });
    }

    log("message stream ended");
    await app.stop();
  })().catch((err) => {
    console.error("photon bridge failed:", err instanceof Error ? err.message : err);
    process.exit(1);
  });
}

main();
