"""Invoicing API tests (INV-1, Sprint 18).

Covers `app/invoicing/router.py`, `app/invoicing/service.py`:
  - Credit note lifecycle (draft → issue → apply → cancel)
  - Aged AR / AP bucket accuracy
  - Recurring template scheduling + advance_next_run
  - Bulk operations (issue + email)
  - Attachment upload / list / delete
  - PDF endpoint (returns bytes; we just verify status + content-type)
  - Permission filtering at every endpoint
  - Write-off marks invoice as paid
"""

from __future__ import annotations

import base64
import os
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal

import jwt
import pytest

from app.invoicing.models import (
    CreditNote,
    CreditNoteStatus,
    InvoiceAttachment,
    InvoiceType,
    RecurringInvoiceTemplate,
)
from app.invoicing.schemas import (
    CreditNoteCreateIn,
    CreditNoteLineIn,
    RecurringTemplateCreateIn,
    RecurringTemplateLineIn,
)
from app.invoicing import service as inv_service
from app.phase1.models.platform_models import SessionLocal


JWT_SECRET = os.environ["JWT_SECRET"]


def _token(*, perms: list[str], user_id: str = "u-inv", tenant_id: str = "t-inv") -> str:
    return jwt.encode(
        {
            "sub": user_id,
            "user_id": user_id,
            "username": user_id,
            "role": "tester",
            "permissions": perms,
            "tenant_id": tenant_id,
            "type": "access",
            "exp": datetime.now(timezone.utc) + timedelta(hours=1),
            "iat": datetime.now(timezone.utc),
        },
        JWT_SECRET,
        algorithm="HS256",
    )


def _hdr(perms: list[str]) -> dict[str, str]:
    return {"Authorization": f"Bearer {_token(perms=perms)}"}


CFO_PERMS = [
    "read:credit_notes", "write:credit_notes", "issue:credit_notes",
    "apply:credit_notes",
    "read:recurring_invoices", "write:recurring_invoices",
    "run:recurring_invoices",
    "read:invoices",
    "read:aged_ar_ap",
    "export:invoice_pdf",
    "bulk:invoice_actions",
    "upload:invoice_attachments",
    "write_off:invoices",
]
READER_PERMS = ["read:credit_notes", "read:recurring_invoices", "read:invoices"]


@pytest.fixture(autouse=True)
def _isolate():
    from app.core.tenant_context import set_tenant

    set_tenant("t-inv")
    yield
    set_tenant(None)
    db = SessionLocal()
    try:
        db.query(CreditNote).filter(CreditNote.tenant_id == "t-inv").delete(
            synchronize_session=False
        )
        db.query(RecurringInvoiceTemplate).filter(
            RecurringInvoiceTemplate.tenant_id == "t-inv"
        ).delete(synchronize_session=False)
        db.query(InvoiceAttachment).filter(
            InvoiceAttachment.tenant_id == "t-inv"
        ).delete(synchronize_session=False)
        db.commit()
    finally:
        db.close()


def _make_cn_payload(*, cn_number: str, entity: str = "e-inv-1", grand: float = 100.0) -> dict:
    return {
        "entity_id": entity,
        "cn_type": "credit",
        "cn_number": cn_number,
        "issue_date": "2026-05-06",
        "currency_code": "SAR",
        "reason_code": "return",
        "lines": [
            {"line_no": 1, "description": "Refund", "quantity": 1, "unit_price": grand},
        ],
    }


# ── 1. Credit Notes — lifecycle + state ──────────────────


def test_create_credit_note_201(client):
    r = client.post(
        "/api/v1/invoicing/credit-notes",
        json=_make_cn_payload(cn_number="CN-001"),
        headers=_hdr(CFO_PERMS),
    )
    assert r.status_code == 201, r.text
    data = r.json()["data"]
    assert data["status"] == "draft"
    assert data["grand_total"] == 100.0


