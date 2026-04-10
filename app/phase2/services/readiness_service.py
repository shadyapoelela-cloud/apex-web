"""
APEX — Client readiness assessment for trial balance binding
خدمة تقييم جاهزية العميل لربط ميزان المراجعة
"""


def compute_readiness(client_data, documents):
    if not client_data.get("client_type"):
        return "not_ready"
    if not client_data.get("main_sector"):
        return "not_ready"
    if not client_data.get("name_ar"):
        return "not_ready"
    if not client_data.get("city") or not client_data.get("region"):
        return "not_ready"
    status = client_data.get("status", "draft")
    if status in ("suspended", "archived"):
        return "not_ready"
    required_docs = [d for d in documents if d.get("required", False)]
    all_accepted = len(required_docs) >= 4 and all(d.get("status") == "accepted" for d in required_docs)
    if not all_accepted:
        return "documents_pending"
    coa_stage = client_data.get("coa_stage")
    if coa_stage and coa_stage != "none":
        if coa_stage == "ready":
            return "ready_for_tb"
        return "coa_in_progress"
    return "ready_for_coa"


def get_missing_for_coa(client_data, documents):
    blockers = []
    if not client_data.get("client_type"):
        blockers.append("نوع الكيان غير محدد")
    if not client_data.get("main_sector"):
        blockers.append("القطاع الرئيسي غير محدد")
    if not client_data.get("name_ar"):
        blockers.append("اسم المنشأة غير مكتمل")
    if not client_data.get("city"):
        blockers.append("المدينة غير محددة")
    if not client_data.get("region"):
        blockers.append("المنطقة غير محددة")
    for doc in documents:
        if doc.get("required") and doc.get("status") != "accepted":
            doc_name = doc.get("name_ar") or doc.get("id") or "غير معروف"
            blockers.append("مستند ناقص: " + str(doc_name))
    return blockers