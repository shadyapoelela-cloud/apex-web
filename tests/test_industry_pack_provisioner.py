"""APEX Platform -- app/core/industry_pack_provisioner.py unit tests.

Coverage target: ≥95% of 62 statements (G-T1.7b.4, Sprint 10).

Event-bus listener + workflow rule provisioning. We exercise:

  * `_safe_install_template` — import failure, template_not_found,
    required_params skip, materialize success, materialize raises.
  * `provision` — full success path, workflow failures captured,
    seed_coa flag + error handling, provision_widgets flag + error,
    flags-disabled paths, always emits at end.
  * `_on_pack_applied` — missing tenant_id, missing pack_id, full path.
  * `get_pack_template_map` — returns dict copy.
  * `manual_provision` — passthrough wrapper.

Mock strategy: monkeypatch `get_template`, `materialize`, `create_rule`,
`mark_provisioned`, and `emit` at module level. No real workflow store
mutation — all interactions captured in fakes.
"""

from __future__ import annotations

import sys
import types
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from app.core import industry_pack_provisioner as ipp


# ══════════════════════════════════════════════════════════════
# Fixtures
# ══════════════════════════════════════════════════════════════


@pytest.fixture
def emit_capture(monkeypatch):
    """Capture every `emit()` call inside industry_pack_provisioner."""
    calls = []

    def fake_emit(event_name, payload, *, source=None):
        calls.append({"event": event_name, "payload": payload, "source": source})

    monkeypatch.setattr(ipp, "emit", fake_emit)
    return calls


@pytest.fixture
def install_stubs(monkeypatch):
    """Install fake `app.core.workflow_templates` + `app.core.workflow_engine`
    + `app.core.industry_packs_service` modules.

    Returns the stub modules so tests can override per-call behavior.
    """
    # ── workflow_templates stub ──
    wt_stub = types.ModuleType("app.core.workflow_templates")

    def fake_get_template(tid):
        # Default: return a template with no required parameters.
        return SimpleNamespace(
            id=tid, parameters=[],
        )

    def fake_materialize(template, params):
        return {
            "name": f"Rule-from-{template.id}",
            "event_pattern": f"{template.id}.event",
            "conditions": [],
            "actions": [{"type": "log", "params": {}}],
            "description_ar": "وصف",
        }

    wt_stub.get_template = fake_get_template
    wt_stub.materialize = fake_materialize
    monkeypatch.setitem(sys.modules, "app.core.workflow_templates", wt_stub)

    # ── workflow_engine stub (only `create_rule` is used) ──
    we_stub = types.ModuleType("app.core.workflow_engine")
    create_calls = []

    def fake_create_rule(**kwargs):
        rule_id = f"rule-{len(create_calls)+1}"
        create_calls.append(kwargs)
        return SimpleNamespace(id=rule_id)

    we_stub.create_rule = fake_create_rule
    we_stub._calls = create_calls
    monkeypatch.setitem(sys.modules, "app.core.workflow_engine", we_stub)

    # ── industry_packs_service stub ──
    ips_stub = types.ModuleType("app.core.industry_packs_service")
    mark_calls = []

    def fake_mark(*a, **kw):
        mark_calls.append({"args": a, "kwargs": kw})

    ips_stub.mark_provisioned = fake_mark
    ips_stub._calls = mark_calls
    monkeypatch.setitem(sys.modules, "app.core.industry_packs_service", ips_stub)

    return SimpleNamespace(wt=wt_stub, we=we_stub, ips=ips_stub)


# ══════════════════════════════════════════════════════════════
# _safe_install_template
# ══════════════════════════════════════════════════════════════


