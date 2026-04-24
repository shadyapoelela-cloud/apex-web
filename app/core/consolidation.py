"""Multi-entity consolidation — merge TBs, translate FX, eliminate IC.

The single biggest gap vs Xero/QuickBooks in Arabic platforms: groups
with multiple entities (Saudi parent + UAE sub + Egypt sub) have to
consolidate in Excel. APEX ships a light but correct consolidation:

  1. Collect each entity's trial balance.
  2. Translate non-functional currencies to the group's functional
     currency using the spot rate at period end (for balance-sheet
     items) and the average rate for the period (for P&L items).
  3. Eliminate intercompany balances — any line tagged with an
     intercompany counterparty entity is cancelled on both sides.
  4. Sum the translated + eliminated results into a consolidated TB.
  5. Emit a translation-reserve adjustment so assets still equal
     liabilities + equity after FX drift.

Uses the same TB shape `fin_statements_service` expects so downstream
report builders work unchanged.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, asdict, field
from decimal import Decimal
from typing import Any, Optional

logger = logging.getLogger(__name__)


# ── Input / output shapes ────────────────────────────────


@dataclass
class EntityTB:
    entity_id: str
    entity_name: str
    currency: str
    lines: list[dict[str, Any]]     # [{code, name_ar, classification, debit, credit, partner_entity_id?}]
    fx_rate_closing: float          # end-of-period spot rate to group ccy
    fx_rate_average: float          # average rate to group ccy


@dataclass
class ConsolidatedTBLine:
    code: str
    name_ar: str
    classification: str              # asset/liability/equity/revenue/expense/contra_*
    debit: float
    credit: float
    note: str = ""                   # translation/elimination notes


@dataclass
class ConsolidatedTB:
    group_name: str
    period_label: str
    functional_currency: str
    entity_count: int
    lines: list[ConsolidatedTBLine]
    total_debit: float
    total_credit: float
    is_balanced: bool
    translation_reserve: float        # plug entry for FX drift
    eliminations_count: int

    def to_dict(self) -> dict[str, Any]:
        return {
            "group_name": self.group_name,
            "period_label": self.period_label,
            "functional_currency": self.functional_currency,
            "entity_count": self.entity_count,
            "lines": [asdict(ln) for ln in self.lines],
            "total_debit": self.total_debit,
            "total_credit": self.total_credit,
            "is_balanced": self.is_balanced,
            "translation_reserve": self.translation_reserve,
            "eliminations_count": self.eliminations_count,
        }


# ── Helpers ──────────────────────────────────────────────


_IS = {"revenue", "expense"}       # translate at average rate
_BS = {"asset", "liability", "equity", "contra_asset", "contra_equity"}  # translate at closing


def _rate_for(classification: str, tb: EntityTB) -> float:
    return tb.fx_rate_average if classification in _IS else tb.fx_rate_closing


def _quantize(v) -> float:
    if not isinstance(v, Decimal):
        v = Decimal(str(v))
    return float(v.quantize(Decimal("0.01")))


# ── Consolidation engine ─────────────────────────────────


def consolidate(
    *,
    group_name: str,
    period_label: str,
    functional_currency: str,
    tbs: list[EntityTB],
) -> ConsolidatedTB:
    """Produce a consolidated TB from N entity TBs.

    Assumes each entity's TB is internally balanced. Does NOT (yet)
    handle minority interests, goodwill, or step acquisitions — those
    need the pre-consolidation "equity method" module which is a
    separate workstream.
    """
    if not tbs:
        return ConsolidatedTB(
            group_name=group_name,
            period_label=period_label,
            functional_currency=functional_currency,
            entity_count=0,
            lines=[],
            total_debit=0.0,
            total_credit=0.0,
            is_balanced=True,
            translation_reserve=0.0,
            eliminations_count=0,
        )

    # 1 + 2. Translate every line to functional currency.
    aggregated: dict[tuple[str, str], ConsolidatedTBLine] = {}
    eliminations = 0

    for tb in tbs:
        for ln in tb.lines:
            code = str(ln.get("code", ""))
            name = str(ln.get("name_ar", "") or ln.get("name", ""))
            clsn = str(ln.get("classification", "")).lower()
            debit = Decimal(str(ln.get("debit", 0)))
            credit = Decimal(str(ln.get("credit", 0)))
            partner = ln.get("partner_entity_id")

            # 3. Elimination — intercompany rows tagged with a partner
            # that's also in the consolidated set cancel out. We zero
            # the contribution here and count it.
            if partner and any(p.entity_id == partner for p in tbs):
                eliminations += 1
                continue

            rate = Decimal(str(_rate_for(clsn, tb)))
            debit *= rate
            credit *= rate

            key = (code, clsn)
            if key not in aggregated:
                aggregated[key] = ConsolidatedTBLine(
                    code=code, name_ar=name, classification=clsn,
                    debit=0.0, credit=0.0,
                    note=f"translated at closing={tb.fx_rate_closing:.4f} / avg={tb.fx_rate_average:.4f}",
                )
            cur = aggregated[key]
            cur.debit = _quantize(Decimal(str(cur.debit)) + debit)
            cur.credit = _quantize(Decimal(str(cur.credit)) + credit)

    lines = sorted(aggregated.values(), key=lambda ln: ln.code)
    total_debit = sum(Decimal(str(ln.debit)) for ln in lines)
    total_credit = sum(Decimal(str(ln.credit)) for ln in lines)

    # 5. Translation reserve — plug entry so BS stays balanced after
    # mixing average-rate P&L with closing-rate BS.
    diff = total_debit - total_credit
    translation_reserve = 0.0
    if abs(diff) >= Decimal("0.01"):
        translation_reserve = _quantize(abs(diff))
        reserve_line = ConsolidatedTBLine(
            code="3999",
            name_ar="احتياطي فروقات ترجمة العملات",
            classification="equity",
            debit=_quantize(-diff) if diff > 0 else 0.0,
            credit=_quantize(diff) if diff > 0 else 0.0,
            note="FX translation plug — balances BS after mixed-rate consolidation",
        )
        # Put it in the right column
        if diff > 0:
            reserve_line.credit = translation_reserve
            reserve_line.debit = 0.0
        else:
            reserve_line.debit = translation_reserve
            reserve_line.credit = 0.0
        lines.append(reserve_line)
        if diff > 0:
            total_credit += Decimal(str(translation_reserve))
        else:
            total_debit += Decimal(str(translation_reserve))

    return ConsolidatedTB(
        group_name=group_name,
        period_label=period_label,
        functional_currency=functional_currency,
        entity_count=len(tbs),
        lines=lines,
        total_debit=_quantize(total_debit),
        total_credit=_quantize(total_credit),
        is_balanced=abs(total_debit - total_credit) < Decimal("0.01"),
        translation_reserve=translation_reserve,
        eliminations_count=eliminations,
    )


def consolidate_from_dicts(payload: dict[str, Any]) -> dict[str, Any]:
    """HTTP-friendly entry point: takes plain dicts, returns plain dict.

    Payload shape:
      {
        "group_name": "APEX Group",
        "period_label": "FY 2025",
        "functional_currency": "SAR",
        "entities": [
          {
            "entity_id": "e1", "entity_name": "APEX KSA", "currency": "SAR",
            "fx_rate_closing": 1.0, "fx_rate_average": 1.0,
            "lines": [
              {"code": "1110", "name_ar": "نقد", "classification": "asset",
               "debit": 100000, "credit": 0},
              ...
            ]
          },
          ...
        ]
      }
    """
    tbs = [
        EntityTB(
            entity_id=str(e["entity_id"]),
            entity_name=str(e.get("entity_name", "")),
            currency=str(e.get("currency", "SAR")),
            fx_rate_closing=float(e.get("fx_rate_closing", 1.0)),
            fx_rate_average=float(e.get("fx_rate_average", 1.0)),
            lines=list(e.get("lines", [])),
        )
        for e in payload.get("entities", [])
    ]
    result = consolidate(
        group_name=str(payload.get("group_name", "Group")),
        period_label=str(payload.get("period_label", "")),
        functional_currency=str(payload.get("functional_currency", "SAR")),
        tbs=tbs,
    )
    return result.to_dict()
