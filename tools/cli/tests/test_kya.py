"""Tests for the ``kya`` CLI module (``tools/cli/kya.py``).

These exercise the pure helpers (``parse_duration``, ``_safe_iso_to_epoch``,
``_read_recent_entries``, ``_current_status``) plus the ``status`` subcommand
end-to-end via ``subprocess`` with a monkeypatched ``HOME``.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

import kya


# --------------------------------------------------------------------------
# parse_duration
# --------------------------------------------------------------------------

@pytest.mark.parametrize(
    "text,expected",
    [
        ("45s", 45),
        ("30m", 1800),
        ("2h", 7200),
        ("90", 90),               # bare integer = seconds
        ("0090", 90),
        ("1h30m", 5400),
        ("1H30M", 5400),          # case-insensitive
        ("  2h  ", 7200),         # surrounding whitespace tolerated
        ("1h 30m", 5400),         # internal whitespace tolerated
        ("2m30s", 150),
        ("1h1m1s", 3661),
    ],
)
def test_parse_duration_valid(text, expected):
    assert kya.parse_duration(text) == expected


@pytest.mark.parametrize("text", ["abc", "", "   ", "1x", "-5", "h", "m30", "0s", "0m0s"])
def test_parse_duration_invalid_raises_valueerror(text):
    with pytest.raises(ValueError):
        kya.parse_duration(text)


def test_parse_duration_bare_zero_is_zero_seconds():
    # Documented contract: a bare digit string is taken verbatim as seconds,
    # so "0" returns 0 (the non-positive guard only covers the suffix forms).
    assert kya.parse_duration("0") == 0


# --------------------------------------------------------------------------
# _safe_iso_to_epoch
# --------------------------------------------------------------------------

def test_safe_iso_to_epoch_valid_utc_z():
    # 2024-01-02T03:04:05Z  ->  known epoch
    got = kya._safe_iso_to_epoch("2024-01-02T03:04:05Z")
    expected = datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc).timestamp()
    assert got == pytest.approx(expected)


def test_safe_iso_to_epoch_valid_with_offset():
    got = kya._safe_iso_to_epoch("2024-01-02T03:04:05+00:00")
    expected = datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc).timestamp()
    assert got == pytest.approx(expected)


@pytest.mark.parametrize("bad", ["not-a-date", "", "2024-13-99", "garbage", "T::"])
def test_safe_iso_to_epoch_malformed_returns_none(bad):
    assert kya._safe_iso_to_epoch(bad) is None


@pytest.mark.parametrize("bad", [None, 123, 12.5, [], {}, object()])
def test_safe_iso_to_epoch_non_string_returns_none(bad):
    assert kya._safe_iso_to_epoch(bad) is None


# --------------------------------------------------------------------------
# _read_recent_entries / _current_status — synthetic activity.jsonl
# --------------------------------------------------------------------------

def _write_log(tmp_path: Path, lines) -> Path:
    p = tmp_path / "activity.jsonl"
    with p.open("w", encoding="utf-8") as f:
        for line in lines:
            if isinstance(line, (dict, list)):
                f.write(json.dumps(line) + "\n")
            else:
                f.write(str(line) + "\n")
    return p


@pytest.fixture(autouse=True)
def _no_container_log(tmp_path, monkeypatch):
    """Keep a real sandbox-container log on the dev machine out of tests."""
    monkeypatch.setattr(kya, "CONTAINER_ACTIVITY_LOG_PATH", tmp_path / "no-container" / "activity.jsonl")


@pytest.fixture()
def patched_log(tmp_path, monkeypatch):
    """Return a callable that installs a synthetic log and points kya at it."""

    def _install(lines):
        p = _write_log(tmp_path, lines)
        monkeypatch.setattr(kya, "ACTIVITY_LOG_PATH", p)
        return p

    return _install


def test_read_recent_entries_missing_file(tmp_path, monkeypatch):
    monkeypatch.setattr(kya, "ACTIVITY_LOG_PATH", tmp_path / "does-not-exist.jsonl")
    assert kya._read_recent_entries(10) == []


def test_read_recent_entries_empty_file(patched_log):
    patched_log([])
    assert kya._read_recent_entries(10) == []


def test_read_recent_entries_newest_first_and_skips_garbage(patched_log):
    patched_log([
        {"startedAt": "2024-01-01T00:00:00Z", "n": 1},
        "this is not json",
        "",
        {"startedAt": "2024-01-02T00:00:00Z", "n": 2},
        {"startedAt": "2024-01-03T00:00:00Z", "n": 3},
    ])
    entries = kya._read_recent_entries(50)
    assert [e["n"] for e in entries] == [3, 2, 1]


@pytest.mark.parametrize("limit", [0, -1, -100])
def test_read_recent_entries_nonpositive_limit_returns_empty(patched_log, limit):
    patched_log([{"startedAt": "2024-01-01T00:00:00Z"}])
    assert kya._read_recent_entries(limit) == []


def test_read_recent_entries_maxlen_bounds_result(patched_log):
    patched_log([{"n": i} for i in range(20)])
    entries = kya._read_recent_entries(5)
    assert len(entries) == 5
    # newest-first => last 5 written, reversed
    assert [e["n"] for e in entries] == [19, 18, 17, 16, 15]


def test_current_status_inactive_when_empty(patched_log):
    patched_log([])
    assert kya._current_status() == {"active": False}


def test_current_status_inactive_when_last_entry_closed(patched_log):
    patched_log([
        {"startedAt": "2024-01-01T00:00:00Z", "endedAt": "2024-01-01T01:00:00Z", "source": "url"},
    ])
    assert kya._current_status() == {"active": False}


def test_current_status_active_open_entry_with_future_duration(patched_log):
    started = datetime.now(timezone.utc) - timedelta(seconds=10)
    patched_log([
        {
            "startedAt": started.isoformat().replace("+00:00", "Z"),
            "source": "url-scheme",
            "requestedDuration": 3600,
        },
    ])
    s = kya._current_status()
    assert s["active"] is True
    assert s["source"] == "url-scheme"
    assert s["requestedDuration"] == 3600
    # ~3590 s remaining; allow slack for test runtime.
    assert s["remainingSeconds"] == pytest.approx(3600 - 10, abs=30)
    assert s["fireDate"] is not None


def test_current_status_active_open_entry_no_duration(patched_log):
    patched_log([
        {"startedAt": "2024-01-01T00:00:00Z", "source": "url"},  # no requestedDuration
    ])
    s = kya._current_status()
    assert s["active"] is True
    assert s["remainingSeconds"] is None
    assert s["fireDate"] is None


def test_current_status_open_entry_with_bad_started(patched_log):
    # Malformed startedAt must not crash; still reported active.
    patched_log([
        {"startedAt": "not-a-real-timestamp", "source": "url", "requestedDuration": 600},
    ])
    s = kya._current_status()
    assert s["active"] is True
    assert s["remainingSeconds"] is None
    assert s["fireDate"] is None


def test_current_status_picks_most_recent_open_entry(patched_log):
    # newest entry (last line) is open => active even though an older one is closed
    patched_log([
        {"startedAt": "2024-01-01T00:00:00Z", "endedAt": "2024-01-01T01:00:00Z", "source": "old"},
        {"startedAt": "2024-01-02T00:00:00Z", "source": "new"},
    ])
    s = kya._current_status()
    assert s["active"] is True
    assert s["source"] == "new"


# --------------------------------------------------------------------------
# `kya status [--json]` subcommand via subprocess (monkeypatched HOME)
# --------------------------------------------------------------------------

_KYA_PY = str(Path(kya.__file__).resolve())


def _run_status(tmp_home: Path, *args):
    # Copy the real environment and only override HOME so the child keeps
    # PATH / LANG / etc. — a bare {"HOME": ...} dict breaks in stripped envs.
    env = os.environ.copy()
    env["HOME"] = str(tmp_home)
    return subprocess.run(
        [sys.executable, _KYA_PY, "status", *args],
        capture_output=True,
        text=True,
        env=env,
        timeout=10,  # a regressed/blocking `kya status` must not hang CI
    )


def test_status_subprocess_inactive_exit_1(tmp_path):
    # Empty / nonexistent log => inactive => exit 1.
    res = _run_status(tmp_path)
    assert res.returncode == 1
    assert res.stdout.strip() == "inactive"


def test_status_subprocess_json_inactive(tmp_path):
    res = _run_status(tmp_path, "--json")
    assert res.returncode == 1
    payload = json.loads(res.stdout)
    assert payload == {"active": False}


def test_status_subprocess_json_active_exit_0(tmp_path):
    log_dir = tmp_path / "Library" / "Application Support" / "KeepingYouAwake"
    log_dir.mkdir(parents=True)
    started = datetime.now(timezone.utc) - timedelta(seconds=5)
    (log_dir / "activity.jsonl").write_text(
        json.dumps(
            {
                "startedAt": started.isoformat().replace("+00:00", "Z"),
                "source": "test",
                "requestedDuration": 1800,
            }
        )
        + "\n",
        encoding="utf-8",
    )
    res = _run_status(tmp_path, "--json")
    assert res.returncode == 0
    payload = json.loads(res.stdout)
    assert payload["active"] is True
    assert payload["source"] == "test"
    assert payload["requestedDuration"] == 1800
    assert isinstance(payload["remainingSeconds"], (int, float))


def test_status_subprocess_human_active(tmp_path):
    log_dir = tmp_path / "Library" / "Application Support" / "KeepingYouAwake"
    log_dir.mkdir(parents=True)
    (log_dir / "activity.jsonl").write_text(
        json.dumps({"startedAt": "2024-01-01T00:00:00Z", "source": "test"}) + "\n",
        encoding="utf-8",
    )
    res = _run_status(tmp_path)
    assert res.returncode == 0
    assert "active" in res.stdout
    assert "source=test" in res.stdout


# --------------------------------------------------------------------------
# Regression tests (autoresearch debug findings)
# --------------------------------------------------------------------------

def test_current_status_ignores_stale_open_entry_behind_newer_closed(patched_log):
    # KYA quit (or crashed) mid-session, leaving an open entry; a later
    # session was opened and closed normally. Only one session can be open
    # at a time, so the newest entry decides the state.
    patched_log([
        {"startedAt": "2024-01-01T00:00:00Z", "source": "stale"},
        {"startedAt": "2024-01-02T00:00:00Z", "endedAt": "2024-01-02T01:00:00Z", "source": "user"},
    ])
    assert kya._current_status() == {"active": False}


def test_activate_without_duration_requests_indefinite(monkeypatch):
    # `activate` with no query falls back to the app's default duration,
    # not indefinite; the CLI must send an explicit seconds=0.
    urls = []
    monkeypatch.setattr(kya, "_open_url", lambda url: urls.append(url) or 0)
    assert kya.main(["activate"]) == 0
    assert urls == ["keepingyouawake:///activate?seconds=0"]


def test_activity_log_path_prefers_most_recently_written(tmp_path, monkeypatch):
    home_log = tmp_path / "home" / "activity.jsonl"
    container_log = tmp_path / "container" / "activity.jsonl"
    for path in (home_log, container_log):
        path.parent.mkdir(parents=True)
        path.write_text("{}\n", encoding="utf-8")
    os.utime(home_log, (1_000, 1_000))
    os.utime(container_log, (2_000, 2_000))
    monkeypatch.setattr(kya, "ACTIVITY_LOG_PATH", home_log)
    monkeypatch.setattr(kya, "CONTAINER_ACTIVITY_LOG_PATH", container_log)
    assert kya._activity_log_path() == container_log

    os.utime(home_log, (3_000, 3_000))
    assert kya._activity_log_path() == home_log


def test_activity_log_path_defaults_to_home_when_none_exist(tmp_path, monkeypatch):
    home_log = tmp_path / "home" / "activity.jsonl"
    monkeypatch.setattr(kya, "ACTIVITY_LOG_PATH", home_log)
    assert kya._activity_log_path() == home_log


def test_status_subprocess_reads_sandbox_container_log(tmp_path):
    # A sandboxed (Xcode-signed) build writes under its container.
    log_dir = (tmp_path / "Library" / "Containers" / "info.marcel-dierkes.KeepingYouAwake"
               / "Data" / "Library" / "Application Support" / "KeepingYouAwake")
    log_dir.mkdir(parents=True)
    (log_dir / "activity.jsonl").write_text(
        json.dumps({"startedAt": "2024-01-01T00:00:00Z", "source": "container"}) + "\n",
        encoding="utf-8",
    )
    res = _run_status(tmp_path, "--json")
    assert res.returncode == 0
    assert json.loads(res.stdout)["source"] == "container"
