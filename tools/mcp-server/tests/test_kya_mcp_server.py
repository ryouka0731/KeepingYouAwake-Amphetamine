"""Tests for the KYA MCP server module (``tools/mcp-server/kya_mcp_server.py``).

Importing the module unconditionally requires the ``mcp`` package (the module
calls ``raise SystemExit(2)`` at import time when it's missing), so the whole
module is gated behind ``pytest.importorskip("mcp")``. Within that, we test:

  * the pure helpers (``_safe_iso_to_epoch``, ``_read_recent_entries``,
    ``_current_status``) — same contracts as the CLI;
  * the ``ALLOWED_DEFAULT_KEYS`` allow-list enforcement in ``kya_set_default``;
  * the ``tools/list`` surface (6 tools with name/description/inputSchema);
  * dispatching every tool via ``call_tool`` with ``_open_url`` / ``defaults
    write`` stubbed out, asserting the returned payload is JSON-serializable
    and matches the declared top-level shape.
"""

from __future__ import annotations

import asyncio
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

pytest.importorskip("mcp", reason="kya_mcp_server imports the 'mcp' package at module load")

import kya_mcp_server as srv


def _run(coro):
    return asyncio.run(coro)


# --------------------------------------------------------------------------
# Pure helpers — mirror the CLI contracts.
# --------------------------------------------------------------------------

def test_safe_iso_to_epoch_valid_and_malformed():
    expected = datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc).timestamp()
    assert srv._safe_iso_to_epoch("2024-01-02T03:04:05Z") == pytest.approx(expected)
    assert srv._safe_iso_to_epoch("not-a-date") is None
    assert srv._safe_iso_to_epoch("") is None
    assert srv._safe_iso_to_epoch(None) is None
    assert srv._safe_iso_to_epoch(123) is None


def _write_log(tmp_path: Path, lines) -> Path:
    p = tmp_path / "activity.jsonl"
    with p.open("w", encoding="utf-8") as f:
        for line in lines:
            f.write((json.dumps(line) if isinstance(line, (dict, list)) else str(line)) + "\n")
    return p


@pytest.fixture(autouse=True)
def _no_container_log(tmp_path, monkeypatch):
    """Keep a real sandbox-container log on the dev machine out of tests."""
    monkeypatch.setattr(srv, "CONTAINER_ACTIVITY_LOG_PATH", tmp_path / "no-container" / "activity.jsonl")


@pytest.fixture(autouse=True)
def _kya_running(monkeypatch):
    """Pretend KYA is running; tests about a stopped app override this."""
    monkeypatch.setattr(srv, "_kya_is_running", lambda: True)


@pytest.fixture()
def patched_log(tmp_path, monkeypatch):
    def _install(lines):
        p = _write_log(tmp_path, lines)
        monkeypatch.setattr(srv, "ACTIVITY_LOG_PATH", p)
        return p

    return _install


def test_read_recent_entries_missing_file(tmp_path, monkeypatch):
    monkeypatch.setattr(srv, "ACTIVITY_LOG_PATH", tmp_path / "nope.jsonl")
    assert srv._read_recent_entries(10) == []


def test_read_recent_entries_empty_and_newest_first(patched_log):
    patched_log([])
    assert srv._read_recent_entries(10) == []
    patched_log([{"n": 1}, "garbage", "", {"n": 2}, {"n": 3}])
    assert [e["n"] for e in srv._read_recent_entries(50)] == [3, 2, 1]


@pytest.mark.parametrize("limit", [0, -1, -50])
def test_read_recent_entries_nonpositive_limit(patched_log, limit):
    patched_log([{"n": 1}])
    assert srv._read_recent_entries(limit) == []


def test_read_recent_entries_maxlen_bounds(patched_log):
    patched_log([{"n": i} for i in range(20)])
    entries = srv._read_recent_entries(3)
    assert len(entries) == 3
    assert [e["n"] for e in entries] == [19, 18, 17]


def test_current_status_inactive_empty(patched_log):
    patched_log([])
    assert srv._current_status() == {"active": False}


def test_current_status_inactive_closed_entry(patched_log):
    patched_log([{"startedAt": "2024-01-01T00:00:00Z", "endedAt": "2024-01-01T01:00:00Z", "source": "u"}])
    assert srv._current_status() == {"active": False}


def test_current_status_active_future_duration(patched_log):
    started = datetime.now(timezone.utc) - timedelta(seconds=10)
    patched_log([{"startedAt": started.isoformat().replace("+00:00", "Z"), "source": "u", "requestedDuration": 3600}])
    s = srv._current_status()
    assert s["active"] is True
    assert s["source"] == "u"
    assert s["remainingSeconds"] == pytest.approx(3600 - 10, abs=30)
    assert s["fireDate"] is not None


