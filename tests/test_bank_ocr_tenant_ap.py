"""Tests for: bank_ocr (parsers + matcher), tenant_context, ap_agent.pipeline."""

from __future__ import annotations

from datetime import date, timedelta
from decimal import Decimal

import pytest


# ── Bank OCR parsers ─────────────────────────────────────────


def test_detect_format_pdf():
    from app.integrations.bank_ocr.parsers import detect_format

    assert detect_format(b"%PDF-1.4\n...", "stmt.pdf") == "pdf"


def test_detect_format_xlsx():
    from app.integrations.bank_ocr.parsers import detect_format

    assert detect_format(b"PK\x03\x04...", "stmt.xlsx") == "xlsx"


def test_detect_format_mt940():
    from app.integrations.bank_ocr.parsers import detect_format

    sample = b":20:STATEMENT\n:25:1234\n:28C:1/1\n:60F:D20260101SAR100,00"
    assert detect_format(sample, "stmt.txt") == "mt940"


def test_detect_format_csv():
    from app.integrations.bank_ocr.parsers import detect_format

    csv_bytes = b"Date,Description,Debit,Credit,Balance\n2026-01-01,Test,,100,500\n"
    assert detect_format(csv_bytes, "stmt.csv") == "csv"


def test_detect_format_unknown():
    from app.integrations.bank_ocr.parsers import detect_format

    assert detect_format(b"random bytes", "stmt.bin") == "unknown"


def test_parse_csv_basic():
    from app.integrations.bank_ocr.parsers import parse_statement

    csv_bytes = (
        b"Date,Description,Debit,Credit,Balance\n"
        b"2026-01-01,Starting,,1000,1000\n"
        b"2026-01-02,Coffee shop,15.50,,984.50\n"
        b"2026-01-03,Salary,,5000,5984.50\n"
    )
    stmt = parse_statement(csv_bytes, "stmt.csv")
    assert len(stmt.transactions) == 3
    # First txn is credit of 1000
    t = stmt.transactions[0]
    assert t.direction == "credit"
    assert t.amount == Decimal("1000")
    # Debit txn
    t2 = stmt.transactions[1]
    assert t2.direction == "debit"
    assert t2.amount == Decimal("15.50")


def test_parse_csv_arabic_headers():
    from app.integrations.bank_ocr.parsers import parse_statement

    csv_bytes = (
        "التاريخ,البيان,مدين,دائن,الرصيد\n"
        "2026-01-05,فاتورة كهرباء,250.00,,750.00\n"
    ).encode("utf-8")
    stmt = parse_statement(csv_bytes, "stmt.csv")
    assert len(stmt.transactions) == 1
    assert stmt.transactions[0].direction == "debit"
    assert stmt.transactions[0].amount == Decimal("250.00")


def test_parse_csv_handles_arabic_digits():
    from app.integrations.bank_ocr.parsers import parse_statement

    # Arabic-Indic digits in the amount column
    csv_bytes = (
        "Date,Description,Debit,Credit,Balance\n"
        "2026-01-01,Test,,١٠٠٠,١٠٠٠\n"
    ).encode("utf-8")
    stmt = parse_statement(csv_bytes, "stmt.csv")
    assert len(stmt.transactions) == 1
    assert stmt.transactions[0].amount == Decimal("1000")


def test_parse_unknown_returns_warning():
    from app.integrations.bank_ocr.parsers import parse_statement

    stmt = parse_statement(b"random", "stmt.bin")
    assert stmt.transactions == []
    assert any("Unsupported" in w for w in stmt.warnings)


# ── Match engine ─────────────────────────────────────────────


def _bank_txn(amount, day=1, desc="Coffee shop", ref=None):
    from app.integrations.bank_ocr.parsers import BankTransaction

    return BankTransaction(
        txn_date=date(2026, 1, day),
        amount=Decimal(str(amount)),
        direction="debit",
        description=desc,
        reference=ref,
    )


def _ledger(amount, day=1, payee="Coffee shop", eid="le-1", ref=None):
    from app.integrations.bank_ocr.matcher import LedgerEntry

    return LedgerEntry(
        id=eid,
        amount=Decimal(str(amount)),
        entry_date=date(2026, 1, day),
        payee=payee,
        reference=ref,
    )


