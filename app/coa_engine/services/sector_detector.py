"""
APEX COA Engine v4.2 — Sector Intelligence (Section 7, Wave 3)
Auto-detects company sector from COA, calculates similarity,
identifies missing mandatory accounts.
"""

import logging
from typing import Dict, List, Optional, Set, Tuple
from collections import Counter

logger = logging.getLogger(__name__)


def detect_sector(
    accounts: List[Dict],
    common_mandatory: List[str] = None,
) -> Dict:
    """Auto-detect company sector by matching account concept_ids against sector mandatory accounts.

    Algorithm:
    1. Collect all concept_ids from classified accounts
    2. For each sector, count how many mandatory accounts are present
    3. Rank sectors by match ratio (matches / total mandatory)
    4. Return best match with confidence

    Args:
        accounts: Classified account list with concept_id field.
        common_mandatory: Optional list of common mandatory concept_ids to exclude from scoring.

    Returns:
        Dict with: sector_code, sector_name_ar, sector_name_en, confidence,
                   match_ratio, matched_accounts, missing_accounts, alternatives
    """
    from app.coa_engine.data.sectors import SECTORS, COMMON_MANDATORY_ACCOUNTS

    if common_mandatory is None:
        common_mandatory = COMMON_MANDATORY_ACCOUNTS

    # Collect concept_ids from accounts
    concept_set: Set[str] = set()
    for acct in accounts:
        cid = acct.get("concept_id")
        if cid:
            concept_set.add(cid)

    if not concept_set:
        return {
            "sector_code": "UNKNOWN",
            "sector_name_ar": "غير محدد",
            "sector_name_en": "Unknown",
            "confidence": 0.0,
            "match_ratio": 0.0,
            "matched_accounts": [],
            "missing_accounts": [],
            "alternatives": [],
        }

    # Score each sector
    sector_scores: List[Tuple[Dict, float, List[str], List[str]]] = []

    for sector in SECTORS:
        mandatory = sector.get("mandatory_accounts", [])
        if not mandatory:
            continue

        # Only count sector-SPECIFIC accounts (exclude common mandatory)
        sector_specific = [m for m in mandatory if m not in common_mandatory]

        if not sector_specific:
            # Sector has no unique mandatory accounts — skip it for detection
            continue

        matched = [m for m in sector_specific if m in concept_set]
        missing = [m for m in sector_specific if m not in concept_set]
        ratio = len(matched) / len(sector_specific) if sector_specific else 0.0

        sector_scores.append((sector, ratio, matched, missing))

    # Sort by match ratio descending
    sector_scores.sort(key=lambda x: x[1], reverse=True)

    if not sector_scores or sector_scores[0][1] == 0:
        return {
            "sector_code": "UNKNOWN",
            "sector_name_ar": "غير محدد",
            "sector_name_en": "Unknown",
            "confidence": 0.0,
            "match_ratio": 0.0,
            "matched_accounts": [],
            "missing_accounts": [],
            "alternatives": [],
        }

    best = sector_scores[0]
    best_sector, best_ratio, best_matched, best_missing = best

    # Confidence: match_ratio mapped to 0-1 range with minimum threshold
    confidence = min(best_ratio, 1.0)

    # Alternatives: sectors with match_ratio >= 0.25
    alternatives = []
    for sector, ratio, matched, missing in sector_scores[1:5]:
        if ratio >= 0.25:
            alternatives.append({
                "sector_code": sector["code"],
                "sector_name_ar": sector["name_ar"],
                "sector_name_en": sector["name_en"],
                "match_ratio": round(ratio, 4),
                "matched_accounts": matched,
            })

    return {
        "sector_code": best_sector["code"],
        "sector_name_ar": best_sector["name_ar"],
        "sector_name_en": best_sector["name_en"],
        "regulatory_body": best_sector.get("regulatory_body", ""),
        "confidence": round(confidence, 4),
        "match_ratio": round(best_ratio, 4),
        "matched_accounts": best_matched,
        "missing_accounts": best_missing,
        "alternatives": alternatives,
    }


