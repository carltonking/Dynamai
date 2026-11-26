# Dynamai agent hub (v1)

A small personal-agent runtime for Carlton's Oracle Cloud Always Free Ubuntu
VM. It speaks the **Vertus hub HTTP API** that Dynamai's island already knows
(`NotchVertusHubClient` in the macOS app), so the Mac app can be wired up
later without inventing a second protocol.

The hub is a long-running FastAPI process. It calls Anthropic's Messages API
with tool use, keeps memory and routines in SQLite, and listens only on
**127.0.0.1:8787**. There is no public port. Reach it with an SSH tunnel.

This folder is new; the rest of Dynamai is unchanged. The island still talks
to local Hermes today — connecting the app to this hub is a follow-up.

## Architecture

```
iMessage (Photon / Spectrum) ──outbound gRPC──► photon bridge
                                                │
                                                ▼
Dynamai Mac app (later) ──SSH tunnel───┐
curl / smoke test ──SSH tunnel─────────┼──► hub :8787 (localhost only)
                                       │       ├─ Anthropic (Claude Sonnet)
                                       │       ├─ tools: shell, search, fetch,
                                       │       │         remember/recall
                                       │       ├─ SQLite (chat, notes, routines)
                                       │       └─ scheduler (cron / interval)
```

- **Process:** one `systemd` service, `Restart=on-failure`, starts on boot.
- **Auth:** a bearer token and a separate approver token, generated on
  install, stored mode 0600 under `/var/lib/dynamai-agent/.vertus/`
  (`token`, `approver-token`). The island will read the same filenames from
  a Mac home directory once we copy them over; they are not in this repo.
- **Model:** `claude-sonnet-5-5` (current Sonnet from Anthropic's `/v1/models`
  list as of 26 Nov 2026). Override with `ANTHROPIC_MODEL`.
- **Tools**
  - `shell` — run a command on the VM, with a timeout and output cap.
    Destructive commands (`rm -r`, `sudo`, `dd`, …) pause for approval.
  - `web_search` — DuckDuckGo instant-answer API plus an HTML scrape.
    Cloud IPs are often blocked by the HTML endpoint; a paid search API
    (Brave, Tavily, or Bing) would be more reliable.
  - `web_fetch` — HTTP(S) GET, HTML stripped to text.
  - `remember` / `recall` / `forget` — durable notes in SQLite.
  - `browser` — interface stub only. Chromium is not installed: this VM has
    about 1 GB of RAM.
- **Memory:** conversation turns plus a notes table. Recent chat is sent back
  to the model; lasting facts go through `remember`.
- **Routines:** stored in SQLite. Schedules may be `once_after_seconds`,
  `every_seconds`, or a 5-field cron expression (UTC). When a job fires the
  hub emits a `routine_fired` event and runs the prompt; a reply of exactly
  `NOTHING_TO_REPORT` is treated as silence by the Dynamai island.