def test_current_status_active_bad_started(patched_log):
    patched_log([{"startedAt": "garbage", "source": "u", "requestedDuration": 600}])
    s = srv._current_status()
    assert s["active"] is True
    assert s["remainingSeconds"] is None
    assert s["fireDate"] is None


# --------------------------------------------------------------------------
# tools/list surface
# --------------------------------------------------------------------------

EXPECTED_TOOL_NAMES = {
    "kya_activate",
    "kya_deactivate",
    "kya_toggle",
    "kya_status",
    "kya_list_recent_sessions",
    "kya_set_default",
}


def _list_tools():
    return _run(srv.list_tools())


def test_list_tools_returns_six_with_required_keys():
    tools = _list_tools()
    assert len(tools) == 6
    names = set()
    for t in tools:
        assert t.name
        assert t.description
        # mcp Tool model exposes inputSchema; it must be a dict-ish schema.
        assert isinstance(t.inputSchema, dict)
        assert t.inputSchema.get("type") == "object"
        # round-trips through JSON (it's an MCP wire payload after all).
        json.dumps(t.model_dump())
        names.add(t.name)
    assert names == EXPECTED_TOOL_NAMES


# --------------------------------------------------------------------------
# call_tool dispatch — _open_url / defaults write stubbed
# --------------------------------------------------------------------------

@pytest.fixture()
def captured_urls(monkeypatch):
    urls: list[str] = []
    monkeypatch.setattr(srv, "_open_url", lambda url: urls.append(url))
    return urls


def _call(name, arguments=None):
    return _run(srv.call_tool(name, arguments or {}))


def _text(result):
    # call_tool returns list[TextContent]
    assert isinstance(result, list) and result
    assert result[0].type == "text"
    return result[0].text


def test_call_kya_activate_seconds(captured_urls):
    out = json.loads(_text(_call("kya_activate", {"duration": 900})))
    assert out == {"activated": True, "request": 900}
    assert captured_urls == ["keepingyouawake:///activate?seconds=900"]


def test_call_kya_activate_indefinite(captured_urls):
    out = json.loads(_text(_call("kya_activate", {"duration": "indefinite"})))
    assert out == {"activated": True, "request": "indefinite"}
    # Without an explicit seconds=0 the app falls back to its default
    # duration, which is not indefinite.
    assert captured_urls == ["keepingyouawake:///activate?seconds=0"]


def test_call_kya_activate_until_end_of_day(captured_urls):
    out = json.loads(_text(_call("kya_activate", {"duration": "until_end_of_day"})))
    assert out["activated"] is True
    assert len(captured_urls) == 1
    assert captured_urls[0].startswith("keepingyouawake:///activate?seconds=")


def test_call_kya_deactivate(captured_urls):
    out = json.loads(_text(_call("kya_deactivate")))
    assert out == {"deactivated": True}
    assert captured_urls == ["keepingyouawake:///deactivate"]


def test_call_kya_toggle(captured_urls):
    out = json.loads(_text(_call("kya_toggle")))
    assert out == {"toggled": True}
    assert captured_urls == ["keepingyouawake:///toggle"]


def test_call_kya_status(patched_log):
    patched_log([])
    out = json.loads(_text(_call("kya_status")))
    assert out == {"active": False}


def test_call_kya_status_active(patched_log):
    started = datetime.now(timezone.utc) - timedelta(seconds=10)
    patched_log([
        {
            "startedAt": started.isoformat().replace("+00:00", "Z"),
            "source": "url-scheme",
            "requestedDuration": 3600,
        },
    ])
    out = json.loads(_text(_call("kya_status")))
    assert out["active"] is True
    assert out["source"] == "url-scheme"
    assert out["requestedDuration"] == 3600
    assert out["remainingSeconds"] == pytest.approx(3600 - 10, abs=30)
    assert out["fireDate"] is not None


def test_call_kya_list_recent_sessions(patched_log):
    patched_log([{"n": 1}, {"n": 2}, {"n": 3}])
    out = json.loads(_text(_call("kya_list_recent_sessions", {"limit": 2})))
    assert [e["n"] for e in out] == [3, 2]
    # default limit path also works
    out_default = json.loads(_text(_call("kya_list_recent_sessions")))
    assert [e["n"] for e in out_default] == [3, 2, 1]


def test_call_kya_list_recent_sessions_limit_zero(patched_log):
    patched_log([{"n": 1}])
    out = json.loads(_text(_call("kya_list_recent_sessions", {"limit": 0})))
    assert out == []


def test_call_unknown_tool():
    text = _text(_call("kya_does_not_exist"))
    assert "unknown tool" in text


