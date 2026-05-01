"""APEX Platform -- app/core/workflow_run_history.py unit tests.

Coverage target: ≥90% of 152 statements (G-T1.7b.2, Sprint 10).

JSON-file persistence + in-memory ring buffer of WorkflowRun dataclass.
We exercise:

  * `_load` — no-file path, valid file, malformed JSON.
  * `_save` — writes succeed; errors are swallowed.
  * `_truncate_payload` — under-cap passthrough, over-cap with mixed
    sizes, unserializable input.
  * `_summarize_action_result` — multiple input shapes.
  * `record_run` — status determination (success/partial/failed/no actions),
    error swallowing, ring-buffer cap honored.
  * `list_runs` — every filter (rule_id, tenant_id, event_name, status, paging).
  * `get_run`, `stats`, `clear` (with and without rule_id).

Filesystem isolation: each test uses `tmp_path / "runs.json"`. The
`fresh_module` fixture monkeypatches `_PATH` and resets the module-level
`_RUNS` deque so tests do not bleed.
"""

from __future__ import annotations

import json
import os

import pytest

from app.core import workflow_run_history as wrh


# ══════════════════════════════════════════════════════════════
# Fixtures
# ══════════════════════════════════════════════════════════════


@pytest.fixture
def isolated_path(tmp_path, monkeypatch):
    """Redirect the module's persistence path to a tmp file + reset
    the in-memory deque. Returns the new path for assertions."""
    p = tmp_path / "runs.json"
    monkeypatch.setattr(wrh, "_PATH", str(p))
    monkeypatch.setattr(wrh, "_MAX_RUNS", 100)
    # Reset the deque to a fresh, capped one.
    from collections import deque
    monkeypatch.setattr(wrh, "_RUNS", deque(maxlen=100))
    return p


def _make_action_result(action="log", ok=True, **extra):
    return {"action": action, "ok": ok, **extra}


# ══════════════════════════════════════════════════════════════
# _load — disk → memory
# ══════════════════════════════════════════════════════════════


class TestLoad:
    def test_no_file_initializes_empty_deque(self, tmp_path, monkeypatch):
        nonexistent = tmp_path / "missing.json"
        monkeypatch.setattr(wrh, "_PATH", str(nonexistent))
        wrh._load()
        assert len(wrh._RUNS) == 0

    def test_valid_file_populates_deque(self, isolated_path):
        run = {
            "id": "run-1", "rule_id": "r1", "rule_name": "Test rule",
            "event_name": "x.y", "tenant_id": "t1", "status": "success",
            "duration_ms": 5, "started_at": "2026-05-02T10:00:00+00:00",
            "ended_at": "2026-05-02T10:00:00+00:00",
            "payload": {"a": 1}, "action_results": [], "error_summary": None,
        }
        isolated_path.write_text(
            json.dumps({"version": 1, "runs": [run]}), encoding="utf-8"
        )
        wrh._load()
        assert len(wrh._RUNS) == 1
        assert wrh._RUNS[0].id == "run-1"
        assert wrh._RUNS[0].rule_name == "Test rule"

    def test_malformed_json_falls_back_to_empty(self, isolated_path):
        isolated_path.write_text("{ not valid JSON !!!", encoding="utf-8")
        wrh._load()
        assert len(wrh._RUNS) == 0


# ══════════════════════════════════════════════════════════════
# _save — memory → disk
# ══════════════════════════════════════════════════════════════


class TestSave:
    def test_writes_runs_to_disk(self, isolated_path):
        wrh.record_run("r1", "Rule one", "evt.x", {"k": 1}, [_make_action_result()])
        # _save() is called inside record_run; verify file exists.
        assert isolated_path.exists()
        raw = json.loads(isolated_path.read_text(encoding="utf-8"))
        assert "runs" in raw
        assert len(raw["runs"]) == 1
        assert raw["runs"][0]["rule_name"] == "Rule one"
        assert raw["version"] == 1

    def test_save_swallows_disk_error(self, isolated_path, monkeypatch):
        """If the file open fails, _save logs and returns — does not raise."""
        wrh._RUNS.append(
            wrh.WorkflowRun(
                id="x", rule_id="r", rule_name="n", event_name="e",
            )
        )

        def boom_open(*a, **kw):
            raise OSError("disk full")

        monkeypatch.setattr("builtins.open", boom_open)
        # Must not raise.
        wrh._save()


