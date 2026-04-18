"""Bank statement parsers — normalize heterogeneous inputs to BankTransaction.

Each bank has its own statement format; rather than embedding format logic
inline, we register one parser per (bank, format) pair. The public API is
a single `parse_statement(bytes|path, bank_hint=?)` function.

For scanned PDFs (no text layer), `_parse_scanned_pdf` will delegate to
Claude Vision via anthropic SDK — controlled by OCR_VISION_ENABLED env var.
"""

from __future__ import annotations

import csv
import io
import logging
import os
import re
from dataclasses import dataclass, field
from datetime import date, datetime
from decimal import Decimal, InvalidOperation
from typing import Optional

logger = logging.getLogger(__name__)


@dataclass
class BankTransaction:
    """Normalized bank transaction. All amounts positive; direction separates."""

    txn_date: date
    amount: Decimal                   # always positive
    direction: str                    # 'debit' or 'credit'
    description: str                  # original payee/description
    reference: Optional[str] = None   # cheque/transfer reference
    balance_after: Optional[Decimal] = None
    raw: dict = field(default_factory=dict)


@dataclass
class ParsedStatement:
    bank: str
    account_number: Optional[str]
    currency: str
    period_start: Optional[date]
    period_end: Optional[date]
    opening_balance: Optional[Decimal]
    closing_balance: Optional[Decimal]
    transactions: list[BankTransaction]
    warnings: list[str] = field(default_factory=list)


# ── Format detection ─────────────────────────────────────────


def detect_format(content: bytes, filename: str = "") -> str:
    """Return one of: 'pdf', 'xlsx', 'csv', 'mt940', 'camt053', 'unknown'."""
    lower = filename.lower()
    if lower.endswith(".pdf") or content[:4] == b"%PDF":
        return "pdf"
    if lower.endswith((".xlsx", ".xlsm")) or content[:4] == b"PK\x03\x04":
        return "xlsx"
    if lower.endswith(".xml") or content.lstrip().startswith(b"<?xml"):
        # camt.053 vs generic XML
        head = content[:2048].decode("utf-8", errors="ignore").lower()
        if "camt.053" in head or "bktocstmt" in head:
            return "camt053"
        return "unknown"
    if content[:2] == b":2" or b":20:" in content[:200]:
        return "mt940"
    if lower.endswith(".csv"):
        return "csv"
    # Heuristic: if mostly printable + commas on line 1 → CSV
    try:
        sample = content[:4096].decode("utf-8", errors="ignore")
        if sample.count(",") > 5 and "\n" in sample:
            return "csv"
    except Exception:
        pass
    return "unknown"


# ── CSV parser (generic fallback) ────────────────────────────

_DATE_PATTERNS = [
    "%Y-%m-%d", "%d/%m/%Y", "%d-%m-%Y", "%m/%d/%Y", "%Y/%m/%d",
]

_ARABIC_DIGITS = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")


def _to_decimal(raw: str) -> Optional[Decimal]:
    if raw is None:
        return None
    s = str(raw).translate(_ARABIC_DIGITS).replace(",", "").replace(" ", "").replace("SAR", "").replace("AED", "").strip()
    if s.startswith("(") and s.endswith(")"):
        s = "-" + s[1:-1]
    try:
        return Decimal(s)
    except (InvalidOperation, ValueError):
        return None


def _parse_date(raw: str) -> Optional[date]:
    if not raw:
        return None
    s = str(raw).translate(_ARABIC_DIGITS).strip()
    for fmt in _DATE_PATTERNS:
        try:
            return datetime.strptime(s, fmt).date()
        except ValueError:
            continue
    return None


def _parse_csv(content: bytes) -> ParsedStatement:
    """Generic CSV parser. Expects headers like Date/Description/Debit/Credit/Balance."""
    warnings: list[str] = []
    try:
        text = content.decode("utf-8-sig")
    except UnicodeDecodeError:
        text = content.decode("cp1256", errors="replace")  # Arabic Windows

    reader = csv.DictReader(io.StringIO(text))
    rows = [{k.strip().lower(): (v or "").strip() for k, v in row.items() if k} for row in reader]

    def _pick(row: dict, keys: list[str]) -> str:
        for k in keys:
            if k in row and row[k]:
                return row[k]
        return ""

    txns: list[BankTransaction] = []
    for row in rows:
        d = _parse_date(_pick(row, ["date", "التاريخ", "trx date", "posting date"]))
        if d is None:
            continue
        debit = _to_decimal(_pick(row, ["debit", "مدين", "withdrawal"]))
        credit = _to_decimal(_pick(row, ["credit", "دائن", "deposit"]))
        desc = _pick(row, ["description", "البيان", "details", "narration", "reference"])
        bal = _to_decimal(_pick(row, ["balance", "الرصيد", "running balance"]))
        ref = _pick(row, ["reference", "ref", "مرجع", "txn ref"]) or None

        if debit and debit > 0:
            txns.append(
                BankTransaction(
                    txn_date=d, amount=debit, direction="debit",
                    description=desc, reference=ref, balance_after=bal, raw=row,
                )
            )
        elif credit and credit > 0:
            txns.append(
                BankTransaction(
                    txn_date=d, amount=credit, direction="credit",
                    description=desc, reference=ref, balance_after=bal, raw=row,
                )
            )
        else:
            warnings.append(f"Row skipped (no amount): {desc[:60]}")

    return ParsedStatement(
        bank="unknown",
        account_number=None,
        currency="SAR",
        period_start=min((t.txn_date for t in txns), default=None),
        period_end=max((t.txn_date for t in txns), default=None),
        opening_balance=None,
        closing_balance=txns[-1].balance_after if txns else None,
        transactions=txns,
        warnings=warnings,
    )


