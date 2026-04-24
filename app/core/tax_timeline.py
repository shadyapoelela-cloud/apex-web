"""Tax Timeline — upcoming tax/compliance obligations as a visual feed.

Adapted from FreeAgent's "Tax Timeline" pattern for GCC+Egypt context:
Zakat, KSA VAT, UAE VAT, UAE Corporate Tax, Egypt VAT, ZATCA e-invoicing
clearance expirations — surfaced as a timeline the user can glance at
and act on before a filing slips.

The computation is deterministic (pure date math + tenant settings) so
there are no external API calls. Each obligation returns:

    {
      id:       stable deterministic key,
      kind:     "zakat" | "vat" | "corporate_tax" | "zatca_csid" | ...,
      title:    Arabic label for the card,
      due_date: ISO date of the deadline,
      period_label: human label of the period being reported,
      jurisdiction: "sa" | "ae" | "eg" | "om" | "bh" | "qa",
      severity: "info" | "warning" | "error" (ramps as deadline nears),
      action_hint: short Arabic CTA,
    }

Bootstrap assumptions (override later via tenant config):
  • KSA VAT: monthly return, due by end of month following the period.
    (Large taxpayers file monthly; small filers file quarterly — we
    default to monthly and offer a config flag.)
  • KSA Zakat: annual return, due 120 days after fiscal year end.
  • UAE VAT: quarterly, due 28 days after period end.
  • UAE Corporate Tax: annual, due 9 months after fiscal year end.
  • Egypt VAT: monthly, due by the end of the following month.
"""

from __future__ import annotations

from dataclasses import dataclass, asdict
from datetime import date, timedelta
from typing import Any, Iterable, Optional


@dataclass(frozen=True)
class Obligation:
    id: str
    kind: str
    title: str
    due_date: str        # ISO yyyy-mm-dd
    period_label: str
    jurisdiction: str
    severity: str
    action_hint: str
    days_until: int

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


# ── Severity calculator ──────────────────────────────────


def _severity_for(days: int) -> str:
    if days < 0:
        return "error"        # past due
    if days <= 7:
        return "error"
    if days <= 21:
        return "warning"
    return "info"


# ── Date helpers ────────────────────────────────────────


def _last_day_of_month(y: int, m: int) -> date:
    if m == 12:
        return date(y, 12, 31)
    return date(y, m + 1, 1) - timedelta(days=1)


def _month_end_plus(base: date, months_forward: int) -> date:
    """Return the last day of the month `months_forward` months ahead of base."""
    y = base.year + (base.month + months_forward - 1) // 12
    m = (base.month + months_forward - 1) % 12 + 1
    return _last_day_of_month(y, m)