def calculate_similarity(
    accounts: List[Dict],
    sector_code: str,
) -> Dict:
    """Calculate similarity score (0-100) between company COA and sector template.

    Scoring dimensions:
    1. Mandatory coverage: % of sector mandatory accounts present (weight: 0.40)
    2. Common coverage: % of common mandatory accounts present (weight: 0.30)
    3. Structure quality: accounts have proper hierarchy and classification (weight: 0.20)
    4. Naming quality: accounts have normalized names (weight: 0.10)

    Args:
        accounts: Classified account list.
        sector_code: Detected or specified sector code.

    Returns:
        Dict with: overall_score, dimensions, grade, details
    """
    from app.coa_engine.data.sectors import get_sector, COMMON_MANDATORY_ACCOUNTS

    sector = get_sector(sector_code)

    # Collect concept_ids
    concept_set: Set[str] = set()
    classified_count = 0
    with_hierarchy = 0
    with_name = 0
    total = len(accounts)

    for acct in accounts:
        cid = acct.get("concept_id")
        if cid:
            concept_set.add(cid)
        if acct.get("main_class"):
            classified_count += 1
        if acct.get("parent_code") or acct.get("level", 0) > 0:
            with_hierarchy += 1
        name = acct.get("name", acct.get("name_normalized", ""))
        if isinstance(name, str) and len(name.strip()) > 2:
            with_name += 1

    if total == 0:
        return {
            "overall_score": 0.0,
            "grade": "F",
            "dimensions": {},
            "details": {},
        }

    # Dimension 1: Mandatory coverage
    if sector:
        mandatory = sector.get("mandatory_accounts", [])
        mandatory_present = sum(1 for m in mandatory if m in concept_set)
        mandatory_coverage = (mandatory_present / len(mandatory) * 100) if mandatory else 50.0  # Unknown mandatory = neutral
    else:
        mandatory_coverage = 50.0  # Unknown sector — neutral score

    # Dimension 2: Common coverage
    common_present = sum(1 for m in COMMON_MANDATORY_ACCOUNTS if m in concept_set)
    common_total = len(COMMON_MANDATORY_ACCOUNTS)
    common_coverage = (common_present / common_total * 100) if common_total else 100.0

    # Dimension 3: Structure quality
    structure_quality = (classified_count / total * 100) if total else 0.0

    # Dimension 4: Naming quality
    naming_quality = (with_name / total * 100) if total else 0.0

    # Weighted score
    overall = (
        mandatory_coverage * 0.40
        + common_coverage * 0.30
        + structure_quality * 0.20
        + naming_quality * 0.10
    )
    overall = max(0.0, min(100.0, overall))

    # Grade
    if overall >= 90:
        grade = "A"
    elif overall >= 80:
        grade = "B"
    elif overall >= 70:
        grade = "C"
    elif overall >= 60:
        grade = "D"
    else:
        grade = "F"

    return {
        "overall_score": round(overall, 2),
        "grade": grade,
        "dimensions": {
            "mandatory_coverage": round(mandatory_coverage, 2),
            "common_coverage": round(common_coverage, 2),
            "structure_quality": round(structure_quality, 2),
            "naming_quality": round(naming_quality, 2),
        },
        "details": {
            "sector_code": sector_code,
            "sector_name": sector["name_ar"] if sector else "غير محدد",
            "mandatory_total": len(sector.get("mandatory_accounts", [])) if sector else 0,
            "mandatory_present": mandatory_present if sector else 0,
            "common_total": common_total,
            "common_present": common_present,
            "total_accounts": total,
            "classified_accounts": classified_count,
        },
    }