class TestSafeInstallTemplate:
    def test_imports_failing_returns_error(self, monkeypatch):
        """If app.core.workflow_templates can't import, error is captured."""
        import builtins
        real_import = builtins.__import__

        def boom(name, *a, **kw):
            if name == "app.core.workflow_templates":
                raise ImportError("offline")
            return real_import(name, *a, **kw)

        monkeypatch.setattr(builtins, "__import__", boom)
        out = ipp._safe_install_template("any-tid", "t1")
        assert out["ok"] is False
        assert "imports:" in out["error"]
        assert out["template_id"] == "any-tid"

    def test_template_not_found(self, install_stubs):
        install_stubs.wt.get_template = lambda tid: None
        out = ipp._safe_install_template("missing-tid", "t1")
        assert out == {
            "template_id": "missing-tid",
            "ok": False,
            "error": "template_not_found",
        }

    def test_required_parameters_skip(self, install_stubs):
        # Template with a required parameter (default=None) is rejected.
        install_stubs.wt.get_template = lambda tid: SimpleNamespace(
            id=tid,
            parameters=[
                {"name": "approver", "default": None},
                {"name": "threshold", "default": 100},
            ],
        )
        out = ipp._safe_install_template("template-x", "t1")
        assert out["ok"] is False
        assert "required_params:approver" in out["error"]

    def test_happy_path_creates_rule(self, install_stubs):
        out = ipp._safe_install_template("anomaly-high-teams", "tenant-1")
        assert out["ok"] is True
        assert out["template_id"] == "anomaly-high-teams"
        assert out["rule_id"].startswith("rule-")
        # create_rule was actually called with tenant_id + name prefix.
        call = install_stubs.we._calls[-1]
        assert call["tenant_id"] == "tenant-1"
        assert call["name"].startswith("[tenant-1]")
        assert call["enabled"] is True

    def test_materialize_or_create_rule_failure_caught(self, install_stubs):
        def boom(*a, **kw):
            raise RuntimeError("rule creation failed")

        install_stubs.we.create_rule = boom
        out = ipp._safe_install_template("anomaly-high-teams", "t1")
        assert out["ok"] is False
        assert "rule creation failed" in out["error"]


# ══════════════════════════════════════════════════════════════
# provision — orchestration
# ══════════════════════════════════════════════════════════════


class TestProvision:
    def test_full_success_for_known_pack(self, install_stubs, emit_capture):
        # fnb_retail has 4 templates in _PACK_TEMPLATES.
        summary = ipp.provision("tenant-1", "fnb_retail")
        assert summary["tenant_id"] == "tenant-1"
        assert summary["pack_id"] == "fnb_retail"
        assert len(summary["workflows"]["installed"]) == 4
        assert len(summary["workflows"]["failed"]) == 0
        assert summary["coa_seeded"] is True
        assert summary["widgets_provisioned"] is True
        # Emit fired.
        assert len(emit_capture) == 1
        e = emit_capture[0]
        assert e["event"] == "industry_pack.provisioned"
        assert e["payload"]["workflows_installed"] == 4
        assert e["payload"]["workflows_failed"] == 0
        assert e["source"] == "industry_pack_provisioner"

    def test_unknown_pack_no_workflows_no_failures(
        self, install_stubs, emit_capture
    ):
        summary = ipp.provision("t1", "no-such-pack")
        # Unknown pack → no templates iterated → all empty.
        assert summary["workflows"]["installed"] == []
        assert summary["workflows"]["failed"] == []
        # coa_seeded + widgets still flipped (no error from stub).
        assert summary["coa_seeded"] is True
        assert summary["widgets_provisioned"] is True
        assert len(emit_capture) == 1

    def test_install_workflows_disabled(self, install_stubs, emit_capture):
        summary = ipp.provision("t1", "fnb_retail", install_workflows=False)
        assert summary["workflows"]["installed"] == []
        # coa + widgets still ran.
        assert summary["coa_seeded"] is True
        assert summary["widgets_provisioned"] is True

    def test_seed_coa_disabled(self, install_stubs, emit_capture):
        summary = ipp.provision("t1", "fnb_retail", seed_coa=False)
        assert summary["coa_seeded"] is False
        # widgets still ran.
        assert summary["widgets_provisioned"] is True

    def test_widgets_disabled(self, install_stubs, emit_capture):
        summary = ipp.provision("t1", "fnb_retail", provision_widgets=False)
        assert summary["widgets_provisioned"] is False
        assert summary["coa_seeded"] is True

    def test_coa_error_captured(self, install_stubs, emit_capture):
        # mark_provisioned raises → coa_error captured.
        call_count = {"n": 0}

        def selective_boom(*a, **kw):
            call_count["n"] += 1
            # First call (coa) raises; second call (widgets) succeeds.
            if call_count["n"] == 1:
                raise RuntimeError("DB locked")

        install_stubs.ips.mark_provisioned = selective_boom
        summary = ipp.provision("t1", "fnb_retail")
        assert summary["coa_seeded"] is False
        assert "DB locked" in summary["coa_error"]
        # Widgets path still ran.
        assert summary["widgets_provisioned"] is True

    def test_widgets_error_captured(self, install_stubs, emit_capture):
        call_count = {"n": 0}

        def selective_boom(*a, **kw):
            call_count["n"] += 1
            if call_count["n"] == 2:
                raise RuntimeError("widgets registry down")

        install_stubs.ips.mark_provisioned = selective_boom
        summary = ipp.provision("t1", "fnb_retail")
        assert summary["coa_seeded"] is True
        assert summary["widgets_provisioned"] is False
        assert "widgets registry down" in summary["widgets_error"]

    def test_workflow_failures_captured(self, install_stubs, emit_capture):
        # First template install fails; subsequent ones succeed.
        call_count = {"n": 0}
        original_get = install_stubs.wt.get_template

        def selective_get(tid):
            call_count["n"] += 1
            if call_count["n"] == 1:
                return None  # template_not_found
            return original_get(tid)

        install_stubs.wt.get_template = selective_get
        summary = ipp.provision("t1", "fnb_retail")
        assert len(summary["workflows"]["failed"]) == 1
        assert summary["workflows"]["failed"][0]["error"] == "template_not_found"
        # 3 of 4 succeeded.
        assert len(summary["workflows"]["installed"]) == 3


