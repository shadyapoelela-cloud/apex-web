"""
APEX Validation Engine — محرك التحقق والضبط
═════════════════════════════════════════════════

يتحقق من:
- معادلة التوازن (أصول = التزامات + حقوق ملكية)
- اتساق الإشارات
- الحسابات غير المصنّفة
- القيم الشاذة
- سلامة المقامات
"""


class ValidationEngine:

    def validate(
        self,
        classified_rows: list,
        income: dict,
        balance: dict,
        classification_summary: dict,
    ) -> list:
        """
        Run all validations and return list of findings.
        Each finding: { code, severity, message, details }
        severity: ERROR | WARNING | INFO
        """
        findings = []

        self._check_balance_equation(balance, findings)
        self._check_unmapped_accounts(classification_summary, findings)
        self._check_negative_anomalies(income, balance, findings)
        self._check_sign_consistency(classified_rows, findings)
        self._check_duplicate_mapping(classified_rows, findings)
        self._check_profit_consistency(income, balance, findings)
        self._check_data_completeness(income, balance, findings)

        return findings

    def _check_balance_equation(self, balance: dict, findings: list):
        """Assets = Liabilities + Equity"""
        bs = balance
        total_assets = bs.get("total_assets", 0)
        total_le = bs.get("total_liabilities_and_equity", 0)
        diff = abs(total_assets - total_le)

        if diff > 100:
            findings.append(
                {
                    "code": "BALANCE_MISMATCH",
                    "severity": "ERROR",
                    "message": f"الميزانية غير متوازنة: أصول ({total_assets:,.0f}) ≠ التزامات + حقوق ملكية ({total_le:,.0f})",
                    "details": {"assets": total_assets, "liabilities_equity": total_le, "difference": round(diff, 2)},
                }
            )
        elif diff > 1:
            findings.append(
                {
                    "code": "BALANCE_ROUNDING",
                    "severity": "INFO",
                    "message": f"فرق تقريب في التوازن: {diff:,.2f}",
                }
            )

    def _check_unmapped_accounts(self, cls_summary: dict, findings: list):
        """Check for unmapped accounts."""
        unmapped = cls_summary.get("unmapped_accounts_count", 0)
        total = cls_summary.get("total_accounts", 1)
        pct = unmapped / total * 100 if total else 0

        if unmapped > 0:
            severity = "ERROR" if pct > 20 else "WARNING" if pct > 5 else "INFO"
            findings.append(
                {
                    "code": "UNMAPPED_ACCOUNTS",
                    "severity": severity,
                    "message": f"{unmapped} حساب غير مصنّف من أصل {total} ({pct:.1f}%)",
                    "details": {
                        "unmapped_count": unmapped,
                        "total": total,
                        "percentage": round(pct, 1),
                        "accounts": cls_summary.get("unmapped_accounts", [])[:10],
                    },
                }
            )

    def _check_negative_anomalies(self, income: dict, balance: dict, findings: list):
        """Check for unexpected negative values."""
        # Revenue should be positive
        if income.get("net_revenue", 0) < 0:
            findings.append(
                {
                    "code": "NEGATIVE_REVENUE",
                    "severity": "WARNING",
                    "message": f"صافي الإيرادات سالب ({income['net_revenue']:,.0f}) — تحقق من تبويب الإيرادات والمرتجعات",
                }
            )

        # Total assets should be positive
        bs = balance
        if bs.get("total_assets", 0) < 0:
            findings.append(
                {
                    "code": "NEGATIVE_ASSETS",
                    "severity": "ERROR",
                    "message": "إجمالي الأصول سالب — خطأ جوهري في البيانات أو التبويب",
                }
            )

        # Inventory should not be negative
        inv = bs.get("current_assets", {}).get("detail", {})
        for k, v in inv.items():
            if "inventory" in k and v < 0:
                findings.append(
                    {
                        "code": "NEGATIVE_INVENTORY",
                        "severity": "WARNING",
                        "message": f"المخزون سالب ({v:,.0f}) — تحقق من بيانات المخزون",
                    }
                )

        # Equity check
        equity = bs.get("equity", {}).get("total", 0)
        if equity < 0:
            findings.append(
                {
                    "code": "NEGATIVE_EQUITY",
                    "severity": "WARNING",
                    "message": f"حقوق الملكية سالبة ({equity:,.0f}) — خسائر متراكمة تجاوزت رأس المال",
                }
            )

    def _check_sign_consistency(self, classified_rows: list, findings: list):
        """Check that debit/credit signs match expected patterns."""
        sign_issues = 0
        for row in classified_rows:
            cls = row.get("normalized_class")
            if not cls:
                continue
            from app.core.constants import ACCOUNT_TAXONOMY

            tax = ACCOUNT_TAXONOMY.get(cls, {})
            expected_sign = tax.get("sign", "debit_normal")
            net = row.get("net_balance", 0)

            # credit_normal accounts should have negative net_balance (before we negate)
            if expected_sign == "credit_normal" and net > 0:
                sign_issues += 1
            elif expected_sign == "debit_normal" and net < 0:
                # Some debit accounts legitimately go negative (contra, adjustments)
                if not tax.get("contra"):
                    sign_issues += 1

        if sign_issues > 5:
            findings.append(
                {
                    "code": "SIGN_INCONSISTENCY",
                    "severity": "WARNING",
                    "message": f"{sign_issues} حساب بإشارة معاكسة للمتوقع — قد يكون طبيعياً لبعض الحسابات أو يشير لخطأ في التبويب",
                    "details": {"count": sign_issues},
                }
            )

    def _check_duplicate_mapping(self, classified_rows: list, findings: list):
        """Check for same account appearing in multiple classifications."""
        seen = {}
        for row in classified_rows:
            name = row.get("name", "").strip()
            cls = row.get("normalized_class")
            if not name or not cls:
                continue
            if name in seen and seen[name] != cls:
                findings.append(
                    {
                        "code": "DUPLICATE_DIFFERENT_CLASS",
                        "severity": "WARNING",
                        "message": f"الحساب '{name}' مصنّف في أكثر من فئة: {seen[name]} و {cls}",
                    }
                )
            seen[name] = cls

    def _check_profit_consistency(self, income: dict, balance: dict, findings: list):
        """Check that net profit in IS matches equity."""
        is_profit = income.get("net_profit", 0)
        eq_detail = balance.get("equity", {}).get("detail", {})
        eq_profit = eq_detail.get("current_year_profit", eq_detail.get("current_year_profit_derived", 0))

        if eq_profit != 0 and abs(is_profit - eq_profit) > 100:
            findings.append(
                {
                    "code": "PROFIT_MISMATCH",
                    "severity": "WARNING",
                    "message": f"صافي الربح في قائمة الدخل ({is_profit:,.0f}) لا يطابق أرباح السنة في حقوق الملكية ({eq_profit:,.0f})",
                }
            )

    def _check_data_completeness(self, income: dict, balance: dict, findings: list):
        """Check if key financial data is missing."""
        if income.get("net_revenue", 0) == 0:
            findings.append(
                {
                    "code": "MISSING_REVENUE",
                    "severity": "WARNING",
                    "message": "لا توجد إيرادات — تحقق من تبويب حسابات الإيرادات",
                }
            )

        if balance.get("total_assets", 0) == 0:
            findings.append(
                {
                    "code": "MISSING_ASSETS",
                    "severity": "ERROR",
                    "message": "لا توجد أصول — تحقق من تبويب حسابات الأصول",
                }
            )

        ca = balance.get("current_assets", {}).get("total", 0)
        cl = balance.get("current_liabilities", {}).get("total", 0)
        if ca == 0 and cl == 0:
            findings.append(
                {
                    "code": "MISSING_CURRENT_SECTION",
                    "severity": "WARNING",
                    "message": "لا توجد أصول أو التزامات متداولة — لن يمكن حساب نسب السيولة",
                }
            )

    def get_severity_counts(self, findings: list) -> dict:
        """Get count of each severity level."""
        counts = {"ERROR": 0, "WARNING": 0, "INFO": 0}
        for f in findings:
            sev = f.get("severity", "INFO")
            counts[sev] = counts.get(sev, 0) + 1
        return counts

    def can_approve(self, findings: list) -> bool:
        """Can the report be approved (no ERRORs)?"""
        return all(f.get("severity") != "ERROR" for f in findings)