def build_sector_report(
    accounts: List[Dict],
    sector_result: Dict,
    similarity_result: Dict,
    quality_score: float,
    errors_summary: Dict,
) -> Dict:
    """Build a comprehensive sector intelligence report card.

    Combines sector detection, similarity scoring, quality assessment,
    and generates actionable recommendations.

    Args:
        accounts: Classified account list.
        sector_result: Output from detect_sector().
        similarity_result: Output from calculate_similarity().
        quality_score: Overall quality score from pipeline.
        errors_summary: Error counts by severity.

    Returns:
        Enhanced report card dict with sector intelligence.
    """
    total = len(accounts)
    classified = sum(1 for a in accounts if a.get("main_class"))
    pending = sum(1 for a in accounts if a.get("review_status") == "pending")

    # Build top actions
    top_actions = []
    priority = 1

    # Action 1: Fix critical errors
    critical = errors_summary.get("critical", 0)
    if critical > 0:
        top_actions.append({
            "priority": priority,
            "action_ar": f"أصلح {critical} خطأ حرج قبل الاعتماد",
            "action_en": f"Fix {critical} critical error(s) before approval",
            "severity": "Critical",
            "estimated_hours": round(critical * 0.5, 1),
        })
        priority += 1

    # Action 2: Add missing sector accounts
    missing = sector_result.get("missing_accounts", [])
    if missing:
        top_actions.append({
            "priority": priority,
            "action_ar": f"أضف {len(missing)} حساب إلزامي مفقود لقطاع {sector_result.get('sector_name_ar', '')}",
            "action_en": f"Add {len(missing)} missing mandatory accounts for {sector_result.get('sector_name_en', '')} sector",
            "severity": "High",
            "missing_accounts": missing,
            "estimated_hours": round(len(missing) * 0.25, 1),
        })
        priority += 1

    # Action 3: Review pending accounts
    if pending > 0:
        top_actions.append({
            "priority": priority,
            "action_ar": f"راجع {pending} حساب بحاجة لمراجعة بشرية",
            "action_en": f"Review {pending} account(s) pending human review",
            "severity": "Medium",
            "estimated_hours": round(pending * 0.1, 1),
        })
        priority += 1

    # Action 4: Fix high errors
    high = errors_summary.get("high", 0)
    if high > 0:
        top_actions.append({
            "priority": priority,
            "action_ar": f"أصلح {high} خطأ عالي الخطورة",
            "action_en": f"Fix {high} high severity error(s)",
            "severity": "High",
            "estimated_hours": round(high * 0.25, 1),
        })
        priority += 1

    # Total estimated effort
    total_hours = sum(a.get("estimated_hours", 0) for a in top_actions)

    # Grade
    score = similarity_result.get("overall_score", quality_score)
    if score >= 90:
        grade, label = "A", "ممتاز"
    elif score >= 80:
        grade, label = "B", "جيد جداً"
    elif score >= 70:
        grade, label = "C", "جيد"
    elif score >= 60:
        grade, label = "D", "مقبول"
    else:
        grade, label = "F", "ضعيف"

    # Executive summary
    sector_name = sector_result.get("sector_name_ar", "غير محدد")
    if grade in ("A", "B"):
        summary_ar = f"شجرة الحسابات متوافقة مع قطاع {sector_name} بنسبة {score:.0f}%. جاهزة للاعتماد."
        summary_en = f"COA is {score:.0f}% aligned with {sector_result.get('sector_name_en', 'Unknown')} sector. Ready for approval."
    elif grade == "C":
        summary_ar = f"شجرة الحسابات مقبولة لقطاع {sector_name} ({score:.0f}%). تحتاج بعض التحسينات."
        summary_en = f"COA is acceptable for {sector_result.get('sector_name_en', 'Unknown')} sector ({score:.0f}%). Some improvements needed."
    else:
        summary_ar = f"شجرة الحسابات تحتاج تحسينات جوهرية لتتوافق مع قطاع {sector_name} ({score:.0f}%)."
        summary_en = f"COA needs significant improvements for {sector_result.get('sector_name_en', 'Unknown')} sector ({score:.0f}%)."

    return {
        "grade": grade,
        "label_ar": label,
        "score": round(score, 2),
        "sector": {
            "code": sector_result.get("sector_code", "UNKNOWN"),
            "name_ar": sector_result.get("sector_name_ar", "غير محدد"),
            "name_en": sector_result.get("sector_name_en", "Unknown"),
            "confidence": sector_result.get("confidence", 0),
            "regulatory_body": sector_result.get("regulatory_body", ""),
        },
        "similarity": similarity_result.get("dimensions", {}),
        "total_accounts": total,
        "classified_accounts": classified,
        "pending_review": pending,
        "executive_summary_ar": summary_ar,
        "executive_summary_en": summary_en,
        "top_actions": top_actions,
        "total_estimated_hours": round(total_hours, 1),
        "benchmark": {
            "sector_avg": 72.0,  # Placeholder — Wave 4 will populate from real data
            "client_position": "above_average" if score >= 72 else "below_average",
            "percentile": min(99, max(1, int(score))),
        },
    }
