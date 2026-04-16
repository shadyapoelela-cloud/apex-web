"""
APEX Platform — Cash Flow Statement (IAS 7 / SOCPA)
═══════════════════════════════════════════════════════════════
Builds the three-section cash flow statement using the Indirect
method (most common in practice + ZATCA-compatible):

  Operating  — starts from net income, adds back non-cash items,
               adjusts for working-capital changes.
  Investing  — CapEx, asset disposals, investment buys/sells.
  Financing  — loan drawdowns/repayments, share issuance/buyback,
               dividends paid.

Net change in cash = O + I + F
Ending cash        = Beginning + Net change
Integrity check    = Ending must equal the reported ending cash;
                     mismatches surface as warnings (not errors).

All math is Decimal. Missing inputs are treated as zero so a
partially-filled form still produces a partial statement.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional


_TWO = Decimal("0.01")


def _q(value: Optional[Decimal | int | float | str]) -> Decimal:
    if value is None:
        return Decimal("0")
    if not isinstance(value, Decimal):
        value = Decimal(str(value))
    return value.quantize(_TWO, rounding=ROUND_HALF_UP)


@dataclass
class CashFlowInput:
    # ── Period reference ──
    period_label: str = "FY"
    beginning_cash: Decimal = Decimal("0")
    ending_cash_reported: Optional[Decimal] = None  # for integrity check

    # ── Operating (indirect: start from NI) ──
    net_income: Decimal = Decimal("0")
    depreciation_amortization: Decimal = Decimal("0")
    impairment_losses: Decimal = Decimal("0")
    loss_on_asset_sale: Decimal = Decimal("0")       # add-back
    gain_on_asset_sale: Decimal = Decimal("0")       # subtract

    # Working capital changes (∆ during period):
    # positive means the account INCREASED — that reduces cash for assets
    # and increases cash for liabilities, respectively.
    increase_receivables: Decimal = Decimal("0")     # − from cash
    increase_inventory: Decimal = Decimal("0")       # − from cash
    increase_prepaid: Decimal = Decimal("0")         # − from cash
    increase_payables: Decimal = Decimal("0")        # + to cash
    increase_accrued: Decimal = Decimal("0")         # + to cash
    increase_deferred_revenue: Decimal = Decimal("0")# + to cash

    # ── Investing ──
    capex: Decimal = Decimal("0")                    # purchase of PPE (− cash)
    proceeds_asset_sale: Decimal = Decimal("0")      # + cash
    purchase_investments: Decimal = Decimal("0")     # − cash
    sale_investments: Decimal = Decimal("0")         # + cash
    acquisitions: Decimal = Decimal("0")             # − cash

    # ── Financing ──
    loan_proceeds: Decimal = Decimal("0")            # + cash
    loan_repayments: Decimal = Decimal("0")          # − cash
    share_issuance: Decimal = Decimal("0")           # + cash
    share_buyback: Decimal = Decimal("0")            # − cash
    dividends_paid: Decimal = Decimal("0")           # − cash
    interest_paid: Decimal = Decimal("0")            # − cash (classification varies)


@dataclass
class CashFlowLine:
    label_ar: str
    label_en: str
    amount: Decimal       # signed (+ inflow / − outflow)


@dataclass
class CashFlowSection:
    name_ar: str
    name_en: str
    lines: list[CashFlowLine]
    subtotal: Decimal


@dataclass
class CashFlowResult:
    period_label: str
    beginning_cash: Decimal
    ending_cash_computed: Decimal
    ending_cash_reported: Optional[Decimal]
    reconciles: Optional[bool]           # True/False/None(unknown)
    reconciliation_diff: Optional[Decimal]
    operating: CashFlowSection
    investing: CashFlowSection
    financing: CashFlowSection
    net_change: Decimal
    warnings: list[str] = field(default_factory=list)


# ═══════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════


def compute_cashflow(inp: CashFlowInput) -> CashFlowResult:
    warnings: list[str] = []

    # ── Operating section ──
    op_lines: list[CashFlowLine] = []
    ni = _q(inp.net_income)
    op_lines.append(CashFlowLine("صافي الربح", "Net income", ni))

    def add_if_nonzero(coll, ar, en, value):
        if value != 0:
            coll.append(CashFlowLine(ar, en, value))

    add_if_nonzero(op_lines, "استهلاك وإطفاء", "Depreciation & amortization", _q(inp.depreciation_amortization))
    add_if_nonzero(op_lines, "خسائر انخفاض قيمة", "Impairment losses", _q(inp.impairment_losses))
    add_if_nonzero(op_lines, "خسارة من بيع أصول", "Loss on asset sale", _q(inp.loss_on_asset_sale))
    gain_sale = -_q(inp.gain_on_asset_sale)
    if gain_sale != 0:
        op_lines.append(CashFlowLine("ربح من بيع أصول (يُطرح)", "Gain on asset sale", gain_sale))

    # Working capital — signs flipped for asset increases:
    add_if_nonzero(op_lines, "الزيادة في المدينين (يُطرح)", "Increase in receivables", -_q(inp.increase_receivables))
    add_if_nonzero(op_lines, "الزيادة في المخزون (يُطرح)", "Increase in inventory", -_q(inp.increase_inventory))
    add_if_nonzero(op_lines, "الزيادة في المصروفات المدفوعة مقدماً (يُطرح)", "Increase in prepaid", -_q(inp.increase_prepaid))
    add_if_nonzero(op_lines, "الزيادة في الدائنين (يُضاف)", "Increase in payables", _q(inp.increase_payables))
    add_if_nonzero(op_lines, "الزيادة في المصروفات المستحقة (يُضاف)", "Increase in accrued", _q(inp.increase_accrued))
    add_if_nonzero(op_lines, "الزيادة في إيرادات مؤجلة (يُضاف)", "Increase in deferred revenue", _q(inp.increase_deferred_revenue))

    operating_subtotal = _q(sum((ln.amount for ln in op_lines), Decimal("0")))
    op_section = CashFlowSection(
        "الأنشطة التشغيلية", "Operating activities", op_lines, operating_subtotal,
    )

    # ── Investing section ──
    inv_lines: list[CashFlowLine] = []
    add_if_nonzero(inv_lines, "شراء ممتلكات وآلات", "CapEx", -_q(inp.capex))
    add_if_nonzero(inv_lines, "متحصلات من بيع أصول", "Proceeds from asset sale", _q(inp.proceeds_asset_sale))
    add_if_nonzero(inv_lines, "شراء استثمارات", "Purchase of investments", -_q(inp.purchase_investments))
    add_if_nonzero(inv_lines, "بيع استثمارات", "Sale of investments", _q(inp.sale_investments))
    add_if_nonzero(inv_lines, "استحواذات", "Acquisitions", -_q(inp.acquisitions))
    investing_subtotal = _q(sum((ln.amount for ln in inv_lines), Decimal("0")))
    inv_section = CashFlowSection(
        "الأنشطة الاستثمارية", "Investing activities", inv_lines, investing_subtotal,
    )

    # ── Financing section ──
    fin_lines: list[CashFlowLine] = []
    add_if_nonzero(fin_lines, "قروض مستلمة", "Loan proceeds", _q(inp.loan_proceeds))
    add_if_nonzero(fin_lines, "سداد قروض", "Loan repayments", -_q(inp.loan_repayments))
    add_if_nonzero(fin_lines, "إصدار أسهم", "Share issuance", _q(inp.share_issuance))
    add_if_nonzero(fin_lines, "إعادة شراء أسهم", "Share buyback", -_q(inp.share_buyback))
    add_if_nonzero(fin_lines, "توزيعات مدفوعة", "Dividends paid", -_q(inp.dividends_paid))
    add_if_nonzero(fin_lines, "فوائد مدفوعة", "Interest paid", -_q(inp.interest_paid))
    financing_subtotal = _q(sum((ln.amount for ln in fin_lines), Decimal("0")))
    fin_section = CashFlowSection(
        "الأنشطة التمويلية", "Financing activities", fin_lines, financing_subtotal,
    )

    # ── Totals + reconciliation ──
    net_change = _q(operating_subtotal + investing_subtotal + financing_subtotal)
    beginning = _q(inp.beginning_cash)
    ending_computed = _q(beginning + net_change)

    reconciles = None
    diff = None
    if inp.ending_cash_reported is not None:
        reported = _q(inp.ending_cash_reported)
        diff = _q(ending_computed - reported)
        reconciles = diff == 0
        if not reconciles:
            warnings.append(
                f"عدم تطابق: القيمة المحسوبة ({ending_computed}) تختلف عن المُبلّغ عنها ({reported}) — "
                f"الفارق {diff}. راجع مكونات القائمة."
            )

    if operating_subtotal < 0:
        warnings.append(
            "التدفق التشغيلي سالب — الشركة تستهلك النقد من عملياتها الأساسية."
        )

    return CashFlowResult(
        period_label=inp.period_label,
        beginning_cash=beginning,
        ending_cash_computed=ending_computed,
        ending_cash_reported=_q(inp.ending_cash_reported) if inp.ending_cash_reported is not None else None,
        reconciles=reconciles,
        reconciliation_diff=diff,
        operating=op_section,
        investing=inv_section,
        financing=fin_section,
        net_change=net_change,
        warnings=warnings,
    )


def result_to_dict(r: CashFlowResult) -> dict:
    def section_to_dict(s: CashFlowSection) -> dict:
        return {
            "name_ar": s.name_ar,
            "name_en": s.name_en,
            "subtotal": f"{s.subtotal}",
            "lines": [
                {
                    "label_ar": ln.label_ar,
                    "label_en": ln.label_en,
                    "amount": f"{ln.amount}",
                }
                for ln in s.lines
            ],
        }

    return {
        "period_label": r.period_label,
        "beginning_cash": f"{r.beginning_cash}",
        "net_change": f"{r.net_change}",
        "ending_cash_computed": f"{r.ending_cash_computed}",
        "ending_cash_reported": None if r.ending_cash_reported is None else f"{r.ending_cash_reported}",
        "reconciles": r.reconciles,
        "reconciliation_diff": None if r.reconciliation_diff is None else f"{r.reconciliation_diff}",
        "operating": section_to_dict(r.operating),
        "investing": section_to_dict(r.investing),
        "financing": section_to_dict(r.financing),
        "warnings": r.warnings,
    }
