"""
APEX Tab Consistency Checker v2 — مراجعة اتساق التبويب
═══════════════════════════════════════════════════════

فحص عميق لكل حساب:
1. اسم الحساب ↔ التبويب الفرعي ↔ التبويب الرئيسي ↔ التصنيف
2. التوافق مع IAS 1 (current/non-current)
3. التوافق مع تصنيف قوائم (QAWAEM)
4. كشف نظام الجرد + فحص الإشارات + اقتراحات التصحيح
"""

from app.core.constants import ACCOUNT_TAXONOMY

EXPECTED_MAIN_TAB = {
    "cash": "أصول متداولة",
    "bank": "أصول متداولة",
    "trade_receivables": "أصول متداولة",
    "other_receivables": "أصول متداولة",
    "employee_advances": "أصول متداولة",
    "inventory": "أصول متداولة",
    "prepaid_expenses": "أصول متداولة",
    "vat_receivable": "أصول متداولة",
    "land": "أصول غير متداولة",
    "buildings": "أصول غير متداولة",
    "machinery": "أصول غير متداولة",
    "vehicles": "أصول غير متداولة",
    "furniture": "أصول غير متداولة",
    "computers": "أصول غير متداولة",
    "leasehold_improvements": "أصول غير متداولة",
    "rou_assets": "أصول غير متداولة",
    "accum_depr_buildings": "أصول غير متداولة",
    "accum_depr_machinery": "أصول غير متداولة",
    "accum_depr_vehicles": "أصول غير متداولة",
    "accum_depr_furniture": "أصول غير متداولة",
    "accum_depr_computers": "أصول غير متداولة",
    "trade_payables": "التزامات متداولة",
    "other_payables": "التزامات متداولة",
    "accrued_expenses": "التزامات متداولة",
    "wages_payable": "التزامات متداولة",
    "vat_payable": "التزامات متداولة",
    "net_vat_payable": "التزامات متداولة",
    "zakat_payable": "التزامات متداولة",
    "short_term_loans": "التزامات متداولة",
    "unearned_revenue": "التزامات متداولة",
    "long_term_loans": "التزامات غير متداولة",
    "end_of_service": "التزامات غير متداولة",
    "non_current_lease_liabilities": "التزامات غير متداولة",
    "share_capital": "حقوق الملكية",
    "statutory_reserve": "حقوق الملكية",
    "retained_earnings": "حقوق الملكية",
    "partner_current_account": "حقوق الملكية",
    "revenue": "إيرادات",
    "service_revenue": "إيرادات",
    "sales_returns": "إيرادات",
    "cogs": "تكلفة المبيعات",
    "purchases": "تكلفة المبيعات",
    "purchases_returns": "تكلفة المبيعات",
    "payroll": "مصروفات إدارية",
    "rent_expense": "مصروفات إدارية",
    "utilities": "مصروفات إدارية",
    "depreciation_expense": "مصروفات إدارية",
    "professional_fees": "مصروفات إدارية",
    "gosi_expense": "مصروفات إدارية",
    "insurance_expense": "مصروفات إدارية",
    "selling_expenses": "مصروفات بيع",
    "marketing_expense": "مصروفات بيع",
    "commissions": "مصروفات بيع",
    "interest_expense": "تكاليف تمويل",
    "bank_charges": "تكاليف تمويل",
    "zakat_tax": "زكاة وضريبة",
}

TAB_VARIANTS = {
    "أصول متداولة": ["أصول متداولة", "أصول جارية"],
    "أصول غير متداولة": ["أصول غير متداولة", "أصول ثابتة", "ممتلكات"],
    "التزامات متداولة": ["التزامات متداولة", "خصوم متداولة", "التزامات جارية"],
    "التزامات غير متداولة": ["التزامات غير متداولة", "خصوم طويلة", "التزامات طويلة"],
    "حقوق الملكية": ["حقوق الملكية", "حقوق المساهمين", "حقوق الشركاء", "رأس المال", "رأس مال"],
    "إيرادات": ["إيرادات", "مبيعات", "إيراد"],
    "تكلفة المبيعات": ["تكلفة المبيعات", "تكلفة مبيعات", "تكلفة البضاعة", "مشتريات", "تكلفة بضاعة"],
    "مصروفات إدارية": ["مصروفات إدارية", "مصاريف إدارية", "عمومية", "إدارية وعمومية", "مصروفات إدارية وعمومية"],
    "مصروفات بيع": ["مصروفات بيع", "مصاريف بيع", "تسويق", "توزيع", "بيع وتوزيع", "بيع وتسويق"],
    "تكاليف تمويل": ["تكاليف تمويل", "مصروفات تمويل", "تمويلية", "مصاريف تمويل"],
    "زكاة وضريبة": ["زكاة", "ضريبة", "زكاة وضريبة"],
    "إيرادات أخرى": ["إيرادات أخرى", "دخل آخر"],
}