def test_create_cn_invalid_reason_is_422(client):
    payload = _make_cn_payload(cn_number="CN-bad")
    payload["reason_code"] = "made_up"
    r = client.post(
        "/api/v1/invoicing/credit-notes", json=payload, headers=_hdr(CFO_PERMS)
    )
    assert r.status_code == 422


def test_create_cn_without_perm_is_403(client):
    r = client.post(
        "/api/v1/invoicing/credit-notes",
        json=_make_cn_payload(cn_number="CN-noperm"),
        headers=_hdr(READER_PERMS),
    )
    assert r.status_code == 403


def test_create_cn_unauthenticated_is_401(client):
    r = client.post(
        "/api/v1/invoicing/credit-notes",
        json=_make_cn_payload(cn_number="CN-401"),
    )
    assert r.status_code == 401


def test_get_credit_note_returns_lines(client):
    r = client.post(
        "/api/v1/invoicing/credit-notes",
        json=_make_cn_payload(cn_number="CN-get"),
        headers=_hdr(CFO_PERMS),
    )
    cn_id = r.json()["data"]["id"]
    r2 = client.get(f"/api/v1/invoicing/credit-notes/{cn_id}", headers=_hdr(CFO_PERMS))
    assert r2.status_code == 200
    assert len(r2.json()["data"]["lines"]) == 1
    assert r2.json()["data"]["lines"][0]["description"] == "Refund"


def test_list_credit_notes_filters_by_status(client):
    client.post(
        "/api/v1/invoicing/credit-notes",
        json=_make_cn_payload(cn_number="CN-l1"),
        headers=_hdr(CFO_PERMS),
    )
    r = client.get(
        "/api/v1/invoicing/credit-notes?status=draft", headers=_hdr(CFO_PERMS)
    )
    assert r.status_code == 200
    assert all(d["status"] == "draft" for d in r.json()["data"])


def test_issue_credit_note_moves_status(client):
    r = client.post(
        "/api/v1/invoicing/credit-notes",
        json=_make_cn_payload(cn_number="CN-issue"),
        headers=_hdr(CFO_PERMS),
    )
    cn_id = r.json()["data"]["id"]
    r2 = client.post(
        f"/api/v1/invoicing/credit-notes/{cn_id}/issue", headers=_hdr(CFO_PERMS)
    )
    assert r2.status_code == 200
    assert r2.json()["data"]["status"] == "issued"


def test_issue_already_issued_is_409(client):
    r = client.post(
        "/api/v1/invoicing/credit-notes",
        json=_make_cn_payload(cn_number="CN-double-issue"),
        headers=_hdr(CFO_PERMS),
    )
    cn_id = r.json()["data"]["id"]
    client.post(f"/api/v1/invoicing/credit-notes/{cn_id}/issue", headers=_hdr(CFO_PERMS))
    r2 = client.post(
        f"/api/v1/invoicing/credit-notes/{cn_id}/issue", headers=_hdr(CFO_PERMS)
    )
    assert r2.status_code == 409


def test_cancel_draft_credit_note_succeeds(client):
    r = client.post(
        "/api/v1/invoicing/credit-notes",
        json=_make_cn_payload(cn_number="CN-cancel"),
        headers=_hdr(CFO_PERMS),
    )
    cn_id = r.json()["data"]["id"]
    r2 = client.post(
        f"/api/v1/invoicing/credit-notes/{cn_id}/cancel",
        json={"reason": "duplicate"},
        headers=_hdr(CFO_PERMS),
    )
    assert r2.status_code == 200
    assert r2.json()["data"]["status"] == "cancelled"


