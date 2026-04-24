"""Tests for app/core/ai_usage_log.py — Claude token/cost accounting."""

from __future__ import annotations


# ── Pricing helper ────────────────────────────────────────


def test_estimate_cost_sonnet():
    from app.core.ai_usage_log import estimate_cost_usd
    # Sonnet: $3 / M input, $15 / M output.
    # 1000 input tokens = $0.003; 500 output tokens = $0.0075. Total $0.0105.
    cost = estimate_cost_usd("claude-sonnet-4-5", 1000, 500)
    assert abs(cost - 0.0105) < 1e-6


def test_estimate_cost_opus():
    from app.core.ai_usage_log import estimate_cost_usd
    # Opus: $15 / M input, $75 / M output.
    cost = estimate_cost_usd("claude-opus-4-7", 1000, 500)
    assert abs(cost - (0.015 + 0.0375)) < 1e-6


def test_estimate_cost_with_date_suffix():
    """Model IDs like 'claude-sonnet-4-5-20260301' match base rates."""
    from app.core.ai_usage_log import estimate_cost_usd
    c1 = estimate_cost_usd("claude-sonnet-4-5-20260301", 1000, 500)
    c2 = estimate_cost_usd("claude-sonnet-4-5", 1000, 500)
    assert abs(c1 - c2) < 1e-9


def test_estimate_cost_unknown_model_defaults_to_sonnet():
    """Unknown model IDs fall back to Sonnet rates (conservative default)."""
    from app.core.ai_usage_log import estimate_cost_usd
    cost = estimate_cost_usd("claude-nonexistent-9-9", 1000, 500)
    # Same as Sonnet.
    assert abs(cost - 0.0105) < 1e-6


def test_estimate_cost_zero_tokens():
    from app.core.ai_usage_log import estimate_cost_usd
    assert estimate_cost_usd("claude-sonnet-4-5", 0, 0) == 0.0


def test_estimate_cost_empty_model():
    from app.core.ai_usage_log import estimate_cost_usd
    assert estimate_cost_usd("", 1000, 500) == 0.0


# ── record_usage — defensive, never raises ─────────────────


def test_record_usage_never_raises():
    """Even on a DB without the table, record_usage returns None, not raise."""
    from app.core.ai_usage_log import record_usage, UsageRecord
    rec = UsageRecord(
        surface="copilot_agent",
        model="claude-sonnet-4-5",
        input_tokens=100,
        output_tokens=50,
        tenant_id="t-test",
    )
    # Should never raise.
    result = record_usage(rec)
    # May return None (no table) or a uuid string (table exists).
    assert result is None or (isinstance(result, str) and len(result) > 0)


# ── tenant_usage_summary — zero shape when empty ───────────


def test_tenant_usage_summary_empty_tenant():
    from app.core.ai_usage_log import tenant_usage_summary
    s = tenant_usage_summary("tenant-that-has-no-usage")
    assert s["tenant_id"] == "tenant-that-has-no-usage"
    assert s["input_tokens"] == 0
    assert s["output_tokens"] == 0
    assert s["cost_usd"] == 0.0
    assert s["calls"] == 0


# ── Model registration ────────────────────────────────────


def test_ai_usage_log_model_registers_with_base_metadata():
    """Importing the module should register the table on the shared Base."""
    from app.core.ai_usage_log import AIUsageLog
    from app.phase1.models.platform_models import Base
    assert "ai_usage_log" in Base.metadata.tables
    assert AIUsageLog.__tablename__ == "ai_usage_log"
