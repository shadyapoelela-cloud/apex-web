"""
ملحق ف — Report Card
تقرير بلغة تجارية للعميل بالعربي: درجة، نقاط قوة/ضعف، إجراءات أولوية، مقارنة قطاعية.
"""
from typing import Dict, List, Optional, Any


def _headline(score: float) -> str:
    if score >= 90:
        return "شجرتك ممتازة وجاهزة للاعتماد"
    if score >= 80:
        return "شجرتك جيدة وتحتاج تعديلات بسيطة"
    if score >= 70:
        return "شجرتك مقبولة وتحتاج مراجعة قبل الاعتماد"
    if score >= 65:
        return "شجرتك تحتاج إصلاحات جوهرية قبل الاستخدام"
    return "شجرتك تحتاج إعادة هيكلة شاملة"


def _grade(score: float) -> str:
    if score >= 90:
        return "A"
    if score >= 80:
        return "B"
    if score >= 70:
        return "C"
    if score >= 65:
        return "D"
    return "F"


def _extract_strengths(result: Dict) -> List[str]:
    """استخراج نقاط القوة من نتيجة التحليل."""
    strengths: List[str] = []
    dims = result.get("quality_dimensions") or {}
    total = result.get("total_accounts", 0)
    confidence_avg = result.get("confidence_avg", 0)
    errors_summary = result.get("errors_summary") or {}

    if dims.get("classification_accuracy", 0) >= 80:
        strengths.append("دقة تصنيف عالية — معظم الحسابات صُنِّفت تلقائياً بثقة")
    if dims.get("completeness", 0) >= 90:
        strengths.append("اكتمال ممتاز — كل الحسابات لها كود واسم")
    if dims.get("naming_quality", 0) >= 80:
        strengths.append("أسماء الحسابات واضحة ووصفية")
    if dims.get("code_consistency", 0) >= 70:
        strengths.append("هيكل الأكواد متسق ومنتظم")
    if errors_summary.get("critical", 0) == 0:
        strengths.append("لا توجد أخطاء حرجة — الشجرة آمنة للاستخدام")
    if total >= 100:
        strengths.append(f"شجرة شاملة تحتوي {total} حساب")
    if confidence_avg >= 0.85:
        strengths.append(f"متوسط ثقة التصنيف مرتفع ({confidence_avg:.0%})")

    return strengths if strengths else ["لا توجد نقاط قوة بارزة — يُنصح بمراجعة شاملة"]


def _extract_weaknesses(result: Dict) -> List[str]:
    """استخراج نقاط الضعف."""
    weaknesses: List[str] = []
    dims = result.get("quality_dimensions") or {}
    errors_summary = result.get("errors_summary") or {}

    critical = errors_summary.get("critical", 0)
    high = errors_summary.get("high", 0)
    medium = errors_summary.get("medium", 0)

    if critical > 0:
        weaknesses.append(f"{critical} خطأ حرج يمنع الاعتماد")
    if high > 0:
        weaknesses.append(f"{high} خطأ مهم يحتاج إصلاح")
    if dims.get("classification_accuracy", 0) < 70:
        weaknesses.append("دقة التصنيف منخفضة — حسابات كثيرة بدون تصنيف واثق")
    if dims.get("completeness", 0) < 80:
        weaknesses.append("اكتمال البيانات ناقص — بعض الحسابات بدون كود أو اسم")
    if dims.get("naming_quality", 0) < 60:
        weaknesses.append("أسماء بعض الحسابات قصيرة أو غامضة")
    if dims.get("code_consistency", 0) < 50:
        weaknesses.append("هيكل الأكواد غير متسق — لا توجد هرمية واضحة")

    return weaknesses if weaknesses else ["لا توجد نقاط ضعف جوهرية"]


