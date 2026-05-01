"""APEX Platform -- app/core/workflow_engine.py unit tests.

Coverage target: ≥85% of 287 statements (G-T1.7b.2, Sprint 10).

Workflow engine: JSON storage + condition/action evaluator + event
listener integration. Tests are condensed (parametrized where natural)
to fit the 100-test G-T1.7b.2 budget.

Mock strategy:
  * `_RULES_FILE` redirected to `tmp_path` per test; `_RULES` reset.
  * External integrations (slack/teams/email/notify/webhook/approvals)
    monkeypatched via `sys.modules` stubs in the same pattern that
    G-T1.7b.1 used for the Stripe SDK.
"""

from __future__ import annotations

import json
import sys
import types

import pytest

from app.core import workflow_engine as we


# ══════════════════════════════════════════════════════════════
# Fixtures
# ══════════════════════════════════════════════════════════════


@pytest.fixture
def isolated_engine(tmp_path, monkeypatch):
    """Redirect persistence path + reset rules dict between tests."""
    p = tmp_path / "rules.json"
    monkeypatch.setattr(we, "_RULES_FILE", str(p))
    monkeypatch.setattr(we, "_RULES", {})
    return p


@pytest.fixture
def stub_integrations(monkeypatch):
    """Install stub modules for slack/teams/email/notify/requests/approvals."""
    # --- slack/teams ---
    slack_stub = types.ModuleType("app.core.slack_backend")
    slack_stub.send_slack_notification = lambda **kw: {"ok": True, "via": "slack-stub"}
    monkeypatch.setitem(sys.modules, "app.core.slack_backend", slack_stub)

    teams_stub = types.ModuleType("app.core.teams_backend")
    teams_stub.send_teams_notification = lambda **kw: {"ok": True, "via": "teams-stub"}
    monkeypatch.setitem(sys.modules, "app.core.teams_backend", teams_stub)

    # --- email ---
    email_stub = types.ModuleType("app.core.email_service")
    email_stub.send_email = lambda **kw: {"ok": True, "to": kw.get("to")}
    monkeypatch.setitem(sys.modules, "app.core.email_service", email_stub)

    # --- notify ---
    # NotificationService lives at app.phase10.services.notification_service —
    # but it's already installed; override its emit_notification only.
    import app.phase10.services.notification_service as ns
    monkeypatch.setattr(
        ns, "emit_notification",
        lambda **kw: {"ok": True, "user_id": kw.get("user_id")},
    )

    # --- approvals ---
    approvals_stub = types.ModuleType("app.core.approvals")

    class _Approval:
        def __init__(self, **kw):
            self.id = "approval-stub-1"

    approvals_stub.create_approval = lambda **kw: _Approval(**kw)
    monkeypatch.setitem(sys.modules, "app.core.approvals", approvals_stub)


@pytest.fixture
def stub_requests(monkeypatch):
    """Install a stub `requests` module for webhook tests."""
    requests_stub = types.ModuleType("requests")

    class _Resp:
        def __init__(self, status_code=200):
            self.status_code = status_code

    def _post(url, json=None, timeout=None):
        # Echo status_code from URL if it contains "/500" (test toggle).
        return _Resp(500 if "/fail" in url else 200)

    requests_stub.post = _post
    monkeypatch.setitem(sys.modules, "requests", requests_stub)


def _make_action(typ="log", **params):
    return {"type": typ, "params": params}


# ══════════════════════════════════════════════════════════════
# Persistence: _load, _save, _serialize, _deserialize
# ══════════════════════════════════════════════════════════════


