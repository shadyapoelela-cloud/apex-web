"""G-SALES-INVOICE-UX-COMPLETE — backend tests for payment auto-JE.

Pre-PR the `record_customer_payment` endpoint updated paid_amount +
status but did NOT post a journal entry. Post-PR it auto-builds the
2-leg payment JE (DR Cash/Bank/Cheque-on-hand / CR AR) and posts it
to the GL via `post_journal_entry`.

Five contracts pinned:

  1.  Payment creates a balanced JE (DR == CR).
  2.  Full payment marks the invoice `paid`.
  3.  Partial payment marks the invoice `partially_paid`.
  4.  Payment-method routing: cash → 1110, bank → 1120, cheque → 1310.
  5.  Overpayment is rejected with 409.

Tests run against the production backend's SessionLocal (SQLite in
local CI). Each test seeds its own tenant + entity + customer + CoA
and tears them down on exit.
"""

from __future__ import annotations

import uuid
from datetime import date
from decimal import Decimal

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.phase1.models.platform_models import SessionLocal, gen_uuid
from app.phase1.services.auth_service import create_access_token
from app.pilot.models.tenant import Tenant
from app.pilot.models.entity import Entity
from app.pilot.models import (
    Customer,
    SalesInvoice,
    SalesInvoiceLine,
    SalesInvoiceStatus,
    JournalEntry,
)
from app.pilot.services.gl_engine import seed_default_coa, seed_fiscal_periods


@pytest.fixture
def setup_invoice():
    """Seed a tenant + entity + CoA + customer + draft sales invoice
    of total 1150 (1000 base + 15% VAT)."""
    s = SessionLocal()
    user_id = gen_uuid()
    suffix = uuid.uuid4().hex[:6]
    t = Tenant(
        id=gen_uuid(),
        slug=f"pmt-{suffix}",
        legal_name_ar="بائع اختبار",
        primary_email=f"pmt_{suffix}@test.invalid",
        primary_country="SA",
        created_by_user_id=user_id,
    )
    s.add(t)
    s.flush()

    e = Entity(
        id=gen_uuid(),
        tenant_id=t.id,
        code=f"E-{suffix}",
        name_ar="كيان دفع",
        country="SA",
        functional_currency="SAR",
    )
    s.add(e)
    s.flush()

    seed_default_coa(s, e)
    seed_fiscal_periods(s, e, 2026)
    s.flush()

    cust = Customer(
        id=gen_uuid(),
        tenant_id=t.id,
        code=f"C-{suffix}",
        name_ar="عميل اختبار",
        kind="company",
        currency="SAR",
        payment_terms="net_30",
    )
    s.add(cust)
    s.flush()

    # Draft invoice 1150 SAR (1000 + 15%)
    inv = SalesInvoice(
        id=gen_uuid(),
        tenant_id=t.id,
        entity_id=e.id,
        customer_id=cust.id,
        invoice_number=f"INV-{suffix}",
        issue_date=date(2026, 5, 10),
        due_date=date(2026, 6, 9),
        status=SalesInvoiceStatus.draft.value,
        currency="SAR",
        subtotal=Decimal("1000.00"),
        vat_amount=Decimal("150.00"),
        total=Decimal("1150.00"),
        paid_amount=Decimal("0"),
    )
    s.add(inv)
    s.flush()

    s.add(SalesInvoiceLine(
        id=gen_uuid(),
        invoice_id=inv.id,
        line_number=1,
        description="خدمة اختبار",
        quantity=Decimal("1"),
        unit_price=Decimal("1000"),
        vat_rate=Decimal("15"),
        subtotal=Decimal("1000"),
        vat_amount=Decimal("150"),
        line_total=Decimal("1150"),
    ))
    s.commit()

    # Issue the invoice so it has a JE + AR balance to settle.
    token = create_access_token(
        user_id, "pmt_test", ["registered_user"], tenant_id=t.id,
    )
    headers = {"Authorization": f"Bearer {token}"}
    client = TestClient(app)
    issue_resp = client.post(
        f"/api/v1/pilot/sales-invoices/{inv.id}/issue", headers=headers,
    )
    assert issue_resp.status_code == 200, (
        f"setup-issue must succeed: {issue_resp.text}"
    )

    ids = (t.id, e.id, cust.id, inv.id)
    s.close()
    yield {
        "client": client,
        "headers": headers,
        "tenant_id": t.id,
        "entity_id": e.id,
        "customer_id": cust.id,
        "invoice_id": inv.id,
    }
    # Teardown
    s2 = SessionLocal()
    try:
        s2.query(SalesInvoiceLine).filter(
            SalesInvoiceLine.invoice_id == inv.id
        ).delete(synchronize_session=False)
        s2.query(SalesInvoice).filter(SalesInvoice.id == inv.id).delete(
            synchronize_session=False
        )
        s2.query(Customer).filter(Customer.id == cust.id).delete(
            synchronize_session=False
        )
        s2.query(Entity).filter(Entity.id == e.id).delete(
            synchronize_session=False
        )
        s2.query(Tenant).filter(Tenant.id == t.id).delete(
            synchronize_session=False
        )
        s2.commit()
    except Exception:
        s2.rollback()
    finally:
        s2.close()


