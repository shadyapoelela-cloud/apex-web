"""Attachments — ملفات مرفقة بأي كيان محاسبي (JE, PO, PI, Vendor, Payment, إلخ).

يستخدم polymorphic pattern:
    parent_type + parent_id → يشير لأي جدول (journal_entries, purchase_orders, ...)

الحماية:
    • الملف نفسه يُخزَّن في storage (S3/local) عبر STORAGE_BACKEND
    • هنا نخزّن metadata فقط + URL/path
    • على ZATCA submission، المرفقات تُقفَل (immutable)

مطلب محاسبي SOCPA/ZATCA: كل قيد يومية + كل فاتورة يجب أن يكون لها مستند مصدر
محفوظ لـ 7 سنوات. هذا الجدول ينفّذ هذا المطلب.
"""

import enum
from sqlalchemy import (
    Column, String, Integer, DateTime, ForeignKey, Index, Boolean, Text,
)

from app.phase1.models.platform_models import Base, gen_uuid, utcnow


class AttachmentKind(str, enum.Enum):
    """نوع المستند المرجعي."""
    invoice = "invoice"           # فاتورة المورد الورقية/PDF
    receipt = "receipt"           # إيصال دفع
    delivery_note = "delivery_note"  # بوليصة تسليم
    contract = "contract"         # عقد
    cr_document = "cr_document"   # سجل تجاري
    vat_cert = "vat_cert"         # شهادة ضريبية
    bank_letter = "bank_letter"   # خطاب بنكي / IBAN
    purchase_order = "purchase_order"  # نسخة PO ممضاة
    other = "other"


class Attachment(Base):
    """مرفق polymorphic لأي كيان في الـ pilot module.

    parent_type: اسم الجدول (مثال: "journal_entries", "purchase_orders", "vendors")
    parent_id: UUID السجل الأب
    """
    __tablename__ = "pilot_attachments"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(
        String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )

    # Polymorphic parent
    parent_type = Column(String(50), nullable=False, index=True)
    parent_id = Column(String(36), nullable=False, index=True)

    # Metadata
    kind = Column(
        String(30), nullable=False, default=AttachmentKind.other.value,
    )
    filename = Column(String(255), nullable=False)
    content_type = Column(String(100), nullable=True)  # MIME type
    size_bytes = Column(Integer, nullable=True)
    description = Column(Text, nullable=True)

    # Storage location
    #   • إذا STORAGE_BACKEND=local: file://path/to/file
    #   • إذا STORAGE_BACKEND=s3: s3://bucket/key
    #   • إذا data URI صغير (<1 MB): data:image/png;base64,...
    storage_url = Column(String(2000), nullable=False)

    # Audit
    uploaded_by_user_id = Column(String(36), nullable=True)
    uploaded_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)

    # Immutability — بعد ZATCA clearance أو period close، لا يُحذف
    is_locked = Column(Boolean, nullable=False, default=False)
    locked_reason = Column(String(255), nullable=True)

    __table_args__ = (
        Index("ix_pilot_attachments_parent", "parent_type", "parent_id"),
        Index("ix_pilot_attachments_tenant_kind", "tenant_id", "kind"),
    )
