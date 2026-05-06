"""FastAPI surface for the invoicing orchestration layer (INV-1)."""

from __future__ import annotations

import base64
import logging
from datetime import date
from typing import Optional

from fastapi import APIRouter, Body, Depends, HTTPException, Query
from fastapi.responses import Response

from app.core.api_version import v1_prefix
from app.invoicing import service as inv_service
from app.invoicing.models import (
    CreditNote,
    InvoiceAttachment,
    InvoiceType,
    RecurringInvoiceTemplate,
)
from app.invoicing.schemas import (
    ApplyCreditNoteIn,
    AttachmentOut,
    BulkActionResultOut,
    BulkInvoiceIdsIn,
    CreditNoteCreateIn,
    CreditNoteOut,
    RecurringTemplateCreateIn,
    RecurringTemplateOut,
    RecurringTemplateUpdateIn,
    WriteOffIn,
)
from app.phase1.models.platform_models import SessionLocal
from app.phase1.routes.phase1_routes import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix=v1_prefix("/invoicing"), tags=["Invoicing"])


# ── Permission helper ─────────────────────────────────────


def _user_perms(user: dict) -> set[str]:
    raw = user.get("permissions") if user else None
    if isinstance(raw, list):
        return {str(p) for p in raw}
    if isinstance(raw, set):
        return {str(p) for p in raw}
    return set()


def _require(user: dict, perm: str) -> None:
    if perm not in _user_perms(user):
        raise HTTPException(status_code=403, detail=f"missing permission: {perm}")


# ── Serializers ───────────────────────────────────────────


def _cn_to_out(cn: CreditNote) -> CreditNoteOut:
    return CreditNoteOut(
        id=cn.id,
        entity_id=cn.entity_id,
        cn_type=cn.cn_type,
        cn_number=cn.cn_number,
        issue_date=cn.issue_date,
        original_invoice_id=cn.original_invoice_id,
        original_invoice_type=cn.original_invoice_type,
        original_invoice_number=cn.original_invoice_number,
        customer_id=cn.customer_id,
        vendor_id=cn.vendor_id,
        subtotal=float(cn.subtotal or 0),
        tax_total=float(cn.tax_total or 0),
        grand_total=float(cn.grand_total or 0),
        currency_code=cn.currency_code,
        reason_code=cn.reason_code,
        reason_text=cn.reason_text,
        status=cn.status,
        applied_amount=float(cn.applied_amount or 0),
        journal_entry_id=cn.journal_entry_id,
        zatca_uuid=cn.zatca_uuid,
        zatca_status=cn.zatca_status,
        notes=cn.notes,
        created_at=cn.created_at,
        updated_at=cn.updated_at,
        lines=[
            {
                "id": l.id,
                "line_no": l.line_no,
                "description": l.description,
                "quantity": float(l.quantity or 0),
                "unit_price": float(l.unit_price or 0),
                "line_total": float(l.line_total or 0),
                "tax_rate": l.tax_rate,
                "tax_amount": float(l.tax_amount or 0),
                "account_id": l.account_id,
            }
            for l in (cn.lines or [])
        ],
    )


def _rec_to_out(t: RecurringInvoiceTemplate) -> RecurringTemplateOut:
    return RecurringTemplateOut(
        id=t.id,
        entity_id=t.entity_id,
        template_name=t.template_name,
        invoice_type=t.invoice_type,
        customer_id=t.customer_id,
        vendor_id=t.vendor_id,
        frequency=t.frequency,
        interval_n=t.interval_n,
        start_date=t.start_date,
        end_date=t.end_date,
        next_run_date=t.next_run_date,
        runs_count=t.runs_count,
        max_runs=t.max_runs,
        currency_code=t.currency_code,
        auto_issue=bool(t.auto_issue),
        auto_send_email=bool(t.auto_send_email),
        is_active=bool(t.is_active),
        last_run_at=t.last_run_at,
        last_invoice_id=t.last_invoice_id,
        lines_json=list(t.lines_json or []),
        notes=t.notes,
        created_at=t.created_at,
    )


