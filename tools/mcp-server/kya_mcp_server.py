#!/usr/bin/env python3
"""KYA MCP server.

Exposes KeepingYouAwake (Amphetamine) primitives as MCP tools so
Claude Code (or any other MCP client speaking stdio) can:

  - activate / deactivate / toggle the keep-awake timer
  - read the current state from the activity-log JSONL
  - list recent sessions
  - flip a known fork-added user-default

Implementation strategy: the server spawns `open -g keepingyouawake://...`
to drive the running KYA app via its existing URL-scheme entry points
(see KYAEvents in the main app). State queries read the JSONL log
written by KYAActivityLogger. No XPC / Mach-service wiring needed; the
server can run on the same Mac as the app or fail gracefully if KYA
isn't installed.

Install:
    uv tool install git+https://github.com/ryouka0731/KeepingYouAwake-Amphetamine.git#subdirectory=tools/mcp-server
        # or `pip install` from a checkout

Wire into Claude Code (~/.claude/mcp_settings.json):
    {
      "mcpServers": {
        "kya": { "command": "kya-mcp-server" }
      }
    }
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

try:
    from mcp.server import Server
    from mcp.server.stdio import stdio_server
    import mcp.types as mcp_types
except ImportError as e:
    print(
        "kya-mcp-server requires the 'mcp' Python package.\n"
        "Install it with one of:\n"
        "    uv pip install 'mcp>=1.0.0,<2'\n"
        "    pip install 'mcp>=1.0.0,<2'\n"
        f"\nUnderlying import error: {e}",
        file=sys.stderr,
    )
    raise SystemExit(2)


ACTIVITY_LOG_PATH = (
    Path.home() / "Library" / "Application Support" / "KeepingYouAwake" / "activity.jsonl"
)

ALLOWED_DEFAULT_KEYS = {
    "info.marcel-dierkes.KeepingYouAwake.ActivateOnACPowerEnabled",
    "info.marcel-dierkes.KeepingYouAwake.ActivateOnExternalDisplayConnectedEnabled",
    "info.marcel-dierkes.KeepingYouAwake.ActivateOnExternalAudioOutputEnabled",
    "info.marcel-dierkes.KeepingYouAwake.ActivateOnCPULoadEnabled",
    "info.marcel-dierkes.KeepingYouAwake.CPULoadActivationThreshold",
    "info.marcel-dierkes.KeepingYouAwake.AllowDisplaySleep",
    "info.marcel-dierkes.KeepingYouAwake.DeactivateOnFullChargeEnabled",
    "info.marcel-dierkes.KeepingYouAwake.DownloadInProgressActivationEnabled",
    "info.marcel-dierkes.KeepingYouAwake.DriveAliveEnabled",
    "info.marcel-dierkes.KeepingYouAwake.MenuBarCountdownDisabled",
    "info.marcel-dierkes.KeepingYouAwake.MouseJigglerEnabled",
    "info.marcel-dierkes.KeepingYouAwake.PreventDiskSleepEnabled",
    "info.marcel-dierkes.KeepingYouAwake.ScheduleEnabled",
}


def _open_url(url: str) -> None:
    """Drive the KYA app via its registered URL scheme. -g keeps focus."""
    subprocess.run(["open", "-g", url], check=False, timeout=5)


def _read_recent_entries(limit: int) -> list[dict[str, Any]]:
    """Return up to `limit` most recent entries, newest-first.

    Uses a bounded `deque` so memory + post-iteration slice cost stay
    O(limit) rather than O(file size). On a long-lived install the
    JSONL log is capped at 1000 lines anyway, but `limit` here can be
    much smaller, and there's no reason to materialise more than that.
    """
    from collections import deque
    if not ACTIVITY_LOG_PATH.exists():
        return []
    if int(limit) <= 0:
        return []
    tail: deque[dict[str, Any]] = deque(maxlen=int(limit))
    with ACTIVITY_LOG_PATH.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                tail.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return list(reversed(tail))


def _safe_iso_to_epoch(s: Any) -> float | None:
    """Tolerant ISO-8601 → epoch seconds. Returns None on any malformation."""
    if not isinstance(s, str):
        return None
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()
    except ValueError:
        return None


def _current_status() -> dict[str, Any]:
    """Best-effort: the most recent log entry without `endedAt` is "active".

    Tolerant to malformed `startedAt` — if the timestamp can't be
    parsed we still return `active=True` but omit `fireDate` /
    `remainingSeconds` rather than crashing the MCP call.
    """
    entries = _read_recent_entries(50)
    for entry in entries:
        if "endedAt" not in entry or entry.get("endedAt") is None:
            started = entry.get("startedAt")
            requested = entry.get("requestedDuration")
            fire_iso = None
            remaining = None
            started_epoch = _safe_iso_to_epoch(started)
            if started_epoch is not None and isinstance(requested, (int, float)) and requested > 0:
                fire_dt = started_epoch + float(requested)
                now = datetime.now(timezone.utc).timestamp()
                remaining = max(0.0, fire_dt - now)
                fire_iso = datetime.fromtimestamp(fire_dt, tz=timezone.utc).isoformat()
            return {
                "active": True,
                "source": entry.get("source", "unknown"),
                "startedAt": started,
                "requestedDuration": requested,
                "fireDate": fire_iso,
                "remainingSeconds": remaining,
            }
    return {"active": False}


# ---------------------------------------------------------------------------
# MCP server wiring
# ---------------------------------------------------------------------------

server = Server("kya")


@server.list_tools()
async def list_tools() -> list[mcp_types.Tool]:
    return [
        mcp_types.Tool(
            name="kya_activate",
            description=(
                "Start a keep-awake session. Pass an integer number of seconds, "
                "or the strings 'indefinite' or 'until_end_of_day'."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "duration": {
                        "oneOf": [
                            {"type": "integer", "minimum": 1},
                            {"type": "string", "enum": ["indefinite", "until_end_of_day"]},
                        ]
                    }
                },
                "required": ["duration"],
            },
        ),
        mcp_types.Tool(
            name="kya_deactivate",
            description="Stop the current keep-awake session, if any.",
            inputSchema={"type": "object", "properties": {}},
        ),
        mcp_types.Tool(
            name="kya_toggle",
            description="Toggle KYA. If active → deactivate; if inactive → activate (default duration).",
            inputSchema={"type": "object", "properties": {}},
        ),
        mcp_types.Tool(
            name="kya_status",
            description="Return the current KYA state (active, source, fireDate, remainingSeconds).",
            inputSchema={"type": "object", "properties": {}},
        ),
        mcp_types.Tool(
            name="kya_list_recent_sessions",
            description="Return up to N recent activate/deactivate entries from the activity log.",
            inputSchema={
                "type": "object",
                "properties": {
                    "limit": {"type": "integer", "minimum": 1, "maximum": 200, "default": 20}
                },
            },
        ),
        mcp_types.Tool(
            name="kya_set_default",
            description=(
                "Flip one of KYA's known user-default keys via `defaults write`. "
                "The key must be in the allow-list — arbitrary keys are rejected."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "key": {"type": "string"},
                    "value": {
                        "oneOf": [
                            {"type": "boolean"},
                            {"type": "number"},
                            {"type": "string"},
                        ]
                    },
                },
                "required": ["key", "value"],
            },
        ),
    ]


@server.call_tool()
async def call_tool(name: str, arguments: dict[str, Any]) -> list[mcp_types.TextContent]:
    if name == "kya_activate":
        duration = arguments["duration"]
        if isinstance(duration, str):
            if duration == "indefinite":
                _open_url("keepingyouawake:///activate")
            elif duration == "until_end_of_day":
                # Compute seconds until next local midnight.
                now = datetime.now()
                tomorrow = now.replace(hour=0, minute=0, second=0, microsecond=0)
                # Add one day.
                from datetime import timedelta
                tomorrow = tomorrow + timedelta(days=1)
                seconds = int((tomorrow - now).total_seconds())
                _open_url(f"keepingyouawake:///activate?seconds={seconds}")
            else:
                return [mcp_types.TextContent(type="text", text=f"unknown duration string: {duration!r}")]
        else:
            seconds = int(duration)
            _open_url(f"keepingyouawake:///activate?seconds={seconds}")
        return [mcp_types.TextContent(type="text", text=json.dumps({"activated": True, "request": duration}))]

    if name == "kya_deactivate":
        _open_url("keepingyouawake:///deactivate")
        return [mcp_types.TextContent(type="text", text=json.dumps({"deactivated": True}))]

    if name == "kya_toggle":
        _open_url("keepingyouawake:///toggle")
        return [mcp_types.TextContent(type="text", text=json.dumps({"toggled": True}))]

    if name == "kya_status":
        return [mcp_types.TextContent(type="text", text=json.dumps(_current_status()))]

    if name == "kya_list_recent_sessions":
        limit = int(arguments.get("limit", 20))
        return [mcp_types.TextContent(type="text", text=json.dumps(_read_recent_entries(limit)))]

    if name == "kya_set_default":
        key = arguments["key"]
        value = arguments["value"]
        if key not in ALLOWED_DEFAULT_KEYS:
            return [mcp_types.TextContent(type="text", text=f"refused: key {key!r} not in allow-list")]
        # Map JSON value → defaults write argument shape.
        domain = "info.marcel-dierkes.KeepingYouAwake"
        cmd: list[str] = ["defaults", "write", domain, key]
        if isinstance(value, bool):
            cmd.extend(["-bool", "YES" if value else "NO"])
        elif isinstance(value, int):
            cmd.extend(["-int", str(value)])
        elif isinstance(value, float):
            cmd.extend(["-float", str(value)])
        else:
            cmd.extend(["-string", str(value)])
        try:
            subprocess.run(cmd, check=True, timeout=5, capture_output=True)
            return [mcp_types.TextContent(type="text", text=json.dumps({"set": key, "value": value}))]
        except subprocess.CalledProcessError as exc:
            return [mcp_types.TextContent(type="text", text=f"defaults write failed: {exc.stderr.decode(errors='replace')}")]

    return [mcp_types.TextContent(type="text", text=f"unknown tool: {name}")]


def main() -> None:
    parser = argparse.ArgumentParser(description="KYA MCP server (stdio)")
    parser.parse_args()
    import asyncio

    async def _run() -> None:
        async with stdio_server() as (read, write):
            await server.run(read, write, server.create_initialization_options())

    asyncio.run(_run())


if __name__ == "__main__":
    main()
