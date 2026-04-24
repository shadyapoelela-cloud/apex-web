"""Multi-currency dashboard data source.

Produces a dashboard payload showing:

  • Per-currency cash balance (read from pilot_gl_postings with
    accounts of category=asset / subcategory=cash|bank)
  • Current FX rate to a target ("display") currency
  • Converted totals + a "FX exposure" number — how much of total cash
    is held outside the display currency

No external API calls — uses the Fx Rate table that already exists in
the pilot module. Callers upload rates via the normal CoA seeding
flow, OR the admin UI lets them set spot rates manually.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, asdict
from datetime import date
from decimal import Decimal
from typing import Any, Optional

logger = logging.getLogger(__name__)


@dataclass
class CurrencyPosition:
    currency: str
    balance_native: float
    fx_rate: float
    balance_converted: float        # in display currency
    pct_of_total: float


@dataclass
class MultiCurrencySnapshot:
    display_currency: str
    as_of: str                      # ISO date
    positions: list[CurrencyPosition]
    total_converted: float
    fx_exposure_pct: float          # % of cash NOT in display ccy

    def to_dict(self) -> dict[str, Any]:
        return {
            "display_currency": self.display_currency,
            "as_of": self.as_of,
            "positions": [asdict(p) for p in self.positions],
            "total_converted": self.total_converted,
            "fx_exposure_pct": self.fx_exposure_pct,
        }


def _get_fx_rate(from_ccy: str, to_ccy: str, at_date: Optional[date] = None) -> float:
    """Latest rate from pilot FxRate table, or 1.0 if same currency / missing."""
    if from_ccy.upper() == to_ccy.upper():
        return 1.0
    try:
        from sqlalchemy import and_, desc
        from app.phase1.models.platform_models import SessionLocal
        from app.pilot.models import FxRate
    except Exception:
        return 1.0
    db = SessionLocal()
    try:
        q = db.query(FxRate).filter(
            and_(FxRate.from_currency == from_ccy.upper(),
                 FxRate.to_currency == to_ccy.upper())
        ).order_by(desc(FxRate.rate_date))
        if at_date:
            q = q.filter(FxRate.rate_date <= at_date)
        row = q.first()
        if row is None:
            # Try inverse.
            inv = db.query(FxRate).filter(
                and_(FxRate.from_currency == to_ccy.upper(),
                     FxRate.to_currency == from_ccy.upper())
            ).order_by(desc(FxRate.rate_date)).first()
            if inv and inv.rate:
                return float(1 / Decimal(str(inv.rate)))
            return 1.0
        return float(row.rate)
    except Exception as e:
        logger.debug("fx lookup failed: %s", e)
        return 1.0
    finally:
        try:
            db.close()
        except Exception:
            pass


def dashboard(
    *,
    display_currency: str = "SAR",
    tenant_id: Optional[str] = None,
) -> dict[str, Any]:
    """Build the multi-currency dashboard snapshot.

    Walks cash/bank account balances per currency and converts to
    display_currency using the latest FxRate. Graceful when no
    postings or rates are present."""
    display_currency = display_currency.upper()
    positions: list[CurrencyPosition] = []

    try:
        from sqlalchemy import func
        from app.phase1.models.platform_models import SessionLocal
        from app.pilot.models import GLPosting, GLAccount
    except Exception:
        return MultiCurrencySnapshot(
            display_currency=display_currency,
            as_of=date.today().isoformat(),
            positions=[],
            total_converted=0.0,
            fx_exposure_pct=0.0,
        ).to_dict()

    db = SessionLocal()
    try:
        q = (
            db.query(
                GLPosting.currency,
                func.coalesce(func.sum(GLPosting.debit_amount), 0),
                func.coalesce(func.sum(GLPosting.credit_amount), 0),
            )
            .join(GLAccount, GLPosting.account_id == GLAccount.id)
            .filter(GLAccount.category == "asset")
            .filter(GLAccount.subcategory.in_(("cash", "bank")))
        )
        if tenant_id:
            q = q.filter(GLPosting.tenant_id == tenant_id)
        rows = q.group_by(GLPosting.currency).all()
    except Exception:
        rows = []
    finally:
        try:
            db.close()
        except Exception:
            pass

    total_converted = Decimal("0")
    native_by_ccy: list[tuple[str, Decimal, float, Decimal]] = []
    for ccy, d, c in rows:
        native = Decimal(str(d or 0)) - Decimal(str(c or 0))
        rate = _get_fx_rate(ccy or display_currency, display_currency)
        converted = native * Decimal(str(rate))
        native_by_ccy.append((ccy or display_currency, native, rate, converted))
        total_converted += converted

    # Build positions with pct_of_total.
    for ccy, native, rate, converted in native_by_ccy:
        pct = 0.0
        if total_converted > 0:
            pct = float((converted / total_converted) * 100)
        positions.append(CurrencyPosition(
            currency=ccy,
            balance_native=float(native.quantize(Decimal("0.01"))),
            fx_rate=round(rate, 6),
            balance_converted=float(converted.quantize(Decimal("0.01"))),
            pct_of_total=round(pct, 2),
        ))

    # FX exposure: share held outside display_currency.
    non_native = sum(
        p.balance_converted for p in positions
        if p.currency.upper() != display_currency
    )
    exposure = 0.0
    if total_converted > 0:
        exposure = round(float(Decimal(str(non_native)) / total_converted * 100), 2)

    return MultiCurrencySnapshot(
        display_currency=display_currency,
        as_of=date.today().isoformat(),
        positions=sorted(positions, key=lambda p: p.balance_converted, reverse=True),
        total_converted=float(total_converted.quantize(Decimal("0.01"))),
        fx_exposure_pct=exposure,
    ).to_dict()
