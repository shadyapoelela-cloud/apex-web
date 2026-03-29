"""
APEX Balance Sheet Builder — بناء قائمة المركز المالي
═════════════════════════════════════════════════════════

يبني الميزانية العمومية من normalized classified rows.
كل بند قابل للتتبع + balance validation.
"""

from app.core.constants import (
    ACCOUNT_TAXONOMY, BALANCE_SHEET, EQUITY,
    get_current_assets, get_non_current_assets,
    get_current_liabilities, get_non_current_liabilities,
    get_equity_classes,
)


class BalanceSheetBuilder:

    def build(self, classified_rows: list, net_profit: float = 0.0) -> dict:
        """
        Build balance sheet from classified rows.

        Args:
            classified_rows: rows with normalized_class
            net_profit: from income statement (for equity completeness)
        """
        warnings = []

        # Group BS + Equity rows by normalized_class
        groups = {}
        for row in classified_rows:
            cls = row.get("normalized_class")
            if not cls:
                continue
            tax = ACCOUNT_TAXONOMY.get(cls, {})
            if tax.get("section") not in (BALANCE_SHEET, EQUITY):
                continue
            if cls not in groups:
                groups[cls] = []
            groups[cls].append(row)

        def sum_class(class_name: str) -> float:
            if class_name not in groups:
                return 0.0
            tax = ACCOUNT_TAXONOMY.get(class_name, {})
            sign = tax.get("sign", "debit_normal")
            is_contra = tax.get("contra", False)
            total = sum(r.get("net_balance", 0) for r in groups.get(class_name, []))

            if is_contra:
                # Contra assets (e.g. accumulated depreciation): keep negative
                # net_balance is negative (credit) → return as-is (negative reduces assets)
                return total
            elif sign == "credit_normal":
                # Liabilities and equity: negate to get positive
                return -total
            return total

        # ─── Current Assets ───
        ca_classes = get_current_assets()
        current_assets_detail = {}
        for cls in ca_classes:
            val = sum_class(cls)
            if val != 0:
                current_assets_detail[cls] = round(val, 2)

        # Contra current assets (allowance for doubtful debts)
        for cls_name in ["allowance_doubtful"]:
            val = sum_class(cls_name)  # already negative from sum_class
            if val != 0:
                current_assets_detail[cls_name] = round(val, 2)

        total_current_assets = sum(current_assets_detail.values())

        # ─── Non-Current Assets ───
        nca_classes = get_non_current_assets()
        non_current_assets_detail = {}
        for cls in nca_classes:
            val = sum_class(cls)
            if val != 0:
                non_current_assets_detail[cls] = round(val, 2)

        total_non_current_assets = sum(non_current_assets_detail.values())
        total_assets = total_current_assets + total_non_current_assets

        # ─── Current Liabilities ───
        cl_classes = get_current_liabilities()
        current_liab_detail = {}
        for cls in cl_classes:
            val = sum_class(cls)
            if val != 0:
                current_liab_detail[cls] = round(val, 2)

        total_current_liabilities = sum(current_liab_detail.values())

        # ─── Non-Current Liabilities ───
        ncl_classes = get_non_current_liabilities()
        non_current_liab_detail = {}
        for cls in ncl_classes:
            val = sum_class(cls)
            if val != 0:
                non_current_liab_detail[cls] = round(val, 2)

        total_non_current_liabilities = sum(non_current_liab_detail.values())
        total_liabilities = total_current_liabilities + total_non_current_liabilities

        # ─── Equity ───
        eq_classes = get_equity_classes()
        equity_detail = {}
        for cls in eq_classes:
            val = sum_class(cls)
            if val != 0:
                equity_detail[cls] = round(val, 2)

        # Add net profit if current_year_profit not already classified
        if "current_year_profit" not in equity_detail and net_profit != 0:
            equity_detail["current_year_profit_derived"] = round(net_profit, 2)

        total_equity = sum(equity_detail.values())

        # ─── Balance Check ───
        total_liab_equity = total_liabilities + total_equity
        balance_diff = round(total_assets - total_liab_equity, 2)

        if abs(balance_diff) > 1.0:
            warnings.append({
                "code": "BALANCE_MISMATCH",
                "severity": "ERROR",
                "message": f"إجمالي الأصول ({total_assets:,.2f}) لا يساوي الالتزامات + حقوق الملكية ({total_liab_equity:,.2f}). الفرق: {balance_diff:,.2f}",
                "details": {
                    "total_assets": total_assets,
                    "total_liabilities_equity": total_liab_equity,
                    "difference": balance_diff,
                },
            })
        elif abs(balance_diff) > 0.01:
            warnings.append({
                "code": "BALANCE_ROUNDING",
                "severity": "INFO",
                "message": f"فرق تقريب بسيط: {balance_diff:,.2f}",
            })

        # Negative equity warning
        if total_equity < 0:
            warnings.append({
                "code": "NEGATIVE_EQUITY",
                "severity": "WARNING",
                "message": f"حقوق الملكية سالبة ({total_equity:,.2f}) — يشير إلى خسائر متراكمة تجاوزت رأس المال",
            })

        # ─── Build line items for traceability ───
        def build_detail(detail_dict: dict) -> dict:
            result = {}
            for cls, val in detail_dict.items():
                tax = ACCOUNT_TAXONOMY.get(cls, {})
                result[cls] = {
                    "amount": val,
                    "label_ar": tax.get("ar_label", cls),
                    "label_en": tax.get("en_label", cls),
                    "accounts": [
                        {"name": r.get("name", ""), "balance": round(r.get("net_balance", 0), 2)}
                        for r in groups.get(cls, [])
                    ],
                }
            return result

        return {
            "balance_sheet": {
                "current_assets": {
                    "detail": current_assets_detail,
                    "total": round(total_current_assets, 2),
                },
                "non_current_assets": {
                    "detail": non_current_assets_detail,
                    "total": round(total_non_current_assets, 2),
                },
                "total_assets": round(total_assets, 2),

                "current_liabilities": {
                    "detail": current_liab_detail,
                    "total": round(total_current_liabilities, 2),
                },
                "non_current_liabilities": {
                    "detail": non_current_liab_detail,
                    "total": round(total_non_current_liabilities, 2),
                },
                "total_liabilities": round(total_liabilities, 2),

                "equity": {
                    "detail": equity_detail,
                    "total": round(total_equity, 2),
                },
                "total_liabilities_and_equity": round(total_liab_equity, 2),
                "balance_check": round(balance_diff, 2),
                "is_balanced": abs(balance_diff) <= 1.0,
            },
            "line_items": {
                "current_assets": build_detail(current_assets_detail),
                "non_current_assets": build_detail(non_current_assets_detail),
                "current_liabilities": build_detail(current_liab_detail),
                "non_current_liabilities": build_detail(non_current_liab_detail),
                "equity": build_detail(equity_detail),
            },
            "warnings": warnings,
        }