def _quarter_end(d: date) -> date:
    q_end_month = ((d.month - 1) // 3 + 1) * 3
    return _last_day_of_month(d.year, q_end_month)


# ── Computation ─────────────────────────────────────────


def upcoming_obligations(
    *,
    today: Optional[date] = None,
    horizon_days: int = 120,
    jurisdictions: Optional[Iterable[str]] = None,
    tenant_profile: Optional[dict[str, Any]] = None,
) -> list[dict[str, Any]]:
    """Enumerate filing deadlines within the horizon.

    `tenant_profile` is an optional dict describing the tenant:
        { "country": "sa", "vat_cadence": "monthly",
          "fiscal_year_end": "2026-12-31",
          "zatca_csid_expires_at": "2026-12-01" }

    Defaults assume a Saudi monthly-VAT SMB.
    """
    today = today or date.today()
    horizon = today + timedelta(days=horizon_days)
    profile = tenant_profile or {}
    country = (profile.get("country") or "sa").lower()
    vat_cadence = (profile.get("vat_cadence") or "monthly").lower()
    fy_end_str = profile.get("fiscal_year_end")
    csid_exp_str = profile.get("zatca_csid_expires_at")

    want = set(jurisdictions) if jurisdictions else None
    if want is None:
        want = {country}

    results: list[Obligation] = []

    # ── KSA VAT — monthly or quarterly ──
    if "sa" in want:
        if vat_cadence == "quarterly":
            # Q1 → due 31 Apr? ZATCA rule: last day of the month following
            # the period. Use end of the quarter + 1 month = quarterly due.
            cur_q_end = _quarter_end(today)
            cursor = cur_q_end
            while cursor <= horizon:
                due = _last_day_of_month((cursor + timedelta(days=1)).year,
                                          (cursor + timedelta(days=1)).month)
                if due >= today:
                    q = ((cursor.month - 1) // 3) + 1
                    results.append(Obligation(
                        id=f"sa_vat_q_{cursor.year}_q{q}",
                        kind="vat",
                        title=f"إقرار ضريبة القيمة المضافة — الربع {q} {cursor.year}",
                        due_date=due.isoformat(),
                        period_label=f"Q{q} {cursor.year}",
                        jurisdiction="sa",
                        severity=_severity_for((due - today).days),
                        action_hint="إيداع إقرار VAT عبر بوابة ZATCA",
                        days_until=(due - today).days,
                    ))
                cursor = _quarter_end(cursor + timedelta(days=95))
        else:
            # Start one month back so the "previous period" return (the
            # most urgent, already-reportable one) is always included.
            prev_m = 12 if today.month == 1 else today.month - 1
            prev_y = today.year - 1 if today.month == 1 else today.year
            cursor = date(prev_y, prev_m, 1)
            while cursor <= horizon:
                due = _last_day_of_month(
                    *((cursor.year + 1, 1) if cursor.month == 12 else (cursor.year, cursor.month + 1))
                )
                if due >= today and due <= horizon:
                    results.append(Obligation(
                        id=f"sa_vat_m_{cursor.year}_{cursor.month:02}",
                        kind="vat",
                        title=f"إقرار ضريبة القيمة المضافة — {cursor:%m/%Y}",
                        due_date=due.isoformat(),
                        period_label=f"{cursor:%Y-%m}",
                        jurisdiction="sa",
                        severity=_severity_for((due - today).days),
                        action_hint="إيداع إقرار VAT عبر بوابة ZATCA",
                        days_until=(due - today).days,
                    ))
                # advance 1 month
                nm = 1 if cursor.month == 12 else cursor.month + 1
                ny = cursor.year + 1 if cursor.month == 12 else cursor.year
                cursor = date(ny, nm, 1)

        # Zakat — annual, 120 days after fiscal year end
        if fy_end_str:
            try:
                fy_end = date.fromisoformat(fy_end_str)
                zakat_due = fy_end + timedelta(days=120)
                if today <= zakat_due <= horizon:
                    results.append(Obligation(
                        id=f"sa_zakat_{fy_end.year}",
                        kind="zakat",
                        title=f"إقرار الزكاة السنوي {fy_end.year}",
                        due_date=zakat_due.isoformat(),
                        period_label=f"FY {fy_end.year}",
                        jurisdiction="sa",
                        severity=_severity_for((zakat_due - today).days),
                        action_hint="احتساب وتقديم إقرار الزكاة — 120 يوم من نهاية السنة المالية",
                        days_until=(zakat_due - today).days,
                    ))
            except Exception:
                pass

        # ZATCA CSID expiry
        if csid_exp_str:
            try:
                csid_exp = date.fromisoformat(csid_exp_str)
                if today <= csid_exp <= horizon:
                    results.append(Obligation(
                        id=f"sa_csid_{csid_exp.isoformat()}",
                        kind="zatca_csid",
                        title="انتهاء صلاحية شهادة ZATCA (CSID)",
                        due_date=csid_exp.isoformat(),
                        period_label=csid_exp.isoformat(),
                        jurisdiction="sa",
                        severity=_severity_for((csid_exp - today).days),
                        action_hint="تجديد شهادة الطابع الإلكتروني قبل انتهائها",
                        days_until=(csid_exp - today).days,
                    ))
            except Exception:
                pass

    # ── UAE VAT (quarterly, 28 days after period end) ──
    if "ae" in want:
        cur_q_end = _quarter_end(today)
        cursor = cur_q_end
        for _ in range(4):
            due = cursor + timedelta(days=28)
            if today <= due <= horizon:
                q = ((cursor.month - 1) // 3) + 1
                results.append(Obligation(
                    id=f"ae_vat_{cursor.year}_q{q}",
                    kind="vat",
                    title=f"إقرار ضريبة القيمة المضافة الإماراتية — الربع {q} {cursor.year}",
                    due_date=due.isoformat(),
                    period_label=f"Q{q} {cursor.year}",
                    jurisdiction="ae",
                    severity=_severity_for((due - today).days),
                    action_hint="إيداع الإقرار عبر بوابة الهيئة الاتحادية للضرائب",
                    days_until=(due - today).days,
                ))
            cursor = _quarter_end(cursor + timedelta(days=95))

        # UAE Corporate Tax — 9 months after FY end
        if fy_end_str:
            try:
                fy_end = date.fromisoformat(fy_end_str)
                ct_due = fy_end + timedelta(days=30 * 9)
                if today <= ct_due <= horizon:
                    results.append(Obligation(
                        id=f"ae_ct_{fy_end.year}",
                        kind="corporate_tax",
                        title=f"ضريبة الشركات الإماراتية — السنة المالية {fy_end.year}",
                        due_date=ct_due.isoformat(),
                        period_label=f"FY {fy_end.year}",
                        jurisdiction="ae",
                        severity=_severity_for((ct_due - today).days),
                        action_hint="تقديم إقرار ضريبة الشركات (9 أشهر من نهاية السنة المالية)",
                        days_until=(ct_due - today).days,
                    ))
            except Exception:
                pass

    # ── Egypt VAT — monthly, end of following month ──
    if "eg" in want:
        cursor = today.replace(day=1)
        for _ in range(4):
            nm = 1 if cursor.month == 12 else cursor.month + 1
            ny = cursor.year + 1 if cursor.month == 12 else cursor.year
            due = _last_day_of_month(ny, nm)
            if today <= due <= horizon:
                results.append(Obligation(
                    id=f"eg_vat_{cursor.year}_{cursor.month:02}",
                    kind="vat",
                    title=f"إقرار ضريبة القيمة المضافة المصرية — {cursor:%m/%Y}",
                    due_date=due.isoformat(),
                    period_label=f"{cursor:%Y-%m}",
                    jurisdiction="eg",
                    severity=_severity_for((due - today).days),
                    action_hint="إيداع الإقرار عبر بوابة مصلحة الضرائب المصرية",
                    days_until=(due - today).days,
                ))
            cursor = date(ny, nm, 1)

    # Sort chronologically — the timeline UI renders in order.
    results.sort(key=lambda o: o.due_date)
    return [o.to_dict() for o in results]
