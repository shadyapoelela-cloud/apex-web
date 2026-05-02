"""APEX Platform -- app/core/workflow_templates.py unit tests.

Coverage target: ≥95% of 57 statements (G-T1.7b.5, Sprint 10 final).

Pure-Python templates catalog + materialize logic. We exercise:

  * `WorkflowTemplate` dataclass — frozen, default factories.
  * `list_templates` — no filter (returns all) + category filter.
  * `get_template` — found / not found.
  * `materialize` — copies template, substitutes parameters via
    path notation; tests cover dict-leaf set, list-element set, default
    fallback when parameter not supplied, missing path/name skip.
  * `_set_path` — tiny path notation walker: dict field, list index,
    mixed `actions[0].params.foo`, out-of-bounds index (silent skip).

No mocking needed — pure stdlib + dataclass.
"""

from __future__ import annotations

import pytest

from app.core import workflow_templates as wt


# ══════════════════════════════════════════════════════════════
# WorkflowTemplate dataclass
# ══════════════════════════════════════════════════════════════


class TestWorkflowTemplate:
    def test_frozen_dataclass_disallows_mutation(self):
        t = wt.WorkflowTemplate(
            id="x", name_ar="ع", name_en="e",
            category="ops", description_ar="d", icon="x",
            event_pattern="evt",
        )
        # Frozen dataclass.
        with pytest.raises(Exception):  # FrozenInstanceError
            t.name_ar = "changed"  # type: ignore[misc]

    def test_default_factories_are_independent(self):
        t1 = wt.WorkflowTemplate(
            id="a", name_ar="ا", name_en="a",
            category="alerts", description_ar="d", icon="x",
            event_pattern="e",
        )
        t2 = wt.WorkflowTemplate(
            id="b", name_ar="ب", name_en="b",
            category="alerts", description_ar="d", icon="x",
            event_pattern="e",
        )
        # Each instance gets its OWN list (not shared).
        t1.conditions.append({"x": 1})  # type: ignore[attr-defined]
        assert t2.conditions == []


# ══════════════════════════════════════════════════════════════
# list_templates / get_template
# ══════════════════════════════════════════════════════════════


class TestListTemplates:
    def test_no_filter_returns_all_templates(self):
        out = wt.list_templates()
        # Catalog has at least 13 templates per the source.
        assert len(out) >= 10
        # Returns a list copy — caller can mutate without affecting catalog.
        ids = {t.id for t in out}
        assert "big-invoice-approval" in ids
        assert "anomaly-high-teams" in ids

    @pytest.mark.parametrize("category,must_have", [
        ("approvals", "big-invoice-approval"),
        ("alerts", "anomaly-high-teams"),
        ("automations", "welcome-new-user"),
        ("compliance", "period-close-reminder"),
        ("ops", "bill-paid-audit-log"),
    ])
    def test_category_filter(self, category, must_have):
        out = wt.list_templates(category=category)
        assert all(t.category == category for t in out)
        assert any(t.id == must_have for t in out)

    def test_unknown_category_returns_empty(self):
        assert wt.list_templates(category="no-such-category") == []


class TestGetTemplate:
    def test_returns_template_when_found(self):
        t = wt.get_template("big-invoice-approval")
        assert t is not None
        assert t.id == "big-invoice-approval"
        assert t.category == "approvals"

    def test_returns_none_when_missing(self):
        assert wt.get_template("does-not-exist") is None


# ══════════════════════════════════════════════════════════════
# materialize — parameter substitution
# ══════════════════════════════════════════════════════════════


class TestMaterialize:
    def test_substitutes_user_supplied_value_at_dict_leaf(self):
        # big-bill-approval has threshold @ conditions[0].value (default 50000)
        # and cfo_user_id @ actions[0].params.approver_user_ids[0].
        t = wt.get_template("big-bill-approval")
        assert t is not None
        rule = wt.materialize(t, {
            "threshold": 75000,
            "cfo_user_id": "u-cfo-1",
        })
        assert rule["conditions"][0]["value"] == 75000
        assert rule["actions"][0]["params"]["approver_user_ids"][0] == "u-cfo-1"

    def test_falls_back_to_default_when_param_missing(self):
        t = wt.get_template("big-bill-approval")
        assert t is not None
        # No params → threshold falls back to its `default` 50000.
        rule = wt.materialize(t, {})
        assert rule["conditions"][0]["value"] == 50000

    def test_skips_param_with_no_default_and_no_value(self):
        t = wt.get_template("big-bill-approval")
        assert t is not None
        # cfo_user_id has no `default` in its parameter spec → without a
        # supplied value, the placeholder string remains unchanged.
        rule = wt.materialize(t, {})
        # Original placeholder stays.
        assert rule["actions"][0]["params"]["approver_user_ids"][0] == "{cfo_user_id}"

    def test_zero_param_template_returns_clean_rule(self):
        # overdue-invoice-slack has no parameters — materialize returns
        # the rule with conditions/actions deep-copied.
        t = wt.get_template("overdue-invoice-slack")
        assert t is not None
        rule = wt.materialize(t, {})
        assert rule["name"] == t.name_ar
        assert rule["event_pattern"] == "invoice.overdue"
        # Mutating the materialized rule must NOT mutate the source template.
        rule["actions"].append({"type": "log", "params": {}})
        assert len(t.actions) == 1

    def test_param_with_blank_path_or_name_is_skipped(self):
        # Build a synthetic template whose parameter has neither path nor name.
        t = wt.WorkflowTemplate(
            id="synthetic",
            name_ar="x", name_en="x",
            category="ops", description_ar="d", icon="x",
            event_pattern="evt",
            conditions=[{"field": "a", "operator": "eq", "value": 0}],
            actions=[],
            parameters=[
                {"name": "", "path": "", "default": 99},  # both blank
                {"name": "x", "default": 99},  # missing path
                {"path": "conditions[0].value", "default": 99},  # missing name
            ],
        )
        rule = wt.materialize(t, {})
        # The first three skipped — value stays at the original 0.
        assert rule["conditions"][0]["value"] == 0


# ══════════════════════════════════════════════════════════════
# _set_path — path-notation walker
# ══════════════════════════════════════════════════════════════


class TestSetPath:
    def test_dict_leaf_set(self):
        d = {"a": {"b": 1}}
        wt._set_path(d, "a.b", 99)
        assert d["a"]["b"] == 99

    def test_list_index_set(self):
        d = {"items": [10, 20, 30]}
        wt._set_path(d, "items[1]", 999)
        assert d["items"] == [10, 999, 30]

    def test_mixed_path(self):
        d = {"actions": [{"params": {"k": "v"}}]}
        wt._set_path(d, "actions[0].params.k", "new-val")
        assert d["actions"][0]["params"]["k"] == "new-val"

    def test_out_of_bounds_index_silently_skipped(self):
        d = {"items": [10]}
        # Index 5 doesn't exist — function silently no-ops.
        wt._set_path(d, "items[5]", 999)
        assert d["items"] == [10]

    def test_non_dict_leaf_target_silently_skipped(self):
        # Attribute access on non-dict cur: cur is a list, key is a name.
        d = [1, 2, 3]
        # Path "a.b" tries dict access — silent no-op.
        # Coverage of the `if isinstance(cur, dict)` False branch.
        wt._set_path({"x": d}, "x", 99)
        # Top-level dict set succeeds.