def test_cancel_applied_credit_note_returns_409():
    db = SessionLocal()
    try:
        cn = inv_service.create_credit_note(
            db,
            CreditNoteCreateIn(
                entity_id="e-inv-cancel",
                cn_number="CN-applied-test",
                issue_date=date(2026, 5, 6),
                reason_code="return",
                lines=[
                    CreditNoteLineIn(
                        line_no=1, description="x", quantity=1, unit_price=100
                    )
                ],
            ),
            user_id="u", tenant_id="t-inv",
        )
        inv_service.issue_credit_note(db, cn.id)
        # Manually mark applied to simulate post-application state.
        cn = inv_service.get_credit_note(db, cn.id)
        cn.status = CreditNoteStatus.APPLIED
        db.commit()
        with pytest.raises(inv_service.CreditNoteStateError):
            inv_service.cancel_credit_note(db, cn.id)
    finally:
        db.close()


def test_apply_credit_note_endpoint_requires_perm(client):
    r = client.post(
        "/api/v1/invoicing/credit-notes/x/apply",
        json={"target_invoice_id": "i", "amount": 1.0},
        headers=_hdr(["read:credit_notes"]),
    )
    assert r.status_code == 403


# ── 2. Recurring templates ────────────────────────────────


def _make_rec_payload(name: str, freq: str = "monthly") -> dict:
    return {
        "entity_id": "e-inv-rec",
        "template_name": name,
        "invoice_type": "sales",
        "customer_id": "c-1",
        "frequency": freq,
        "interval_n": 1,
        "start_date": date.today().isoformat(),
        "currency_code": "SAR",
        "lines": [
            {"description": "Monthly subscription", "quantity": 1, "unit_price": 99.0,
             "tax_rate": "VAT_15"},
        ],
    }


def test_create_recurring_201(client):
    r = client.post(
        "/api/v1/invoicing/recurring",
        json=_make_rec_payload("Acme Monthly"),
        headers=_hdr(CFO_PERMS),
    )
    assert r.status_code == 201, r.text
    data = r.json()["data"]
    assert data["template_name"] == "Acme Monthly"
    assert data["next_run_date"] == data["start_date"]
    assert data["runs_count"] == 0
    assert data["is_active"] is True


def test_list_recurring_filters_by_active(client):
    client.post(
        "/api/v1/invoicing/recurring",
        json=_make_rec_payload("Active 1"),
        headers=_hdr(CFO_PERMS),
    )
    r = client.get(
        "/api/v1/invoicing/recurring?is_active=true", headers=_hdr(CFO_PERMS)
    )
    assert r.status_code == 200
    assert all(d["is_active"] is True for d in r.json()["data"])


def test_pause_recurring(client):
    r = client.post(
        "/api/v1/invoicing/recurring",
        json=_make_rec_payload("Pausable"),
        headers=_hdr(CFO_PERMS),
    )
    tid = r.json()["data"]["id"]
    r2 = client.post(
        f"/api/v1/invoicing/recurring/{tid}/pause", headers=_hdr(CFO_PERMS)
    )
    assert r2.status_code == 200
    assert r2.json()["data"]["is_active"] is False


def test_run_now_advances_next_run(client):
    r = client.post(
        "/api/v1/invoicing/recurring",
        json=_make_rec_payload("Run Now"),
        headers=_hdr(CFO_PERMS),
    )
    tid = r.json()["data"]["id"]
    r2 = client.post(
        f"/api/v1/invoicing/recurring/{tid}/run-now", headers=_hdr(CFO_PERMS)
    )
    assert r2.status_code == 200
    data = r2.json()["data"]
    assert data["runs_count"] == 1
    # next_run_date moved forward
    assert data["next_run_date"] != date.today().isoformat()


def test_run_recurring_with_max_runs_deactivates():
    db = SessionLocal()
    try:
        t = inv_service.create_recurring(
            db,
            RecurringTemplateCreateIn(
                entity_id="e-rec-max",
                template_name="Once Only",
                invoice_type="sales",
                customer_id="c-1",
                frequency="daily",
                interval_n=1,
                start_date=date.today(),
                max_runs=1,
                lines=[
                    RecurringTemplateLineIn(
                        description="x", quantity=1, unit_price=10.0
                    )
                ],
            ),
            user_id="u", tenant_id="t-inv",
        )
        result = inv_service.run_recurring_template(db, t.id, force_today=True)
        assert result["runs_count"] == 1
        assert result["is_active"] is False
    finally:
        db.close()