def _build_priority_actions(result: Dict) -> List[Dict]:
    """بناء قائمة إجراءات مرتبة بالأثر."""
    actions: List[Dict] = []
    errors_summary = result.get("errors_summary") or {}
    errors = result.get("errors") or []
    dims = result.get("quality_dimensions") or {}
    recommendations = result.get("recommendations") or []

    critical = errors_summary.get("critical", 0)
    high = errors_summary.get("high", 0)

    if critical > 0:
        actions.append({
            "action": f"أصلح {critical} خطأ حرج (تكرار أكواد، تصنيف خاطئ)",
            "impact": f"+{min(critical * 5, 20)} نقاط",
            "effort": "متوسط",
        })

    if high > 0:
        actions.append({
            "action": f"أصلح {high} خطأ مهم (هرمية، طبيعة الرصيد)",
            "impact": f"+{min(high * 2, 10)} نقاط",
            "effort": "متوسط",
        })

    # Depreciation gap
    depr_errors = [e for e in errors if isinstance(e, dict) and "إهلاك" in str(e.get("description_ar", ""))]
    if depr_errors:
        count = len(depr_errors)
        actions.append({
            "action": f"أضف مجمع إهلاك لـ {count} أصل",
            "impact": f"+{min(count, 8)} نقاط",
            "effort": "سهل",
        })

    if dims.get("naming_quality", 0) < 70:
        actions.append({
            "action": "حسِّن أسماء الحسابات الغامضة أو القصيرة",
            "impact": "+5 نقاط",
            "effort": "سهل",
        })

    if dims.get("code_consistency", 0) < 60:
        actions.append({
            "action": "أعد هيكلة الأكواد لتتبع نمطاً هرمياً موحداً",
            "impact": "+10 نقاط",
            "effort": "صعب",
        })

    # From engine recommendations
    for rec in recommendations[:3]:
        if rec and rec not in [a["action"] for a in actions]:
            actions.append({
                "action": rec,
                "impact": "+3 نقاط",
                "effort": "متوسط",
            })

    # Sort by impact (descending)
    def _impact_num(a: Dict) -> int:
        try:
            return int(a["impact"].replace("+", "").replace(" نقاط", "").replace(" نقطة", ""))
        except (ValueError, AttributeError):
            return 0

    actions.sort(key=_impact_num, reverse=True)
    return actions[:8]


def _readiness(score: float, critical: int) -> str:
    if critical > 0:
        return "blocked"
    if score >= 80:
        return "approved"
    return "pending_review"


def generate_report_card(
    result: Dict,
    sector_benchmark: Optional[Dict] = None,
) -> Dict[str, Any]:
    """
    يولّد تقريراً بلغة تجارية للعميل بالعربي.

    Parameters:
        result: نتيجة process() من Engine — يجب أن يحتوي:
            quality_score, quality_grade, quality_dimensions,
            errors_summary, errors, recommendations,
            total_accounts, confidence_avg, sector_detected
        sector_benchmark: بيانات المقارنة القطاعية (اختياري)
    """
    score = result.get("quality_score", 0)
    if isinstance(score, (int, float)) and score <= 1.0:
        score = score * 100  # normalize 0-1 → 0-100
    score = round(score, 1)
    grade = _grade(score)

    errors_summary = result.get("errors_summary") or {}
    critical = errors_summary.get("critical", 0)

    strengths = _extract_strengths(result)
    weaknesses = _extract_weaknesses(result)
    priority_actions = _build_priority_actions(result)

    # Sector comparison
    sector_comparison = None
    sector_detected = result.get("sector_detected")
    if sector_benchmark and sector_detected:
        avg = sector_benchmark.get("avg_score", 0)
        sample = sector_benchmark.get("sample_size", 0)
        if avg > 0:
            pct_above = round(min(max((score - avg + 50) / 100 * 100, 5), 95))
            sector_comparison = {
                "sector": sector_detected,
                "sector_name_ar": sector_benchmark.get("sector_name_ar", sector_detected),
                "your_score": score,
                "sector_avg": avg,
                "rank_text": f"أعلى من {pct_above}% من شركات {sector_benchmark.get('sector_name_ar', sector_detected)}",
            }

    return {
        "grade": grade,
        "score": score,
        "headline_ar": _headline(score),
        "strengths": strengths,
        "weaknesses": weaknesses,
        "priority_actions": priority_actions,
        "sector_comparison": sector_comparison,
        "readiness": _readiness(score, critical),
    }
