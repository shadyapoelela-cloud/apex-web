"""ZATCA Engine — توليد QR TLV + invoice hash + chain للمرحلة الثانية.

المرحلة الثانية من ZATCA (Integration Phase) تتطلب:
  1. لكل فاتورة: QR code بصيغة TLV (Tag-Length-Value) مُشفَّر Base64
  2. invoice_hash: SHA-256 hash للفاتورة بصيغة Base64
  3. previous_invoice_hash: سلسلة تربط كل فاتورة بالتي قبلها
  4. ICV (Invoice Counter Value): تسلسلي بلا فجوات بدءاً من 1
  5. UUID: معرّف فريد لكل فاتورة (UUIDv4)
  6. للمبسّطة (simplified): الحقول الأساسية + QR TLV
  7. للضريبية (standard): XML UBL 2.1 موقّع + إرسال مباشر قبل العميل

TLV fields (للمبسّطة):
  Tag 1: Seller Name (اسم البائع)
  Tag 2: VAT Number (الرقم الضريبي — 15 رقم)
  Tag 3: Invoice Date & Time (ISO 8601)
  Tag 4: Invoice Total with VAT (شامل VAT)
  Tag 5: VAT Amount
  Tag 6: XML Hash (Base64) — للمرحلة 2
  Tag 7: Public Key — للمرحلة 2
  Tag 8: Signature — للمرحلة 2

لأغراض الاختبار والـ Day-1، هذا المحرّك يولّد Tags 1-5 + 6 (hash)،
ويترك 7-8 للتكامل مع ZATCA Fatoora portal الفعلي (يتطلب CSR/CSID).
"""

import base64
import hashlib
import uuid as _uuid
from datetime import datetime, timezone, date
from decimal import Decimal
from typing import Optional

from sqlalchemy.orm import Session

from app.pilot.models import (
    Tenant, Entity, Branch,
    ZatcaOnboarding, ZatcaInvoiceSubmission,
    ZatcaEnvironment, ZatcaInvoiceKind, ZatcaSubmissionStatus,
    PosTransaction, PosTransactionLine, PosPayment,
)


# ══════════════════════════════════════════════════════════════════════════
# TLV encoder
# ══════════════════════════════════════════════════════════════════════════

def _tlv_encode(tag: int, value: str | bytes) -> bytes:
    """Encode a single TLV field.

    Tag: 1 byte (1-255)
    Length: 1 byte (0-255) — length of value
    Value: raw bytes
    """
    if isinstance(value, str):
        value_bytes = value.encode("utf-8")
    else:
        value_bytes = value
    if len(value_bytes) > 255:
        raise ValueError(f"TLV value too long for tag {tag}: {len(value_bytes)} bytes (max 255)")
    return bytes([tag, len(value_bytes)]) + value_bytes


def build_qr_tlv(
    *,
    seller_name: str,
    vat_number: str,
    invoice_datetime: datetime,
    total_with_vat: Decimal,
    vat_amount: Decimal,
    invoice_hash: Optional[str] = None,
) -> str:
    """يبني QR TLV Base64 لفاتورة مبسّطة (ZATCA Phase 1/2)."""
    parts = b""
    parts += _tlv_encode(1, seller_name)
    parts += _tlv_encode(2, vat_number)
    # ISO 8601 UTC
    if invoice_datetime.tzinfo is None:
        invoice_datetime = invoice_datetime.replace(tzinfo=timezone.utc)
    parts += _tlv_encode(3, invoice_datetime.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))
    parts += _tlv_encode(4, f"{float(total_with_vat):.2f}")
    parts += _tlv_encode(5, f"{float(vat_amount):.2f}")
    if invoice_hash:
        parts += _tlv_encode(6, invoice_hash)
    return base64.b64encode(parts).decode("ascii")


# ══════════════════════════════════════════════════════════════════════════
# Invoice hash + chain
# ══════════════════════════════════════════════════════════════════════════

def compute_invoice_hash(canonical_content: str) -> str:
    """SHA-256 للـ canonical content → Base64."""
    digest = hashlib.sha256(canonical_content.encode("utf-8")).digest()
    return base64.b64encode(digest).decode("ascii")


