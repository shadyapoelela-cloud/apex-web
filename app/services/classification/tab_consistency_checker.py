"""
APEX Tab Consistency Checker — مراجعة اتساق التبويب المحاسبي
═══════════════════════════════════════════════════════════════

يراجع:
1. اتساق اسم الحساب مع التبويب الفرعي والرئيسي
2. توافق التبويب مع IFRS و SOCPA
3. كشف الحسابات المصنّفة في تبويب غير منطقي
4. اقتراح التصحيحات
5. كشف نظام الجرد (دوري/مستمر)
"""

import re
from typing import List, Dict
from app.core.constants import ACCOUNT_TAXONOMY


class TabConsistencyChecker:
    """
    Reviews the consistency between account names, their assigned tabs,
    and the normalized classification. Detects mismatches and suggests corrections.
    """

    def check(self, classified_rows: list) -> dict:
        """
        Run all consistency checks.

        Returns:
            {
                "inventory_system": "periodic" | "perpetual" | "unknown",
                "consistency_score": 0-100,
                "findings": [...],
                "mismatches": [...],
                "suggestions": [...],
                "ifrs_notes": [...],
                "socpa_notes": [...],
            }
        """
        findings = []
        mismatches = []
        suggestions = []
        ifrs_notes = []
        socpa_notes = []

        # 1. Detect inventory system
        inv_system = self._detect_inventory_system(classified_rows, findings)

        # 2. Check tab-name consistency
        self._check_tab_name_consistency(classified_rows, mismatches, suggestions)

        # 3. Check IFRS compliance
        self._check_ifrs_compliance(classified_rows, ifrs_notes)

        # 4. Check SOCPA compliance
        self._check_socpa_compliance(classified_rows, socpa_notes)

        # 5. Check for common classification errors
        self._check_common_errors(classified_rows, findings, suggestions)

        # 6. Check sign consistency
        self._check_sign_patterns(classified_rows, findings)

        # Calculate consistency score
        total_accounts = len(classified_rows)
        mismatch_count = len(mismatches)
        consistency_score = max(0, 100 - (mismatch_count / max(total_accounts, 1)) * 100 - len(findings) * 2)

        return {
            "inventory_system": inv_system,
            "consistency_score": round(consistency_score, 1),
            "total_checked": total_accounts,
            "mismatches_count": mismatch_count,
            "findings": findings,
            "mismatches": mismatches[:20],  # Limit to 20
            "suggestions": suggestions[:15],
            "ifrs_notes": ifrs_notes,
            "socpa_notes": socpa_notes,
        }

    # ─────────────────────────────────────────────────────────────────────

    def _detect_inventory_system(self, rows: list, findings: list) -> str:
        """
        Detect if the company uses periodic or perpetual inventory system.

        Periodic: has purchases account, no COGS account, inventory is static
        Perpetual: has COGS account, inventory changes with each sale
        """
        has_purchases = False
        has_cogs_direct = False
        has_inventory = False
        inventory_has_movement = False

        for row in rows:
            cls = row.get("normalized_class", "")
            name = row.get("name", "").lower()

            if cls == "purchases":
                has_purchases = True
            if cls == "cogs":
                # Check if it's actual COGS or purchases labeled as COGS
                if "مشتريات" not in name and "purchases" not in name:
                    has_cogs_direct = True
            if cls and "inventory" in cls:
                has_inventory = True
                # Check if inventory has movements
                mov_d = row.get("movement_debit", 0)
                mov_c = row.get("movement_credit", 0)
                if mov_d > 0 or mov_c > 0:
                    inventory_has_movement = True

        if has_purchases and not has_cogs_direct:
            system = "periodic"
            findings.append({
                "code": "PERIODIC_INVENTORY",
                "severity": "INFO",
                "category": "inventory",
                "message": "الشركة تستخدم نظام الجرد الدوري — يتطلب إدخال مخزون آخر المدة يدوياً من الجرد الفعلي",
                "detail": "تم اكتشاف حسابات مشتريات بدون حساب تكلفة بضاعة مباعة مباشر. يجب إدخال رصيد المخزون الفعلي في نهاية الفترة لحساب تكلفة البضاعة المباعة بدقة.",
            })
        elif has_cogs_direct:
            system = "perpetual"
            findings.append({
                "code": "PERPETUAL_INVENTORY",
                "severity": "INFO",
                "category": "inventory",
                "message": "الشركة تستخدم نظام الجرد المستمر",
            })
        else:
            system = "unknown"
            findings.append({
                "code": "UNKNOWN_INVENTORY_SYSTEM",
                "severity": "WARNING",
                "category": "inventory",
                "message": "لم يتم تحديد نظام الجرد — لا توجد حسابات مشتريات أو تكلفة بضاعة مباعة",
            })

        return system

    def _check_tab_name_consistency(self, rows: list, mismatches: list, suggestions: list):
        """Check if account names are consistent with their tab classification."""

        # Keywords that should match specific tabs
        tab_keywords = {
            "أصول متداولة": ["صندوق", "بنك", "نقد", "عملاء", "مدين", "مخزون", "مدفوعة مقدم", "ضريبة مدخلات"],
            "أصول غير متداولة": ["أثاث", "سيارات", "آلات", "مباني", "أراضي", "ديكور", "إهلاك", "حاسب"],
            "التزامات متداولة": ["دائن", "موردين", "مستحق", "ضريبة مخرجات", "رواتب مستحق"],
            "التزامات غير متداولة": ["قرض طويل", "مكافأة نهاية", "إيجار طويل"],
            "حقوق ملكية": ["رأس المال", "احتياطي", "أرباح مبقاة", "جاري الشريك"],
            "إيرادات": ["مبيعات", "إيرادات", "خدمات"],
            "تكلفة مبيعات": ["مشتريات", "تكلفة بضاعة", "مرتجع مشتريات"],
            "مصروفات إدارية": ["رواتب", "إيجار", "كهرباء", "صيانة", "تأمين", "أتعاب", "رسوم حكومية"],
            "مصروفات بيع": ["عمولات", "تسويق", "إعلان", "شحن", "نقل"],
        }

        for row in rows:
            tab = row.get("tab", "")
            name = row.get("name", "").lower()
            cls = row.get("normalized_class", "")

            if not cls or not tab:
                continue

            # Check: is the account name in a logical tab?
            main_tab = tab.split(" - ")[0].strip() if " - " in tab else tab

            # Revenue in expense tab or vice versa
            if cls == "revenue" and "مصروفات" in tab:
                mismatches.append({
                    "account": row.get("name", ""),
                    "current_tab": tab,
                    "classified_as": cls,
                    "issue": "حساب إيرادات مصنّف ضمن المصروفات",
                    "suggestion": "نقل إلى تبويب إيرادات",
                })

            # Expense in revenue tab
            if cls in ("payroll", "rent_expense", "utilities") and "إيرادات" in tab:
                mismatches.append({
                    "account": row.get("name", ""),
                    "current_tab": tab,
                    "classified_as": cls,
                    "issue": "حساب مصروف مصنّف ضمن الإيرادات",
                    "suggestion": "نقل إلى تبويب المصروفات",
                })

            # Asset in liability tab
            tax = ACCOUNT_TAXONOMY.get(cls, {})
            if tax.get("section") == "balance_sheet":
                is_asset = not tax.get("liability") and not tax.get("contra")
                is_liability = tax.get("liability", False)

                if is_asset and "التزامات" in main_tab:
                    mismatches.append({
                        "account": row.get("name", ""),
                        "current_tab": tab,
                        "classified_as": cls,
                        "issue": "حساب أصل مصنّف ضمن الالتزامات",
                        "suggestion": f"نقل إلى أصول {'متداولة' if tax.get('current') else 'غير متداولة'}",
                    })

                if is_liability and "أصول" in main_tab:
                    mismatches.append({
                        "account": row.get("name", ""),
                        "current_tab": tab,
                        "classified_as": cls,
                        "issue": "حساب التزام مصنّف ضمن الأصول",
                        "suggestion": f"نقل إلى التزامات {'متداولة' if tax.get('current') else 'غير متداولة'}",
                    })

    def _check_ifrs_compliance(self, rows: list, notes: list):
        """Check IFRS compliance issues."""

        has_rou = any(r.get("normalized_class") == "rou_assets" for r in rows)
        has_lease_liab = any(r.get("normalized_class") == "non_current_lease_liabilities" for r in rows)
        has_rent = any(r.get("normalized_class") == "rent_expense" for r in rows)

        # IFRS 16: Leases
        if has_rent and not has_rou:
            notes.append({
                "standard": "IFRS 16",
                "issue": "وجود مصروف إيجار بدون أصول حق استخدام — قد يتطلب تطبيق IFRS 16",
                "severity": "INFO",
                "recommendation": "مراجعة عقود الإيجار لتحديد ما يجب رسملته حسب IFRS 16",
            })

        # IFRS 9: ECL
        has_receivables = any(r.get("normalized_class") == "trade_receivables" for r in rows)
        has_allowance = any(r.get("normalized_class") == "allowance_doubtful" for r in rows)
        if has_receivables and not has_allowance:
            notes.append({
                "standard": "IFRS 9",
                "issue": "ذمم مدينة بدون مخصص خسائر ائتمانية متوقعة (ECL)",
                "severity": "WARNING",
                "recommendation": "إنشاء مخصص خسائر ائتمانية متوقعة حسب IFRS 9",
            })

        # IAS 2: Inventory
        has_inventory = any("inventory" in r.get("normalized_class", "") for r in rows)
        if has_inventory:
            notes.append({
                "standard": "IAS 2",
                "issue": "التحقق من طريقة تقييم المخزون (FIFO/المتوسط المرجح)",
                "severity": "INFO",
                "recommendation": "التأكد من استخدام طريقة FIFO أو المتوسط المرجح حسب IAS 2 (LIFO غير مقبول)",
            })

    def _check_socpa_compliance(self, rows: list, notes: list):
        """Check Saudi accounting standards compliance."""

        # Zakat
        has_zakat = any(r.get("normalized_class") == "zakat_tax" for r in rows)
        has_equity = any(r.get("normalized_class") in ("share_capital", "retained_earnings") for r in rows)
        if has_equity and not has_zakat:
            notes.append({
                "standard": "SOCPA / هيئة الزكاة",
                "issue": "لا يوجد حساب زكاة أو ضريبة دخل",
                "severity": "WARNING",
                "recommendation": "التأكد من احتساب الزكاة حسب نظام هيئة الزكاة والضريبة والجمارك",
            })

        # GOSI
        has_payroll = any(r.get("normalized_class") == "payroll" for r in rows)
        has_gosi = any(r.get("normalized_class") == "gosi_expense" for r in rows)
        if has_payroll and not has_gosi:
            notes.append({
                "standard": "نظام التأمينات الاجتماعية",
                "issue": "وجود رواتب بدون تأمينات اجتماعية (GOSI)",
                "severity": "WARNING",
                "recommendation": "التأكد من تسجيل مساهمات التأمينات الاجتماعية",
            })

        # End of Service
        has_eos = any(r.get("normalized_class") == "end_of_service" for r in rows)
        if has_payroll and not has_eos:
            notes.append({
                "standard": "نظام العمل السعودي",
                "issue": "وجود رواتب بدون مخصص مكافأة نهاية الخدمة",
                "severity": "WARNING",
                "recommendation": "التأكد من احتساب مكافأة نهاية الخدمة حسب المادة 84 من نظام العمل",
            })

        # VAT
        has_vat_in = any(r.get("normalized_class") == "vat_receivable" for r in rows)
        has_vat_out = any(r.get("normalized_class") in ("vat_payable", "net_vat_payable") for r in rows)
        if (has_vat_in or has_vat_out) and not (has_vat_in and has_vat_out):
            notes.append({
                "standard": "نظام ضريبة القيمة المضافة",
                "issue": "وجود ضريبة مدخلات أو مخرجات فقط — يجب وجود الاثنين",
                "severity": "INFO",
                "recommendation": "مراجعة تسجيل ضريبة القيمة المضافة (مدخلات + مخرجات)",
            })

    def _check_common_errors(self, rows: list, findings: list, suggestions: list):
        """Check for common classification errors."""

        # Check: purchases classified as COGS
        for row in rows:
            cls = row.get("normalized_class", "")
            name = row.get("name", "").lower()

            # Purchases returns classified as COGS
            if cls == "cogs" and ("مرتجع" in name or "مسموح" in name or "خصم مكتسب" in name):
                findings.append({
                    "code": "COGS_INCLUDES_RETURNS",
                    "severity": "INFO",
                    "category": "classification",
                    "message": f"الحساب '{row.get('name', '')}' مصنّف كتكلفة بضاعة مباعة — تأكد أنه ليس مرتجع مشتريات",
                })

            # Employee advance in expense
            if cls in ("payroll", "admin_expenses") and ("سلفة" in name or "عهدة" in name):
                suggestions.append({
                    "account": row.get("name", ""),
                    "current_class": cls,
                    "suggested_class": "employee_advances",
                    "reason": "السلف والعهد تُسجّل كأصول متداولة وليس مصروفات",
                })

    def _check_sign_patterns(self, rows: list, findings: list):
        """Check for unusual sign patterns that may indicate misclassification."""
        credit_assets = 0
        debit_liabilities = 0

        for row in rows:
            cls = row.get("normalized_class", "")
            if not cls:
                continue
            tax = ACCOUNT_TAXONOMY.get(cls, {})
            net = row.get("net_balance", 0)

            if tax.get("section") == "balance_sheet":
                is_asset = not tax.get("liability") and not tax.get("contra")
                is_liability = tax.get("liability", False)

                if is_asset and net < -1000:
                    credit_assets += 1
                if is_liability and net > 1000:
                    debit_liabilities += 1

        if credit_assets > 3:
            findings.append({
                "code": "MANY_CREDIT_ASSETS",
                "severity": "WARNING",
                "category": "signs",
                "message": f"{credit_assets} حساب أصل برصيد دائن — قد يشير لخطأ في التبويب أو قيد محاسبي",
            })

        if debit_liabilities > 3:
            findings.append({
                "code": "MANY_DEBIT_LIABILITIES",
                "severity": "WARNING",
                "category": "signs",
                "message": f"{debit_liabilities} حساب التزام برصيد مدين — تحقق من التبويب",
            })