class TabConsistencyChecker:
    def check(self, classified_rows: list) -> dict:
        findings, mismatches, suggestions, ifrs_notes, socpa_notes = [], [], [], [], []
        inv_system = self._detect_inventory(classified_rows, findings)
        self._check_consistency(classified_rows, mismatches, suggestions)
        self._check_ifrs(classified_rows, ifrs_notes)
        self._check_socpa(classified_rows, socpa_notes)
        self._check_signs(classified_rows, findings)
        crit = len([m for m in mismatches if m.get("severity") == "error"])
        warn = len([m for m in mismatches if m.get("severity") == "warning"])
        score = max(0, 100 - crit * 5 - warn * 2 - len(findings))
        return {
            "inventory_system": inv_system,
            "consistency_score": round(score, 1),
            "total_checked": len(classified_rows),
            "mismatches_count": len(mismatches),
            "critical_mismatches": crit,
            "findings": findings,
            "mismatches": mismatches[:30],
            "suggestions": suggestions[:20],
            "ifrs_notes": ifrs_notes,
            "socpa_notes": socpa_notes,
        }

    def _detect_inventory(self, rows, findings):
        has_purch = any(r.get("normalized_class") == "purchases" for r in rows)
        has_cogs = any(r.get("normalized_class") == "cogs" and "مشتريات" not in r.get("name", "").lower() for r in rows)
        if has_purch and not has_cogs:
            findings.append(
                {
                    "code": "PERIODIC",
                    "severity": "INFO",
                    "category": "inventory",
                    "message": "نظام جرد دوري — يتطلب إدخال مخزون آخر المدة الفعلي",
                    "reference": "IAS 2 — الفقرة 34",
                    "authority": "SOCPA/IFRS",
                }
            )
            return "periodic"
        if has_cogs:
            findings.append(
                {"code": "PERPETUAL", "severity": "INFO", "category": "inventory", "message": "نظام جرد مستمر"}
            )
            return "perpetual"
        return "unknown"

    def _tabs_match(self, actual, expected):
        if expected in actual:
            return True
        for v in TAB_VARIANTS.get(expected, [expected]):
            if v in actual:
                return True
        return False

    def _check_consistency(self, rows, mismatches, suggestions):
        for row in rows:
            name, tab, cls = row.get("name", ""), row.get("tab", ""), row.get("normalized_class", "")
            if not cls or not tab:
                continue
            main_tab = tab.split(" - ")[0].strip() if " - " in tab else tab
            expected = EXPECTED_MAIN_TAB.get(cls)
            if expected and not self._tabs_match(main_tab, expected):
                sev = (
                    "error"
                    if cls
                    in ("cash", "bank", "trade_receivables", "inventory", "trade_payables", "share_capital", "revenue")
                    else "warning"
                )
                mismatches.append(
                    {
                        "account": name,
                        "current_tab": main_tab,
                        "expected_tab": expected,
                        "classified_as": cls,
                        "severity": sev,
                        "issue_ar": f"'{name}' ({cls}) يجب أن يكون في '{expected}' لكنه في '{main_tab}'",
                        "reference": "IAS 1 — تصنيف متداول/غير متداول",
                        "authority": "SOCPA/IFRS",
                    }
                )
            tax = ACCOUNT_TAXONOMY.get(cls, {})
            if tax.get("section") == "balance_sheet":
                is_asset = not tax.get("liability") and not tax.get("contra")
                if is_asset and "التزامات" in main_tab:
                    mismatches.append(
                        {
                            "account": name,
                            "severity": "error",
                            "issue_ar": f"أصل '{name}' مبوّب في الالتزامات",
                            "reference": "IAS 1",
                            "authority": "SOCPA/IFRS",
                        }
                    )
                if tax.get("liability") and "أصول" in main_tab and "إهلاك" not in name.lower():
                    mismatches.append(
                        {
                            "account": name,
                            "severity": "error",
                            "issue_ar": f"التزام '{name}' مبوّب في الأصول",
                            "reference": "IAS 1",
                            "authority": "SOCPA/IFRS",
                        }
                    )
            if cls in ("payroll", "admin_expenses") and ("سلفة" in name.lower() or "عهدة" in name.lower()):
                suggestions.append(
                    {"account": name, "current_class": cls, "suggested": "أصل متداول (سلف وعهد)", "reference": "IAS 1"}
                )

    def _check_ifrs(self, rows, notes):
        has = lambda c: any(c in (r.get("normalized_class") or "") for r in rows)
        if has("trade_receivables") and not has("allowance_doubtful"):
            notes.append(
                {
                    "standard": "IFRS 9",
                    "severity": "WARNING",
                    "issue": "ذمم مدينة بدون مخصص ECL",
                    "recommendation": "مصفوفة المخصص المبسّطة",
                    "reference": "IFRS 9 — 5.5.15",
                }
            )
        if has("rent_expense") and not has("rou_assets"):
            notes.append(
                {
                    "standard": "IFRS 16",
                    "severity": "INFO",
                    "issue": "مصروف إيجار بدون أصل حق استخدام",
                    "recommendation": "مراجعة عقود الإيجار > 12 شهراً",
                    "reference": "IFRS 16 — الفقرة 9",
                }
            )
        if (has("machinery") or has("vehicles") or has("furniture")) and not has("accum_depr"):
            notes.append(
                {
                    "standard": "IAS 16",
                    "severity": "WARNING",
                    "issue": "أصول ثابتة بدون إهلاك",
                    "reference": "IAS 16 — 43-62",
                }
            )
        if has("inventory"):
            notes.append(
                {
                    "standard": "IAS 2",
                    "severity": "INFO",
                    "issue": "تحقق من طريقة تقييم المخزون (FIFO/متوسط مرجح — LIFO محظور)",
                    "reference": "IAS 2 — 25",
                }
            )

    def _check_socpa(self, rows, notes):
        has = lambda c: any(r.get("normalized_class") == c for r in rows)
        has_any = lambda cs: any(r.get("normalized_class") in cs for r in rows)
        if has("payroll") and not has("gosi_expense"):
            notes.append(
                {
                    "standard": "GOSI",
                    "severity": "WARNING",
                    "issue": "رواتب بدون GOSI",
                    "recommendation": "12.5% سعوديين + 2% أجانب",
                }
            )
        if has("payroll") and not has("end_of_service"):
            notes.append(
                {"standard": "نظام العمل م84 + IAS 19", "severity": "WARNING", "issue": "رواتب بدون مخصص نهاية خدمة"}
            )
        if has_any(["share_capital", "retained_earnings"]) and not has("zakat_tax"):
            notes.append({"standard": "ZATCA", "severity": "WARNING", "issue": "لا يوجد زكاة أو ضريبة"})
        if not has("statutory_reserve") and has_any(["share_capital", "retained_earnings"]):
            notes.append({"standard": "نظام الشركات م158", "severity": "INFO", "issue": "لا يوجد احتياطي نظامي"})

    def _check_signs(self, rows, findings):
        bad_assets, bad_liab = 0, 0
        for row in rows:
            cls = row.get("normalized_class", "")
            if not cls:
                continue
            tax = ACCOUNT_TAXONOMY.get(cls, {})
            net = row.get("net_balance", 0)
            if tax.get("section") == "balance_sheet":
                if not tax.get("liability") and not tax.get("contra") and net < -5000:
                    bad_assets += 1
                if tax.get("liability") and net > 5000:
                    bad_liab += 1
        if bad_assets > 3:
            findings.append(
                {
                    "code": "CREDIT_ASSETS",
                    "severity": "WARNING",
                    "message": f"{bad_assets} أصل برصيد دائن — خطأ محتمل في التبويب",
                    "reference": "IAS 1",
                }
            )
        if bad_liab > 3:
            findings.append(
                {
                    "code": "DEBIT_LIABILITIES",
                    "severity": "WARNING",
                    "message": f"{bad_liab} التزام برصيد مدين",
                    "reference": "IAS 1",
                }
            )