def _att_to_out(a: InvoiceAttachment) -> AttachmentOut:
    return AttachmentOut(
        id=a.id,
        invoice_id=a.invoice_id,
        invoice_type=a.invoice_type,
        filename=a.filename,
        file_size=a.file_size,
        mime_type=a.mime_type,
        uploaded_at=a.uploaded_at,
        uploaded_by=a.uploaded_by,
    )


# ── Credit Notes ──────────────────────────────────────────


@router.post("/credit-notes", status_code=201)
def create_credit_note(
    payload: CreditNoteCreateIn,
    user: dict = Depends(get_current_user),
):
    _require(user, "write:credit_notes")
    db = SessionLocal()
    try:
        try:
            cn = inv_service.create_credit_note(
                db, payload,
                user_id=user.get("user_id") or user.get("sub"),
                tenant_id=user.get("tenant_id"),
            )
        except inv_service.CreditNoteAmountError as e:
            raise HTTPException(status_code=400, detail=str(e))
        except inv_service.InvoicingError as e:
            raise HTTPException(status_code=400, detail=str(e))
        return {"success": True, "data": _cn_to_out(cn).model_dump(mode="json")}
    finally:
        db.close()


@router.get("/credit-notes")
def list_credit_notes(
    entity_id: Optional[str] = Query(None),
    customer_id: Optional[str] = Query(None),
    vendor_id: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    cn_type: Optional[str] = Query(None),
    from_date: Optional[date] = Query(None),
    to_date: Optional[date] = Query(None),
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    user: dict = Depends(get_current_user),
):
    _require(user, "read:credit_notes")
    db = SessionLocal()
    try:
        rows = inv_service.list_credit_notes(
            db,
            entity_id=entity_id,
            customer_id=customer_id,
            vendor_id=vendor_id,
            status=status,
            cn_type=cn_type,
            from_date=from_date,
            to_date=to_date,
            limit=limit,
            offset=offset,
        )
        return {
            "success": True,
            "data": [_cn_to_out(r).model_dump(mode="json") for r in rows],
        }
    finally:
        db.close()


@router.get("/credit-notes/{cn_id}")
def get_credit_note(cn_id: str, user: dict = Depends(get_current_user)):
    _require(user, "read:credit_notes")
    db = SessionLocal()
    try:
        cn = inv_service.get_credit_note(db, cn_id)
        if cn is None:
            raise HTTPException(status_code=404, detail="credit note not found")
        return {"success": True, "data": _cn_to_out(cn).model_dump(mode="json")}
    finally:
        db.close()


@router.post("/credit-notes/{cn_id}/issue")
def issue_credit_note(cn_id: str, user: dict = Depends(get_current_user)):
    _require(user, "issue:credit_notes")
    db = SessionLocal()
    try:
        try:
            cn = inv_service.issue_credit_note(
                db, cn_id, user_id=user.get("user_id") or user.get("sub")
            )
        except inv_service.CreditNoteNotFoundError:
            raise HTTPException(status_code=404, detail="credit note not found")
        except inv_service.CreditNoteStateError as e:
            raise HTTPException(status_code=409, detail=str(e))
        return {"success": True, "data": _cn_to_out(cn).model_dump(mode="json")}
    finally:
        db.close()


@router.post("/credit-notes/{cn_id}/apply")
def apply_credit_note(
    cn_id: str,
    payload: ApplyCreditNoteIn,
    user: dict = Depends(get_current_user),
):
    _require(user, "apply:credit_notes")
    db = SessionLocal()
    try:
        try:
            cn = inv_service.apply_credit_note(
                db, cn_id, payload.target_invoice_id,
                amount=payload.amount,
                user_id=user.get("user_id") or user.get("sub"),
                reason=payload.reason,
            )
        except inv_service.CreditNoteNotFoundError:
            raise HTTPException(status_code=404, detail="credit note not found")
        except inv_service.CreditNoteStateError as e:
            raise HTTPException(status_code=409, detail=str(e))
        except inv_service.CreditNoteAmountError as e:
            raise HTTPException(status_code=400, detail=str(e))
        return {"success": True, "data": _cn_to_out(cn).model_dump(mode="json")}
    finally:
        db.close()


