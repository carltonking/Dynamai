# SPDX-License-Identifier: GPL-3.0-or-later
"""Run the hub with: python -m dynamai_agent"""

from __future__ import annotations

import uvicorn

from dynamai_agent.config import HOST, PORT


def main() -> None:
    # One worker: the event bus, scheduler and in-flight runs live in this process.
    uvicorn.run(
        "dynamai_agent.app:app",
        host=HOST,
        port=PORT,
        workers=1,
        log_level="info",
        access_log=False,
    )


if __name__ == "__main__":
    main()