- **iMessage:** a Photon / Spectrum bridge (`channels/photon/`, systemd
  `dynamai-photon`) opens an outbound gRPC connection to Spectrum Cloud
  (Stable SDK, https://photon.codes/docs/spectrum-ts/getting-started).
  No public webhook is required. Inbound DMs from an allowlisted sender
  (`PHOTON_ALLOWLIST`, default Carlton's +1 914-263-2426) are posted to
  `POST /api/prompt` with a per-sender `conversation_id`; the reply is
  sent back over iMessage. The shared Photon number is +1 (628) 267-9185.
  A Sendblue webhook skeleton remains at `POST /hooks/sendblue` but stays
  disabled unless its env vars are set.

## Vertus API (what the island already calls)

All `/api/*` routes require `Authorization: Bearer <token>`. Destructive
approvals also need `X-Vertus-Approver`. The island sends
`X-Vertus-Client: local`.

| Method | Path | Role |
|--------|------|------|
| POST | `/api/prompt` | Body `{"text","agent_id":"primary","conversation_id"?}`. **202** `{"accepted":true,"run_id"}`. `conversation_id` keeps iMessage threads separate from the island's default history. |
| GET | `/api/events?run_id=` | SSE stream of one run, until `done` / `cancelled` / `error`. |
| GET | `/api/events?since=` | Fleet stream of every event, resumable by `seq`. |
| GET | `/api/agents` | `{"agents":[{"id":"primary","model":"..."}]}`. |
| GET | `/api/runs/{id}` | Includes `run_kind` (`user` or `routine`) and `routine_id`. |
| POST | `/api/runs/{id}/cancel` | Stop an in-flight run. |
| GET | `/api/approvals?state=pending` | Ledger of waiting approvals. |
| POST | `/api/approvals/{id}` | Body `{"choice":"once"|"deny"|…}`. |
| GET | `/api/routines?agent_id=primary` | `{"routines":[{"routine_id","name","prompt",…}]}`. |
| POST | `/api/routines` | Create one (v1 addition, used for tests). |
| POST | `/api/routines/{id}/run` | Fire one now. |
| DELETE | `/api/routines/{id}` | Remove one. |
| GET | `/health` | Unauthenticated liveness (localhost only). |

SSE events are one JSON object per `data:` line, including `seq`, `run_id`,
`agent_id`, and `type`:

- `text` — `{text}`
- `activity` — `{text:"running shell…"}` (the island shows the tool name)
- `done` / `cancelled` / `error` (`error` uses `{message}`)
- `approval_request` / `approval_resolved`
- `routine_fired` — `{routine_id, run_id}`

Comments (`: ping`) are keepalives; the island ignores them.

## Setup on the VM

The intended host is Ubuntu 24.04, 1 OCPU, ~1 GB RAM. Create a **2–4 GB
swapfile first** (3 GB is what was used on first install):

```sh
sudo fallocate -l 3G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

Put the API key in a root-owned env file. Never commit it.

```sh
sudo install -m 600 /dev/null /etc/dynamai-agent.env
# then write ANTHROPIC_API_KEY, ANTHROPIC_MODEL, DYNAMAI_DATA_DIR, etc.
# See env.example.
```

Copy this `agent/` tree to the VM and run:

```sh
./scripts/install.sh
```

That creates `/opt/dynamai-agent` (venv + code), `/var/lib/dynamai-agent`
(SQLite, tokens, workspace), installs `dynamai-agent.service`, enables it,
and starts it. Token paths are printed; the token values are not.
If `/etc/dynamai-photon.env` is already present, it also runs
`scripts/install-photon.sh`.

```sh
sudo systemctl status dynamai-agent
sudo systemctl status dynamai-photon
```

### Photon iMessage bridge

The bridge is a small Bun service next to the hub. Spectrum credentials go
in a **separate** root-owned env file — not in git, not in the hub env file:

```sh
sudo install -m 600 /dev/null /etc/dynamai-photon.env
# then write, without printing the values:
#   SPECTRUM_PROJECT_ID=d9ef34f9-b695-43fe-aeb7-ef19de1739fa
#   SPECTRUM_PROJECT_SECRET=...
#   DYNAMAI_HUB_URL=http://127.0.0.1:8787
#   DYNAMAI_TOKEN_FILE=/var/lib/dynamai-agent/.vertus/token
#   PHOTON_ALLOWLIST=+19142632426
```

Then:

```sh
./scripts/install-photon.sh
sudo journalctl -u dynamai-photon -f
```

A healthy start logs `spectrum connected, waiting for inbound iMessages`.
Text the shared Photon number **+1 (628) 267-9185** from an allowlisted
phone. The service never initiates a conversation on its own.

Docs used: Stable Spectrum, https://photon.codes/docs/spectrum-ts/getting-started
and https://photon.codes/docs/spectrum-ts/providers/imessage.

## How to tunnel

From this machine (or a Mac), forward the local port to the VM's loopback:

```sh
ssh -i /path/to/oracle-vm/id_ed25519 -o IdentitiesOnly=yes \
    -L 8787:127.0.0.1:8787 ubuntu@143.47.99.132
```

Leave that session open. Then, with the bearer token in a 0600 file:

```sh
curl -sS http://127.0.0.1:8787/health
curl -sS -D- -o - \
  -H "Authorization: Bearer $(cat /path/to/token)" \
  -H "Content-Type: application/json" \
  -d '{"text":"Hello","agent_id":"primary"}' \
  http://127.0.0.1:8787/api/prompt
# follow with:
curl -N -H "Authorization: Bearer $(cat /path/to/token)" \
  "http://127.0.0.1:8787/api/events?run_id=RUN_ID"
```

A scripted check lives at `scripts/smoke_test.py`:

```sh
python3 scripts/smoke_test.py --token-file /path/to/token
```

## Layout

```
agent/
  dynamai_agent/          Python package (FastAPI app, engine, tools)
  channels/photon/        Bun Spectrum iMessage bridge
  systemd/                unit files (hub + photon)
  scripts/install.sh      VM install / upgrade (hub; photon if env present)
  scripts/install-photon.sh
  scripts/smoke_test.py   prompt + memory + routine check
  env.example             env file template, no secrets
  requirements.txt
```

Data on the VM: `/var/lib/dynamai-agent/hub.sqlite`, `workspace/`, `.vertus/`.

## What's next

- **Browser:** add Playwright/Chromium only on a larger machine, behind the
  existing `browser` tool.
- **Photon:** the live iMessage path. Add more numbers to `PHOTON_ALLOWLIST`
  only if Carlton wants other people to talk to the agent. A webhook is
  optional and unused; the SDK's outbound connection is enough.
- **Dynamai wiring:** `NotchVertusHubClient` is still in the app but the
  Vertus/Hermes page currently starts `hermes acp` locally. Point that client
  at this hub through the tunnel (and later, perhaps Tailscale), and copy the
  token files to `~/.vertus/` on the Mac.