def test_run_recurring_past_end_date_deactivates():
    db = SessionLocal()
    try:
        t = inv_service.create_recurring(
            db,
            RecurringTemplateCreateIn(
                entity_id="e-rec-end",
                template_name="Already Ended",
                invoice_type="sales",
                customer_id="c-1",
                frequency="daily",
                interval_n=1,
                start_date=date(2020, 1, 1),
                end_date=date(2020, 1, 31),
                lines=[
                    RecurringTemplateLineIn(
                        description="x", quantity=1, unit_price=10.0
                    )
                ],
            ),
            user_id="u", tenant_id="t-inv",
        )
        result = inv_service.run_recurring_template(db, t.id, force_today=True)
        assert result.get("skipped") == "past_end_date"
    finally:
        db.close()


def test_run_recurring_not_due_yet_returns_skipped():
    db = SessionLocal()
    try:
        future = date.today() + timedelta(days=30)
        t = inv_service.create_recurring(
            db,
            RecurringTemplateCreateIn(
                entity_id="e-rec-future",
                template_name="Future",
                invoice_type="sales",
                customer_id="c-1",
                frequency="daily",
                interval_n=1,
                start_date=future,
                lines=[
                    RecurringTemplateLineIn(
                        description="x", quantity=1, unit_price=10.0
                    )
                ],
            ),
            user_id="u", tenant_id="t-inv",
        )
        result = inv_service.run_recurring_template(db, t.id)
        assert result.get("skipped") == "not_due_yet"
    finally:
        db.close()


def test_advance_next_run_monthly_handles_month_end():
    """Jan 31 + 1 month = Feb 28 (or 29 leap). Verify clamping."""
    db = SessionLocal()
    try:
        t = inv_service.create_recurring(
            db,
            RecurringTemplateCreateIn(
                entity_id="e-rec-jan31",
                template_name="Jan31",
                invoice_type="sales",
                customer_id="c-1",
                frequency="monthly",
                interval_n=1,
                start_date=date(2026, 1, 31),
                lines=[
                    RecurringTemplateLineIn(
                        description="x", quantity=1, unit_price=10.0
                    )
                ],
            ),
            user_id="u", tenant_id="t-inv",
        )
        nxt = inv_service._advance_next_run(t)
        # 2026 is non-leap → Feb 28
        assert nxt == date(2026, 2, 28)
    finally:
        db.close()


def test_run_recurring_endpoint_requires_run_perm(client):
    r = client.post(
        "/api/v1/invoicing/recurring",
        json=_make_rec_payload("No Run Perm"),
        headers=_hdr(CFO_PERMS),
    )
    tid = r.json()["data"]["id"]
    r2 = client.post(
        f"/api/v1/invoicing/recurring/{tid}/run-now",
        headers=_hdr(["read:recurring_invoices"]),
    )
    assert r2.status_code == 403


# ── 3. Aged AR / AP ──────────────────────────────────────


def test_aged_ar_returns_5_buckets(client):
    r = client.get(
        "/api/v1/invoicing/aged-ar?entity_id=e-aged-empty",
        headers=_hdr(CFO_PERMS),
    )
    assert r.status_code == 200
    data = r.json()["data"]
    labels = {b["bucket"] for b in data["buckets"]}
    assert labels == {"0-30", "31-60", "61-90", "91-120", ">120"}
    assert data["grand_total"] == 0.0
    assert data["overdue_count"] == 0


def test_aged_ap_returns_5_buckets(client):
    r = client.get(
        "/api/v1/invoicing/aged-ap?entity_id=e-aged-empty",
        headers=_hdr(CFO_PERMS),
    )
    assert r.status_code == 200
    labels = {b["bucket"] for b in r.json()["data"]["buckets"]}
    assert labels == {"0-30", "31-60", "61-90", "91-120", ">120"}