class TestPersistence:
    def test_load_no_file_starts_empty(self, isolated_engine):
        we._load()
        assert we._RULES == {}

    def test_load_valid_file(self, isolated_engine):
        rule_dict = {
            "id": "r1", "name": "Rule 1", "event_pattern": "x.*",
            "conditions": [{"field": "a", "operator": "eq", "value": 1}],
            "actions": [{"type": "log", "params": {"message": "hi"}}],
            "enabled": True,
        }
        isolated_engine.write_text(
            json.dumps({"version": 1, "rules": [rule_dict]}), encoding="utf-8"
        )
        we._load()
        assert "r1" in we._RULES
        assert we._RULES["r1"].name == "Rule 1"
        assert len(we._RULES["r1"].conditions) == 1
        assert we._RULES["r1"].conditions[0].field == "a"

    def test_load_malformed_json_falls_back_to_empty(self, isolated_engine):
        isolated_engine.write_text("{ not json }", encoding="utf-8")
        we._load()
        assert we._RULES == {}

    def test_save_after_create_writes_file(self, isolated_engine):
        we.create_rule("Rule A", "evt.x")
        assert isolated_engine.exists()
        raw = json.loads(isolated_engine.read_text(encoding="utf-8"))
        assert len(raw["rules"]) == 1
        assert raw["rules"][0]["name"] == "Rule A"


# ══════════════════════════════════════════════════════════════
# CRUD
# ══════════════════════════════════════════════════════════════


class TestCRUD:
    def test_create_get_update_delete_cycle(self, isolated_engine):
        rule = we.create_rule(
            "Rule A", "evt.x",
            conditions=[{"field": "amount", "operator": "gt", "value": 100}],
            actions=[{"type": "log", "params": {"message": "fired"}}],
            description_ar="تجريبي",
            owner_user_id="u1",
            tenant_id="t1",
            enabled=True,
        )
        assert rule.id in we._RULES
        # get_rule
        assert we.get_rule(rule.id) is rule
        assert we.get_rule("nonexistent") is None
        # update_rule — replace conditions and actions, change name
        updated = we.update_rule(
            rule.id,
            name="Rule A v2",
            conditions=[{"field": "x", "operator": "eq", "value": 1}],
            actions=[{"type": "log", "params": {}}],
            enabled=False,
        )
        assert updated.name == "Rule A v2"
        assert updated.enabled is False
        assert updated.conditions[0].field == "x"
        # update_rule — passing already-typed objects (Condition / Action)
        updated2 = we.update_rule(
            rule.id,
            conditions=[we.Condition(field="y", operator="eq", value=2)],
            actions=[we.Action(type="log", params={})],
        )
        assert updated2.conditions[0].field == "y"
        # update_rule — unknown rule → None
        assert we.update_rule("missing-id", name="x") is None
        # delete_rule
        assert we.delete_rule(rule.id) is True
        assert we.delete_rule(rule.id) is False

    def test_list_rules_tenant_scoping(self, isolated_engine):
        # Global rule (tenant_id None) + two tenant-scoped rules.
        we.create_rule("Global", "evt.*")
        we.create_rule("T1 only", "evt.*", tenant_id="t1")
        we.create_rule("T2 only", "evt.*", tenant_id="t2")
        # No filter → all three.
        assert len(we.list_rules()) == 3
        # tenant_id="t1" → global + t1 (2 rules)
        names_t1 = {r.name for r in we.list_rules(tenant_id="t1")}
        assert names_t1 == {"Global", "T1 only"}


# ══════════════════════════════════════════════════════════════
# Helpers: _resolve_path, _to_number
# ══════════════════════════════════════════════════════════════


class TestPathResolution:
    def test_resolve_path_simple_and_nested(self):
        assert we._resolve_path({"a": 1}, "a") == 1
        assert we._resolve_path({"a": {"b": {"c": 5}}}, "a.b.c") == 5
        # Missing segment → None
        assert we._resolve_path({"a": 1}, "a.b") is None
        assert we._resolve_path({}, "anything") is None

    def test_to_number_casts(self):
        assert we._to_number("42") == 42.0
        assert we._to_number(3.14) == 3.14
        assert we._to_number(None) is None
        assert we._to_number("not a number") is None


