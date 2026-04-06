from app.config.phase1_constants import (
    MIN_QUALITY_FOR_APPROVAL,
    MIN_COMPLETENESS_FOR_TB,
    MIN_REPORTING_FOR_TB,
)


def check_approval_gates(accounts, quality_scores):
    blockers = []
    pending = [a for a in accounts if a.get("status") not in ("approved", "rejected")]
    if pending:
        blockers.append(str(len(pending)) + " حساب لم يتخذ فيه قرار")
    overall = quality_scores.get("overall", 0)
    if overall < MIN_QUALITY_FOR_APPROVAL:
        blockers.append("الجودة " + str(overall) + "% < " + str(MIN_QUALITY_FOR_APPROVAL) + "%")
    comp = quality_scores.get("completeness", 0)
    if comp < MIN_COMPLETENESS_FOR_TB:
        blockers.append("الاكتمال " + str(comp) + "% < " + str(MIN_COMPLETENESS_FOR_TB) + "%")
    rep = quality_scores.get("reporting", 0)
    if rep < MIN_REPORTING_FOR_TB:
        blockers.append("التقارير " + str(rep) + "% < " + str(MIN_REPORTING_FOR_TB) + "%")
    classes = set(a.get("normalized_class") for a in accounts if a.get("status") == "approved")
    missing = {"revenue", "expense", "asset", "liability", "equity"} - classes
    if missing:
        blockers.append("فئات مفقودة: " + ", ".join(missing))
    return {
        "can_approve": len(blockers) == 0,
        "blockers": blockers,
        "quality_overall": overall,
        "pending_count": len(pending),
        "approved_count": len([a for a in accounts if a.get("status") == "approved"]),
    }