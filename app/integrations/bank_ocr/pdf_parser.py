"""PDF bank-statement parser — text-layer first, Claude Vision fallback.

Strategy:
  1. Try pdfplumber on the PDF bytes. If it extracts text, feed to the
     bank detector + appropriate template.
  2. If no text layer (scanned PDF), fall back to Claude Vision when
     OCR_VISION_ENABLED=true and ANTHROPIC_API_KEY is set.
  3. Bank detection is done via keywords in the first page — each template
     declares its signature strings.

Graceful degradation:
  - If pdfplumber is not installed: return a ParsedStatement with a clear
    warning rather than raising.
  - If Claude Vision is disabled or unavailable: same.

This lets us ship the scaffold today and incrementally harden the parsing
per-bank as sample statements come in.
"""

from __future__ import annotations

import io
import logging
import os
import re
from datetime import date, datetime
from decimal import Decimal, InvalidOperation
from typing import Optional

from app.integrations.bank_ocr.parsers import (
    BankTransaction,
    ParsedStatement,
    _parse_date as _parse_date_common,
    _to_decimal,
)

logger = logging.getLogger(__name__)

OCR_VISION_ENABLED = os.environ.get("OCR_VISION_ENABLED", "false").lower() == "true"


# ── pdfplumber wrapper (lazy + graceful) ───────────────────


def _extract_pdf_text(content: bytes) -> Optional[str]:
    """Return the concatenated text of all pages, or None on failure."""
    try:
        import pdfplumber
    except ImportError:
        return None
    try:
        with pdfplumber.open(io.BytesIO(content)) as pdf:
            parts: list[str] = []
            for page in pdf.pages:
                text = page.extract_text() or ""
                if text:
                    parts.append(text)
            return "\n".join(parts) if parts else None
    except Exception as e:
        logger.warning("pdfplumber failed: %s", e)
        return None


def _extract_pdf_tables(content: bytes) -> list[list[list[str]]]:
    """Return a list of tables (list of rows) across all pages, or []."""
    try:
        import pdfplumber
    except ImportError:
        return []
    tables: list[list[list[str]]] = []
    try:
        with pdfplumber.open(io.BytesIO(content)) as pdf:
            for page in pdf.pages:
                for tbl in page.extract_tables() or []:
                    if tbl and len(tbl) > 1:
                        tables.append(tbl)
        return tables
    except Exception as e:
        logger.warning("pdfplumber table extract failed: %s", e)
        return []


# ── Claude Vision fallback (stub) ──────────────────────────


def _extract_via_claude_vision(content: bytes) -> Optional[str]:
    """When OCR_VISION_ENABLED and ANTHROPIC_API_KEY are set, ask Claude to
    read the PDF. Returns the extracted text-like representation.

    This is a scaffold — the full integration wires anthropic SDK, converts
    PDF pages to images, and feeds them as vision inputs. For now we
    return None so the bank detector can report "scanned PDF, OCR not
    available".
    """
    if not OCR_VISION_ENABLED:
        return None
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not api_key:
        return None
    logger.info("Claude Vision OCR requested (scaffold — not yet implemented)")
    return None


# ── Bank detectors ─────────────────────────────────────────


# Each entry: (bank_id, bank_name_ar, list of signatures to look for)
_BANK_SIGNATURES = [
    ("al_rajhi", "مصرف الراجحي",
        ["مصرف الراجحي", "Al Rajhi Bank", "alrajhibank.com.sa"]),
    ("snb", "البنك الأهلي السعودي (SNB)",
        ["البنك الأهلي السعودي", "Saudi National Bank", "SNB", "alahli.com"]),
    ("riyad", "بنك الرياض",
        ["بنك الرياض", "Riyad Bank", "riyadbank.com"]),
    ("albilad", "بنك البلاد",
        ["بنك البلاد", "Bank Albilad", "bankalbilad.com"]),
    ("enbd", "Emirates NBD",
        ["Emirates NBD", "ENBD", "emiratesnbd.com"]),
    ("fab", "First Abu Dhabi Bank",
        ["First Abu Dhabi", "FAB ", "bankfab.com"]),
    ("adcb", "ADCB",
        ["Abu Dhabi Commercial Bank", "ADCB", "adcb.com"]),
    ("mashreq", "Mashreq",
        ["Mashreq Bank", "Mashreq ", "mashreq.com"]),
]


def detect_bank(text: str) -> str:
    """Return the bank_id that matches the statement text, or 'unknown'."""
    upper = (text or "")[:4096]
    for bank_id, _, sigs in _BANK_SIGNATURES:
        if any(sig in upper for sig in sigs):
            return bank_id
    return "unknown"


# ── Generic table-based row parser ─────────────────────────


_AR_DIGITS = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")