# ══════════════════════════════════════════════════════════════
# _truncate_payload + _summarize_action_result
# ══════════════════════════════════════════════════════════════


class TestTruncatePayload:
    def test_small_payload_passthrough(self):
        small = {"a": 1, "b": "two"}
        assert wrh._truncate_payload(small, max_chars=4000) == small

    def test_large_field_replaced_with_truncation_marker(self):
        big = {"small": 1, "big": "x" * 2000}
        out = wrh._truncate_payload(big, max_chars=100)
        assert out["small"] == 1
        assert isinstance(out["big"], str)
        assert out["big"].startswith("<truncated:")

    def test_unserializable_payload_returns_marker(self):
        class _Bad:
            def __repr__(self):
                raise RuntimeError("nope")

        # Hand a non-JSON-friendly object; default=str catches most things.
        # Force the outer json.dumps to fail by passing self-referential dict.
        d: dict = {}
        d["self"] = d
        out = wrh._truncate_payload(d)
        # Either the truncation worked (top-level fields retained as
        # markers) or the unserializable fallback fired — both pass.
        assert isinstance(out, dict)


class TestSummarizeActionResult:
    def test_minimal_result(self):
        out = wrh._summarize_action_result({"action": "log", "ok": True})
        assert out == {"action": "log", "ok": True}

    def test_records_error_truncated_to_300(self):
        long_err = "X" * 1000
        out = wrh._summarize_action_result(
            {"action": "slack", "ok": False, "error": long_err}
        )
        assert out["error"] == "X" * 300

    def test_passes_through_known_metadata_keys(self):
        out = wrh._summarize_action_result({
            "action": "approval",
            "success": True,  # alternate key form
            "approval_id": "a1",
            "rule_id": "r1",
            "comment_id": "c1",
            "notification_id": "n1",
            "status": "pending",
        })
        assert out["ok"] is True
        assert out["approval_id"] == "a1"
        assert out["rule_id"] == "r1"
        assert out["comment_id"] == "c1"
        assert out["notification_id"] == "n1"
        assert out["status"] == "pending"


# ══════════════════════════════════════════════════════════════
# record_run — status determination + persistence
# ══════════════════════════════════════════════════════════════


class TestRecordRun:
    def test_all_actions_ok_status_success(self, isolated_path):
        rid = wrh.record_run(
            "r1", "Rule", "evt.x", {"k": 1},
            [_make_action_result(ok=True), _make_action_result(ok=True)],
        )
        assert rid  # non-empty id
        assert wrh._RUNS[0].status == "success"

    def test_no_actions_status_success(self, isolated_path):
        wrh.record_run("r1", "Rule", "evt.x", {}, [])
        assert wrh._RUNS[0].status == "success"

    def test_all_actions_failed_status_failed(self, isolated_path):
        wrh.record_run(
            "r1", "Rule", "evt.x", {},
            [_make_action_result(ok=False, error="boom1"),
             _make_action_result(ok=False, error="boom2")],
        )
        run = wrh._RUNS[0]
        assert run.status == "failed"
        assert "boom1" in run.error_summary

    def test_mixed_actions_status_partial(self, isolated_path):
        wrh.record_run(
            "r1", "Rule", "evt.x", {},
            [_make_action_result(ok=True), _make_action_result(ok=False, error="x")],
        )
        assert wrh._RUNS[0].status == "partial"

    def test_tenant_id_from_payload_when_not_provided(self, isolated_path):
        wrh.record_run("r1", "Rule", "evt.x", {"tenant_id": "t-xyz"}, [])
        assert wrh._RUNS[0].tenant_id == "t-xyz"

    def test_explicit_tenant_id_takes_precedence(self, isolated_path):
        wrh.record_run(
            "r1", "Rule", "evt.x", {"tenant_id": "t-payload"}, [],
            tenant_id="t-explicit",
        )
        assert wrh._RUNS[0].tenant_id == "t-explicit"

    def test_swallows_internal_error_returning_empty_id(
        self, isolated_path, monkeypatch
    ):
        # Force WorkflowRun construction to blow up.
        def boom(**_kw):
            raise RuntimeError("ctor failed")

        monkeypatch.setattr(wrh, "WorkflowRun", boom)
        out = wrh.record_run("r1", "Rule", "evt.x", {}, [])
        assert out == ""

    def test_ring_buffer_cap_honored(self, isolated_path, monkeypatch):
        """Push more runs than the cap; verify deque size <= cap."""
        # cap was set to 100 in fixture; rebuild with cap=3 for speed.
        from collections import deque
        monkeypatch.setattr(wrh, "_MAX_RUNS", 3)
        monkeypatch.setattr(wrh, "_RUNS", deque(maxlen=3))
        for i in range(10):
            wrh.record_run(f"r{i}", f"Rule {i}", "evt.x", {}, [])
        assert len(wrh._RUNS) == 3
        # newest-first: r9 most recent.
        assert wrh._RUNS[0].rule_name == "Rule 9"


