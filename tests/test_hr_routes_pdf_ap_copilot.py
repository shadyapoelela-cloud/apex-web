"""Tests for Week 2/3 P1 work: HR routes, PDF parser, AP processors, Copilot agent."""

from __future__ import annotations

from datetime import date
from decimal import Decimal
from unittest.mock import patch

import pytest


# ── HR REST routes ─────────────────────────────────────────


def test_hr_create_employee_and_read_back(client):
    payload = {
        "employee_number": f"API-{uuid4_hex()[:6]}",
        "name_ar": "أحمد علي",
        "name_en": "Ahmed Ali",
        "nationality": "SAU",
        "hire_date": "2026-01-01",
        "basic_salary": 8000,
        "housing_allowance": 2000,
        "bank_iban": "SA0380000000608010167519",
        "gosi_applicable": True,
    }
    resp = client.post("/hr/employees", json=payload)
    assert resp.status_code == 201, resp.text
    created = resp.json()["data"]
    assert created["name_ar"] == "أحمد علي"
    emp_id = created["id"]

    read = client.get(f"/hr/employees/{emp_id}")
    assert read.status_code == 200
    assert read.json()["data"]["employee_number"] == payload["employee_number"]


def test_hr_list_employees_is_paginated(client):
    # Create a few employees first
    for i in range(3):
        client.post(
            "/hr/employees",
            json={
                "employee_number": f"PAGE-{uuid4_hex()[:6]}-{i}",
                "name_ar": f"موظف {i}",
                "hire_date": "2026-01-01",
                "basic_salary": 5000,
            },
        )
    resp = client.get("/hr/employees?limit=2")
    assert resp.status_code == 200
    body = resp.json()
    assert "data" in body and "next_cursor" in body and "has_more" in body
    assert body["limit"] == 2


def test_hr_update_employee(client):
    create = client.post(
        "/hr/employees",
        json={
            "employee_number": f"UPD-{uuid4_hex()[:6]}",
            "name_ar": "قبل التحديث",
            "hire_date": "2026-01-01",
            "basic_salary": 3000,
        },
    )
    emp_id = create.json()["data"]["id"]
    update = client.put(
        f"/hr/employees/{emp_id}",
        json={
            "employee_number": create.json()["data"]["employee_number"],
            "name_ar": "بعد التحديث",
            "hire_date": "2026-01-01",
            "basic_salary": 3500,
        },
    )
    assert update.status_code == 200
    assert update.json()["data"]["name_ar"] == "بعد التحديث"
    assert Decimal(update.json()["data"]["basic_salary"]) == Decimal("3500")


def test_hr_terminate_employee(client):
    create = client.post(
        "/hr/employees",
        json={
            "employee_number": f"TERM-{uuid4_hex()[:6]}",
            "name_ar": "للإنهاء",
            "hire_date": "2026-01-01",
            "basic_salary": 1000,
        },
    )
    emp_id = create.json()["data"]["id"]
    terminate = client.delete(f"/hr/employees/{emp_id}")
    assert terminate.status_code == 200
    assert terminate.json()["data"]["status"] == "terminated"


def test_hr_leave_request_lifecycle(client):
    emp = client.post(
        "/hr/employees",
        json={
            "employee_number": f"LV-{uuid4_hex()[:6]}",
            "name_ar": "موظف للإجازة",
            "hire_date": "2026-01-01",
            "basic_salary": 5000,
        },
    ).json()["data"]

    req = client.post(
        "/hr/leave-requests",
        json={
            "employee_id": emp["id"],
            "leave_type": "annual",
            "start_date": "2026-05-01",
            "end_date": "2026-05-07",
        },
    )
    assert req.status_code == 201
    req_id = req.json()["data"]["id"]
    assert req.json()["data"]["days"] == 7

    approve = client.post(f"/hr/leave-requests/{req_id}/approve")
    assert approve.status_code == 200


def test_hr_gosi_calc_endpoint(client):
    r = client.post(
        "/hr/calc/gosi",
        json={
            "country": "ksa",
            "basic_salary": 8000,
            "housing_allowance": 2000,
            "is_national": True,
        },
    )
    assert r.status_code == 200
    data = r.json()["data"]
    assert Decimal(data["employee_contribution"]) == Decimal("1000.00")
    assert Decimal(data["employer_contribution"]) == Decimal("1200.00")


def test_hr_eosb_calc_endpoint(client):
    r = client.post(
        "/hr/calc/eosb",
        json={
            "country": "ksa",
            "monthly_wage": 10000,
            "years_of_service": 8,
            "resigned": False,
        },
    )
    assert r.status_code == 200
    assert Decimal(r.json()["data"]["payable"]) == Decimal("55000.00")