def build_canonical_content(
    *, invoice_uuid: str, invoice_counter: int, issue_date: date,
    total_excl_vat: Decimal, vat_total: Decimal, total_incl_vat: Decimal,
    previous_hash: Optional[str] = None,
) -> str:
    """Build a deterministic canonical string used to compute invoice_hash.

    في الواقع ZATCA يستخدم canonical XML hashing. هنا نستخدم تنسيق مبسّط
    قابل للاستبدال بالـ UBL XML الحقيقي لاحقاً.
    """
    parts = [
        f"UUID:{invoice_uuid}",
        f"ICV:{invoice_counter}",
        f"DATE:{issue_date.isoformat()}",
        f"EXCL:{float(total_excl_vat):.2f}",
        f"VAT:{float(vat_total):.2f}",
        f"INCL:{float(total_incl_vat):.2f}",
        f"PIH:{previous_hash or ''}",
    ]
    return "|".join(parts)


# ══════════════════════════════════════════════════════════════════════════
# Onboarding
# ══════════════════════════════════════════════════════════════════════════

def create_or_get_onboarding(
    db: Session, *, entity: Entity,
    environment: str = ZatcaEnvironment.developer_portal.value,
    vat_number: Optional[str] = None,
) -> ZatcaOnboarding:
    """يُنشئ سجل Onboarding إذا لم يكن موجوداً."""
    existing = db.query(ZatcaOnboarding).filter(
        ZatcaOnboarding.entity_id == entity.id,
        ZatcaOnboarding.environment == environment,
    ).first()
    if existing:
        return existing
    onb = ZatcaOnboarding(
        tenant_id=entity.tenant_id,
        entity_id=entity.id,
        environment=environment,
        vat_registration_number=vat_number or entity.vat_number,
        cr_number=entity.cr_number,
        status="pending",
        invoice_counter=0,
    )
    db.add(onb)
    db.flush()
    return onb


def simulate_csid_issuance(db: Session, onboarding: ZatcaOnboarding) -> ZatcaOnboarding:
    """محاكاة لإصدار CSID — في الإنتاج يُستبدل بـ REST call إلى ZATCA.

    نُولّد CSID placeholder (sha256 من entity_id + timestamp) + certificate وهمية.
    """
    seed = f"{onboarding.entity_id}|{datetime.now(timezone.utc).isoformat()}"
    csid = hashlib.sha256(seed.encode()).hexdigest()[:40].upper()
    onboarding.csid = csid
    onboarding.csid_certificate_pem = f"-----BEGIN CERTIFICATE-----\nSIMULATED-{csid}\n-----END CERTIFICATE-----"
    onboarding.csid_issued_at = datetime.now(timezone.utc)
    onboarding.status = "onboarded"
    db.flush()
    return onboarding


# ══════════════════════════════════════════════════════════════════════════
# Invoice submission (from POS)
# ══════════════════════════════════════════════════════════════════════════

