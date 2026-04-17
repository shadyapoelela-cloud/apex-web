"""Tests for the 4 new Copilot agent tools (create_invoice, send_reminder,
generate_report, categorize_transaction).

Focused on the tool IMPLEMENTATIONS — the Claude tool_use plumbing is
already covered by the existing test_hr_routes_pdf_ap_copilot.py.
"""

from __future__ import annotations


def test_tool_definitions_include_new_four():
    """The registry exposes the 4 new tools with proper JSON schemas."""
    from app.services.copilot_agent import TOOL_DEFINITIONS

    names = {t["name"] for t in TOOL_DEFINITIONS}
    for t in ("create_invoice", "send_reminder", "generate_report",
              "categorize_transaction"):
        assert t in names, f"{t} missing from registry"

    # Pull create_invoice and verify its schema shape
    ci = next(t for t in TOOL_DEFINITIONS if t["name"] == "create_invoice")
    assert ci["input_schema"]["required"] == ["client_name", "description", "amount"]


def test_tool_impls_registered_for_all_new_tools():
    from app.services.copilot_agent import TOOL_IMPLS

    for t in ("create_invoice", "send_reminder", "generate_report",
              "categorize_transaction"):
        assert callable(TOOL_IMPLS.get(t)), f"{t} impl missing"


def test_create_invoice_produces_draft_with_correct_vat():
    from app.services.copilot_agent import TOOL_IMPLS

    result = TOOL_IMPLS["create_invoice"]({
        "client_name": "شركة الرياض",
        "description": "استشارات محاسبية",
        "amount": 1000,
        "vat_rate": 15,
    })
    assert result["status"] == "draft"
    assert result["draft_id"].startswith("draft_")
    assert result["subtotal"] == 1000
    assert abs(result["vat_amount"] - 150) < 0.01
    assert abs(result["grand_total"] - 1150) < 0.01
    assert result["requires_confirmation"] is True


def test_create_invoice_rejects_missing_fields():
    from app.services.copilot_agent import TOOL_IMPLS

    bad = TOOL_IMPLS["create_invoice"]({"client_name": "", "description": "x", "amount": 100})
    assert bad["status"] == "rejected"

    zero = TOOL_IMPLS["create_invoice"]({"client_name": "A", "description": "B", "amount": 0})
    assert zero["status"] == "rejected"


def test_send_reminder_rejects_no_target():
    from app.services.copilot_agent import TOOL_IMPLS
    r = TOOL_IMPLS["send_reminder"]({})
    assert r["status"] == "rejected"


def test_send_reminder_queues_when_given_invoice_id():
    from app.services.copilot_agent import TOOL_IMPLS
    r = TOOL_IMPLS["send_reminder"]({"invoice_id": "INV-42", "channel": "whatsapp"})
    assert r["status"] == "queued"
    assert r["channel"] == "whatsapp"
    assert r["requires_confirmation"] is True


def test_generate_report_returns_download_url():
    from app.services.copilot_agent import TOOL_IMPLS
    r = TOOL_IMPLS["generate_report"]({
        "report_type": "profit_and_loss",
        "period": "2026-04-01:2026-04-30",
        "format": "excel",
    })
    assert r["format"] == "excel"
    assert r["report_type"] == "profit_and_loss"
    assert r["download_url"].startswith("/api/v1/reports/download/")


def test_categorize_transaction_picks_up_netflix():
    from app.services.copilot_agent import TOOL_IMPLS
    r = TOOL_IMPLS["categorize_transaction"]({
        "description": "NETFLIX.COM monthly",
        "amount": 45,
    })
    assert r["account_code"] == "5501"
    assert r["matched_on"] == "netflix"
    assert r["confidence"] > 0.9


def test_categorize_transaction_picks_up_arabic_gosi():
    from app.services.copilot_agent import TOOL_IMPLS
    r = TOOL_IMPLS["categorize_transaction"]({
        "description": "مؤسسة التأمينات الاجتماعية — اشتراك مارس",
        "amount": 8700,
    })
    assert r["account_code"] == "2402"
    assert r["source"] == "lexicon"


def test_categorize_transaction_falls_back_for_unknown():
    from app.services.copilot_agent import TOOL_IMPLS
    r = TOOL_IMPLS["categorize_transaction"]({
        "description": "random merchant ABC-123 XYZ",
        "amount": 99,
    })
    assert r["account_code"] == "9999"
    assert r["source"] == "fallback"
    assert r["confidence"] < 0.5