def test_match_engine_exact():
    from app.integrations.bank_ocr.matcher import MatchEngine

    engine = MatchEngine()
    txn = _bank_txn(15.50, day=2, ref="REF-1")
    ledger = [_ledger(15.50, day=2, eid="le-exact", ref="REF-1")]
    best = engine.best_match(txn, ledger)
    assert best is not None
    assert best.score == 100
    assert best.layer == "L1_exact"


def test_match_engine_amount_date_within_window():
    from app.integrations.bank_ocr.matcher import MatchEngine

    engine = MatchEngine(date_window_days=3)
    txn = _bank_txn(200, day=5)
    ledger = [_ledger(200, day=7, eid="le-7d"), _ledger(200, day=10, eid="le-10d")]
    best = engine.best_match(txn, ledger)
    assert best is not None
    assert best.score == 75
    assert best.ledger_entry_id == "le-7d"


def test_match_engine_fuzzy_arabic():
    from app.integrations.bank_ocr.matcher import MatchEngine

    engine = MatchEngine(fuzzy_threshold=0.6)
    # Bank says "أحمد الراجحي", ledger has "احمد الراجحى" (diacritic/alif diff)
    txn = _bank_txn(500, day=1, desc="أحمد الراجحي")
    ledger = [_ledger(500, day=20, payee="احمد الراجحى", eid="le-fuzzy")]
    best = engine.best_match(txn, ledger)
    assert best is not None
    assert best.layer == "L3_fuzzy_payee"
    assert best.score >= 50


def test_match_engine_no_match_returns_none():
    from app.integrations.bank_ocr.matcher import MatchEngine

    engine = MatchEngine()
    txn = _bank_txn(100, day=1, desc="Random")
    ledger = [_ledger(200, day=1, payee="Totally different")]
    assert engine.best_match(txn, ledger) is None


# ── Tenant context ───────────────────────────────────────────


def test_current_tenant_defaults_to_none():
    from app.core.tenant_context import current_tenant

    assert current_tenant() is None


def test_set_tenant_and_read_back():
    from app.core.tenant_context import current_tenant, set_tenant

    set_tenant("tenant-abc")
    assert current_tenant() == "tenant-abc"
    set_tenant(None)  # cleanup
    assert current_tenant() is None


# ── AP pipeline ──────────────────────────────────────────────


def test_ap_pipeline_auto_approves_small_invoices():
    from app.features.ap_agent.pipeline import APPipeline

    pipe = APPipeline()
    invoice = {
        "status": "received",
        "total": 500,
    }
    trace = pipe.run_until_blocked(invoice)
    # Should flow: received -> ocr_done -> coded -> approved -> scheduled
    statuses = [r.next_status.value for r in trace]
    assert "ocr_done" in statuses
    assert "approved" in statuses
    assert statuses[-1] == "scheduled"


def test_ap_pipeline_manager_approval_for_medium():
    from app.features.ap_agent.pipeline import APPipeline

    pipe = APPipeline()
    invoice = {"status": "received", "total": 5000}
    trace = pipe.run_until_blocked(invoice)
    # Stops at awaiting_approval with manager policy
    assert trace[-1].next_status.value == "awaiting_approval"
    assert trace[-1].extracted.get("approval_policy") == "manager"


def test_ap_pipeline_cfo_approval_for_large():
    from app.features.ap_agent.pipeline import APPipeline

    pipe = APPipeline()
    invoice = {"status": "received", "total": 50000}
    trace = pipe.run_until_blocked(invoice)
    assert trace[-1].next_status.value == "awaiting_approval"
    assert trace[-1].extracted.get("approval_policy") == "cfo"


def test_ap_pipeline_custom_policy_overrides_default():
    from app.features.ap_agent.pipeline import APPipeline

    pipe = APPipeline()
    invoice = {"status": "received", "total": 500}
    ctx = {"policy": {"auto_max": 100, "manager_max": 1000}}
    trace = pipe.run_until_blocked(invoice, ctx)
    # With custom policy, 500 > auto_max=100 → manager approval needed
    assert trace[-1].extracted.get("approval_policy") == "manager"


def test_ap_pipeline_scheduled_payment_defaults_to_due_date():
    from app.features.ap_agent.pipeline import APPipeline

    pipe = APPipeline()
    invoice = {
        "status": "received",
        "total": 100,
        "due_date": "2026-05-15",
    }
    trace = pipe.run_until_blocked(invoice)
    # Last step is schedule_payment — check scheduled_payment_date set
    assert trace[-1].extracted.get("scheduled_payment_date") == "2026-05-15"
