"""
APEX — Document lifecycle service with status transition validation
خدمة دورة حياة المستندات مع التحقق من صحة انتقالات الحالة
"""
from datetime import datetime, timezone

VALID_TRANSITIONS = {
    "missing":      ["uploaded"],
    "uploaded":     ["under_review", "accepted"],
    "under_review": ["accepted", "rejected"],
    "accepted":     ["expired", "replaced"],
    "rejected":     ["replaced"],
    "expired":      ["replaced"],
    "replaced":     ["uploaded"],
}


def can_transition(current_status, new_status):
    return new_status in VALID_TRANSITIONS.get(current_status, [])


def transition_document(doc, new_status, reason=None):
    current = doc.get("status", "missing")
    if not can_transition(current, new_status):
        raise ValueError(f"Invalid: {current} -> {new_status}")
    updated = {**doc, "status": new_status}
    now = datetime.now(timezone.utc).isoformat()
    if new_status == "uploaded":
        updated["uploaded_at"] = now
    elif new_status == "accepted":
        updated["accepted_at"] = now
    elif new_status == "rejected":
        updated["rejected_at"] = now
        updated["reject_reason"] = reason
    elif new_status == "replaced":
        updated["replaced_at"] = now
    return updated