"""AI-powered Journal-Entry extraction from uploaded documents.

POST /pilot/entities/{entity_id}/ai/read-document
  - Accepts a PDF or image file (invoice, receipt, bank slip, etc.)
  - Uses Claude Sonnet 4 (vision) to extract transaction details
  - Proposes a balanced Journal Entry against the entity's Chart of Accounts
  - Does NOT save — the frontend lets the user review/edit then confirm

When `ANTHROPIC_API_KEY` is not configured, returns a mock response so the
UI remains functional in dev.
"""

from __future__ import annotations

import base64
import json
import logging
import os
from typing import Any, Dict

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy.orm import Session

from app.phase1.models.platform_models import get_db
from app.pilot.models import Entity, GLAccount

router = APIRouter(prefix="/pilot", tags=["AI / Journal Entries"])

ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY", "")
_CLAUDE_MODEL = os.environ.get("CLAUDE_MODEL", "claude-sonnet-4-20250514")
_MAX_FILE_BYTES = 20 * 1024 * 1024  # 20 MB
_ALLOWED_TYPES = {
    "application/pdf",
    "image/png",
    "image/jpeg",
    "image/jpg",
    "image/webp",
}


@router.post("/entities/{entity_id}/ai/read-document")
async def ai_read_document(
    entity_id: str,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
) -> Dict[str, Any]:
    """Extract a proposed journal entry from an uploaded document."""

    # ── Validate entity ────────────────────────────────────────────
    entity = db.query(Entity).filter(Entity.id == entity_id).first()
    if entity is None:
        raise HTTPException(status_code=404, detail="Entity not found")

    # ── Validate file ──────────────────────────────────────────────
    content_type = (file.content_type or "").lower()
    if content_type not in _ALLOWED_TYPES:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Unsupported file type: {content_type}. "
                "Accepted: PDF, PNG, JPG, WEBP."
            ),
        )

    data = await file.read()
    if len(data) > _MAX_FILE_BYTES:
        raise HTTPException(status_code=413, detail="File too large (max 20 MB)")
    if not data:
        raise HTTPException(status_code=400, detail="Empty file")

    # ── Chart of Accounts context for the LLM ──────────────────────
    accounts = (
        db.query(GLAccount)
        .filter(GLAccount.entity_id == entity_id)
        .order_by(GLAccount.code)
        .all()
    )
    # Only detail (postable) accounts
    detail_accounts = [a for a in accounts if getattr(a, "type", None) in ("detail", "Detail", None)]
    coa_lines = [
        f"  {getattr(a, 'code', '?')} | {getattr(a, 'name_ar', '') or getattr(a, 'name_en', '')}"
        for a in detail_accounts[:150]
    ]
    coa_context = "\n".join(coa_lines) if coa_lines else "(لم تُبذر شجرة الحسابات بعد)"

    # ── Fallback: no API key → mock proposal ───────────────────────
    if not ANTHROPIC_API_KEY:
        return {
            "success": True,
            "data": _mock_proposal(file.filename or "document", detail_accounts),
            "mock": True,
        }

    # ── Call Claude with the file ──────────────────────────────────
    try:
        import anthropic  # type: ignore
    except ImportError as exc:
        logging.error("anthropic package not installed: %s", exc)
        raise HTTPException(
            status_code=500,
            detail="Anthropic SDK not installed on server",
        ) from exc

    client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)

    system_prompt = _build_system_prompt(coa_context)

    file_b64 = base64.standard_b64encode(data).decode("utf-8")
    # PDFs go via "document" block; images via "image" block.
    if content_type == "application/pdf":
        file_block = {
            "type": "document",
            "source": {
                "type": "base64",
                "media_type": "application/pdf",
                "data": file_b64,
            },
        }
    else:
        file_block = {
            "type": "image",
            "source": {
                "type": "base64",
                "media_type": content_type,
                "data": file_b64,
            },
        }

    try:
        response = client.messages.create(
            model=_CLAUDE_MODEL,
            max_tokens=2000,
            temperature=0.2,
            system=system_prompt,
            messages=[
                {
                    "role": "user",
                    "content": [
                        file_block,
                        {
                            "type": "text",
                            "text": (
                                "حلّل هذا المستند واستخرج قيد اليومية المقترح. "
                                "أرجع JSON فقط — بدون markdown أو شرح إضافي."
                            ),
                        },
                    ],
                }
            ],
        )
    except anthropic.APIError as exc:  # type: ignore[attr-defined]
        logging.error("Claude API error: %s", exc)
        raise HTTPException(status_code=502, detail=f"Claude API error: {exc}") from exc
    except Exception as exc:  # noqa: BLE001 — surface any other error
        logging.error("AI document read failed: %s", exc, exc_info=True)
        raise HTTPException(status_code=502, detail=f"AI error: {exc}") from exc

    ai_text = "".join(
        getattr(block, "text", "") for block in (response.content or [])
    ).strip()

    # Tolerate markdown fences
    if ai_text.startswith("```"):
        stripped = ai_text.strip("`").strip()
        # remove an optional "json" language tag
        if stripped.lower().startswith("json"):
            stripped = stripped[4:].lstrip("\n")
        # drop trailing fence if still present
        if stripped.endswith("```"):
            stripped = stripped[:-3].rstrip()
        ai_text = stripped

    try:
        parsed = json.loads(ai_text)
    except json.JSONDecodeError as exc:
        logging.error("AI returned non-JSON: %s | raw=%s", exc, ai_text[:500])
        raise HTTPException(
            status_code=502,
            detail=f"AI returned invalid JSON: {exc}",
        ) from exc

    # Enrich proposed lines with account_id when code matches CoA
    coa_by_code = {str(getattr(a, "code", "")): a for a in detail_accounts}
    proposed = parsed.get("proposed_je", {}) if isinstance(parsed, dict) else {}
    for line in proposed.get("lines", []) or []:
        code = str(line.get("account_code") or "")
        if code and code in coa_by_code:
            acc = coa_by_code[code]
            line["account_id"] = getattr(acc, "id", None)
            line["account_name_resolved"] = getattr(acc, "name_ar", "") or getattr(
                acc, "name_en", ""
            )

    return {"success": True, "data": parsed, "mock": False}


