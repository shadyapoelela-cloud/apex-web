"""
╔════════════════════════════════════════════════════════════════════╗
║  APEX KNOWLEDGE CONSTITUTION — الدستور المعرفي لمنصة أبكس        ║
║══════════════════════════════════════════════════════════════════════
║                                                                    ║
║  هذه الوثيقة تحكم كيف تفكر المنصة وكيف تقرر وكيف تستدل.          ║
║  كل محرك وكل خدمة وكل تقرير يجب أن يلتزم بهذه المبادئ.          ║
║                                                                    ║
╚════════════════════════════════════════════════════════════════════╝
"""

# ═══════════════════════════════════════════
#  1. ترتيب القوة المرجعية
# ═══════════════════════════════════════════

REFERENCE_HIERARCHY = [
    # الأولوية الأعلى أولاً
    {
        "level": 1,
        "type": "binding_law",
        "ar": "نظام/قانون ملزم",
        "trust": 1.0,
        "can_override": False,
        "description": "نصوص قانونية صادرة بمرسوم ملكي أو قرار مجلس وزراء",
    },
    {
        "level": 2,
        "type": "implementing_regulation",
        "ar": "لائحة تنفيذية",
        "trust": 0.98,
        "can_override": False,
        "description": "لوائح تفصيلية صادرة من الجهة المختصة بموجب النظام",
    },
    {
        "level": 3,
        "type": "professional_standard",
        "ar": "معيار مهني معتمد",
        "trust": 0.95,
        "can_override": False,
        "description": "معايير IFRS المعتمدة من SOCPA أو معايير المراجعة",
    },
    {
        "level": 4,
        "type": "regulatory_instruction",
        "ar": "تعليمات وقواعد تنظيمية",
        "trust": 0.92,
        "can_override": False,
        "description": "قواعد وتعليمات من الجهات الرقابية",
    },
    {
        "level": 5,
        "type": "official_guidance",
        "ar": "دليل/إرشاد رسمي",
        "trust": 0.88,
        "can_override": True,
        "description": "أدلة إرشادية رسمية من الجهات",
    },
    {
        "level": 6,
        "type": "official_bulletin",
        "ar": "نشرة/تعميم رسمي",
        "trust": 0.85,
        "can_override": True,
        "description": "تعاميم ونشرات رسمية",
    },
    {
        "level": 7,
        "type": "approved_case",
        "ar": "حالة/سابقة معتمدة",
        "trust": 0.80,
        "can_override": True,
        "description": "حالات سابقة تم اعتمادها داخل المنصة",
    },
    {
        "level": 8,
        "type": "best_practice",
        "ar": "أفضل ممارسة مهنية",
        "trust": 0.75,
        "can_override": True,
        "description": "ممارسات مهنية متعارف عليها دولياً",
    },
    {
        "level": 9,
        "type": "interpretive_note",
        "ar": "ملاحظة تفسيرية",
        "trust": 0.70,
        "can_override": True,
        "description": "تفسيرات وشروحات داخلية معتمدة",
    },
    {
        "level": 10,
        "type": "market_insight",
        "ar": "رؤية سوقية/اقتصادية",
        "trust": 0.60,
        "can_override": True,
        "description": "تحليلات وأنماط سوقية داعمة للاستدلال",
    },
]


# ═══════════════════════════════════════════
#  2. مبادئ الاستدلال
# ═══════════════════════════════════════════

REASONING_PRINCIPLES = {
    "official_first": {
        "ar": "الرسمي أولاً",
        "rule": "عند وجود مصدر رسمي ساري المفعول → يُستخدم كمرجع أساسي بدون استثناء",
    },
    "recency_wins": {
        "ar": "الأحدث يسود",
        "rule": "عند تساوي القوة المرجعية → يُقدّم الأحدث تاريخاً",
    },
    "interpretive_below_official": {
        "ar": "التفسيري لا يعلو على الرسمي",
        "rule": "الملاحظات التفسيرية والأنماط لا تحل محل النص القانوني أو المعيار المعتمد",
    },
    "superseded_for_history_only": {
        "ar": "المُلغى للتاريخ فقط",
        "rule": "المصادر الملغاة أو المحلّة تُستخدم فقط للرجوع التاريخي — لا تُستخدم كمرجع حالي",
    },
    "conflict_must_surface": {
        "ar": "التعارض يجب أن يظهر",
        "rule": "إذا وُجد تعارض بين مصادر → يجب عرضه صراحةً مع الإشارة لكل مصدر",
    },
    "no_fabrication": {
        "ar": "لا اختلاق",
        "rule": "AI لا يخلق مرجعاً من العدم — كل استدلال يجب أن يستند لمصدر أو قاعدة مسجّلة",
    },
    "uncertainty_acknowledged": {
        "ar": "الشك يُعترف به",
        "rule": "عند عدم وجود مرجع كافٍ → تُصرّح المنصة بعدم اليقين بدل الجزم",
    },
    "sector_context_matters": {
        "ar": "السياق القطاعي مهم",
        "rule": "نفس القاعدة قد تُطبّق بشكل مختلف حسب القطاع — يجب مراعاة النمط القطاعي",
    },
    "data_gap_declared": {
        "ar": "نقص البيانات يُعلن",
        "rule": "إذا كانت البيانات ناقصة لإصدار حكم → يُصرّح بذلك ويُطلب البيانات اللازمة",
    },
    "ai_explains_not_decides": {
        "ar": "AI يشرح ولا يقرر",
        "rule": "الذكاء الاصطناعي يفسّر ويوصي ويحذّر — لكن القرار النهائي للمحلل أو العميل",
    },
}


# ═══════════════════════════════════════════
#  3. قواعد الثقة (Confidence)
# ═══════════════════════════════════════════

