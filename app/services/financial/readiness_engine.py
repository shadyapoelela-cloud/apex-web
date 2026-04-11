"""
APEX Readiness Engine v2 — محرك الجاهزية التمويلية/الاستثمارية
═══════════════════════════════════════════════════════════════════

يحسب درجة الجاهزية من 100 بناءً على:
  - الربحية (20%)
  - السيولة (15%)
  - المديونية (15%)
  - الكفاءة (10%)
  - جودة الأرباح (10%)
  - جودة البيانات واكتمالها (15%)
  - التوازن المحاسبي والتحققات (10%)
  - استقرار الاتجاهات (5%)

كل مكوّن يخرج: score + max + weight + details
"""

from app.core.constants import INDUSTRY_BENCHMARKS


class ReadinessEngine:

    def calculate(
        self,
        income: dict,
        balance: dict,
        ratios: dict,
        validations: list,
        confidence: dict,
        industry: str = "general",
    ) -> dict:
        """
        Calculate readiness score with full breakdown.
        """
        benchmarks = INDUSTRY_BENCHMARKS.get(industry, INDUSTRY_BENCHMARKS["general"])
        components = []
        negative_drivers = []

        # ═══ 1. Profitability (20%) ═══
        prof_score = self._score_profitability(income, ratios, benchmarks, negative_drivers)
        components.append(
            {
                "name": "الربحية",
                "name_en": "Profitability",
                "score": prof_score,
                "max_score": 20,
                "weight": 0.20,
            }
        )

        # ═══ 2. Liquidity (15%) ═══
        liq_score = self._score_liquidity(ratios, benchmarks, negative_drivers)
        components.append(
            {
                "name": "السيولة",
                "name_en": "Liquidity",
                "score": liq_score,
                "max_score": 15,
                "weight": 0.15,
            }
        )

        # ═══ 3. Leverage (15%) ═══
        lev_score = self._score_leverage(ratios, benchmarks, negative_drivers)
        components.append(
            {
                "name": "المديونية",
                "name_en": "Leverage",
                "score": lev_score,
                "max_score": 15,
                "weight": 0.15,
            }
        )

        # ═══ 4. Efficiency (10%) ═══
        eff_score = self._score_efficiency(ratios, benchmarks, negative_drivers)
        components.append(
            {
                "name": "الكفاءة التشغيلية",
                "name_en": "Efficiency",
                "score": eff_score,
                "max_score": 10,
                "weight": 0.10,
            }
        )

        # ═══ 5. Earnings Quality (10%) ═══
        eq_score = self._score_earnings_quality(income, balance, negative_drivers)
        components.append(
            {
                "name": "جودة الأرباح",
                "name_en": "Earnings Quality",
                "score": eq_score,
                "max_score": 10,
                "weight": 0.10,
            }
        )

        # ═══ 6. Data Completeness (15%) ═══
        data_score = self._score_data_completeness(confidence, negative_drivers)
        components.append(
            {
                "name": "اكتمال البيانات",
                "name_en": "Data Completeness",
                "score": data_score,
                "max_score": 15,
                "weight": 0.15,
            }
        )

        # ═══ 7. Accounting Integrity (10%) ═══
        integ_score = self._score_integrity(validations, negative_drivers)
        components.append(
            {
                "name": "سلامة التوازن المحاسبي",
                "name_en": "Accounting Integrity",
                "score": integ_score,
                "max_score": 10,
                "weight": 0.10,
            }
        )

        # ═══ 8. Trend Stability (5%) ═══
        # Without multi-period data, give neutral score
        trend_score = 3  # Neutral — needs multi-period
        components.append(
            {
                "name": "استقرار الاتجاهات",
                "name_en": "Trend Stability",
                "score": trend_score,
                "max_score": 5,
                "weight": 0.05,
                "note": "يحتاج بيانات أكثر من فترة للحساب الدقيق",
            }
        )

        # ═══ Final Score ═══
        final_score = sum(c["score"] for c in components)
        final_score = min(100, max(0, final_score))

        if final_score >= 85:
            label = "Strong / Bankable"
            label_ar = "قوي — جاهز للتمويل"
        elif final_score >= 70:
            label = "Good with Conditions"
            label_ar = "جيد — بشروط"
        elif final_score >= 55:
            label = "Needs Strengthening"
            label_ar = "يحتاج تعزيز"
        else:
            label = "High Risk / Insufficient"
            label_ar = "مخاطر عالية — غير جاهز"

        return {
            "readiness": {
                "score": round(final_score, 1),
                "label": label,
                "label_ar": label_ar,
                "components": components,
                "negative_drivers": negative_drivers,
                "industry": industry,
            }
        }

    # ─── Component Scorers ───

    def _score_profitability(self, income, ratios, benchmarks, neg_drivers) -> float:
        """Score profitability out of 20."""
        score = 0
        prof = ratios.get("profitability", {})

        # Net margin (8 points)
        nm = prof.get("net_margin_pct")
        bench_nm = benchmarks.get("net_margin", 8)
        if nm is not None:
            if nm >= bench_nm:
                score += 8
            elif nm >= bench_nm * 0.5:
                score += 5
            elif nm > 0:
                score += 3
            else:
                neg_drivers.append("صافي الربح سالب — خسارة")
        else:
            score += 2  # No data → partial

        # Gross margin (6 points)
        gm = prof.get("gross_margin_pct")
        bench_gm = benchmarks.get("gross_margin", 35)
        if gm is not None:
            if gm >= bench_gm:
                score += 6
            elif gm >= bench_gm * 0.7:
                score += 4
            elif gm > 0:
                score += 2
            else:
                neg_drivers.append("هامش الربح الإجمالي سالب")

        # ROE (3 points)
        roe = prof.get("roe_pct")
        if roe is not None:
            if roe >= benchmarks.get("roe", 12):
                score += 3
            elif roe > 0:
                score += 1.5
            else:
                neg_drivers.append("العائد على حقوق الملكية سالب")

        # ROA (3 points)
        roa = prof.get("roa_pct")
        if roa is not None:
            if roa >= benchmarks.get("roa", 6):
                score += 3
            elif roa > 0:
                score += 1.5

        return min(20, score)

    def _score_liquidity(self, ratios, benchmarks, neg_drivers) -> float:
        """Score liquidity out of 15."""
        score = 0
        liq = ratios.get("liquidity", {})

        # Current ratio (7 points)
        cr = liq.get("current_ratio")
        if cr is not None:
            if cr >= benchmarks.get("current_ratio", 1.5):
                score += 7
            elif cr >= 1.0:
                score += 5
            elif cr >= 0.5:
                score += 2
                neg_drivers.append(f"نسبة التداول ضعيفة ({cr})")
            else:
                neg_drivers.append(f"نسبة التداول خطيرة ({cr})")

        # Quick ratio (4 points)
        qr = liq.get("quick_ratio")
        if qr is not None:
            if qr >= benchmarks.get("quick_ratio", 1.0):
                score += 4
            elif qr >= 0.5:
                score += 2

        # Working capital (4 points)
        wc = liq.get("working_capital", 0)
        if wc > 0:
            score += 4
        elif wc == 0:
            score += 1
        else:
            neg_drivers.append("رأس المال العامل سالب")

        return min(15, score)

    def _score_leverage(self, ratios, benchmarks, neg_drivers) -> float:
        """Score leverage out of 15."""
        score = 0
        lev = ratios.get("leverage", {})

        # Debt to equity (7 points)
        de = lev.get("debt_to_equity")
        bench_de = benchmarks.get("debt_to_equity", 1.0)
        if de is not None:
            if de <= bench_de:
                score += 7
            elif de <= bench_de * 1.5:
                score += 4
            elif de <= bench_de * 2.5:
                score += 2
                neg_drivers.append(f"نسبة الدين لحقوق الملكية مرتفعة ({de})")
            else:
                neg_drivers.append(f"نسبة الدين لحقوق الملكية خطيرة ({de})")

        # Debt to assets (4 points)
        da = lev.get("debt_to_assets_pct")
        if da is not None:
            if da <= 50:
                score += 4
            elif da <= 70:
                score += 2
            else:
                neg_drivers.append(f"نسبة الدين للأصول مرتفعة ({da}%)")

        # Interest coverage (4 points)
        ic = lev.get("interest_coverage")
        if ic is not None:
            bench_ic = benchmarks.get("interest_coverage", 3)
            if ic >= bench_ic:
                score += 4
            elif ic >= 1.5:
                score += 2
            else:
                neg_drivers.append(f"تغطية الفوائد ضعيفة ({ic})")
        else:
            score += 2  # No finance cost → not penalized

        return min(15, score)

    def _score_efficiency(self, ratios, benchmarks, neg_drivers) -> float:
        """Score efficiency out of 10."""
        score = 0
        eff = ratios.get("efficiency", {})

        # Asset turnover (4 points)
        at = eff.get("asset_turnover")
        if at is not None:
            if at >= benchmarks.get("asset_turnover", 1.0):
                score += 4
            elif at >= 0.5:
                score += 2

        # Inventory days (3 points)
        inv_days = eff.get("days_in_inventory")
        if inv_days is not None:
            bench_days = benchmarks.get("inventory_days", 60)
            if inv_days <= bench_days:
                score += 3
            elif inv_days <= bench_days * 1.5:
                score += 1.5
            else:
                neg_drivers.append(f"أيام المخزون مرتفعة ({inv_days} يوم)")

        # DSO (3 points)
        dso = eff.get("dso")
        if dso is not None:
            bench_dso = benchmarks.get("dso", 45)
            if dso <= bench_dso:
                score += 3
            elif dso <= bench_dso * 1.5:
                score += 1.5
            else:
                neg_drivers.append(f"أيام التحصيل مرتفعة ({dso} يوم)")

        return min(10, score)

    def _score_earnings_quality(self, income, balance, neg_drivers) -> float:
        """Score earnings quality out of 10."""
        score = 0
        net_profit = income.get("net_profit", 0)
        net_rev = income.get("net_revenue", 0)
        op_profit = income.get("operating_profit", 0)

        # Is profit from operations (not one-time)? (5 points)
        if net_rev > 0 and op_profit > 0:
            op_ratio = op_profit / net_rev if net_rev else 0
            if op_ratio > 0.05:
                score += 5
            elif op_ratio > 0:
                score += 3
        elif net_profit > 0:
            score += 2
            neg_drivers.append("الربح ليس من العمليات التشغيلية")

        # Revenue base (3 points)
        if net_rev > 0:
            score += 3
        else:
            neg_drivers.append("لا توجد إيرادات تشغيلية")

        # Balance sheet health (2 points)
        equity = balance.get("equity", {}).get("total", 0)
        if equity > 0:
            score += 2
        else:
            neg_drivers.append("حقوق الملكية سالبة — خطورة عالية")

        return min(10, score)

    def _score_data_completeness(self, confidence, neg_drivers) -> float:
        """Score data completeness out of 15."""
        score = 0
        mapping = confidence.get("mapping", 0)
        completeness = confidence.get("completeness", 0)

        # Mapping quality (8 points)
        score += mapping * 8

        # Data completeness (7 points)
        score += completeness * 7

        if mapping < 0.70:
            neg_drivers.append(f"جودة تصنيف الحسابات منخفضة ({mapping*100:.0f}%)")
        if completeness < 0.70:
            neg_drivers.append("بيانات ناقصة — يؤثر على موثوقية التحليل")

        return min(15, round(score, 1))

    def _score_integrity(self, validations, neg_drivers) -> float:
        """Score accounting integrity out of 10."""
        errors = sum(1 for v in validations if v.get("severity") == "ERROR")
        warnings = sum(1 for v in validations if v.get("severity") == "WARNING")

        if errors == 0 and warnings == 0:
            return 10
        elif errors == 0 and warnings <= 2:
            return 8
        elif errors == 0:
            return 6
        elif errors == 1:
            neg_drivers.append("يوجد خطأ محاسبي واحد على الأقل")
            return 3
        else:
            neg_drivers.append(f"يوجد {errors} أخطاء محاسبية")
            return 0