def submit_pos_invoice(
    db: Session, *, pos_txn_id: str,
    simulate: bool = True,
) -> ZatcaInvoiceSubmission:
    """يُولّد ZatcaInvoiceSubmission من معاملة POS مكتملة.

    الخطوات:
      1. تحميل POS txn + entity + onboarding النشط
      2. توليد UUID + ICV تسلسلي
      3. بناء canonical content + invoice_hash
      4. ربط PIH من آخر فاتورة (chain)
      5. بناء QR TLV
      6. إنشاء ZatcaInvoiceSubmission (status=submitted في simulate mode)
      7. تحديث onboarding.invoice_counter + previous_invoice_hash
    """
    txn = db.query(PosTransaction).filter(PosTransaction.id == pos_txn_id).first()
    if not txn:
        raise ValueError("معاملة POS غير موجودة")
    if txn.status != "completed":
        raise ValueError(f"فقط المعاملات المكتملة تُرسل (الحالية: {txn.status})")

    # تحقق idempotency
    existing = db.query(ZatcaInvoiceSubmission).filter(
        ZatcaInvoiceSubmission.source_type == "pos_txn",
        ZatcaInvoiceSubmission.source_id == txn.id,
    ).first()
    if existing:
        return existing

    branch = db.query(Branch).filter(Branch.id == txn.branch_id).first()
    entity = db.query(Entity).filter(Entity.id == branch.entity_id).first()
    tenant = db.query(Tenant).filter(Tenant.id == txn.tenant_id).first()

    if entity.country != "SA":
        raise ValueError(f"ZATCA خاص بالسعودية فقط — الكيان {entity.code} في {entity.country}")

    # Onboarding
    onboarding = create_or_get_onboarding(db, entity=entity)
    if onboarding.status == "pending":
        onboarding = simulate_csid_issuance(db, onboarding)

    # ICV و UUID
    new_icv = (onboarding.invoice_counter or 0) + 1
    inv_uuid = str(_uuid.uuid4())

    # كمية القيم
    total_excl = abs(txn.taxable_amount or Decimal("0"))
    vat_total = abs(txn.vat_total or Decimal("0"))
    total_incl = abs(txn.grand_total or Decimal("0"))

    # canonical content + hash
    canonical = build_canonical_content(
        invoice_uuid=inv_uuid,
        invoice_counter=new_icv,
        issue_date=txn.transacted_at.date(),
        total_excl_vat=total_excl,
        vat_total=vat_total,
        total_incl_vat=total_incl,
        previous_hash=onboarding.previous_invoice_hash,
    )
    inv_hash = compute_invoice_hash(canonical)

    # QR TLV
    qr_tlv = build_qr_tlv(
        seller_name=entity.name_ar or entity.name_en or tenant.legal_name_ar,
        vat_number=entity.vat_number or tenant.primary_vat_number or "000000000000000",
        invoice_datetime=txn.transacted_at,
        total_with_vat=total_incl,
        vat_amount=vat_total,
        invoice_hash=inv_hash,
    )

    sub = ZatcaInvoiceSubmission(
        tenant_id=entity.tenant_id,
        entity_id=entity.id,
        onboarding_id=onboarding.id,
        source_type="pos_txn",
        source_id=txn.id,
        source_reference=txn.receipt_number,
        invoice_kind=ZatcaInvoiceKind.simplified.value,
        invoice_uuid=inv_uuid,
        invoice_counter=new_icv,
        invoice_hash=inv_hash,
        previous_invoice_hash=onboarding.previous_invoice_hash,
        qr_tlv_base64=qr_tlv,
        total_excl_vat=total_excl,
        total_vat=vat_total,
        total_incl_vat=total_incl,
        status=(ZatcaSubmissionStatus.reported.value if simulate
                else ZatcaSubmissionStatus.pending.value),
        submitted_at=(datetime.now(timezone.utc) if simulate else None),
        zatca_uuid_ack=(inv_uuid if simulate else None),
        response_json=({"simulated": True, "status": "reported"} if simulate else None),
    )
    db.add(sub)
    db.flush()

    # تحديث onboarding chain
    onboarding.invoice_counter = new_icv
    onboarding.previous_invoice_hash = inv_hash

    # نسخ القيم المحسوبة إلى سجل POS
    txn.zatca_uuid = inv_uuid
    txn.zatca_hash = inv_hash
    txn.zatca_previous_hash = sub.previous_invoice_hash
    txn.zatca_qr_payload = qr_tlv
    txn.zatca_status = sub.status
    txn.zatca_submitted_at = sub.submitted_at

    db.flush()
    return sub


# ══════════════════════════════════════════════════════════════════════════
# TLV decoder (للتحقق والاختبار)
# ══════════════════════════════════════════════════════════════════════════

def decode_qr_tlv(qr_base64: str) -> dict:
    """فكّ ترميز QR TLV ليُعيد الحقول بوضوح (للتحقق أو العرض)."""
    raw = base64.b64decode(qr_base64)
    result: dict[int, str] = {}
    i = 0
    while i < len(raw):
        tag = raw[i]
        length = raw[i+1]
        value = raw[i+2:i+2+length]
        try:
            result[tag] = value.decode("utf-8")
        except UnicodeDecodeError:
            result[tag] = value.hex()
        i += 2 + length
    return {
        "seller_name": result.get(1),
        "vat_number": result.get(2),
        "invoice_datetime": result.get(3),
        "total_with_vat": result.get(4),
        "vat_amount": result.get(5),
        "invoice_hash": result.get(6),
        "public_key": result.get(7),
        "signature": result.get(8),
        "raw_tags": result,
    }