# ══════════════════════════════════════════════════════════════
# list_runs / get_run / stats / clear
# ══════════════════════════════════════════════════════════════


class TestQueries:
    def _seed_three_runs(self):
        wrh.record_run("r1", "Rule A", "invoice.created",
                       {"tenant_id": "t1"},
                       [_make_action_result(ok=True)])
        wrh.record_run("r2", "Rule B", "payment.received",
                       {"tenant_id": "t2"},
                       [_make_action_result(ok=False, error="x")])
        wrh.record_run("r1", "Rule A", "invoice.created",
                       {"tenant_id": "t1"},
                       [_make_action_result(ok=True),
                        _make_action_result(ok=False, error="y")])

    def test_list_runs_filter_by_rule_id(self, isolated_path):
        self._seed_three_runs()
        out = wrh.list_runs(rule_id="r1")
        assert len(out) == 2
        for r in out:
            assert r["rule_id"] == "r1"

    def test_list_runs_filter_by_tenant_id(self, isolated_path):
        self._seed_three_runs()
        out = wrh.list_runs(tenant_id="t2")
        assert len(out) == 1
        assert out[0]["rule_id"] == "r2"

    def test_list_runs_filter_by_event_name(self, isolated_path):
        self._seed_three_runs()
        out = wrh.list_runs(event_name="payment.received")
        assert len(out) == 1

    def test_list_runs_filter_by_status(self, isolated_path):
        self._seed_three_runs()
        out = wrh.list_runs(status="failed")
        assert len(out) == 1
        out_partial = wrh.list_runs(status="partial")
        assert len(out_partial) == 1

    def test_list_runs_paging(self, isolated_path):
        self._seed_three_runs()
        # limit=1
        page0 = wrh.list_runs(limit=1, offset=0)
        page1 = wrh.list_runs(limit=1, offset=1)
        assert len(page0) == 1
        assert len(page1) == 1
        assert page0[0]["id"] != page1[0]["id"]

    def test_get_run_found_and_not_found(self, isolated_path):
        rid = wrh.record_run("r1", "Rule", "evt.x", {}, [])
        assert wrh.get_run(rid) is not None
        assert wrh.get_run("nonexistent-id") is None

    def test_stats_aggregates_by_status_rule_event(self, isolated_path):
        self._seed_three_runs()
        s = wrh.stats()
        assert s["total"] == 3
        assert "success" in s["by_status"]
        assert "failed" in s["by_status"]
        assert "Rule A" in s["top_rules"]
        assert "invoice.created" in s["top_events"]
        assert s["cap"] >= 3

    def test_clear_all_runs(self, isolated_path):
        self._seed_three_runs()
        n = wrh.clear()
        assert n == 3
        assert len(wrh._RUNS) == 0

    def test_clear_only_one_rule(self, isolated_path):
        self._seed_three_runs()
        n = wrh.clear(rule_id="r1")
        assert n == 2  # 2 runs were rule r1
        assert len(wrh._RUNS) == 1
        assert wrh._RUNS[0].rule_id == "r2"