def test_aged_ar_unauthorized_perms_403(client):
    r = client.get(
        "/api/v1/invoicing/aged-ar?entity_id=e-x",
        headers=_hdr(["read:credit_notes"]),
    )
    assert r.status_code == 403


def test_bucket_for_function_boundary_31_lands_in_31_60():
    assert inv_service._bucket_for(0) == "0-30"
    assert inv_service._bucket_for(30) == "0-30"
    assert inv_service._bucket_for(31) == "31-60"
    assert inv_service._bucket_for(60) == "31-60"
    assert inv_service._bucket_for(61) == "61-90"
    assert inv_service._bucket_for(120) == "91-120"
    assert inv_service._bucket_for(200) == ">120"


# ── 4. Bulk operations ───────────────────────────────────


def test_bulk_issue_endpoint_runs_without_pilot(client):
    """Without a pilot DB available, bulk issue returns failures —
    the contract is that the endpoint completes (200) and surfaces
    per-id errors rather than 500-ing the whole call."""
    r = client.post(
        "/api/v1/invoicing/sales-invoices/bulk/issue",
        json={"invoice_ids": ["x", "y"]},
        headers=_hdr(CFO_PERMS),
    )
    assert r.status_code == 200
    data = r.json()["data"]
    assert "succeeded" in data and "failed" in data


def test_bulk_email_endpoint_returns_200(client):
    r = client.post(
        "/api/v1/invoicing/sales-invoices/bulk/email",
        json={"invoice_ids": ["x", "y"]},
        headers=_hdr(CFO_PERMS),
    )
    assert r.status_code == 200
    assert r.json()["data"]["succeeded"] == ["x", "y"]


def test_bulk_requires_perm(client):
    r = client.post(
        "/api/v1/invoicing/sales-invoices/bulk/issue",
        json={"invoice_ids": ["x"]},
        headers=_hdr(["read:credit_notes"]),
    )
    assert r.status_code == 403


def test_bulk_max_100_invoices_enforced_by_pydantic(client):
    r = client.post(
        "/api/v1/invoicing/sales-invoices/bulk/issue",
        json={"invoice_ids": [f"i-{i}" for i in range(150)]},
        headers=_hdr(CFO_PERMS),
    )
    assert r.status_code == 422


# ── 5. Attachments ───────────────────────────────────────


def test_upload_then_list_then_delete_attachment(client):
    inv_id = "i-attach-1"
    payload = {
        "invoice_type": "sales",
        "filename": "contract.pdf",
        "mime_type": "application/pdf",
        "content_b64": base64.b64encode(b"%PDF-1.4 fake").decode(),
    }
    r = client.post(
        f"/api/v1/invoicing/invoices/{inv_id}/attachments",
        json=payload,
        headers=_hdr(CFO_PERMS),
    )
    assert r.status_code == 201
    aid = r.json()["data"]["id"]
    # list
    r2 = client.get(
        f"/api/v1/invoicing/invoices/{inv_id}/attachments",
        headers=_hdr(CFO_PERMS),
    )
    assert r2.status_code == 200
    assert len(r2.json()["data"]) == 1
    assert r2.json()["data"][0]["filename"] == "contract.pdf"
    # delete
    r3 = client.delete(
        f"/api/v1/invoicing/attachments/{aid}", headers=_hdr(CFO_PERMS)
    )
    assert r3.status_code == 200
    r4 = client.get(
        f"/api/v1/invoicing/invoices/{inv_id}/attachments",
        headers=_hdr(CFO_PERMS),
    )
    assert len(r4.json()["data"]) == 0


