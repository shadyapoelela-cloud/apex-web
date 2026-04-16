"""
APEX Platform — Aging Report (AR / AP)
═══════════════════════════════════════════════════════════════
Classic AR/AP aging schedule with 5 buckets (customisable):

  • Current (not yet due)
  • 1–30 days past due
  • 31–60 days past due
  • 61–90 days past due
  • 90+ days past due

Input is a list of open invoices with due dates + balances.
Output aggregates per-counterparty (customer or supplier) and
totals by bucket. Useful for collections prioritisation and
credit-risk provisioning.

Adds an Expected Credit Loss (ECL) rough estimate per bucket
using customisable loss rates (defaults are illustrative IFRS 9
simplified approach rates).
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime
from decimal import Decimal, ROUND_HALF_UP
from typing import List, Optional


_TWO = Decimal("0.01")


def _q(v: Decimal | int | float | str) -> Decimal:
    if not isinstance(v, Decimal):
        v = Decimal(str(v))
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


_BUCKETS = [
    ("current", "Current (غير مستحق)",    None, 0),
    ("d1_30",   "1-30 يوم",                0, 30),
    ("d31_60",  "31-60 يوم",               31, 60),
    ("d61_90",  "61-90 يوم",               61, 90),
    ("d90_plus","90+ يوم",                 91, None),
]

# Illustrative default ECL rates (IFRS 9 simplified approach)
_DEFAULT_ECL_RATES = {
    "current": Decimal("0.005"),  # 0.5%
    "d1_30":   Decimal("0.02"),   # 2%
    "d31_60":  Decimal("0.05"),   # 5%
    "d61_90":  Decimal("0.15"),   # 15%
    "d90_plus": Decimal("0.40"),  # 40%
}


@dataclass
class AgingInvoice:
    counterparty: str         # customer or supplier name
    invoice_number: str
    invoice_date: str         # ISO "YYYY-MM-DD"
    due_date: str             # ISO "YYYY-MM-DD"
    balance: Decimal          # outstanding (positive)


@dataclass
class AgingInput:
    kind: str = "ar"          # 'ar' (receivables) | 'ap' (payables)
    as_of_date: Optional[str] = None  # defaults to today
    invoices: List[AgingInvoice] = field(default_factory=list)
    # Optional override for ECL rates (applies only to AR)
    ecl_rates_override: Optional[dict] = None


@dataclass
class AgedInvoice:
    counterparty: str
    invoice_number: str
    invoice_date: str
    due_date: str
    days_past_due: int
    bucket_code: str
    bucket_label: str
    balance: Decimal


@dataclass
class BucketTotal:
    code: str
    label: str
    count: int
    total: Decimal
    percentage: Decimal
    ecl_rate_pct: Decimal
    ecl_amount: Decimal


@dataclass
class CounterpartyAging:
    counterparty: str
    total: Decimal
    by_bucket: dict           # code -> Decimal


@dataclass
class AgingResult:
    kind: str
    as_of_date: str
    total_outstanding: Decimal
    total_ecl: Decimal
    buckets: List[BucketTotal]
    by_counterparty: List[CounterpartyAging]
    invoices: List[AgedInvoice]
    warnings: list[str] = field(default_factory=list)


def _parse_date(s: str, field_name: str) -> date:
    try:
        return datetime.strptime(s, "%Y-%m-%d").date()
    except (ValueError, TypeError):
        raise ValueError(f"{field_name} must be ISO date YYYY-MM-DD, got {s!r}")


def _bucket_for(days: int) -> tuple[str, str]:
    if days <= 0:
        return "current", "Current (غير مستحق)"
    for code, label, lo, hi in _BUCKETS:
        if lo is None:
            continue
        if hi is None:
            if days >= lo:
                return code, label
        elif lo <= days <= hi:
            return code, label
    return "d90_plus", "90+ يوم"


def compute_aging(inp: AgingInput) -> AgingResult:
    warnings: list[str] = []

    kind = (inp.kind or "").lower()
    if kind not in ("ar", "ap"):
        raise ValueError("kind must be 'ar' (receivables) or 'ap' (payables)")
    if not inp.invoices:
        raise ValueError("At least one invoice is required")

    today = date.today() if inp.as_of_date is None else _parse_date(inp.as_of_date, "as_of_date")

    # ECL rates
    rates = dict(_DEFAULT_ECL_RATES)
    if inp.ecl_rates_override:
        for k, v in inp.ecl_rates_override.items():
            if k in rates:
                rates[k] = Decimal(str(v))

    aged: List[AgedInvoice] = []
    bucket_totals: dict[str, Decimal] = {b[0]: Decimal("0") for b in _BUCKETS}
    bucket_counts: dict[str, int] = {b[0]: 0 for b in _BUCKETS}
    by_cp: dict[str, CounterpartyAging] = {}

    for inv in inp.invoices:
        due = _parse_date(inv.due_date, f"due_date for {inv.invoice_number}")
        dpd = (today - due).days
        code, label = _bucket_for(dpd)
        bal = _q(inv.balance)
        if bal < 0:
            warnings.append(
                f"فاتورة {inv.invoice_number}: الرصيد سالب — يُحتمل أن تكون دفعة زائدة."
            )

        aged.append(AgedInvoice(
            counterparty=inv.counterparty,
            invoice_number=inv.invoice_number,
            invoice_date=inv.invoice_date,
            due_date=inv.due_date,
            days_past_due=max(0, dpd),
            bucket_code=code,
            bucket_label=label,
            balance=bal,
        ))

        bucket_totals[code] += bal
        bucket_counts[code] += 1

        cp = by_cp.get(inv.counterparty)
        if cp is None:
            cp = CounterpartyAging(
                counterparty=inv.counterparty,
                total=Decimal("0"),
                by_bucket={b[0]: Decimal("0") for b in _BUCKETS},
            )
            by_cp[inv.counterparty] = cp
        cp.total += bal
        cp.by_bucket[code] = _q(cp.by_bucket[code] + bal)

    total_outstanding = _q(sum(bucket_totals.values(), Decimal("0")))

    buckets_out: List[BucketTotal] = []
    total_ecl = Decimal("0")
    for code, label, _lo, _hi in _BUCKETS:
        total = _q(bucket_totals[code])
        pct = Decimal("0")
        if total_outstanding > 0:
            pct = (total / total_outstanding * Decimal("100")).quantize(
                _TWO, rounding=ROUND_HALF_UP
            )
        rate = rates.get(code, Decimal("0"))
        ecl = _q(total * rate) if kind == "ar" else Decimal("0")
        total_ecl += ecl
        buckets_out.append(BucketTotal(
            code=code, label=label,
            count=bucket_counts[code], total=total,
            percentage=pct,
            ecl_rate_pct=(rate * Decimal("100")).quantize(_TWO, rounding=ROUND_HALF_UP),
            ecl_amount=ecl,
        ))

    # Top counterparties sorted by total desc
    cp_list = sorted(by_cp.values(), key=lambda c: c.total, reverse=True)
    # Quantize totals
    for cp in cp_list:
        cp.total = _q(cp.total)
        cp.by_bucket = {k: _q(v) for k, v in cp.by_bucket.items()}

    # Warnings
    overdue_90_pct = Decimal("0")
    if total_outstanding > 0:
        overdue_90_pct = bucket_totals["d90_plus"] / total_outstanding * Decimal("100")
    if kind == "ar" and overdue_90_pct > Decimal("15"):
        warnings.append(
            f"نسبة الديون المتأخرة أكثر من 90 يوم = "
            f"{overdue_90_pct.quantize(_TWO)}% — مرتفعة. راجع سياسة التحصيل."
        )

    return AgingResult(
        kind=kind,
        as_of_date=today.isoformat(),
        total_outstanding=total_outstanding,
        total_ecl=_q(total_ecl),
        buckets=buckets_out,
        by_counterparty=cp_list,
        invoices=aged,
        warnings=warnings,
    )


def result_to_dict(r: AgingResult) -> dict:
    return {
        "kind": r.kind,
        "as_of_date": r.as_of_date,
        "total_outstanding": f"{r.total_outstanding}",
        "total_ecl": f"{r.total_ecl}",
        "buckets": [
            {
                "code": b.code,
                "label": b.label,
                "count": b.count,
                "total": f"{b.total}",
                "percentage": f"{b.percentage}",
                "ecl_rate_pct": f"{b.ecl_rate_pct}",
                "ecl_amount": f"{b.ecl_amount}",
            }
            for b in r.buckets
        ],
        "by_counterparty": [
            {
                "counterparty": cp.counterparty,
                "total": f"{cp.total}",
                "by_bucket": {k: f"{v}" for k, v in cp.by_bucket.items()},
            }
            for cp in r.by_counterparty
        ],
        "invoices": [
            {
                "counterparty": inv.counterparty,
                "invoice_number": inv.invoice_number,
                "invoice_date": inv.invoice_date,
                "due_date": inv.due_date,
                "days_past_due": inv.days_past_due,
                "bucket_code": inv.bucket_code,
                "bucket_label": inv.bucket_label,
                "balance": f"{inv.balance}",
            }
            for inv in r.invoices
        ],
        "warnings": r.warnings,
    }