@router.post("/credit-notes/{cn_id}/cancel")
def cancel_credit_note(
    cn_id: str,
    payload: dict = Body(default_factory=dict),
    user: dict = Depends(get_current_user),
):
    _require(user, "write:credit_notes")
    db = SessionLocal()
    try:
        try:
            cn = inv_service.cancel_credit_note(
                db, cn_id,
                user_id=user.get("user_id") or user.get("sub"),
                reason=payload.get("reason"),
            )
        except inv_service.CreditNoteNotFoundError:
            raise HTTPException(status_code=404, detail="credit note not found")
        except inv_service.CreditNoteStateError as e:
            raise HTTPException(status_code=409, detail=str(e))
        return {"success": True, "data": _cn_to_out(cn).model_dump(mode="json")}
    finally:
        db.close()


# ── Recurring templates ───────────────────────────────────


@router.post("/recurring", status_code=201)
def create_recurring(
    payload: RecurringTemplateCreateIn,
    user: dict = Depends(get_current_user),
):
    _require(user, "write:recurring_invoices")
    db = SessionLocal()
    try:
        row = inv_service.create_recurring(
            db, payload,
            user_id=user.get("user_id") or user.get("sub"),
            tenant_id=user.get("tenant_id"),
        )
        return {"success": True, "data": _rec_to_out(row).model_dump(mode="json")}
    finally:
        db.close()


@router.get("/recurring")
def list_recurring(
    entity_id: Optional[str] = Query(None),
    is_active: Optional[bool] = Query(None),
    invoice_type: Optional[str] = Query(None),
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    user: dict = Depends(get_current_user),
):
    _require(user, "read:recurring_invoices")
    db = SessionLocal()
    try:
        rows = inv_service.list_recurring(
            db,
            entity_id=entity_id,
            is_active=is_active,
            invoice_type=invoice_type,
            limit=limit, offset=offset,
        )
        return {
            "success": True,
            "data": [_rec_to_out(r).model_dump(mode="json") for r in rows],
        }
    finally:
        db.close()


@router.patch("/recurring/{template_id}")
def update_recurring(
    template_id: str,
    payload: RecurringTemplateUpdateIn,
    user: dict = Depends(get_current_user),
):
    _require(user, "write:recurring_invoices")
    db = SessionLocal()
    try:
        try:
            row = inv_service.update_recurring(
                db, template_id, payload,
                user_id=user.get("user_id") or user.get("sub"),
            )
        except inv_service.RecurringNotFoundError:
            raise HTTPException(status_code=404, detail="template not found")
        return {"success": True, "data": _rec_to_out(row).model_dump(mode="json")}
    finally:
        db.close()


@router.post("/recurring/{template_id}/run-now")
def run_recurring_now(template_id: str, user: dict = Depends(get_current_user)):
    _require(user, "run:recurring_invoices")
    db = SessionLocal()
    try:
        try:
            result = inv_service.run_recurring_template(
                db, template_id,
                user_id=user.get("user_id") or user.get("sub"),
                force_today=True,
            )
        except inv_service.RecurringNotFoundError:
            raise HTTPException(status_code=404, detail="template not found")
        except inv_service.RecurringInactiveError:
            raise HTTPException(status_code=409, detail="template is not active")
        return {"success": True, "data": result}
    finally:
        db.close()


@router.post("/recurring/{template_id}/pause")
def pause_recurring(template_id: str, user: dict = Depends(get_current_user)):
    _require(user, "write:recurring_invoices")
    db = SessionLocal()
    try:
        try:
            row = inv_service.pause_recurring(db, template_id)
        except inv_service.RecurringNotFoundError:
            raise HTTPException(status_code=404, detail="template not found")
        return {"success": True, "data": _rec_to_out(row).model_dump(mode="json")}
    finally:
        db.close()