# ═══════════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════════

def _build_system_prompt(coa_context: str) -> str:
    return f"""أنت مساعد محاسبي خبير متخصّص في المعايير السعودية (SOCPA) والضرائب (ZATCA).

**مهمتك**: قراءة المستند المرفق (فاتورة / إيصال / كشف / عقد) واستخراج قيد يومية مقترح متوازن.

**خطوات العمل**:
1. استخرج من المستند: التاريخ، الطرف، الوصف، المبلغ الإجمالي، ضريبة القيمة المضافة (إن وجدت)، العملة.
2. اختر الحسابات المناسبة من شجرة حسابات الشركة (المدرجة أدناه).
3. اقترح قيداً متوازناً (المدين = الدائن).
4. إذا كان هناك VAT، افصله في سطر منفصل (حساب VAT مستحق أو قابل للاسترداد).

**شجرة الحسابات المتاحة (Detail accounts فقط)**:
{coa_context}

**قاعدة صارمة**: أرجع JSON صحيحاً فقط — بدون markdown، بدون شرح قبل أو بعد.

**البنية المطلوبة**:
{{
  "confidence": 0.0-1.0,
  "extracted": {{
    "date": "YYYY-MM-DD",
    "vendor": "اسم الطرف",
    "document_number": "رقم المستند (إن وجد)",
    "description": "وصف موجز للمعاملة",
    "amount": 0.00,
    "tax_amount": 0.00,
    "currency": "SAR"
  }},
  "proposed_je": {{
    "memo_ar": "بيان واضح موجز",
    "kind": "manual",
    "lines": [
      {{
        "account_code": "الرقم من الشجرة",
        "account_name": "اسم الحساب المقترح",
        "debit": 0.00,
        "credit": 0.00,
        "description": "تفصيل السطر"
      }}
    ]
  }},
  "warnings": ["تحذيرات (فارغة إن لم يوجد)"],
  "notes": "ملاحظات للمراجع"
}}

**تحقّقات قبل الإرجاع**:
- مجموع المدين = مجموع الدائن.
- جميع account_code موجودة في شجرة الحسابات المقدّمة.
- confidence منخفض (< 0.5) إذا كان المستند غير واضح.
"""


def _mock_proposal(filename: str, accounts: list) -> Dict[str, Any]:
    """Fallback proposal used when ANTHROPIC_API_KEY is missing.

    Picks the first expense + first cash-like account from the CoA so the
    UI gets real account IDs to render.
    """
    expense = next(
        (a for a in accounts if "مصروف" in (getattr(a, "name_ar", "") or "")),
        None,
    ) or (accounts[0] if accounts else None)
    cash = next(
        (
            a
            for a in accounts
            if "بنك" in (getattr(a, "name_ar", "") or "")
            or "صندوق" in (getattr(a, "name_ar", "") or "")
        ),
        None,
    ) or (accounts[1] if len(accounts) > 1 else expense)

    def _acc_dict(a, debit, credit):
        return {
            "account_code": getattr(a, "code", "") if a else "",
            "account_id": getattr(a, "id", None) if a else None,
            "account_name": (getattr(a, "name_ar", "") or getattr(a, "name_en", "")) if a else "",
            "debit": debit,
            "credit": credit,
            "description": "",
        }

    return {
        "confidence": 0.60,
        "extracted": {
            "date": None,
            "vendor": "مورد (تجريبي)",
            "document_number": None,
            "description": f"قراءة تجريبية من {filename}",
            "amount": 1000.00,
            "tax_amount": 150.00,
            "currency": "SAR",
        },
        "proposed_je": {
            "memo_ar": f"فاتورة مقترحة — {filename}",
            "kind": "manual",
            "lines": [
                _acc_dict(expense, 1000.00, 0.0),
                _acc_dict(cash, 0.0, 1000.00),
            ],
        },
        "warnings": [
            "هذا اقتراح تجريبي (لم يُفعَّل Claude). عيّن متغيّر البيئة "
            "ANTHROPIC_API_KEY للحصول على تحليل حقيقي للمستند."
        ],
        "notes": "راجع الحسابات والمبالغ قبل الحفظ.",
    }