def _clean(cell: Optional[str]) -> str:
    if cell is None:
        return ""
    return str(cell).translate(_AR_DIGITS).strip()


def _parse_amount(cell: Optional[str]) -> Optional[Decimal]:
    c = _clean(cell)
    if not c:
        return None
    # Strip common currency markers
    c = c.replace("SAR", "").replace("AED", "").replace("ر.س", "").replace(",", "").strip()
    # Handle parentheses for negatives
    if c.startswith("(") and c.endswith(")"):
        c = "-" + c[1:-1]
    try:
        return Decimal(c)
    except (InvalidOperation, ValueError):
        return None


def _parse_pdf_table(rows: list[list[str]]) -> list[BankTransaction]:
    """Heuristic row parser — tolerates bank-specific column orders.

    Looks at the header row to find date / description / debit / credit /
    balance columns, then iterates data rows.
    """
    if not rows or len(rows) < 2:
        return []
    header = [_clean(c).lower() for c in rows[0]]

    def _idx(keywords: list[str]) -> int:
        for i, h in enumerate(header):
            if any(k in h for k in keywords):
                return i
        return -1

    idx_date = _idx(["date", "التاريخ", "تاريخ"])
    idx_desc = _idx(["description", "details", "narration", "reference", "البيان", "بيان"])
    idx_debit = _idx(["debit", "withdraw", "مدين", "سحب"])
    idx_credit = _idx(["credit", "deposit", "دائن", "إيداع"])
    idx_bal = _idx(["balance", "الرصيد", "رصيد"])

    if idx_date < 0:
        return []

    out: list[BankTransaction] = []
    for row in rows[1:]:
        if len(row) <= idx_date:
            continue
        d = _parse_date_common(_clean(row[idx_date]))
        if d is None:
            continue
        desc = _clean(row[idx_desc]) if idx_desc >= 0 and idx_desc < len(row) else ""
        debit = _parse_amount(row[idx_debit]) if idx_debit >= 0 and idx_debit < len(row) else None
        credit = _parse_amount(row[idx_credit]) if idx_credit >= 0 and idx_credit < len(row) else None
        balance = _parse_amount(row[idx_bal]) if idx_bal >= 0 and idx_bal < len(row) else None

        if debit and debit > 0:
            out.append(BankTransaction(
                txn_date=d, amount=debit, direction="debit",
                description=desc, balance_after=balance,
            ))
        elif credit and credit > 0:
            out.append(BankTransaction(
                txn_date=d, amount=credit, direction="credit",
                description=desc, balance_after=balance,
            ))
    return out


# ── Public entry point ─────────────────────────────────────


def parse_pdf(content: bytes, bank_hint: Optional[str] = None) -> ParsedStatement:
    """Parse a PDF bank statement into a ParsedStatement.

    Never raises — returns a ParsedStatement with warnings on failure.
    """
    warnings: list[str] = []

    text = _extract_pdf_text(content)
    if not text:
        # Scanned PDF — try Claude Vision.
        text = _extract_via_claude_vision(content)
        if not text:
            warnings.append(
                "PDF has no extractable text layer. "
                "Enable OCR_VISION_ENABLED=true + set ANTHROPIC_API_KEY "
                "for Claude Vision OCR."
            )
            return ParsedStatement(
                bank=bank_hint or "unknown_scanned",
                account_number=None,
                currency="SAR",
                period_start=None,
                period_end=None,
                opening_balance=None,
                closing_balance=None,
                transactions=[],
                warnings=warnings,
            )

    bank_id = detect_bank(text) if not bank_hint else bank_hint
    tables = _extract_pdf_tables(content)
    txns: list[BankTransaction] = []
    for tbl in tables:
        txns.extend(_parse_pdf_table(tbl))

    if not txns:
        warnings.append(
            f"Bank={bank_id}: no transactions extracted from {len(tables)} table(s). "
            "A bank-specific template may be needed."
        )

    return ParsedStatement(
        bank=bank_id,
        account_number=_extract_account_number(text),
        currency="SAR" if bank_id in ("al_rajhi", "snb", "riyad", "albilad") else
                 "AED" if bank_id in ("enbd", "fab", "adcb", "mashreq") else "SAR",
        period_start=min((t.txn_date for t in txns), default=None),
        period_end=max((t.txn_date for t in txns), default=None),
        opening_balance=None,
        closing_balance=txns[-1].balance_after if txns else None,
        transactions=txns,
        warnings=warnings,
    )


def _extract_account_number(text: str) -> Optional[str]:
    """Best-effort account extraction — Saudi IBAN starts with SA + 22 digits."""
    m = re.search(r"\b(SA\d{22})\b", text)
    if m:
        return m.group(1)
    # UAE IBAN pattern
    m = re.search(r"\b(AE\d{21})\b", text)
    if m:
        return m.group(1)
    return None