def test_hr_payroll_run_endpoint(client):
    # Seed at least one active employee
    client.post(
        "/hr/employees",
        json={
            "employee_number": f"PAY-{uuid4_hex()[:6]}",
            "name_ar": "راتبه",
            "nationality": "SAU",
            "hire_date": "2026-01-01",
            "basic_salary": 5000,
            "housing_allowance": 1500,
            "gosi_applicable": True,
        },
    )
    run = client.post("/hr/payroll/run", json={"period": "2099-01"})
    assert run.status_code in (201, 409), run.text


# ── Bank PDF parser ────────────────────────────────────────


def test_pdf_parser_no_pdfplumber_returns_warning(monkeypatch):
    """When pdfplumber isn't available, we get a structured warning, not a crash."""
    from app.integrations.bank_ocr import pdf_parser

    monkeypatch.setattr(pdf_parser, "_extract_pdf_text", lambda _content: None)
    monkeypatch.setattr(pdf_parser, "_extract_via_claude_vision", lambda _content: None)

    result = pdf_parser.parse_pdf(b"%PDF-fake")
    assert result.transactions == []
    assert any("text layer" in w.lower() for w in result.warnings)


def test_pdf_parser_detects_al_rajhi_bank():
    from app.integrations.bank_ocr.pdf_parser import detect_bank

    text = "مصرف الراجحي\nAccount Statement\nPeriod: 2026-04-01 to 2026-04-30"
    assert detect_bank(text) == "al_rajhi"


def test_pdf_parser_detects_snb():
    from app.integrations.bank_ocr.pdf_parser import detect_bank

    text = "Saudi National Bank\nSNB Statement\nIBAN: SA03..."
    assert detect_bank(text) == "snb"


def test_pdf_parser_detects_enbd():
    from app.integrations.bank_ocr.pdf_parser import detect_bank

    text = "Emirates NBD\nAccount holder: Ahmed"
    assert detect_bank(text) == "enbd"


def test_pdf_parser_detects_unknown_bank():
    from app.integrations.bank_ocr.pdf_parser import detect_bank

    assert detect_bank("Unrelated garbage text") == "unknown"


def test_pdf_parser_extracts_iban_from_text():
    from app.integrations.bank_ocr.pdf_parser import _extract_account_number

    text = "Account IBAN: SA0380000000608010167519\nBalance..."
    assert _extract_account_number(text) == "SA0380000000608010167519"


def test_pdf_parser_table_row_parser():
    from app.integrations.bank_ocr.pdf_parser import _parse_pdf_table

    rows = [
        ["Date", "Description", "Debit", "Credit", "Balance"],
        ["2026-04-01", "فاتورة STC", "150.00", "", "9850.00"],
        ["2026-04-02", "راتب", "", "5000.00", "14850.00"],
    ]
    txns = _parse_pdf_table(rows)
    assert len(txns) == 2
    assert txns[0].direction == "debit"
    assert txns[1].direction == "credit"


def test_pdf_parser_table_arabic_headers():
    from app.integrations.bank_ocr.pdf_parser import _parse_pdf_table

    rows = [
        ["التاريخ", "البيان", "مدين", "دائن", "الرصيد"],
        ["2026-04-05", "كهرباء", "320.50", "", "13000"],
    ]
    txns = _parse_pdf_table(rows)
    assert len(txns) == 1
    assert txns[0].direction == "debit"
    assert txns[0].amount == Decimal("320.50")


# ── AP Agent real processors ───────────────────────────────


def test_ap_gl_coding_heuristic_matches_telecom():
    from app.features.ap_agent.real_processors import processor_gl_coding_real

    invoice = {"vendor_name": "STC Business", "total": 500, "line_items": []}
    result = processor_gl_coding_real(invoice, {})
    assert result.extracted["suggested_account_id"] == "5200-Telecom"
    assert result.extracted["coding_confidence"] >= 0.5


def test_ap_gl_coding_heuristic_matches_rent_arabic():
    from app.features.ap_agent.real_processors import processor_gl_coding_real

    invoice = {"vendor_name": "مؤجر المكتب", "total": 15000, "line_items": [{"description": "إيجار شهر أبريل"}]}
    result = processor_gl_coding_real(invoice, {})
    assert result.extracted["suggested_account_id"] == "5500-Rent"