# ══════════════════════════════════════════════════════════════
# evaluate_condition / evaluate_conditions
# ══════════════════════════════════════════════════════════════


class TestConditionEvaluation:
    @pytest.mark.parametrize("op,actual,expected,result", [
        ("eq", 5, 5, True),
        ("eq", 5, 6, False),
        ("ne", 5, 6, True),
        ("ne", 5, 5, False),
        ("gt", 10, 5, True),
        ("gt", 5, 10, False),
        ("gte", 5, 5, True),
        ("lt", 5, 10, True),
        ("lte", 5, 5, True),
        ("contains", "hello world", "world", True),
        ("contains", "hello", "world", False),
        ("starts_with", "hello", "hel", True),
        ("ends_with", "hello", "llo", True),
        ("in", "b", ["a", "b", "c"], True),
        ("in", "z", ["a", "b", "c"], False),
        ("in", "x", "not-a-list", False),  # non-iterable falls False
        ("gt", "abc", 5, False),  # non-numeric → False
        ("unknown_op", 1, 1, False),  # unknown operator
    ])
    def test_operator_matrix(self, op, actual, expected, result):
        cond = we.Condition(field="x", operator=op, value=expected)
        assert we.evaluate_condition(cond, {"x": actual}) is result

    def test_case_insensitive_string_match(self):
        cond = we.Condition(
            field="x", operator="contains", value="WORLD", case_sensitive=False
        )
        assert we.evaluate_condition(cond, {"x": "Hello world"}) is True

    def test_evaluate_conditions_all_must_pass(self):
        rule = we.WorkflowRule(
            id="r", name="n", event_pattern="*",
            conditions=[
                we.Condition(field="amount", operator="gt", value=100),
                we.Condition(field="status", operator="eq", value="open"),
            ],
        )
        assert we.evaluate_conditions(rule, {"amount": 200, "status": "open"}) is True
        assert we.evaluate_conditions(rule, {"amount": 50, "status": "open"}) is False

    def test_evaluate_conditions_empty_list_always_true(self):
        rule = we.WorkflowRule(id="r", name="n", event_pattern="*", conditions=[])
        assert we.evaluate_conditions(rule, {}) is True


# ══════════════════════════════════════════════════════════════
# _resolve_template
# ══════════════════════════════════════════════════════════════


class TestResolveTemplate:
    def test_replaces_payload_dotted_paths(self):
        out = we._resolve_template(
            "Invoice {payload.invoice.number} for {payload.customer.name}",
            {"invoice": {"number": "INV-1"}, "customer": {"name": "Acme"}},
        )
        assert out == "Invoice INV-1 for Acme"

    def test_replaces_bare_paths_and_unresolved_blanks(self):
        out = we._resolve_template("Hello {name}, missing={missing.field}", {"name": "X"})
        assert out == "Hello X, missing="

    def test_non_string_passthrough(self):
        # The function is annotated as string-only but defensively passes
        # non-strings through.
        assert we._resolve_template(123, {}) == 123  # type: ignore[arg-type]


# ══════════════════════════════════════════════════════════════
# execute_action — every action type
# ══════════════════════════════════════════════════════════════