# ── MT940 parser (minimal) ──────────────────────────────────

_MT940_DATE_RE = re.compile(r"^(\d{2})(\d{2})(\d{2})")


def _parse_mt940(content: bytes) -> ParsedStatement:
    """Parse SWIFT MT940 account statement.

    Minimal support: :25: account, :28C: sequence, :60F: opening balance,
    :61: transaction (with :86: description), :62F: closing balance.
    """
    warnings: list[str] = []
    text = content.decode("utf-8", errors="ignore").replace("\r\n", "\n")
    account = None
    opening = closing = None
    currency = "SAR"
    txns: list[BankTransaction] = []
    period_start = period_end = None

    cur_txn: Optional[BankTransaction] = None

    for line in text.split("\n"):
        if line.startswith(":25:"):
            account = line[4:].strip()
        elif line.startswith(":60F:"):
            body = line[5:].strip()
            sign, rest = body[0], body[1:]
            ccy = rest[6:9]
            amt = _to_decimal(rest[9:].replace(",", "."))
            currency = ccy
            if amt is not None:
                opening = -amt if sign == "D" else amt
        elif line.startswith(":62F:"):
            body = line[5:].strip()
            sign, rest = body[0], body[1:]
            amt = _to_decimal(rest[9:].replace(",", "."))
            if amt is not None:
                closing = -amt if sign == "D" else amt
        elif line.startswith(":61:"):
            body = line[4:].strip()
            m = _MT940_DATE_RE.match(body)
            if not m:
                continue
            yy, mm, dd = (int(x) for x in m.groups())
            year = 2000 + yy if yy < 90 else 1900 + yy
            try:
                txn_date = date(year, mm, dd)
            except ValueError:
                continue
            rest = body[6:]
            # Debit/Credit marker (C/D/RC/RD)
            direction = "credit" if rest[:1] in ("C", "R") and rest[:2] != "RD" else "debit"
            # Find amount block
            m2 = re.match(r"[A-Z]+(\d+[,\.]?\d*)", rest)
            amt = _to_decimal(m2.group(1).replace(",", ".")) if m2 else None
            if amt is None:
                continue
            cur_txn = BankTransaction(
                txn_date=txn_date, amount=amt, direction=direction,
                description="",
            )
            txns.append(cur_txn)
            period_start = txn_date if period_start is None else min(period_start, txn_date)
            period_end = txn_date if period_end is None else max(period_end, txn_date)
        elif line.startswith(":86:") and cur_txn is not None:
            cur_txn.description = line[4:].strip()

    return ParsedStatement(
        bank="mt940",
        account_number=account,
        currency=currency,
        period_start=period_start,
        period_end=period_end,
        opening_balance=opening,
        closing_balance=closing,
        transactions=txns,
        warnings=warnings,
    )


# ── Main entry point ───────────────────────────────────────


def parse_statement(content: bytes, filename: str = "", bank_hint: Optional[str] = None) -> ParsedStatement:
    """Entry point — auto-detect format + dispatch."""
    fmt = detect_format(content, filename)
    if fmt == "csv":
        return _parse_csv(content)
    if fmt == "mt940":
        return _parse_mt940(content)
    if fmt == "pdf":
        return _parse_pdf(content, bank_hint=bank_hint)
    if fmt == "xlsx":
        return _parse_xlsx(content)
    if fmt == "camt053":
        return _parse_camt053(content)
    return ParsedStatement(
        bank="unknown",
        account_number=None,
        currency="SAR",
        period_start=None,
        period_end=None,
        opening_balance=None,
        closing_balance=None,
        transactions=[],
        warnings=[f"Unsupported format: {fmt}"],
    )


# ── Stubs for format parsers that need heavy deps ─────────


def _parse_pdf(content: bytes, bank_hint: Optional[str] = None) -> ParsedStatement:
    """PDF parsing — delegated to the dedicated module."""
    from app.integrations.bank_ocr.pdf_parser import parse_pdf as _real_pdf

    return _real_pdf(content, bank_hint=bank_hint)


def _parse_xlsx(content: bytes) -> ParsedStatement:
    """XLSX parsing — uses openpyxl. Stubbed for now."""
    return ParsedStatement(
        bank="xlsx_unknown",
        account_number=None,
        currency="SAR",
        period_start=None,
        period_end=None,
        opening_balance=None,
        closing_balance=None,
        transactions=[],
        warnings=["XLSX parsing not yet implemented — requires openpyxl"],
    )


def _parse_camt053(content: bytes) -> ParsedStatement:
    """ISO 20022 camt.053 XML parsing — stubbed."""
    return ParsedStatement(
        bank="camt053",
        account_number=None,
        currency="SAR",
        period_start=None,
        period_end=None,
        opening_balance=None,
        closing_balance=None,
        transactions=[],
        warnings=["camt.053 parsing not yet implemented"],
    )
