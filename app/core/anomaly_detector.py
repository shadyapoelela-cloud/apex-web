"""
APEX — Anomaly detector for financial transactions (Wave 3 PR#1).

Patterns #110–#111 from APEX_GLOBAL_RESEARCH_210:
- Anomaly feed (daily card by $ impact) — "دفعنا مورد X ثلاث مرات"
- Duplicate payment detector (fuzzy vendor + amount + date)

Design:
- Pure functions over caller-supplied lists of dicts. Nothing here
  touches the DB directly so the detector can be exercised against
  any data source (live DB query, CSV upload, AI OCR output) with
  zero adaptation.
- Each detector returns `AnomalyFinding` with a severity, type, a
  human-readable Arabic message, and a pointer to the offending row
  IDs so the UI can link back.
- A scan coordinator runs every detector and collates findings by
  severity for the UI "Anomaly Feed" card.

Transaction shape (minimal fields the detectors read):
    {
      "id": "...",                 # any string identifier
      "vendor": "...",             # payee name, optional
      "vendor_id": "...",          # stable vendor id, optional
      "amount": Decimal | str | number,
      "date": "YYYY-MM-DD" | datetime,
      "created_at": datetime,      # for off-hours detection
      "description": "...",        # optional free text
      "category": "...",           # expense category, optional
    }
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass, field
from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal, InvalidOperation
from typing import Any, Iterable, List, Optional


# ── Severity taxonomy (matches the Master Blueprint §7.4 palette) ─────

_SEVERITY_LOW = "low"
_SEVERITY_MEDIUM = "medium"
_SEVERITY_HIGH = "high"


@dataclass
class AnomalyFinding:
    """Single detection. The UI renders these as daily cards."""

    type: str                   # "duplicate_payment" | "round_number" | ...
    severity: str               # low | medium | high
    message_ar: str             # human-readable Arabic explanation
    impact: Decimal             # total SAR (or caller's currency) affected
    transaction_ids: List[str]  # anchors back to the underlying rows
    evidence: dict = field(default_factory=dict)  # raw facts for the drawer

    def to_dict(self) -> dict:
        return {
            "type": self.type,
            "severity": self.severity,
            "message_ar": self.message_ar,
            "impact": str(self.impact),
            "transaction_ids": list(self.transaction_ids),
            "evidence": dict(self.evidence),
        }


# ── Helpers ───────────────────────────────────────────────────────────


def _to_decimal(v: Any) -> Optional[Decimal]:
    if v is None:
        return None
    if isinstance(v, Decimal):
        return v
    try:
        return Decimal(str(v))
    except (InvalidOperation, TypeError, ValueError):
        return None


def _to_date(v: Any) -> Optional[date]:
    if v is None:
        return None
    if isinstance(v, datetime):
        return v.date()
    if isinstance(v, date):
        return v
    if isinstance(v, str):
        for fmt in ("%Y-%m-%d", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M:%S.%f", "%Y/%m/%d"):
            try:
                return datetime.strptime(v[:19], fmt).date()
            except ValueError:
                continue
    return None


def _to_datetime(v: Any) -> Optional[datetime]:
    if v is None:
        return None
    if isinstance(v, datetime):
        return v
    if isinstance(v, date):
        return datetime.combine(v, time(0, 0))
    if isinstance(v, str):
        try:
            return datetime.fromisoformat(v.replace("Z", "+00:00"))
        except ValueError:
            return None
    return None


_WS_RE = re.compile(r"\s+")


def _normalize_vendor(name: Optional[str]) -> str:
    """Fold Arabic + Latin names for fuzzy comparison:
    - strip diacritics, tatweel, and case
    - collapse whitespace
    - map alef/yeh/teh-marbuta variants to canonical form
    """
    if not name:
        return ""
    s = unicodedata.normalize("NFKD", name)
    s = "".join(c for c in s if not unicodedata.combining(c))
    # Arabic-specific tweaks
    replacements = {
        "\u0622": "\u0627",  # آ -> ا
        "\u0623": "\u0627",  # أ -> ا
        "\u0625": "\u0627",  # إ -> ا
        "\u0649": "\u064A",  # ى -> ي
        "\u0629": "\u0647",  # ة -> ه
        "\u0640": "",         # ـ (tatweel)
    }
    for src, dst in replacements.items():
        s = s.replace(src, dst)
    return _WS_RE.sub(" ", s.strip().lower())


# ── Detector 1: Duplicate payments (fuzzy vendor + amount + date) ────


def find_duplicate_payments(
    txns: Iterable[dict],
    *,
    window_days: int = 7,
    amount_tolerance: Decimal = Decimal("0.01"),
) -> List[AnomalyFinding]:
    """Find payments that look suspiciously like duplicates.

    Matches on (normalized vendor, amount ± tolerance, date within window).
    A group of 2+ matching txns produces one finding with all ids listed.
    """
    rows = [t for t in txns if _to_decimal(t.get("amount")) is not None]
    findings: List[AnomalyFinding] = []
    seen_ids: set = set()

    for i, a in enumerate(rows):
        if a.get("id") in seen_ids:
            continue
        da = _to_date(a.get("date"))
        aa = _to_decimal(a["amount"]) or Decimal("0")
        va = _normalize_vendor(a.get("vendor") or a.get("vendor_id"))
        if not va or da is None:
            continue

        group = [a]
        for b in rows[i + 1 :]:
            if b.get("id") in seen_ids:
                continue
            db_ = _to_date(b.get("date"))
            ab = _to_decimal(b["amount"]) or Decimal("0")
            vb = _normalize_vendor(b.get("vendor") or b.get("vendor_id"))
            if not vb or db_ is None:
                continue
            if va != vb:
                continue
            if abs(aa - ab) > amount_tolerance:
                continue
            if abs((da - db_).days) > window_days:
                continue
            group.append(b)

        if len(group) >= 2:
            ids = [str(t.get("id", "")) for t in group]
            total = sum((_to_decimal(t["amount"]) or Decimal("0")) for t in group)
            findings.append(
                AnomalyFinding(
                    type="duplicate_payment",
                    severity=_SEVERITY_HIGH if len(group) >= 3 else _SEVERITY_MEDIUM,
                    message_ar=(
                        f"دُفعت للمورد نفسه ({a.get('vendor') or 'غير معروف'}) "
                        f"{len(group)} مرات بقيمة {aa} خلال {window_days} يوم."
                    ),
                    impact=aa * (len(group) - 1),  # one legitimate + rest = overpayment
                    transaction_ids=ids,
                    evidence={
                        "vendor": a.get("vendor"),
                        "amount": str(aa),
                        "count": len(group),
                    },
                )
            )
            seen_ids.update(ids)

    return findings


# ── Detector 2: Round-number payments (5k / 10k / 50k pattern) ───────


_ROUND_THRESHOLDS = [
    (Decimal("50000"), _SEVERITY_HIGH),
    (Decimal("10000"), _SEVERITY_MEDIUM),
    (Decimal("5000"), _SEVERITY_LOW),
]


def find_round_number_anomalies(
    txns: Iterable[dict],
    *,
    min_threshold: Decimal = Decimal("5000"),
) -> List[AnomalyFinding]:
    """Flag payments whose amount is an exact multiple of 1,000+.

    Exact round sums are a common manual-entry red flag: legitimate
    invoice amounts rarely land on 50,000.00 SAR on the dot.
    """
    findings: List[AnomalyFinding] = []
    for t in txns:
        amt = _to_decimal(t.get("amount"))
        if amt is None or amt < min_threshold:
            continue
        # Integer? And a multiple of 1,000?
        if amt != amt.to_integral_value() or amt % Decimal("1000") != 0:
            continue
        severity = _SEVERITY_LOW
        for threshold, sev in _ROUND_THRESHOLDS:
            if amt >= threshold:
                severity = sev
                break
        findings.append(
            AnomalyFinding(
                type="round_number",
                severity=severity,
                message_ar=(
                    f"دفعة بقيمة {amt} — رقم مستدير بالضبط، غالبًا "
                    "يشير إلى إدخال يدوي دون رجوع لفاتورة."
                ),
                impact=amt,
                transaction_ids=[str(t.get("id", ""))],
                evidence={"vendor": t.get("vendor"), "amount": str(amt)},
            )
        )
    return findings


# ── Detector 3: Off-hours entries (midnight postings) ────────────────


def find_off_hours_entries(
    txns: Iterable[dict],
    *,
    business_hours: tuple = (6, 22),  # 06:00 – 22:00 local
) -> List[AnomalyFinding]:
    """Flag entries created between 22:00 and 06:00.

    After-hours manual journal entries are a classic fraud indicator —
    legitimate accounting happens during business hours in most orgs.
    """
    start_h, end_h = business_hours
    findings: List[AnomalyFinding] = []
    for t in txns:
        ts = _to_datetime(t.get("created_at"))
        if ts is None:
            continue
        hour = ts.hour
        if start_h <= hour < end_h:
            continue
        amt = _to_decimal(t.get("amount")) or Decimal("0")
        findings.append(
            AnomalyFinding(
                type="off_hours_entry",
                severity=_SEVERITY_HIGH if amt >= Decimal("10000") else _SEVERITY_MEDIUM,
                message_ar=(
                    f"قيد بقيمة {amt} تم إدخاله في {ts.strftime('%H:%M')} — "
                    "خارج ساعات العمل المعتادة."
                ),
                impact=amt,
                transaction_ids=[str(t.get("id", ""))],
                evidence={
                    "hour": hour,
                    "timestamp": ts.isoformat(),
                    "vendor": t.get("vendor"),
                },
            )
        )
    return findings


# ── Detector 4: New vendor, large first payment ──────────────────────


def find_new_vendor_large_payment(
    txns: Iterable[dict],
    *,
    threshold: Decimal = Decimal("50000"),
) -> List[AnomalyFinding]:
    """Flag a vendor's FIRST payment when it is unusually large.

    A brand-new vendor immediately receiving >50k SAR is worth a
    second look — could be a phantom vendor, typo-squat of a real
    supplier, or a missing approval.
    """
    # Sort by date ascending so we can identify the first occurrence
    # per vendor without a separate query.
    rows = sorted(
        [t for t in txns if _to_decimal(t.get("amount")) is not None],
        key=lambda t: (_to_date(t.get("date")) or date.min, str(t.get("id", ""))),
    )
    seen: set = set()
    findings: List[AnomalyFinding] = []
    for t in rows:
        key = _normalize_vendor(t.get("vendor") or t.get("vendor_id"))
        if not key:
            continue
        if key in seen:
            continue
        seen.add(key)
        amt = _to_decimal(t["amount"]) or Decimal("0")
        if amt < threshold:
            continue
        findings.append(
            AnomalyFinding(
                type="new_vendor_large",
                severity=_SEVERITY_HIGH,
                message_ar=(
                    f"أول معاملة مع المورد ({t.get('vendor') or 'غير معروف'}) "
                    f"بقيمة {amt} — تجاوزت الحد المعتاد للتحقق."
                ),
                impact=amt,
                transaction_ids=[str(t.get("id", ""))],
                evidence={"vendor": t.get("vendor"), "amount": str(amt)},
            )
        )
    return findings


# ── Detector 5: Category spend spike (vs 90-day baseline) ─────────────


def find_category_spikes(
    txns: Iterable[dict],
    *,
    spike_multiplier: float = 3.0,
) -> List[AnomalyFinding]:
    """Flag categories whose current-month spend is >3× the prior
    90-day average. "Spend" is total absolute amount per category.
    """
    rows = [t for t in txns if _to_decimal(t.get("amount")) is not None
            and _to_date(t.get("date")) is not None
            and t.get("category")]
    if not rows:
        return []

    latest = max(_to_date(t["date"]) for t in rows)  # type: ignore[type-var]
    current_start = latest.replace(day=1)
    baseline_end = current_start - timedelta(days=1)
    baseline_start = baseline_end - timedelta(days=90)

    current: dict[str, Decimal] = {}
    baseline_totals: dict[str, Decimal] = {}
    baseline_counts: dict[str, int] = {}

    for t in rows:
        d = _to_date(t["date"])
        amt = _to_decimal(t["amount"]) or Decimal("0")
        cat = t["category"]
        if d is None:
            continue
        if d >= current_start:
            current[cat] = current.get(cat, Decimal("0")) + abs(amt)
        elif baseline_start <= d <= baseline_end:
            baseline_totals[cat] = baseline_totals.get(cat, Decimal("0")) + abs(amt)
            baseline_counts[cat] = baseline_counts.get(cat, 0) + 1

    findings: List[AnomalyFinding] = []
    for cat, cur in current.items():
        base_total = baseline_totals.get(cat)
        base_count = baseline_counts.get(cat, 0)
        if not base_total or base_count == 0:
            continue
        # Normalize baseline to a per-month average.
        baseline_monthly = (base_total / Decimal(str(base_count))) * Decimal("30")
        if baseline_monthly <= 0:
            continue
        ratio = float(cur / baseline_monthly)
        if ratio < spike_multiplier:
            continue
        findings.append(
            AnomalyFinding(
                type="category_spike",
                severity=_SEVERITY_HIGH if ratio >= 5 else _SEVERITY_MEDIUM,
                message_ar=(
                    f"مصاريف فئة '{cat}' هذا الشهر بلغت {cur} — "
                    f"أعلى بـ {ratio:.1f}× من متوسط آخر 90 يوم."
                ),
                impact=cur - baseline_monthly,
                transaction_ids=[
                    str(t.get("id", "")) for t in rows
                    if t["category"] == cat and (_to_date(t["date"]) or date.min) >= current_start
                ],
                evidence={
                    "category": cat,
                    "current": str(cur),
                    "baseline_monthly": str(baseline_monthly.quantize(Decimal("0.01"))),
                    "multiplier": round(ratio, 2),
                },
            )
        )
    return findings


# ── Coordinator ───────────────────────────────────────────────────────


def scan_all(
    txns: Iterable[dict],
    *,
    window_days: int = 7,
    round_number_min: Decimal = Decimal("5000"),
    business_hours: tuple = (6, 22),
    new_vendor_threshold: Decimal = Decimal("50000"),
    spike_multiplier: float = 3.0,
) -> List[AnomalyFinding]:
    """Run every detector and return findings sorted by severity desc."""
    rows = list(txns)
    findings: List[AnomalyFinding] = []
    findings.extend(find_duplicate_payments(rows, window_days=window_days))
    findings.extend(find_round_number_anomalies(rows, min_threshold=round_number_min))
    findings.extend(find_off_hours_entries(rows, business_hours=business_hours))
    findings.extend(find_new_vendor_large_payment(rows, threshold=new_vendor_threshold))
    findings.extend(find_category_spikes(rows, spike_multiplier=spike_multiplier))

    severity_rank = {_SEVERITY_HIGH: 0, _SEVERITY_MEDIUM: 1, _SEVERITY_LOW: 2}
    findings.sort(
        key=lambda f: (severity_rank.get(f.severity, 3), -float(f.impact)),
    )
    return findings