class TestExecuteAction:
    def _rule(self):
        return we.WorkflowRule(id="r", name="Rule", event_pattern="*")

    def test_log_action(self):
        out = we.execute_action(
            we.Action(type="log", params={"message": "hello {payload.x}"}),
            {"x": "world"},
            self._rule(),
        )
        assert out["ok"] is True
        assert out["action"] == "log"
        assert "hello world" in out["message"]

    def test_slack_action(self, stub_integrations):
        out = we.execute_action(
            we.Action(type="slack", params={"title": "T", "body": "B"}),
            {}, self._rule(),
        )
        assert out["ok"] is True
        assert out["via"] == "slack-stub"

    def test_teams_action(self, stub_integrations):
        out = we.execute_action(
            we.Action(type="teams", params={"title": "T", "body": "B"}),
            {}, self._rule(),
        )
        assert out["ok"] is True
        assert out["via"] == "teams-stub"

    def test_email_action_happy(self, stub_integrations):
        out = we.execute_action(
            we.Action(type="email", params={"to": "a@b.com", "subject": "S"}),
            {}, self._rule(),
        )
        assert out["ok"] is True
        assert out["to"] == "a@b.com"

    def test_email_action_missing_to(self, stub_integrations):
        out = we.execute_action(
            we.Action(type="email", params={}),
            {}, self._rule(),
        )
        assert out["ok"] is False
        assert out["error"] == "missing_to"

    def test_notify_action_happy(self, stub_integrations):
        out = we.execute_action(
            we.Action(type="notify",
                      params={"user_id": "u1", "body_ar": "م", "body_en": "e"}),
            {}, self._rule(),
        )
        assert out["ok"] is True
        assert out["user_id"] == "u1"

    def test_notify_action_missing_user_id(self, stub_integrations):
        out = we.execute_action(
            we.Action(type="notify", params={}),
            {}, self._rule(),
        )
        assert out["ok"] is False
        assert out["error"] == "missing_user_id"

    def test_webhook_success_and_fail(self, stub_requests):
        ok = we.execute_action(
            we.Action(type="webhook", params={"url": "http://hook.test/ok"}),
            {}, self._rule(),
        )
        assert ok["ok"] is True
        assert ok["status"] == 200
        bad = we.execute_action(
            we.Action(type="webhook", params={"url": "http://hook.test/fail"}),
            {}, self._rule(),
        )
        assert bad["ok"] is False
        assert bad["status"] == 500

    def test_webhook_missing_url(self, stub_requests):
        out = we.execute_action(
            we.Action(type="webhook", params={}),
            {}, self._rule(),
        )
        assert out["ok"] is False
        assert out["error"] == "missing_url"

    def test_webhook_request_raises(self, monkeypatch, stub_requests):
        # Replace .post on the already-injected stub with a raiser.
        sys.modules["requests"].post = lambda *a, **kw: (_ for _ in ()).throw(
            RuntimeError("network down")
        )
        out = we.execute_action(
            we.Action(type="webhook", params={"url": "http://hook.test/ok"}),
            {}, self._rule(),
        )
        assert out["ok"] is False
        assert "network down" in out["error"]

    def test_approval_action_happy(self, stub_integrations):
        out = we.execute_action(
            we.Action(type="approval", params={
                "approver_user_ids": ["u1", "u2"],
                "title_ar": "موافقة",
                "object_type": "invoice",
                "object_id_field": "invoice_id",
            }),
            {"invoice_id": "INV-1", "tenant_id": "t1"}, self._rule(),
        )
        assert out["ok"] is True
        assert out["approval_id"] == "approval-stub-1"

    def test_approval_via_user_id_field(self, stub_integrations):
        out = we.execute_action(
            we.Action(type="approval", params={
                "approver_user_id_field": "owner_id",
                "title_ar": "م",
            }),
            {"owner_id": "u-owner"}, self._rule(),
        )
        assert out["ok"] is True

    def test_approval_missing_approvers(self, stub_integrations):
        out = we.execute_action(
            we.Action(type="approval", params={"title_ar": "م"}),
            {}, self._rule(),
        )
        assert out["ok"] is False
        assert out["error"] == "missing_approver_user_ids"

    def test_unknown_action_type(self):
        out = we.execute_action(
            we.Action(type="quantum", params={}), {}, self._rule(),
        )
        assert out["ok"] is False
        assert out["error"].startswith("unknown_action")

    def test_action_raising_is_caught(self, stub_integrations, monkeypatch):
        # Force email to raise.
        sys.modules["app.core.email_service"].send_email = (
            lambda **kw: (_ for _ in ()).throw(RuntimeError("smtp dead"))
        )
        out = we.execute_action(
            we.Action(type="email", params={"to": "a@b.com"}),
            {}, self._rule(),
        )
        assert out["ok"] is False
        assert "smtp dead" in out["error"]