# ── Aged AR / AP ──────────────────────────────────────────


@router.get("/aged-ar")
def aged_ar(
    entity_id: str = Query(..., min_length=1),
    as_of_date: Optional[date] = Query(None),
    user: dict = Depends(get_current_user),
):
    _require(user, "read:aged_ar_ap")
    db = SessionLocal()
    try:
        report = inv_service.compute_aged_ar(db, entity_id, as_of=as_of_date)
        return {"success": True, "data": report}
    finally:
        db.close()


@router.get("/aged-ap")
def aged_ap(
    entity_id: str = Query(..., min_length=1),
    as_of_date: Optional[date] = Query(None),
    user: dict = Depends(get_current_user),
):
    _require(user, "read:aged_ar_ap")
    db = SessionLocal()
    try:
        report = inv_service.compute_aged_ap(db, entity_id, as_of=as_of_date)
        return {"success": True, "data": report}
    finally:
        db.close()


# ── PDF ───────────────────────────────────────────────────


@router.post("/sales-invoices/{invoice_id}/pdf")
def sales_invoice_pdf(invoice_id: str, user: dict = Depends(get_current_user)):
    _require(user, "export:invoice_pdf")
    db = SessionLocal()
    try:
        try:
            pdf_bytes = inv_service.generate_invoice_pdf(
                db, invoice_id, InvoiceType.SALES
            )
        except inv_service.InvoiceNotFoundError:
            raise HTTPException(status_code=404, detail="invoice not found")
        except inv_service.InvoicingError as e:
            raise HTTPException(status_code=500, detail=str(e))
        return Response(
            content=pdf_bytes,
            media_type="application/pdf",
            headers={
                "Content-Disposition": f'attachment; filename="invoice-{invoice_id}.pdf"',
            },
        )
    finally:
        db.close()


@router.post("/purchase-invoices/{invoice_id}/pdf")
def purchase_invoice_pdf(invoice_id: str, user: dict = Depends(get_current_user)):
    _require(user, "export:invoice_pdf")
    db = SessionLocal()
    try:
        try:
            pdf_bytes = inv_service.generate_invoice_pdf(
                db, invoice_id, InvoiceType.PURCHASE
            )
        except inv_service.InvoiceNotFoundError:
            raise HTTPException(status_code=404, detail="invoice not found")
        except inv_service.InvoicingError as e:
            raise HTTPException(status_code=500, detail=str(e))
        return Response(
            content=pdf_bytes,
            media_type="application/pdf",
            headers={
                "Content-Disposition": f'attachment; filename="bill-{invoice_id}.pdf"',
            },
        )
    finally:
        db.close()


# ── Bulk operations ───────────────────────────────────────


@router.post("/sales-invoices/bulk/issue")
def bulk_issue(
    payload: BulkInvoiceIdsIn,
    user: dict = Depends(get_current_user),
):
    _require(user, "bulk:invoice_actions")
    db = SessionLocal()
    try:
        result = inv_service.bulk_issue_invoices(
            db, payload.invoice_ids,
            user_id=user.get("user_id") or user.get("sub"),
        )
        return {"success": True, "data": result}
    finally:
        db.close()


@router.post("/sales-invoices/bulk/email")
def bulk_email(
    payload: BulkInvoiceIdsIn,
    user: dict = Depends(get_current_user),
):
    _require(user, "bulk:invoice_actions")
    db = SessionLocal()
    try:
        result = inv_service.bulk_send_invoice_emails(
            db, payload.invoice_ids,
            user_id=user.get("user_id") or user.get("sub"),
        )
        return {"success": True, "data": result}
    finally:
        db.close()


# ── Attachments ──────────────────────────────────────────