def test_ap_gl_coding_fallback_to_general():
    from app.features.ap_agent.real_processors import processor_gl_coding_real

    invoice = {"vendor_name": "xyz corp", "total": 100, "line_items": []}
    result = processor_gl_coding_real(invoice, {})
    assert "General Expenses" in result.extracted["suggested_account_id"]
    assert result.extracted["coding_confidence"] < 0.5


def test_ap_3way_match_passes_within_tolerance():
    from app.features.ap_agent.models import APInvoiceStatus
    from app.features.ap_agent.real_processors import processor_3way_match

    invoice = {"total": 1000}
    ctx = {
        "po": {"id": "po-1", "total": 1005},          # 0.5% variance — within tolerance
        "receipt": {"id": "r-1", "received_total": 1000},
    }
    result = processor_3way_match(invoice, ctx)
    assert result.next_status == APInvoiceStatus.APPROVED
    assert result.extracted["matched_po_id"] == "po-1"


def test_ap_3way_match_escalates_on_variance():
    from app.features.ap_agent.models import APInvoiceStatus
    from app.features.ap_agent.real_processors import processor_3way_match

    invoice = {"total": 1200}
    ctx = {
        "po": {"id": "po-1", "total": 1000},    # 20% variance — exceeds 2%
    }
    result = processor_3way_match(invoice, ctx)
    assert result.next_status == APInvoiceStatus.AWAITING_APPROVAL
    assert result.extracted["approval_policy"] == "cfo_variance"


def test_ap_3way_match_with_no_po_falls_through():
    from app.features.ap_agent.models import APInvoiceStatus
    from app.features.ap_agent.real_processors import processor_3way_match

    invoice = {"total": 100}
    result = processor_3way_match(invoice, {})
    assert result.next_status == APInvoiceStatus.APPROVED


def test_ap_ocr_real_degrades_without_api_key(monkeypatch):
    from app.features.ap_agent import real_processors

    monkeypatch.setattr(real_processors, "OCR_VISION_ENABLED", True)
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)

    invoice = {"raw_file_url": "https://example.com/inv.pdf"}
    result = real_processors.processor_ocr_real(invoice, {})
    # Should not raise; should produce OCR_DONE with zero confidence + reason
    assert result.extracted["ocr_confidence"] == 0.0
    assert "skipped" in result.log_entry.lower() or "not installed" in result.log_entry.lower()


# ── Copilot Agent ──────────────────────────────────────────


def test_copilot_agent_without_sdk(monkeypatch):
    """run_agent returns a structured error when anthropic SDK missing."""
    from app.services import copilot_agent

    # Simulate missing SDK by patching the import in run_agent.
    import sys
    saved = sys.modules.pop("anthropic", None)
    try:
        # Inject a bad module so `import anthropic` fails.
        sys.modules["anthropic"] = None
        result = copilot_agent.run_agent("مرحبا")
        assert result.success is False
        assert "anthropic" in (result.error or "").lower()
    finally:
        if saved is not None:
            sys.modules["anthropic"] = saved
        else:
            sys.modules.pop("anthropic", None)


def test_copilot_agent_without_api_key(monkeypatch):
    """run_agent reports missing API key rather than raising."""
    from app.services import copilot_agent

    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    result = copilot_agent.run_agent("ما مصاريف الشهر؟")
    assert result.success is False
    assert result.error


def test_copilot_tool_definitions_are_valid_json_schema():
    from app.services.copilot_agent import TOOL_DEFINITIONS

    assert len(TOOL_DEFINITIONS) >= 5
    for tool in TOOL_DEFINITIONS:
        assert "name" in tool and "description" in tool and "input_schema" in tool
        schema = tool["input_schema"]
        assert schema["type"] == "object"
        assert "properties" in schema


def test_copilot_tool_implementations_are_callable():
    from app.services.copilot_agent import TOOL_IMPLS

    # Each tool impl must be callable and return a dict
    for name, impl in TOOL_IMPLS.items():
        assert callable(impl), f"{name} must be callable"


def test_copilot_query_financial_data_stub():
    from app.services.copilot_agent import _impl_query_financial_data

    result = _impl_query_financial_data(
        {"metric": "total_expenses", "period": "this_month"}
    )
    assert result["metric"] == "total_expenses"
    assert "value" in result
    assert "currency" in result


def test_copilot_lookup_entity_stub():
    from app.services.copilot_agent import _impl_lookup_entity

    result = _impl_lookup_entity({"entity_type": "client", "query": "أحمد"})
    assert result["entity_type"] == "client"
    assert "matches" in result


# ── Helpers ───────────────────────────────────────────────


def uuid4_hex():
    import uuid
    return uuid.uuid4().hex