def _post_payment(ctx, *, amount, method, payment_date="2026-05-10"):
    return ctx["client"].post(
        f"/api/v1/pilot/sales-invoices/{ctx['invoice_id']}/payment",
        headers=ctx["headers"],
        json={
            "invoice_id": ctx["invoice_id"],
            "payment_date": payment_date,
            "amount": amount,
            "method": method,
        },
    )


def test_payment_creates_je_balanced(setup_invoice):
    ctx = setup_invoice
    resp = _post_payment(ctx, amount=1150.00, method="bank_transfer")
    assert resp.status_code == 201, resp.text
    data = resp.json()
    je_id = data.get("journal_entry_id")
    assert je_id is not None, "payment response must include journal_entry_id"

    s = SessionLocal()
    try:
        je = s.query(JournalEntry).filter(JournalEntry.id == je_id).first()
        assert je is not None
        assert je.status == "posted", f"expected posted, got {je.status}"
        assert Decimal(str(je.total_debit)) == Decimal("1150.00")
        assert Decimal(str(je.total_credit)) == Decimal("1150.00")
        assert je.source_type == "customer_payment"
    finally:
        s.close()


def test_full_payment_marks_invoice_paid(setup_invoice):
    ctx = setup_invoice
    resp = _post_payment(ctx, amount=1150.00, method="cash")
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["invoice_status"] == "paid"
    assert Decimal(str(body["invoice_paid_amount"])) == Decimal("1150.00")
    assert Decimal(str(body["remaining_balance"])) == Decimal("0.00")


def test_partial_payment_marks_partially_paid(setup_invoice):
    ctx = setup_invoice
    resp = _post_payment(ctx, amount=400.00, method="cash")
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["invoice_status"] == "partially_paid", (
        f"400 < 1150 → partially_paid; got {body}"
    )
    assert Decimal(str(body["remaining_balance"])) == Decimal("750.00")


def test_payment_method_routes_to_correct_account(setup_invoice):
    """cash → 1110, bank_transfer → 1120, cheque → 1310."""
    ctx = setup_invoice
    # cash → 1110
    r1 = _post_payment(ctx, amount=100.00, method="cash")
    assert r1.status_code == 201
    je1_id = r1.json()["journal_entry_id"]

    # bank_transfer → 1120
    r2 = _post_payment(ctx, amount=100.00, method="bank_transfer")
    assert r2.status_code == 201
    je2_id = r2.json()["journal_entry_id"]

    # cheque → 1310 (Cheques on hand)
    r3 = _post_payment(ctx, amount=100.00, method="cheque")
    assert r3.status_code == 201
    je3_id = r3.json()["journal_entry_id"]

    s = SessionLocal()
    try:
        from app.pilot.models import JournalLine, GLAccount

        def _debit_account_code(je_id):
            ln = (
                s.query(JournalLine)
                .filter(
                    JournalLine.journal_entry_id == je_id,
                    JournalLine.debit_amount > 0,
                )
                .first()
            )
            assert ln is not None, f"JE {je_id} missing debit line"
            acc = s.query(GLAccount).filter(
                GLAccount.id == ln.account_id
            ).first()
            return acc.code if acc else None

        assert _debit_account_code(je1_id) == "1110", "cash → 1110"
        assert _debit_account_code(je2_id) == "1120", "bank → 1120"
        assert _debit_account_code(je3_id) == "1310", "cheque → 1310"
    finally:
        s.close()


def test_overpayment_rejected(setup_invoice):
    ctx = setup_invoice
    resp = _post_payment(ctx, amount=2000.00, method="cash")
    assert resp.status_code == 409, (
        f"overpayment must 409; got {resp.status_code}: {resp.text}"
    )
    # Body must explain the overpayment, not leak as a generic error.
    assert "overpayment" in resp.text.lower()