CONFIDENCE_RULES = {
    "calculation": {
        "source_trust": "40% — من القوة المرجعية للمصدر",
        "data_completeness": "30% — من اكتمال البيانات المطلوبة",
        "validation_pass": "20% — من عدد فحوصات التحقق الناجحة",
        "freshness": "10% — من حداثة المصدر ومراجعته",
    },
    "thresholds": {
        "excellent": {"min": 0.90, "ar": "ممتاز", "action": "يمكن اعتماد النتائج"},
        "good": {"min": 0.75, "ar": "جيد", "action": "يمكن الاعتماد مع ملاحظات"},
        "acceptable": {"min": 0.60, "ar": "مقبول", "action": "يتطلب مراجعة إضافية"},
        "needs_review": {"min": 0.0, "ar": "يحتاج مراجعة", "action": "لا يُعتمد — مراجعة يدوية مطلوبة"},
    },
    "freshness_decay": {
        "law": "لا يتقادم ما لم يُلغَ",
        "regulation": "مراجعة سنوية",
        "standard": "مراجعة سنوية",
        "guidance": "مراجعة كل 6 أشهر",
        "market_insight": "مراجعة ربع سنوية",
        "case": "مراجعة سنوية",
    },
}


# ═══════════════════════════════════════════
#  4. قواعد التعامل مع الحالات الخاصة
# ═══════════════════════════════════════════

SPECIAL_CASES = {
    "missing_data": {
        "action": "صرّح بنقص البيانات + حدد البيانات المطلوبة + أعطِ تحليلاً جزئياً مع تنبيه",
        "never": "لا تخمّن بيانات مالية غير موجودة",
    },
    "conflict_between_sources": {
        "action": "اعرض كلا المصدرين + أشر للأحدث + أشر للأقوى مرجعياً + دع المستخدم يقرر",
        "never": "لا تختار مصدراً بصمت دون إشارة للتعارض",
    },
    "outdated_knowledge": {
        "action": "أشر بوضوح أن المعلومة قد تكون قديمة + اذكر تاريخ آخر مراجعة + أنصح بالتحقق",
        "flag": "⚠️ STALE_CONTENT",
    },
    "sector_exception": {
        "action": "طبّق القاعدة العامة + أشر للاستثناء القطاعي + وضّح الفرق",
    },
    "small_vs_large_entity": {
        "action": "حدد حجم المنشأة أولاً (micro/small/medium/large) ثم طبّق المعايير المناسبة",
        "thresholds": {
            "micro": {"revenue_max": 3000000, "employees_max": 5, "standards": "SOCPA micro"},
            "small": {"revenue_max": 40000000, "employees_max": 49, "standards": "IFRS for SMEs"},
            "medium": {"revenue_max": 200000000, "employees_max": 249, "standards": "Full IFRS"},
            "large": {"revenue_min": 200000000, "standards": "Full IFRS + CMA requirements"},
        },
    },
    "going_concern_doubt": {
        "action": "ارفع تحذير فوري + اذكر المؤشرات + أشر للمراجع (IAS 1 + نظام الإفلاس)",
        "severity": "CRITICAL",
    },
    "negative_equity": {
        "action": "تحذير عسر فني + إشارة لنظام الإفلاس + إشارة لنظام الشركات (خسائر 50%)",
        "severity": "CRITICAL",
    },
}


# ═══════════════════════════════════════════
#  5. قواعد إخراج المعرفة
# ═══════════════════════════════════════════

OUTPUT_RULES = {
    "citation_required": "كل حقيقة نظامية أو معيارية يجب أن تحمل citation بالمصدر والمادة",
    "confidence_shown": "كل نتيجة تحمل مؤشر ثقة واضح",
    "effective_date_shown": "كل مرجع يحمل تاريخ نفاذه",
    "status_shown": "كل مرجع يحمل حالته (active/superseded/archived)",
    "source_type_labeled": "كل مرجع يحمل نوعه (نظام/لائحة/معيار/ممارسة/رؤية سوقية)",
    "ai_vs_engine_labeled": "يُميّز بوضوح بين ما حسبه المحرك المالي وما استنتجه AI",
    "numbers_from_engine_only": "الأرقام المالية من المحرك فقط — AI لا يغيّر أي رقم",
    "actionable_recommendations": "التوصيات يجب أن تكون عملية مع جدول زمني وأولوية",
}


# ═══════════════════════════════════════════
#  Helper Functions
# ═══════════════════════════════════════════


def get_trust_level(source_type: str) -> float:
    """Get trust level for a source type."""
    for ref in REFERENCE_HIERARCHY:
        if ref["type"] == source_type:
            return ref["trust"]
    return 0.5  # default


def get_confidence_label(score: float) -> str:
    """Get label for a confidence score."""
    for label, info in CONFIDENCE_RULES["thresholds"].items():
        if score >= info["min"]:
            return info["ar"]
    return "يحتاج مراجعة"


def get_entity_size(revenue: float = 0, employees: int = 0) -> str:
    """Determine entity size classification."""
    thresholds = SPECIAL_CASES["small_vs_large_entity"]["thresholds"]
    if revenue <= thresholds["micro"]["revenue_max"] and employees <= thresholds["micro"]["employees_max"]:
        return "micro"
    if revenue <= thresholds["small"]["revenue_max"]:
        return "small"
    if revenue <= thresholds["medium"]["revenue_max"]:
        return "medium"
    return "large"


def get_applicable_standards(entity_size: str) -> str:
    """Get applicable accounting standards for entity size."""
    return SPECIAL_CASES["small_vs_large_entity"]["thresholds"].get(entity_size, {}).get("standards", "Full IFRS")