# ══════════════════════════════════════════════════════════════
# _on_pack_applied (event listener)
# ══════════════════════════════════════════════════════════════


class TestOnPackApplied:
    def test_full_path_calls_provision(self, install_stubs, emit_capture):
        # Direct call (NOT via emit) — listener triggers provision().
        ipp._on_pack_applied(
            "industry_pack.applied",
            {"tenant_id": "t1", "pack_id": "services"},
        )
        # provision() emits exactly one industry_pack.provisioned event.
        assert any(
            c["event"] == "industry_pack.provisioned" for c in emit_capture
        )

    def test_missing_tenant_id_skipped(self, install_stubs, emit_capture):
        ipp._on_pack_applied(
            "industry_pack.applied",
            {"pack_id": "services"},  # no tenant_id
        )
        # Nothing emitted; provision never ran.
        assert emit_capture == []

    def test_missing_pack_id_skipped(self, install_stubs, emit_capture):
        ipp._on_pack_applied(
            "industry_pack.applied",
            {"tenant_id": "t1"},  # no pack_id
        )
        assert emit_capture == []


# ══════════════════════════════════════════════════════════════
# Public introspection helpers
# ══════════════════════════════════════════════════════════════


class TestPublicAPI:
    def test_get_pack_template_map_returns_copy(self):
        m = ipp.get_pack_template_map()
        assert isinstance(m, dict)
        assert "fnb_retail" in m
        # Mutating the copy must not affect the source.
        m["fnb_retail"].clear()
        assert len(ipp._PACK_TEMPLATES["fnb_retail"]) > 0

    def test_manual_provision_passes_through(self, install_stubs, emit_capture):
        out = ipp.manual_provision(
            "t1", "logistics",
            seed_coa=False, install_workflows=True, provision_widgets=False,
        )
        assert out["coa_seeded"] is False
        assert out["widgets_provisioned"] is False
        # Workflow path ran.
        assert len(out["workflows"]["installed"]) > 0
