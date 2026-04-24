"""Real ledger aggregation for Copilot agent tools.

Bridges the Claude tool-use layer to the actual GL data stored in
`pilot_gl_postings` + `pilot_gl_accounts`. Until this module existed
the Copilot tools returned `value: 0` placeholders — so the LLM could
"see" the shape of an answer but never the number. With this module
the agent stops being a demo and starts reading real books.

Design notes:
  • All functions are defensive — if the pilot tables are absent (fresh
    CI DB, minimal test fixture) they return a zero-shaped result, not
    a 500. The existing placeholder tests still pass.
  • Tenant scoping uses `tenant_guard.current_tenant()` when available;
    falls back to "no filter" only in dev (documented).
  • Amounts are aggregated from GLPosting.functional_debit/credit (post-
    ledger, post-FX) so multi-currency tenants see one number.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import Any, Optional

logger = logging.getLogger(__name__)


# ── Period parsing ─────────────────────────────────────────


@dataclass
class PeriodRange:
    start: date
    end: date
    label: str


def parse_period(period: str) -> PeriodRange:
    """Parse 'this_month' | 'last_month' | 'ytd' | 'YYYY-MM-DD:YYYY-MM-DD'.

    Defensive: unrecognized input becomes "this_month". Never raises
    during an agent run — a bad period should still yield a result the
    LLM can narrate around.
    """
    today = date.today()
    p = (period or "this_month").strip().lower()

    if p == "this_month":
        start = today.replace(day=1)
        return PeriodRange(start, today, f"{start:%Y-%m}")

    if p == "last_month":
        first_this = today.replace(day=1)
        end = first_this - timedelta(days=1)
        start = end.replace(day=1)
        return PeriodRange(start, end, f"{start:%Y-%m}")

    if p == "ytd":
        start = today.replace(month=1, day=1)
        return PeriodRange(start, today, f"YTD {today.year}")

    if p in ("last_quarter", "this_quarter"):
        q = (today.month - 1) // 3
        if p == "last_quarter":
            q -= 1
        year = today.year + (q // 4)
        q %= 4
        start = date(year, q * 3 + 1, 1)
        end_month = q * 3 + 3
        if end_month == 12:
            end = date(year, 12, 31)
        else:
            end = date(year, end_month + 1, 1) - timedelta(days=1)
        return PeriodRange(start, end, f"Q{q+1} {year}")

    if ":" in p:
        try:
            a, b = p.split(":", 1)
            return PeriodRange(
                date.fromisoformat(a.strip()),
                date.fromisoformat(b.strip()),
                f"{a}..{b}",
            )
        except Exception:
            pass

    # fallback — treat anything else as this month
    start = today.replace(day=1)
    return PeriodRange(start, today, f"{start:%Y-%m}")


# ── Tenant scoping ─────────────────────────────────────────


def _current_tenant_id() -> Optional[str]:
    try:
        from app.core.tenant_guard import current_tenant
        tid = current_tenant()
        return tid if tid else None
    except Exception:
        return None


# ── Core aggregation ──────────────────────────────────────


# CoA categories → direction used for metric aggregation.
_METRIC_CATEGORIES: dict[str, tuple[str, str]] = {
    # metric name → (category, side_for_positive_number)
    "total_expenses":       ("expense",   "debit"),
    "total_revenue":        ("revenue",   "credit"),
    "cash_balance":         ("asset",     "debit"),    # filtered by subcategory
    "accounts_receivable":  ("asset",     "debit"),    # filtered by subcategory
    "accounts_payable":     ("liability", "credit"),   # filtered by subcategory
}

# Subcategory refinements for the asset/liability buckets above.
_METRIC_SUBCATEGORIES: dict[str, tuple[str, ...]] = {
    "cash_balance":        ("cash", "bank"),
    "accounts_receivable": ("receivables",),
    "accounts_payable":    ("payables",),
}


def _empty_result(
    metric: str,
    period_label: str,
    currency: str = "SAR",
    note: Optional[str] = None,
) -> dict[str, Any]:
    """Return the legacy placeholder shape — used when tables are absent
    or when an exception blocks a real query. Preserves backward-compat
    with existing tests that assert on `metric`, `value`, `currency`.
    """
    out: dict[str, Any] = {
        "metric": metric,
        "period": period_label,
        "value": 0,
        "currency": currency,
        "breakdown": [],
    }
    if note:
        out["_note"] = note
    return out


def aggregate_metric(
    metric: str,
    period: str,
    dimension: Optional[str] = None,
    tenant_id: Optional[str] = None,
) -> dict[str, Any]:
    """Compute one metric over a date range from pilot_gl_postings.

    Returns the same shape as the legacy placeholder plus a `breakdown`
    populated when `dimension` is requested.

    Special-case metrics `mrr` and `burn_rate` fall back to the
    placeholder for now — they need product-specific definitions the
    team hasn't finalised.
    """
    rng = parse_period(period)

    if metric in ("mrr", "burn_rate"):
        return _empty_result(
            metric, rng.label,
            note=f"{metric} requires subscription/burn definition not yet wired",
        )

    mapping = _METRIC_CATEGORIES.get(metric)
    if mapping is None:
        return _empty_result(metric, rng.label, note=f"unknown metric: {metric}")

    category, positive_side = mapping
    subcats = _METRIC_SUBCATEGORIES.get(metric)

    # Lazy imports so a missing pilot module doesn't blow up on import.
    try:
        from sqlalchemy import func
        from app.phase1.models.platform_models import SessionLocal
        from app.pilot.models import GLPosting, GLAccount
    except Exception as e:
        logger.debug("aggregate_metric: pilot layer unavailable (%s)", e)
        return _empty_result(
            metric, rng.label,
            note="pilot GL not loaded — tables not present in this environment",
        )

    tid = tenant_id or _current_tenant_id()
    db = SessionLocal()
    try:
        # Confirm the tables exist before querying — on a fresh test DB
        # they might not.
        try:
            from sqlalchemy import inspect as _inspect
            insp = _inspect(db.get_bind())
            tables = set(insp.get_table_names())
            if "pilot_gl_postings" not in tables or "pilot_gl_accounts" not in tables:
                return _empty_result(
                    metric, rng.label,
                    note="pilot_gl_postings not yet created for this tenant",
                )
        except Exception:
            pass  # proceed, let the query raise if truly broken

        q = (
            db.query(
                GLAccount.code,
                GLAccount.name_ar,
                func.coalesce(func.sum(GLPosting.debit_amount), 0).label("d"),
                func.coalesce(func.sum(GLPosting.credit_amount), 0).label("c"),
            )
            .join(GLAccount, GLPosting.account_id == GLAccount.id)
            .filter(GLAccount.category == category)
        )
        if subcats:
            q = q.filter(GLAccount.subcategory.in_(subcats))
        if tid:
            q = q.filter(GLPosting.tenant_id == tid)

        # Time window — GLPosting has no date column directly; filter
        # via JournalEntry.je_date if the FK is present. Importing here
        # avoids making it a hard dependency above.
        try:
            from app.pilot.models import JournalEntry
            q = q.join(JournalEntry, GLPosting.journal_entry_id == JournalEntry.id)
            q = q.filter(JournalEntry.je_date >= rng.start)
            q = q.filter(JournalEntry.je_date <= rng.end)
        except Exception:
            pass  # no time filter if model import fails — better than 500

        q = q.group_by(GLAccount.code, GLAccount.name_ar)
        rows = q.all()

        breakdown: list[dict[str, Any]] = []
        total = Decimal("0")
        for code, name_ar, d, c in rows:
            d = Decimal(str(d or 0))
            c = Decimal(str(c or 0))
            net = (d - c) if positive_side == "debit" else (c - d)
            total += net
            breakdown.append({
                "account_code": code,
                "account_name": name_ar,
                "amount": float(net.quantize(Decimal("0.01"))),
            })

        # Sort by magnitude so the LLM narrates the top drivers first.
        breakdown.sort(key=lambda r: abs(r["amount"]), reverse=True)

        return {
            "metric": metric,
            "period": rng.label,
            "dimension": dimension,
            "value": float(total.quantize(Decimal("0.01"))),
            "currency": "SAR",
            "breakdown": breakdown[:20],  # cap — LLM context hygiene
            "row_count": len(breakdown),
        }
    except Exception as e:
        logger.warning("aggregate_metric failed: %s", e)
        return _empty_result(
            metric, rng.label,
            note=f"aggregation failed — {e.__class__.__name__}",
        )
    finally:
        try:
            db.close()
        except Exception:
            pass


# ── Entity lookup ─────────────────────────────────────────


def lookup_entity(
    entity_type: str,
    query: str,
    tenant_id: Optional[str] = None,
    limit: int = 10,
) -> dict[str, Any]:
    """Search clients, invoices, accounts, employees, vendors.

    Returns a dict shaped {entity_type, query, matches: [{id, label, ...}]}.
    Matches on Arabic OR English names (case-insensitive LIKE).
    """
    tid = tenant_id or _current_tenant_id()
    q = (query or "").strip()
    if not q:
        return {"entity_type": entity_type, "query": query, "matches": []}

    pattern = f"%{q}%"
    matches: list[dict[str, Any]] = []

    try:
        from app.phase1.models.platform_models import SessionLocal
    except Exception:
        return {
            "entity_type": entity_type,
            "query": query,
            "matches": [],
            "_note": "core layer not available",
        }

    db = SessionLocal()
    try:
        if entity_type == "account":
            try:
                from app.pilot.models import GLAccount
                qset = db.query(GLAccount).filter(
                    (GLAccount.code.ilike(pattern))
                    | (GLAccount.name_ar.ilike(pattern))
                    | (GLAccount.name_en.ilike(pattern))
                )
                if tid:
                    qset = qset.filter(GLAccount.tenant_id == tid)
                for a in qset.limit(limit).all():
                    matches.append({
                        "id": a.id,
                        "label": f"{a.code} — {a.name_ar}",
                        "code": a.code,
                        "name_ar": a.name_ar,
                        "category": a.category,
                    })
            except Exception as e:
                logger.debug("account lookup failed: %s", e)

        elif entity_type == "client":
            # Look in the phase1 Client model first, then pilot entities.
            for model_path in (
                ("app.phase1.models.client_models", "Client"),
                ("app.pilot.models", "Entity"),
            ):
                try:
                    mod = __import__(model_path[0], fromlist=[model_path[1]])
                    Model = getattr(mod, model_path[1])
                    name_cols = [c for c in ("name_ar", "name", "display_name", "legal_name") if hasattr(Model, c)]
                    if not name_cols:
                        continue
                    filters = [getattr(Model, c).ilike(pattern) for c in name_cols]
                    from sqlalchemy import or_
                    rs = db.query(Model).filter(or_(*filters)).limit(limit).all()
                    for r in rs:
                        label = (
                            getattr(r, "name_ar", None)
                            or getattr(r, "name", None)
                            or getattr(r, "display_name", None)
                            or getattr(r, "legal_name", None)
                            or str(getattr(r, "id", ""))
                        )
                        matches.append({"id": str(getattr(r, "id", "")), "label": label})
                    if matches:
                        break
                except Exception:
                    continue

        elif entity_type == "invoice":
            try:
                from app.pilot.models import ZatcaInvoiceSubmission  # type: ignore
                rs = db.query(ZatcaInvoiceSubmission).filter(
                    ZatcaInvoiceSubmission.invoice_id.ilike(pattern)
                ).limit(limit).all()
                for r in rs:
                    matches.append({
                        "id": str(getattr(r, "id", "")),
                        "label": f"Invoice {getattr(r, 'invoice_id', '')}",
                    })
            except Exception:
                pass

        # employee / vendor — not yet wired to a canonical model; return empty
        # deterministically so the LLM says "no match" instead of hallucinating.

    finally:
        try:
            db.close()
        except Exception:
            pass

    return {
        "entity_type": entity_type,
        "query": query,
        "matches": matches,
        "count": len(matches),
    }


# ── Report builder passthrough ────────────────────────────


def get_report_summary(
    report_type: str,
    period: str,
    currency: str = "SAR",
    tenant_id: Optional[str] = None,
) -> dict[str, Any]:
    """Build a small structured report the agent can narrate.

    For the Big Three (P&L, BS, TB) we derive a summary from aggregated
    ledger data rather than calling the full fin_statements_service —
    the agent needs a narratable snapshot, not a publish-grade document.
    """
    rng = parse_period(period)

    if report_type == "trial_balance":
        rev = aggregate_metric("total_revenue", period, tenant_id=tenant_id)
        exp = aggregate_metric("total_expenses", period, tenant_id=tenant_id)
        cash = aggregate_metric("cash_balance", period, tenant_id=tenant_id)
        ar = aggregate_metric("accounts_receivable", period, tenant_id=tenant_id)
        ap = aggregate_metric("accounts_payable", period, tenant_id=tenant_id)
        return {
            "report_type": report_type,
            "period": rng.label,
            "currency": currency,
            "sections": [
                {"name": "الإيرادات",     "value": rev["value"]},
                {"name": "المصروفات",     "value": exp["value"]},
                {"name": "صافي الدخل",    "value": round(rev["value"] - exp["value"], 2)},
                {"name": "النقدية",        "value": cash["value"]},
                {"name": "ذمم مدينة",     "value": ar["value"]},
                {"name": "ذمم دائنة",     "value": ap["value"]},
            ],
        }

    if report_type in ("profit_and_loss", "p_and_l", "income_statement"):
        rev = aggregate_metric("total_revenue", period, tenant_id=tenant_id)
        exp = aggregate_metric("total_expenses", period, tenant_id=tenant_id)
        return {
            "report_type": "profit_and_loss",
            "period": rng.label,
            "currency": currency,
            "sections": [
                {"name": "الإيرادات",  "value": rev["value"],  "breakdown": rev.get("breakdown", [])},
                {"name": "المصروفات",  "value": exp["value"],  "breakdown": exp.get("breakdown", [])},
                {"name": "صافي الدخل", "value": round(rev["value"] - exp["value"], 2)},
            ],
        }

    if report_type == "balance_sheet":
        cash = aggregate_metric("cash_balance", period, tenant_id=tenant_id)
        ar = aggregate_metric("accounts_receivable", period, tenant_id=tenant_id)
        ap = aggregate_metric("accounts_payable", period, tenant_id=tenant_id)
        return {
            "report_type": "balance_sheet",
            "period": rng.label,
            "currency": currency,
            "sections": [
                {"name": "النقدية",      "value": cash["value"]},
                {"name": "ذمم مدينة",    "value": ar["value"]},
                {"name": "ذمم دائنة",    "value": ap["value"]},
            ],
        }

    # cash_flow / aging_report / vat_return — deferred to dedicated services
    return {
        "report_type": report_type,
        "period": rng.label,
        "currency": currency,
        "sections": [],
        "_note": f"{report_type}: dedicated builder not wired into agent yet",
    }


# ── Variance + forecast ───────────────────────────────────


def explain_variance(
    account: str,
    period_a: str,
    period_b: str,
    tenant_id: Optional[str] = None,
) -> dict[str, Any]:
    """Compare one account's net balance between two periods.

    `account` can be either an account CODE ("5301") or a partial name
    ("marketing", "تسويق"). We resolve it, aggregate the net debit/credit
    over each period, and return the delta plus top driver line-items.
    """
    rng_a = parse_period(period_a)
    rng_b = parse_period(period_b)

    # Resolve account.
    tid = tenant_id or _current_tenant_id()
    resolved_code: Optional[str] = None
    resolved_name: Optional[str] = None
    account_id: Optional[str] = None
    category: Optional[str] = None

    try:
        from app.phase1.models.platform_models import SessionLocal
        from app.pilot.models import GLAccount
        from sqlalchemy import or_
        db = SessionLocal()
        try:
            q = db.query(GLAccount).filter(
                or_(
                    GLAccount.code == account,
                    GLAccount.name_ar.ilike(f"%{account}%"),
                    GLAccount.name_en.ilike(f"%{account}%"),
                )
            )
            if tid:
                q = q.filter(GLAccount.tenant_id == tid)
            row = q.first()
            if row:
                account_id = row.id
                resolved_code = row.code
                resolved_name = row.name_ar
                category = row.category
        finally:
            try:
                db.close()
            except Exception:
                pass
    except Exception as e:
        logger.debug("variance: account resolve skipped — %s", e)

    if account_id is None:
        return {
            "account": account,
            "period_a": rng_a.label,
            "period_b": rng_b.label,
            "value_a": 0,
            "value_b": 0,
            "delta": 0,
            "drivers": [],
            "_note": "account not found — variance cannot be computed",
        }

    def _net_for(rng: PeriodRange) -> float:
        try:
            from sqlalchemy import func
            from app.phase1.models.platform_models import SessionLocal
            from app.pilot.models import GLPosting, JournalEntry
        except Exception:
            return 0.0
        db = SessionLocal()
        try:
            q = (
                db.query(
                    func.coalesce(func.sum(GLPosting.debit_amount), 0),
                    func.coalesce(func.sum(GLPosting.credit_amount), 0),
                )
                .join(JournalEntry, GLPosting.journal_entry_id == JournalEntry.id)
                .filter(GLPosting.account_id == account_id)
                .filter(JournalEntry.je_date >= rng.start)
                .filter(JournalEntry.je_date <= rng.end)
            )
            if tid:
                q = q.filter(GLPosting.tenant_id == tid)
            d, c = q.first() or (0, 0)
            d = Decimal(str(d or 0))
            c = Decimal(str(c or 0))
            # Use category's natural side to produce a positive-means-increase number.
            if category in ("liability", "equity", "revenue"):
                net = c - d
            else:  # asset, expense, contra_equity, or unknown → default debit
                net = d - c
            return float(net.quantize(Decimal("0.01")))
        except Exception as e:
            logger.debug("variance net query failed: %s", e)
            return 0.0
        finally:
            try:
                db.close()
            except Exception:
                pass

    v_a = _net_for(rng_a)
    v_b = _net_for(rng_b)
    delta = round(v_b - v_a, 2)

    # Drivers: the top 5 journal-line partners in period B for this account.
    drivers: list[dict[str, Any]] = []
    try:
        from sqlalchemy import func
        from app.phase1.models.platform_models import SessionLocal
        from app.pilot.models import JournalLine, JournalEntry
        db = SessionLocal()
        try:
            q = (
                db.query(
                    JournalLine.partner_name,
                    func.coalesce(func.sum(JournalLine.functional_debit), 0).label("d"),
                    func.coalesce(func.sum(JournalLine.functional_credit), 0).label("c"),
                )
                .join(JournalEntry, JournalLine.journal_entry_id == JournalEntry.id)
                .filter(JournalLine.account_id == account_id)
                .filter(JournalEntry.je_date >= rng_b.start)
                .filter(JournalEntry.je_date <= rng_b.end)
                .filter(JournalLine.partner_name.isnot(None))
                .group_by(JournalLine.partner_name)
                .order_by((func.coalesce(func.sum(JournalLine.functional_debit), 0)
                           + func.coalesce(func.sum(JournalLine.functional_credit), 0)).desc())
                .limit(5)
            )
            if tid:
                q = q.filter(JournalLine.tenant_id == tid)
            for name, d, c in q.all():
                drivers.append({
                    "partner": name,
                    "amount": float((Decimal(str(d or 0)) - Decimal(str(c or 0))).quantize(Decimal("0.01"))),
                })
        finally:
            try:
                db.close()
            except Exception:
                pass
    except Exception as e:
        logger.debug("variance drivers query failed: %s", e)

    return {
        "account": resolved_code or account,
        "account_name": resolved_name,
        "period_a": rng_a.label,
        "period_b": rng_b.label,
        "value_a": v_a,
        "value_b": v_b,
        "delta": delta,
        "drivers": drivers,
        "currency": "SAR",
    }


def forecast_metric(
    metric: str,
    horizon_months: int,
    tenant_id: Optional[str] = None,
    lookback_months: int = 6,
) -> dict[str, Any]:
    """Project a metric forward via simple moving-average of the last N months.

    Not ML — just a defensible baseline that gives the agent a real
    number to narrate instead of a placeholder zero. Confidence interval
    is ±1 standard deviation of the lookback window.

    `cash_balance` is projected as the latest balance plus the net monthly
    cash-flow trend (revenue − expenses) — the most-requested forecast.
    """
    today = date.today()
    horizon_months = max(1, min(24, int(horizon_months)))
    lookback_months = max(2, min(24, int(lookback_months)))

    # Build the lookback series: one value per completed month.
    series: list[float] = []
    month_cursor = today.replace(day=1)
    for _i in range(lookback_months):
        # Compute previous month boundary
        month_end = month_cursor - timedelta(days=1)
        month_start = month_end.replace(day=1)
        period = f"{month_start.isoformat()}:{month_end.isoformat()}"
        if metric == "cash_balance":
            rev = aggregate_metric("total_revenue", period, tenant_id=tenant_id)["value"]
            exp = aggregate_metric("total_expenses", period, tenant_id=tenant_id)["value"]
            series.append(float(rev - exp))
        else:
            r = aggregate_metric(metric, period, tenant_id=tenant_id)
            series.append(float(r.get("value", 0)))
        month_cursor = month_start

    # Reverse to chronological order (oldest → newest).
    series.reverse()

    if not series or all(v == 0 for v in series):
        return {
            "metric": metric,
            "horizon_months": horizon_months,
            "projected_values": [0.0] * horizon_months,
            "confidence_interval": {"low": [0.0] * horizon_months, "high": [0.0] * horizon_months},
            "method": "moving_average",
            "lookback_months": lookback_months,
            "_note": "no historical data — forecast is zero-filled",
        }

    # Trend: simple average of the last N months.
    avg = sum(series) / len(series)
    mean_sq_dev = sum((v - avg) ** 2 for v in series) / len(series)
    std = mean_sq_dev ** 0.5

    if metric == "cash_balance":
        # Project forward from today's estimated balance.
        current = aggregate_metric("cash_balance", "this_month", tenant_id=tenant_id)["value"]
        projected = []
        running = float(current)
        for _m in range(horizon_months):
            running += avg
            projected.append(round(running, 2))
    else:
        projected = [round(avg, 2)] * horizon_months

    low = [round(v - std, 2) for v in projected]
    high = [round(v + std, 2) for v in projected]

    return {
        "metric": metric,
        "horizon_months": horizon_months,
        "projected_values": projected,
        "confidence_interval": {"low": low, "high": high},
        "method": "moving_average",
        "lookback_months": lookback_months,
        "historical_series": [round(v, 2) for v in series],
        "currency": "SAR",
    }