# ══════════════════════════════════════════════════════════════
# Engine: _matches_pattern, process_event, helpers
# ══════════════════════════════════════════════════════════════


class TestPatternMatching:
    @pytest.mark.parametrize("pattern,name,result", [
        ("*", "anything.here", True),
        ("invoice.created", "invoice.created", True),
        ("invoice.created", "invoice.updated", False),
        ("invoice.*", "invoice.created", True),
        ("invoice.*", "payment.received", False),
        ("invoice.*", "invoice", False),  # no dot following prefix
    ])
    def test_pattern_matching(self, pattern, name, result):
        assert we._matches_pattern(pattern, name) is result


class TestProcessEvent:
    def test_full_path_executes_matching_rule_and_logs_run(
        self, isolated_engine, stub_integrations
    ):
        rule = we.create_rule(
            "Big invoice", "invoice.created",
            conditions=[{"field": "total", "operator": "gt", "value": 1000}],
            actions=[{"type": "log", "params": {"message": "alert!"}}],
        )
        results = we.process_event(
            "invoice.created", {"total": 5000, "tenant_id": "t1"}
        )
        assert len(results) == 1
        assert results[0]["rule_id"] == rule.id
        assert results[0]["actions"][0]["ok"] is True
        # run_count incremented + last_run_at set.
        r = we.get_rule(rule.id)
        assert r.run_count == 1
        assert r.last_run_at is not None
        assert r.last_error is None

    def test_disabled_rule_skipped(self, isolated_engine):
        we.create_rule("Disabled", "invoice.created",
                       actions=[{"type": "log", "params": {}}], enabled=False)
        out = we.process_event("invoice.created", {})
        assert out == []

    def test_pattern_mismatch_skipped(self, isolated_engine):
        we.create_rule("R", "invoice.created",
                       actions=[{"type": "log", "params": {}}])
        assert we.process_event("payment.received", {}) == []

    def test_tenant_mismatch_skipped(self, isolated_engine):
        we.create_rule("R", "invoice.*",
                       actions=[{"type": "log", "params": {}}], tenant_id="t1")
        assert we.process_event("invoice.created", {"tenant_id": "t2"}) == []

    def test_failed_conditions_skipped(self, isolated_engine):
        we.create_rule(
            "R", "invoice.*",
            conditions=[{"field": "total", "operator": "gt", "value": 10000}],
            actions=[{"type": "log", "params": {}}],
        )
        out = we.process_event("invoice.created", {"total": 50})
        assert out == []

    def test_failed_action_records_last_error(self, isolated_engine, stub_integrations):
        # email with no `to` returns ok=False — last_error captures it.
        rule = we.create_rule(
            "Bad email", "invoice.*",
            actions=[{"type": "email", "params": {}}],
        )
        we.process_event("invoice.created", {})
        r = we.get_rule(rule.id)
        assert r.last_error is not None
        assert "missing_to" in r.last_error


# ══════════════════════════════════════════════════════════════
# stats + validate_event_name
# ══════════════════════════════════════════════════════════════


class TestStatsAndValidation:
    def test_stats_reflects_enabled_disabled_split(self, isolated_engine):
        we.create_rule("R1", "*")
        we.create_rule("R2", "*", enabled=False)
        s = we.stats()
        assert s["rules_total"] == 2
        assert s["rules_enabled"] == 1
        assert s["rules_disabled"] == 1
        assert "storage_path" in s

    def test_validate_event_name_branches(self):
        assert we.validate_event_name("*")["kind"] == "wildcard"
        assert we.validate_event_name("invoice.*")["kind"] == "wildcard"
        # Exact name path (known or unknown — both return kind=exact).
        out = we.validate_event_name("totally.unknown.event")
        assert out["kind"] == "exact"