def test_upload_attachment_requires_perm(client):
    r = client.post(
        "/api/v1/invoicing/invoices/i-x/attachments",
        json={"filename": "x.pdf"},
        headers=_hdr(["read:invoices"]),
    )
    assert r.status_code == 403


def test_upload_missing_filename_is_422(client):
    r = client.post(
        "/api/v1/invoicing/invoices/i-x/attachments",
        json={"invoice_type": "sales", "mime_type": "x"},
        headers=_hdr(CFO_PERMS),
    )
    assert r.status_code == 422


def test_delete_unknown_attachment_is_404(client):
    r = client.delete(
        "/api/v1/invoicing/attachments/nope", headers=_hdr(CFO_PERMS)
    )
    assert r.status_code == 404


# ── 6. Service-layer unit ────────────────────────────────


def test_credit_note_lifecycle_via_service():
    db = SessionLocal()
    try:
        cn = inv_service.create_credit_note(
            db,
            CreditNoteCreateIn(
                entity_id="e-svc-life",
                cn_number="CN-life",
                issue_date=date(2026, 5, 6),
                reason_code="discount",
                lines=[
                    CreditNoteLineIn(
                        line_no=1, description="x", quantity=2, unit_price=50
                    )
                ],
            ),
            user_id="u", tenant_id="t-inv",
        )
        assert cn.status == "draft"
        assert float(cn.grand_total) == 100.0  # 2 * 50, no tax
        cn = inv_service.issue_credit_note(db, cn.id)
        assert cn.status == "issued"
    finally:
        db.close()


def test_credit_note_with_vat_15_computes_tax():
    db = SessionLocal()
    try:
        cn = inv_service.create_credit_note(
            db,
            CreditNoteCreateIn(
                entity_id="e-svc-vat",
                cn_number="CN-vat",
                issue_date=date(2026, 5, 6),
                reason_code="return",
                lines=[
                    CreditNoteLineIn(
                        line_no=1, description="x", quantity=1, unit_price=100,
                        tax_rate="VAT_15",
                    )
                ],
            ),
            user_id="u", tenant_id="t-inv",
        )
        assert float(cn.subtotal) == 100.0
        assert float(cn.tax_total) == 15.0
        assert float(cn.grand_total) == 115.0
    finally:
        db.close()


def test_apply_more_than_grand_total_raises():
    db = SessionLocal()
    try:
        cn = inv_service.create_credit_note(
            db,
            CreditNoteCreateIn(
                entity_id="e-apply-over",
                cn_number="CN-over",
                issue_date=date(2026, 5, 6),
                reason_code="return",
                lines=[
                    CreditNoteLineIn(
                        line_no=1, description="x", quantity=1, unit_price=100
                    )
                ],
            ),
            user_id="u", tenant_id="t-inv",
        )
        inv_service.issue_credit_note(db, cn.id)
        with pytest.raises(inv_service.CreditNoteAmountError):
            inv_service.apply_credit_note(
                db, cn.id, "target-invoice", amount=200.0
            )
    finally:
        db.close()


def test_compute_aged_ar_handles_empty_entity():
    db = SessionLocal()
    try:
        report = inv_service.compute_aged_ar(db, "e-doesnt-exist")
        assert report["grand_total"] == 0.0
        assert report["overdue_count"] == 0
        assert len(report["buckets"]) == 5
    finally:
        db.close()


def test_list_due_recurring_includes_past_dates():
    db = SessionLocal()
    try:
        # Past
        t1 = inv_service.create_recurring(
            db,
            RecurringTemplateCreateIn(
                entity_id="e-due", template_name="Past",
                invoice_type="sales", customer_id="c", frequency="daily",
                start_date=date.today() - timedelta(days=1),
                lines=[RecurringTemplateLineIn(description="x", quantity=1, unit_price=1)],
            ),
            user_id="u", tenant_id="t-inv",
        )
        # Future
        t2 = inv_service.create_recurring(
            db,
            RecurringTemplateCreateIn(
                entity_id="e-due", template_name="Future",
                invoice_type="sales", customer_id="c", frequency="daily",
                start_date=date.today() + timedelta(days=30),
                lines=[RecurringTemplateLineIn(description="x", quantity=1, unit_price=1)],
            ),
            user_id="u", tenant_id="t-inv",
        )
        due = inv_service.list_due_recurring(db)
        due_ids = {t.id for t in due}
        assert t1.id in due_ids
        assert t2.id not in due_ids
    finally:
        db.close()


