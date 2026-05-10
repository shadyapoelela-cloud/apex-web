"""G-SALES-INVOICE-UX-FOLLOWUP — backend tests for the cancel endpoint.

Three contracts pinned:

  1.  Cancel on a draft invoice — no JE to reverse → 200 + status=cancelled.
  2.  Cancel on an issued invoice — must reverse the posted JE.
  3.  Cancel on an invoice with payments — must 409 and leave the
      invoice + JE untouched.
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
from app.pilot.models import (
    Customer,
    JournalEntry,
    SalesInvoice,
    SalesInvoiceLine,
    SalesInvoiceStatus,
)
from app.pilot.models.entity import Entity
from app.pilot.models.tenant import Tenant
from app.pilot.services.gl_engine import seed_default_coa, seed_fiscal_periods


@pytest.fixture
def setup_invoice():
    s = SessionLocal()
    user_id = gen_uuid()
    suffix = uuid.uuid4().hex[:6]
    t = Tenant(
        id=gen_uuid(),
        slug=f"cxl-{suffix}",
        legal_name_ar="بائع اختبار إلغاء",
        primary_email=f"cxl_{suffix}@test.invalid",
        primary_country="SA",
        created_by_user_id=user_id,
    )
    s.add(t)
    s.flush()
    e = Entity(
        id=gen_uuid(),
        tenant_id=t.id,
        code=f"E-{suffix}",
        name_ar="كيان إلغاء",
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
        name_ar="عميل إلغاء",
        kind="company",
        currency="SAR",
        payment_terms="net_30",
    )
    s.add(cust)
    s.flush()
    inv = SalesInvoice(
        id=gen_uuid(),
        tenant_id=t.id,
        entity_id=e.id,
        customer_id=cust.id,
        invoice_number=f"INV-CXL-{suffix}",
        issue_date=date(2026, 5, 11),
        due_date=date(2026, 6, 10),
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
        description="خدمة اختبار إلغاء",
        quantity=Decimal("1"),
        unit_price=Decimal("1000"),
        vat_rate=Decimal("15"),
        subtotal=Decimal("1000"),
        vat_amount=Decimal("150"),
        line_total=Decimal("1150"),
    ))
    s.commit()
    token = create_access_token(
        user_id, "cxl_test", ["registered_user"], tenant_id=t.id,
    )
    headers = {"Authorization": f"Bearer {token}"}
    client = TestClient(app)
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


def test_cancel_draft_invoice_succeeds(setup_invoice):
    """Cancelling a draft is a no-op against the GL (no JE existed)."""
    ctx = setup_invoice
    resp = ctx["client"].post(
        f"/api/v1/pilot/sales-invoices/{ctx['invoice_id']}/cancel",
        headers=ctx["headers"],
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["status"] == "cancelled"
    # No JE was posted for the draft, so journal_entry_id stays None.
    assert body["journal_entry_id"] is None


def test_cancel_issued_invoice_reverses_je(setup_invoice):
    """Cancelling an issued invoice must reverse the posted JE."""
    ctx = setup_invoice
    # Issue first
    issue = ctx["client"].post(
        f"/api/v1/pilot/sales-invoices/{ctx['invoice_id']}/issue",
        headers=ctx["headers"],
    )
    assert issue.status_code == 200, issue.text
    je_id_before = issue.json()["journal_entry_id"]
    assert je_id_before is not None

    # Cancel
    cancel = ctx["client"].post(
        f"/api/v1/pilot/sales-invoices/{ctx['invoice_id']}/cancel",
        headers=ctx["headers"],
    )
    assert cancel.status_code == 200, cancel.text
    assert cancel.json()["status"] == "cancelled"

    # Verify a reversal JE exists — same dollar amounts, opposite sign.
    s = SessionLocal()
    try:
        # reverse_journal_entry sets source_type='je_reversal' and
        # also sets the original JE's status to 'reversed'.
        reversals = (
            s.query(JournalEntry)
            .filter(JournalEntry.source_type == "je_reversal")
            .filter(JournalEntry.tenant_id == ctx["tenant_id"])
            .all()
        )
        assert len(reversals) == 1, (
            f"expected one reversal JE, got {len(reversals)}"
        )
        rev = reversals[0]
        assert Decimal(str(rev.total_debit)) == Decimal("1150.00")
        assert rev.source_id == je_id_before, (
            "reversal must reference the original JE"
        )
        # The original JE should now be in reversed state.
        original = s.query(JournalEntry).filter(
            JournalEntry.id == je_id_before
        ).first()
        assert original.status == "reversed"
    finally:
        s.close()


def test_cancel_invoice_with_payment_is_rejected(setup_invoice):
    """Once payment is applied, cancel must 409."""
    ctx = setup_invoice
    # Issue + record a partial payment
    ctx["client"].post(
        f"/api/v1/pilot/sales-invoices/{ctx['invoice_id']}/issue",
        headers=ctx["headers"],
    )
    pay = ctx["client"].post(
        f"/api/v1/pilot/sales-invoices/{ctx['invoice_id']}/payment",
        headers=ctx["headers"],
        json={
            "invoice_id": ctx["invoice_id"],
            "payment_date": "2026-05-11",
            "amount": 100.00,
            "method": "cash",
        },
    )
    assert pay.status_code == 201, pay.text

    # Now try to cancel — should refuse.
    cancel = ctx["client"].post(
        f"/api/v1/pilot/sales-invoices/{ctx['invoice_id']}/cancel",
        headers=ctx["headers"],
    )
    assert cancel.status_code == 409, (
        f"expected 409 after payment; got {cancel.status_code}: {cancel.text}"
    )
    assert "applied payments" in cancel.text.lower() or "paid" in cancel.text.lower()