@router.post("/invoices/{invoice_id}/attachments", status_code=201)
def upload_attachment(
    invoice_id: str,
    payload: dict = Body(...),
    user: dict = Depends(get_current_user),
):
    """Body shape:
        {
          "invoice_type": "sales" | "purchase" | "credit_note",
          "filename": "...",
          "mime_type": "...",
          "content_b64": "<base64 file bytes>"
        }
    Storage backend hookup (S3 / local FS) is left to a follow-up;
    for now we record the metadata + a synthetic storage_key.
    """
    _require(user, "upload:invoice_attachments")
    invoice_type = payload.get("invoice_type") or InvoiceType.SALES
    filename = payload.get("filename")
    mime_type = payload.get("mime_type") or "application/octet-stream"
    content_b64 = payload.get("content_b64") or ""
    if not filename:
        raise HTTPException(status_code=422, detail="filename is required")
    try:
        size = len(base64.b64decode(content_b64)) if content_b64 else 0
    except Exception:
        size = 0
    storage_key = f"local/invoices/{invoice_id}/{filename}"
    db = SessionLocal()
    try:
        att = inv_service.create_attachment(
            db,
            invoice_id=invoice_id,
            invoice_type=invoice_type,
            filename=filename,
            file_size=size,
            mime_type=mime_type,
            storage_key=storage_key,
            user_id=user.get("user_id") or user.get("sub"),
            tenant_id=user.get("tenant_id"),
        )
        return {"success": True, "data": _att_to_out(att).model_dump(mode="json")}
    finally:
        db.close()


@router.get("/invoices/{invoice_id}/attachments")
def list_invoice_attachments(
    invoice_id: str, user: dict = Depends(get_current_user)
):
    _require(user, "read:invoices")
    db = SessionLocal()
    try:
        rows = inv_service.list_attachments(db, invoice_id)
        return {
            "success": True,
            "data": [_att_to_out(r).model_dump(mode="json") for r in rows],
        }
    finally:
        db.close()


@router.delete("/attachments/{attachment_id}")
def delete_attachment(
    attachment_id: str, user: dict = Depends(get_current_user)
):
    _require(user, "upload:invoice_attachments")
    db = SessionLocal()
    try:
        try:
            inv_service.delete_attachment(db, attachment_id)
        except inv_service.AttachmentNotFoundError:
            raise HTTPException(status_code=404, detail="attachment not found")
        return {"success": True, "data": {"id": attachment_id}}
    finally:
        db.close()


# ── Write-off ────────────────────────────────────────────


@router.post("/invoices/{invoice_id}/write-off")
def write_off_invoice(
    invoice_id: str,
    payload: WriteOffIn,
    user: dict = Depends(get_current_user),
):
    _require(user, "write_off:invoices")
    db = SessionLocal()
    try:
        try:
            result = inv_service.write_off_invoice(
                db, invoice_id, payload.reason,
                user_id=user.get("user_id") or user.get("sub"),
                write_off_account_id=payload.write_off_account_id,
            )
        except inv_service.InvoiceNotFoundError:
            raise HTTPException(status_code=404, detail="invoice not found")
        except inv_service.InvoicingError as e:
            raise HTTPException(status_code=500, detail=str(e))
        return {"success": True, "data": result}
    finally:
        db.close()


# ── Admin endpoint for the recurring scheduler ────────────


@router.post("/admin/run-due-now")
def admin_run_due_now(user: dict = Depends(get_current_user)):
    """Run every due recurring template right now.

    Permission gate is `run:recurring_invoices` for now; tighten to
    an admin secret once the scheduler is in production.
    """
    _require(user, "run:recurring_invoices")
    db = SessionLocal()
    try:
        templates = inv_service.list_due_recurring(db)
        results: list[dict] = []
        for t in templates:
            try:
                r = inv_service.run_recurring_template(
                    db, t.id,
                    user_id=user.get("user_id") or user.get("sub"),
                    force_today=True,
                )
                results.append({"template_id": t.id, **r})
            except Exception as e:  # noqa: BLE001
                results.append({"template_id": t.id, "error": str(e)})
        return {"success": True, "data": {"ran": len(results), "results": results}}
    finally:
        db.close()


__all__ = ["router"]
