"""
APEX Cash Flow Builder — بناء قائمة التدفقات النقدية
══════════════════════════════════════════════════════════

الطريقة: غير مباشرة (Indirect Method)
يبدأ من صافي الربح ثم:
  1. يضيف التعديلات غير النقدية (إهلاك، إطفاء، مخصصات)
  2. يحسب تغيرات رأس المال العامل
  3. يفصل الأنشطة الاستثمارية
  4. يفصل الأنشطة التمويلية

إذا لم تتوفر بيانات الحركة → confidence منخفض + تحذير
لا يختلق أرقام ثابتة أبداً
"""

from app.core.constants import ACCOUNT_TAXONOMY


class CashFlowBuilder:
    """
    Builds cash flow statement using the indirect method.

    Requires:
    - Income statement (for net profit + non-cash items)
    - Balance sheet current period
    - Balance sheet prior period (optional - for working capital changes)
    - Classified rows (for detail)
    """

    def build(
        self,
        income: dict,
        balance_current: dict,
        balance_prior: dict = None,
        classified_rows: list = None,
    ) -> dict:
        """
        Build cash flow statement.

        Args:
            income: income_statement from IncomeStatementBuilder
            balance_current: current period balance_sheet
            balance_prior: prior period balance_sheet (None if unavailable)
            classified_rows: for extracting non-cash details
        """
        warnings = []
        has_prior = balance_prior is not None

        if not has_prior:
            warnings.append(
                {
                    "code": "NO_PRIOR_PERIOD",
                    "severity": "WARNING",
                    "message": "لا تتوفر بيانات الفترة السابقة — التدفقات النقدية مشتقة جزئياً من الأرصدة الحالية فقط",
                }
            )

        # ═══ Operating Activities ═══
        net_profit = income.get("net_profit", 0)

        # Non-cash adjustments
        depreciation = income.get("depreciation", 0)
        amortization = income.get("amortization", 0)

        # Extract provisions and non-cash from classified rows
        provisions_change = 0
        if classified_rows:
            for row in classified_rows:
                cls = row.get("normalized_class", "")
                if cls in ("end_of_service", "warranty_provision"):
                    provisions_change += row.get("net_balance", 0)
            # Provisions are credit_normal → negate
            provisions_change = -provisions_change

        non_cash_total = depreciation + amortization + provisions_change

        # Working capital changes (current period - prior period)
        wc_changes = {}
        wc_total = 0

        if has_prior:
            wc_changes = self._calculate_wc_changes(balance_current, balance_prior)
            wc_total = sum(wc_changes.values())
        else:
            # Without prior period, we can't calculate WC changes accurately
            # We estimate from current balances only with low confidence
            wc_changes = self._estimate_wc_from_current(balance_current)
            wc_total = 0  # Don't include estimated WC in totals
            warnings.append(
                {
                    "code": "WC_ESTIMATED",
                    "severity": "WARNING",
                    "message": "تغيرات رأس المال العامل غير متاحة — تحتاج بيانات فترتين للحساب الدقيق",
                }
            )

        operating_cash_flow = net_profit + non_cash_total + wc_total

        # ═══ Investing Activities ═══
        investing = {}
        investing_total = 0

        if has_prior:
            investing = self._calculate_investing(balance_current, balance_prior, income)
            investing_total = sum(investing.values())
        else:
            # Can estimate capex from fixed assets + depreciation
            ppe_current = self._sum_ppe(balance_current)
            estimated_capex = -(ppe_current) if ppe_current > 0 else 0
            if estimated_capex != 0:
                investing["estimated_capex"] = round(estimated_capex, 2)
                warnings.append(
                    {
                        "code": "INVESTING_ESTIMATED",
                        "severity": "WARNING",
                        "message": "الأنشطة الاستثمارية تقديرية — تحتاج بيانات فترتين",
                    }
                )

        # ═══ Financing Activities ═══
        financing = {}
        financing_total = 0

        if has_prior:
            financing = self._calculate_financing(balance_current, balance_prior)
            financing_total = sum(financing.values())
        else:
            warnings.append(
                {
                    "code": "FINANCING_ESTIMATED",
                    "severity": "WARNING",
                    "message": "الأنشطة التمويلية غير متاحة — تحتاج بيانات فترتين",
                }
            )

        # ═══ Net Change ═══
        net_change = operating_cash_flow + investing_total + financing_total

        # ═══ Confidence ═══
        if has_prior:
            confidence = 0.85
            confidence_label = "جيد"
        else:
            confidence = 0.45
            confidence_label = "تقديري — يحتاج بيانات فترتين"

        return {
            "cash_flow": {
                "operating": {
                    "net_profit": round(net_profit, 2),
                    "non_cash_adjustments": {
                        "depreciation": round(depreciation, 2),
                        "amortization": round(amortization, 2),
                        "provisions_change": round(provisions_change, 2),
                        "total": round(non_cash_total, 2),
                    },
                    "working_capital_changes": {k: round(v, 2) for k, v in wc_changes.items()},
                    "working_capital_total": round(wc_total, 2),
                    "total": round(operating_cash_flow, 2),
                },
                "investing": {
                    "detail": {k: round(v, 2) for k, v in investing.items()},
                    "total": round(investing_total, 2),
                },
                "financing": {
                    "detail": {k: round(v, 2) for k, v in financing.items()},
                    "total": round(financing_total, 2),
                },
                "net_cash_change": round(net_change, 2),
                "has_prior_period": has_prior,
                "confidence": confidence,
                "confidence_label": confidence_label,
            },
            "warnings": warnings,
        }

    def _calculate_wc_changes(self, current: dict, prior: dict) -> dict:
        """Calculate working capital changes between two periods."""
        changes = {}

        ca_curr = current.get("current_assets", {}).get("detail", {})
        ca_prior = prior.get("current_assets", {}).get("detail", {})
        cl_curr = current.get("current_liabilities", {}).get("detail", {})
        cl_prior = prior.get("current_liabilities", {}).get("detail", {})

        # Asset increases → cash outflow (negative)
        # Skip cash items
        cash_classes = {"cash_on_hand", "bank_accounts", "demand_deposits"}
        for cls in set(list(ca_curr.keys()) + list(ca_prior.keys())):
            if cls in cash_classes:
                continue
            curr_val = ca_curr.get(cls, 0)
            prior_val = ca_prior.get(cls, 0)
            delta = curr_val - prior_val
            if delta != 0:
                tax = ACCOUNT_TAXONOMY.get(cls, {})
                label = tax.get("ar_label", cls)
                changes[f"تغير {label}"] = -delta  # Asset increase = cash decrease

        # Liability increases → cash inflow (positive)
        for cls in set(list(cl_curr.keys()) + list(cl_prior.keys())):
            curr_val = cl_curr.get(cls, 0)
            prior_val = cl_prior.get(cls, 0)
            delta = curr_val - prior_val
            if delta != 0:
                tax = ACCOUNT_TAXONOMY.get(cls, {})
                label = tax.get("ar_label", cls)
                changes[f"تغير {label}"] = delta  # Liability increase = cash increase

        return changes

    def _estimate_wc_from_current(self, balance: dict) -> dict:
        """Show current WC balances for reference (not as changes)."""
        result = {}
        ca = balance.get("current_assets", {}).get("detail", {})
        cash_classes = {"cash_on_hand", "bank_accounts", "demand_deposits"}
        for cls, val in ca.items():
            if cls in cash_classes or val == 0:
                continue
            tax = ACCOUNT_TAXONOMY.get(cls, {})
            result[f"رصيد {tax.get('ar_label', cls)}"] = val
        return result

    def _calculate_investing(self, current: dict, prior: dict, income: dict) -> dict:
        """Calculate investing activities."""
        investing = {}

        nca_curr = current.get("non_current_assets", {}).get("detail", {})
        nca_prior = prior.get("non_current_assets", {}).get("detail", {})

        # PPE changes (gross, before depreciation)
        ppe_classes = {
            "land",
            "buildings",
            "machinery",
            "vehicles",
            "furniture",
            "computers",
            "leasehold_improvements",
            "rou_assets",
            "intangible_assets",
            "projects_under_construction",
        }
        {k for k in ACCOUNT_TAXONOMY if k.startswith("accum_depr")}

        for cls in ppe_classes:
            curr_val = nca_curr.get(cls, 0)
            prior_val = nca_prior.get(cls, 0)
            delta = curr_val - prior_val
            if delta != 0:
                tax = ACCOUNT_TAXONOMY.get(cls, {})
                label = tax.get("ar_label", cls)
                investing[f"{'شراء' if delta > 0 else 'بيع'} {label}"] = -delta

        # Investment changes
        for cls in ("long_term_investments", "short_term_investments"):
            curr_val = (
                nca_curr.get(cls, 0)
                if cls in nca_curr
                else current.get("current_assets", {}).get("detail", {}).get(cls, 0)
            )
            prior_val = (
                nca_prior.get(cls, 0)
                if cls in nca_prior
                else prior.get("current_assets", {}).get("detail", {}).get(cls, 0)
            )
            delta = curr_val - prior_val
            if delta != 0:
                investing[f"تغير استثمارات"] = -delta

        return investing

    def _calculate_financing(self, current: dict, prior: dict) -> dict:
        """Calculate financing activities."""
        financing = {}

        # Loan changes
        loan_classes = {
            "current_loans": "قروض قصيرة الأجل",
            "current_portion_ltl": "الجزء المتداول من قروض طويلة",
            "long_term_loans": "قروض طويلة الأجل",
            "overdraft": "تسهيلات بنكية",
            "murabaha_financing": "تمويل مرابحة",
            "non_current_lease_liabilities": "التزامات إيجارية",
        }

        for cls, label in loan_classes.items():
            curr_val = self._get_from_balance(current, cls)
            prior_val = self._get_from_balance(prior, cls)
            delta = curr_val - prior_val
            if delta != 0:
                financing[f"{'حصول على' if delta > 0 else 'سداد'} {label}"] = delta

        # Equity changes (capital injections/distributions)
        eq_curr = current.get("equity", {}).get("detail", {})
        eq_prior = prior.get("equity", {}).get("detail", {})

        for cls in ("share_capital", "partners_current_account"):
            curr_val = eq_curr.get(cls, 0)
            prior_val = eq_prior.get(cls, 0)
            delta = curr_val - prior_val
            if delta != 0:
                tax = ACCOUNT_TAXONOMY.get(cls, {})
                financing[f"تغير {tax.get('ar_label', cls)}"] = delta

        # Drawings/distributions
        drawings_curr = eq_curr.get("drawings", 0)
        drawings_prior = eq_prior.get("drawings", 0)
        delta = drawings_curr - drawings_prior
        if delta != 0:
            financing["مسحوبات / توزيعات"] = -delta

        return financing

    def _sum_ppe(self, balance: dict) -> float:
        """Sum all PPE gross values."""
        nca = balance.get("non_current_assets", {}).get("detail", {})
        ppe_classes = {"land", "buildings", "machinery", "vehicles", "furniture", "computers", "leasehold_improvements"}
        return sum(nca.get(cls, 0) for cls in ppe_classes)

    def _get_from_balance(self, balance: dict, cls: str) -> float:
        """Get a value from either current/non-current liabilities or equity."""
        for section in ("current_liabilities", "non_current_liabilities", "equity"):
            detail = balance.get(section, {}).get("detail", {})
            if cls in detail:
                return detail[cls]
        return 0