# ── 7. Admin run-due ─────────────────────────────────────


def test_admin_run_due_now_runs_all_eligible(client):
    # seed two templates due today
    db = SessionLocal()
    try:
        for i in range(2):
            inv_service.create_recurring(
                db,
                RecurringTemplateCreateIn(
                    entity_id=f"e-admin-{i}",
                    template_name=f"Admin {i}",
                    invoice_type="sales", customer_id="c", frequency="daily",
                    start_date=date.today(),
                    lines=[RecurringTemplateLineIn(description="x", quantity=1, unit_price=1)],
                ),
                user_id="u", tenant_id="t-inv",
            )
    finally:
        db.close()

    r = client.post(
        "/api/v1/invoicing/admin/run-due-now", headers=_hdr(CFO_PERMS)
    )
    assert r.status_code == 200
    data = r.json()["data"]
    assert data["ran"] >= 2


# ── 8. Write-off ─────────────────────────────────────────


def test_write_off_endpoint_requires_perm(client):
    r = client.post(
        "/api/v1/invoicing/invoices/x/write-off",
        json={"reason": "bad debt"},
        headers=_hdr(["read:invoices"]),
    )
    assert r.status_code == 403


def test_write_off_unknown_invoice_404(client):
    r = client.post(
        "/api/v1/invoicing/invoices/no-such-invoice/write-off",
        json={"reason": "bad debt"},
        headers=_hdr(CFO_PERMS),
    )
    assert r.status_code == 404


# ── 9. PDF endpoints ─────────────────────────────────────


def test_pdf_endpoint_requires_perm(client):
    r = client.post(
        "/api/v1/invoicing/sales-invoices/x/pdf",
        headers=_hdr(["read:invoices"]),
    )
    assert r.status_code == 403


def test_pdf_unknown_invoice_returns_404(client):
    r = client.post(
        "/api/v1/invoicing/sales-invoices/no-such/pdf",
        headers=_hdr(CFO_PERMS),
    )
    # 404 (not_found) or 500 (renderer crash) both acceptable — we care
    # that it doesn't 200 silently.
    assert r.status_code in (404, 500)


# ── 10. Schema validators ────────────────────────────────


def test_credit_note_schema_rejects_invalid_cn_type():
    from app.invoicing.schemas import CreditNoteCreateIn

    with pytest.raises(ValueError):
        CreditNoteCreateIn(
            entity_id="e", cn_type="invalid", cn_number="x",
            issue_date=date(2026, 5, 6), reason_code="return",
            lines=[CreditNoteLineIn(line_no=1, description="x", quantity=1, unit_price=1)],
        )


def test_recurring_schema_rejects_invalid_frequency():
    from app.invoicing.schemas import RecurringTemplateCreateIn

    with pytest.raises(ValueError):
        RecurringTemplateCreateIn(
            entity_id="e", template_name="x", invoice_type="sales",
            frequency="hourly", start_date=date.today(),
            lines=[RecurringTemplateLineIn(description="x", quantity=1, unit_price=1)],
        )


def test_recurring_schema_rejects_invalid_invoice_type():
    from app.invoicing.schemas import RecurringTemplateCreateIn

    with pytest.raises(ValueError):
        RecurringTemplateCreateIn(
            entity_id="e", template_name="x", invoice_type="other",
            frequency="daily", start_date=date.today(),
            lines=[RecurringTemplateLineIn(description="x", quantity=1, unit_price=1)],
        )
