"""
APEX Income Statement Builder — بناء قائمة الدخل
═══════════════════════════════════════════════════

يبني قائمة الدخل من normalized classified rows فقط.
لا يستخدم اشتقاق بالفرق إلا كـ fallback مع warning.
كل بند قابل للتتبع.
"""

from app.core.constants import ACCOUNT_TAXONOMY


class IncomeStatementBuilder:
    """
    Builds income statement from classified trial balance rows.

    Rules:
    - Revenue accounts have credit_normal sign → negate net_balance to get positive revenue
    - Expense accounts have debit_normal sign → net_balance is already positive cost
    - Returns/discounts are debit_normal → reduce revenue
    """

    def build(self, classified_rows: list, opening_inventory: float = 0.0,
              closing_inventory_override: float = None) -> dict:
        """
        Build income statement from classified rows.

        Args:
            classified_rows: List of rows with normalized_class from classifier
            opening_inventory: بضاعة أول المدة (من عمود D في النموذج)
            closing_inventory_override: مخزون آخر المدة الفعلي (من الجرد) — للجرد الدوري
        """
        warnings = []

        # Group rows by normalized_class
        groups = {}
        for row in classified_rows:
            cls = row.get("normalized_class")
            if not cls:
                continue
            section = ACCOUNT_TAXONOMY.get(cls, {}).get("section")
            if section != "income_statement":
                continue
            if cls not in groups:
                groups[cls] = []
            groups[cls].append(row)

        # Helper: sum net_balance for a class, applying sign rule
        def sum_class(class_name: str) -> float:
            if class_name not in groups:
                return 0.0
            sign = ACCOUNT_TAXONOMY.get(class_name, {}).get("sign", "debit_normal")
            total = sum(r.get("net_balance", 0) for r in groups.get(class_name, []))
            if sign == "credit_normal":
                return -total
            return total

        def sum_classes(class_names: list) -> float:
            return sum(sum_class(c) for c in class_names)

        # ─── Revenue ───
        revenue = sum_class("revenue")
        service_revenue = sum_class("service_revenue")
        other_revenue = sum_class("other_revenue")
        gross_revenue = revenue + service_revenue + other_revenue

        sales_returns = sum_class("sales_returns")
        sales_discounts = sum_class("sales_discounts")

        net_revenue = gross_revenue - sales_returns - sales_discounts

        # ─── COGS ───
        cogs_direct = sum_class("cogs")
        purchases = sum_class("purchases")
        purchases_returns = sum_class("purchases_returns")
        freight_in = sum_class("freight_in")
        direct_labor = sum_class("direct_labor")

        # Closing inventory: use override if provided (periodic system)
        if closing_inventory_override is not None:
            closing_inventory = closing_inventory_override
            inv_source = "user_input"
        else:
            closing_inventory = self._get_closing_inventory(classified_rows)
            inv_source = "trial_balance"

        # COGS calculation
        if cogs_direct > 0 and purchases == 0:
            # Direct COGS (perpetual system)
            cogs = cogs_direct
            cogs_method = "direct"
        elif purchases > 0:
            # Periodic system: COGS = opening + net_purchases - closing
            net_purchases = purchases - purchases_returns + freight_in
            cogs = opening_inventory + net_purchases - closing_inventory
            cogs_method = f"periodic_{inv_source}"
            if closing_inventory_override is not None:
                warnings.append({
                    "code": "PERIODIC_CLOSING_INV_USED",
                    "severity": "INFO",
                    "message": f"تم استخدام مخزون آخر المدة الفعلي ({closing_inventory_override:,.0f}) من الجرد الدوري لحساب تكلفة البضاعة المباعة",
                })
            elif opening_inventory == 0 and closing_inventory == 0:
                warnings.append({
                    "code": "COGS_NO_INVENTORY",
                    "severity": "WARNING",
                    "message": "تكلفة البضاعة المباعة محسوبة بدون بيانات مخزون أول وآخر المدة",
                })
        else:
            cogs = 0
            cogs_method = "none"

        gross_profit = net_revenue - cogs

        # ─── Operating Expenses ───
        admin_expenses = sum_classes([
            "admin_expenses", "payroll", "rent_expense", "utilities",
            "depreciation_expense", "amortization_expense", "government_fees",
            "insurance_expense", "travel_expense", "professional_fees",
            "misc_admin_expense", "gosi_expense", "medical_insurance",
        ])

        selling_expenses = sum_classes([
            "selling_expenses", "sales_commission", "marketing_expense",
        ])

        total_opex = admin_expenses + selling_expenses
        operating_profit = gross_profit - total_opex  # EBIT

        # ─── EBITDA ───
        depreciation = sum_class("depreciation_expense")
        amortization = sum_class("amortization_expense")
        ebitda = operating_profit + depreciation + amortization

        # ─── Non-operating ───
        other_income = sum_classes(["other_income", "gains_asset_disposal", "forex_gain", "finance_income"])
        other_expenses = sum_classes(["other_expenses", "losses_asset_disposal", "forex_loss", "penalties", "bad_debts"])
        finance_cost = sum_class("finance_cost")

        profit_before_tax = operating_profit + other_income - other_expenses - finance_cost

        # ─── Tax / Zakat ───
        zakat_tax = sum_class("zakat_tax")
        net_profit = profit_before_tax - zakat_tax

        # ─── Build detailed line items for traceability ───
        line_items = {}
        for cls, rows in groups.items():
            line_items[cls] = {
                "label_ar": ACCOUNT_TAXONOMY.get(cls, {}).get("ar_label", cls),
                "label_en": ACCOUNT_TAXONOMY.get(cls, {}).get("en_label", cls),
                "amount": round(sum_class(cls), 2),
                "accounts": [
                    {"name": r.get("name", ""), "balance": round(r.get("net_balance", 0), 2)}
                    for r in rows
                ],
            }

        return {
            "income_statement": {
                "revenue": round(revenue, 2),
                "service_revenue": round(service_revenue, 2),
                "other_operating_revenue": round(other_revenue, 2),
                "gross_revenue": round(gross_revenue, 2),
                "sales_returns": round(sales_returns, 2),
                "sales_discounts": round(sales_discounts, 2),
                "net_revenue": round(net_revenue, 2),

                "opening_inventory": round(opening_inventory, 2),
                "purchases": round(purchases, 2),
                "purchases_returns": round(purchases_returns, 2),
                "freight_in": round(freight_in, 2),
                "closing_inventory": round(closing_inventory, 2),
                "cogs": round(cogs, 2),
                "cogs_method": cogs_method,
                "gross_profit": round(gross_profit, 2),

                "admin_expenses": round(admin_expenses, 2),
                "selling_expenses": round(selling_expenses, 2),
                "total_operating_expenses": round(total_opex, 2),
                "operating_profit": round(operating_profit, 2),

                "ebitda": round(ebitda, 2),
                "depreciation": round(depreciation, 2),
                "amortization": round(amortization, 2),

                "other_income": round(other_income, 2),
                "other_expenses": round(other_expenses, 2),
                "finance_cost": round(finance_cost, 2),
                "profit_before_tax": round(profit_before_tax, 2),

                "zakat_tax": round(zakat_tax, 2),
                "net_profit": round(net_profit, 2),
            },
            "line_items": line_items,
            "warnings": warnings,
        }

    def _get_closing_inventory(self, classified_rows: list) -> float:
        """Get closing inventory from balance sheet classified rows."""
        inv_classes = ["inventory", "inventory_raw", "inventory_wip", "inventory_transit"]
        total = 0.0
        for row in classified_rows:
            if row.get("normalized_class") in inv_classes:
                total += row.get("net_balance", 0)
        return total
