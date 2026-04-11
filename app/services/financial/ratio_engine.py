"""
APEX Ratio Engine — محرك النسب المالية
═══════════════════════════════════════════

يحسب 25+ نسبة مالية مع:
- حماية من القسمة على صفر
- تحذيرات للقيم غير المنطقية
- مقارنة بمعايير القطاع
"""

from typing import Optional
from app.core.constants import INDUSTRY_BENCHMARKS

DAYS_PER_YEAR = 365


class RatioEngine:

    def calculate(
        self,
        income: dict,
        balance: dict,
        industry: str = "general",
    ) -> dict:
        """
        Calculate all financial ratios.

        Args:
            income: income_statement dict from IncomeStatementBuilder
            balance: balance_sheet dict from BalanceSheetBuilder
            industry: industry code for benchmarking
        """
        warnings = []
        benchmarks = INDUSTRY_BENCHMARKS.get(industry, INDUSTRY_BENCHMARKS["general"])

        # Extract values
        net_rev = income.get("net_revenue", 0)
        gross_profit = income.get("gross_profit", 0)
        operating_profit = income.get("operating_profit", 0)
        ebitda = income.get("ebitda", 0)
        net_profit = income.get("net_profit", 0)
        finance_cost = income.get("finance_cost", 0)
        cogs = income.get("cogs", 0)

        total_assets = balance.get("total_assets", 0)
        ca = balance.get("current_assets", {}).get("total", 0)
        inventory = sum(v for k, v in balance.get("current_assets", {}).get("detail", {}).items() if "inventory" in k)
        trade_recv = balance.get("current_assets", {}).get("detail", {}).get("trade_receivables", 0)
        cash = sum(
            v
            for k, v in balance.get("current_assets", {}).get("detail", {}).items()
            if k in ("cash_on_hand", "bank_accounts", "demand_deposits")
        )

        cl = balance.get("current_liabilities", {}).get("total", 0)
        total_liab = balance.get("total_liabilities", 0)
        total_equity = balance.get("equity", {}).get("total", 0)
        trade_pay = balance.get("current_liabilities", {}).get("detail", {}).get("trade_payables", 0)

        # ─── Profitability ───
        profitability = {
            "gross_margin_pct": self._pct(gross_profit, net_rev, warnings, "gross_margin"),
            "operating_margin_pct": self._pct(operating_profit, net_rev, warnings, "operating_margin"),
            "ebitda_margin_pct": self._pct(ebitda, net_rev, warnings, "ebitda_margin"),
            "net_margin_pct": self._pct(net_profit, net_rev, warnings, "net_margin"),
            "roa_pct": self._pct(net_profit, total_assets, warnings, "roa"),
            "roe_pct": self._pct(net_profit, total_equity, warnings, "roe"),
        }

        # ─── Liquidity ───
        liquidity = {
            "current_ratio": self._ratio(ca, cl, warnings, "current_ratio"),
            "quick_ratio": self._ratio(ca - inventory, cl, warnings, "quick_ratio"),
            "cash_ratio": self._ratio(cash, cl, warnings, "cash_ratio"),
            "working_capital": round(ca - cl, 2),
            "working_capital_to_revenue": self._ratio(ca - cl, net_rev, warnings, "wc_to_rev"),
        }

        # ─── Leverage ───
        leverage = {
            "debt_to_equity": self._ratio(total_liab, total_equity, warnings, "debt_to_equity"),
            "debt_to_assets_pct": self._pct(total_liab, total_assets, warnings, "debt_to_assets"),
            "liabilities_to_assets_pct": self._pct(total_liab, total_assets, warnings, "liab_to_assets"),
            "interest_coverage": (
                self._ratio(operating_profit, finance_cost, warnings, "interest_coverage") if finance_cost > 0 else None
            ),
        }

        # ─── Efficiency ───
        asset_turnover = self._ratio(net_rev, total_assets, warnings, "asset_turnover")
        inv_turnover = self._ratio(cogs, inventory, warnings, "inventory_turnover") if inventory > 0 else None
        days_inv = round(DAYS_PER_YEAR / inv_turnover, 1) if inv_turnover and inv_turnover > 0 else None
        recv_turnover = self._ratio(net_rev, trade_recv, warnings, "recv_turnover") if trade_recv > 0 else None
        dso = round(DAYS_PER_YEAR / recv_turnover, 1) if recv_turnover and recv_turnover > 0 else None
        pay_turnover = self._ratio(cogs, trade_pay, warnings, "pay_turnover") if trade_pay > 0 else None
        dpo = round(DAYS_PER_YEAR / pay_turnover, 1) if pay_turnover and pay_turnover > 0 else None

        # Cash Conversion Cycle
        ccc = None
        if days_inv is not None and dso is not None and dpo is not None:
            ccc = round(days_inv + dso - dpo, 1)

        efficiency = {
            "asset_turnover": asset_turnover,
            "inventory_turnover": inv_turnover,
            "days_in_inventory": days_inv,
            "receivables_turnover": recv_turnover,
            "dso": dso,
            "payables_turnover": pay_turnover,
            "dpo": dpo,
            "cash_conversion_cycle": ccc,
        }

        # ─── Benchmarking ───
        benchmark_comparison = {}
        ratio_map = {
            "gross_margin": profitability.get("gross_margin_pct"),
            "net_margin": profitability.get("net_margin_pct"),
            "ebitda_margin": profitability.get("ebitda_margin_pct"),
            "roe": profitability.get("roe_pct"),
            "roa": profitability.get("roa_pct"),
            "current_ratio": liquidity.get("current_ratio"),
            "quick_ratio": liquidity.get("quick_ratio"),
            "debt_to_equity": leverage.get("debt_to_equity"),
            "interest_coverage": leverage.get("interest_coverage"),
            "asset_turnover": efficiency.get("asset_turnover"),
            "inventory_days": efficiency.get("days_in_inventory"),
            "dso": efficiency.get("dso"),
        }

        for key, actual in ratio_map.items():
            if actual is None:
                continue
            bench = benchmarks.get(key)
            if bench is None:
                continue
            # Determine if higher or lower is better
            lower_is_better = key in ("debt_to_equity", "inventory_days", "dso", "dpo")
            if lower_is_better:
                status = "good" if actual <= bench * 1.1 else "warning" if actual <= bench * 1.5 else "danger"
            else:
                status = "good" if actual >= bench * 0.9 else "warning" if actual >= bench * 0.5 else "danger"

            benchmark_comparison[key] = {
                "actual": actual,
                "benchmark": bench,
                "status": status,
                "industry": industry,
            }

        return {
            "ratios": {
                "profitability": profitability,
                "liquidity": liquidity,
                "leverage": leverage,
                "efficiency": efficiency,
            },
            "benchmark_comparison": benchmark_comparison,
            "industry": industry,
            "warnings": warnings,
        }

    # ─── Safe math ───

    def _pct(self, numerator: float, denominator: float, warnings: list, label: str) -> Optional[float]:
        if denominator == 0:
            if numerator != 0:
                warnings.append(
                    {
                        "code": f"ZERO_DENOMINATOR_{label.upper()}",
                        "severity": "WARNING",
                        "message": f"مقام النسبة {label} يساوي صفر — لا يمكن حساب النسبة",
                    }
                )
            return None
        result = round(numerator / denominator * 100, 2)
        # Sanity check
        if abs(result) > 1000:
            warnings.append(
                {
                    "code": f"OUTLIER_{label.upper()}",
                    "severity": "WARNING",
                    "message": f"النسبة {label} = {result}% — قيمة غير اعتيادية قد تشير لخطأ في البيانات",
                }
            )
        return result

    def _ratio(self, numerator: float, denominator: float, warnings: list, label: str) -> Optional[float]:
        if denominator == 0:
            if numerator != 0:
                warnings.append(
                    {
                        "code": f"ZERO_DENOMINATOR_{label.upper()}",
                        "severity": "WARNING",
                        "message": f"مقام {label} يساوي صفر",
                    }
                )
            return None
        result = round(numerator / denominator, 2)
        if abs(result) > 100:
            warnings.append(
                {
                    "code": f"OUTLIER_{label.upper()}",
                    "severity": "WARNING",
                    "message": f"{label} = {result} — قيمة غير اعتيادية",
                }
            )
        return result