# --------------------------------------------------------------------------
# ALLOWED_DEFAULT_KEYS allow-list
# --------------------------------------------------------------------------

def test_set_default_allowlist_is_nonempty_set_of_strings():
    assert isinstance(srv.ALLOWED_DEFAULT_KEYS, set)
    assert srv.ALLOWED_DEFAULT_KEYS
    assert all(isinstance(k, str) for k in srv.ALLOWED_DEFAULT_KEYS)


def test_set_default_rejects_key_not_in_allowlist(monkeypatch):
    called = []
    monkeypatch.setattr(srv.subprocess, "run", lambda *a, **k: called.append(a) or None)
    text = _text(_call("kya_set_default", {"key": "info.marcel-dierkes.KeepingYouAwake.SomethingEvil", "value": True}))
    assert "refused" in text
    assert "not in allow-list" in text
    # crucially: no `defaults write` (or anything) was shelled out.
    assert called == []


def test_set_default_accepts_allowed_key(monkeypatch):
    allowed_key = next(iter(srv.ALLOWED_DEFAULT_KEYS))
    captured = {}

    class _Completed:
        stderr = b""

    def _fake_run(cmd, *a, **k):
        captured["cmd"] = cmd
        return _Completed()

    monkeypatch.setattr(srv.subprocess, "run", _fake_run)
    out = json.loads(_text(_call("kya_set_default", {"key": allowed_key, "value": True})))
    assert out == {"set": allowed_key, "value": True}
    assert captured["cmd"][:2] == ["defaults", "write"]
    assert allowed_key in captured["cmd"]
    assert "-bool" in captured["cmd"]


def test_set_default_accepts_allowed_key_int_value(monkeypatch):
    # Pick a key whose name suggests an int threshold; any allowed key works
    # for the code path (it branches on the Python value type, not the key).
    allowed_key = "info.marcel-dierkes.KeepingYouAwake.CPULoadActivationThreshold"
    assert allowed_key in srv.ALLOWED_DEFAULT_KEYS
    captured = {}

    class _Completed:
        stderr = b""

    monkeypatch.setattr(srv.subprocess, "run", lambda cmd, *a, **k: captured.setdefault("cmd", cmd) or _Completed())
    out = json.loads(_text(_call("kya_set_default", {"key": allowed_key, "value": 80})))
    assert out == {"set": allowed_key, "value": 80}
    assert "-int" in captured["cmd"]
    assert "80" in captured["cmd"]


def test_set_default_accepts_allowed_key_false_value(monkeypatch):
    allowed_key = next(iter(srv.ALLOWED_DEFAULT_KEYS))
    captured = {}

    class _Completed:
        stderr = b""

    monkeypatch.setattr(srv.subprocess, "run", lambda cmd, *a, **k: captured.setdefault("cmd", cmd) or _Completed())
    out = json.loads(_text(_call("kya_set_default", {"key": allowed_key, "value": False})))
    assert out == {"set": allowed_key, "value": False}
    # Source emits `defaults write <domain> <key> -bool NO` for a false value.
    assert captured["cmd"][:2] == ["defaults", "write"]
    assert allowed_key in captured["cmd"]
    assert "-bool" in captured["cmd"]
    assert "NO" in captured["cmd"]
    assert "YES" not in captured["cmd"]


def test_current_status_ignores_stale_open_entry_behind_newer_closed(patched_log):
    # An entry left open by a quit/crash must not be reported once a newer
    # session has been opened and closed.
    patched_log([
        {"startedAt": "2024-01-01T00:00:00Z", "source": "stale"},
        {"startedAt": "2024-01-02T00:00:00Z", "endedAt": "2024-01-02T01:00:00Z", "source": "user"},
    ])
    assert srv._current_status() == {"active": False}


def test_activity_log_path_prefers_most_recently_written(tmp_path, monkeypatch):
    import os
    home_log = tmp_path / "home" / "activity.jsonl"
    container_log = tmp_path / "container" / "activity.jsonl"
    for path in (home_log, container_log):
        path.parent.mkdir(parents=True)
        path.write_text("{}\n", encoding="utf-8")
    os.utime(home_log, (1_000, 1_000))
    os.utime(container_log, (2_000, 2_000))
    monkeypatch.setattr(srv, "ACTIVITY_LOG_PATH", home_log)
    monkeypatch.setattr(srv, "CONTAINER_ACTIVITY_LOG_PATH", container_log)
    assert srv._activity_log_path() == container_log


def test_current_status_inactive_when_kya_not_running(patched_log, monkeypatch):
    patched_log([{"startedAt": "2024-01-01T00:00:00Z", "source": "user"}])
    monkeypatch.setattr(srv, "_kya_is_running", lambda: False)
    assert srv._current_status() == {"active": False}
