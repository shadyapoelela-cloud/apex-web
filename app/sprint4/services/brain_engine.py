# -*- coding: utf-8 -*-
"""
Sprint 4 — Knowledge Brain Engine
Core logic for concept resolution, alias matching,
conflict detection, and authority hierarchy.
"""

import re
from typing import Optional, List, Dict, Tuple

# ── Authority hierarchy (lower number = higher authority) ──
AUTHORITY_LEVELS = {
    "law": 1,
    "regulation": 2,
    "standard": 3,
    "policy": 4,
    "platform": 5,
    "expert": 6,
    "ai": 7,
}

# ── Domain packs ──────────────────────────────────────────
DOMAIN_PACKS = [
    "accounting",
    "finance",
    "tax_zakat",
    "audit",
    "compliance",
    "hr",
    "marketing",
    "operations",
    "legal_regulatory",
    "funding",
    "support_incentives",
    "licensing",
    "investment_residency",
]

# ── Source systems (Sprint 4 awareness) ──────────────────
SOURCE_SYSTEMS = [
    "odoo",
    "sap",
    "oracle",
    "quickbooks",
    "zoho",
    "xero",
    "qoyod",
    "daftra",
    "custom_erp",
    "other",
]

# ── Boundary status values ────────────────────────────────
BOUNDARY_STATUSES = [
    "authoritative",
    "advisory",
    "suggestive",
    "uncertain",
    "review_required",
]


def normalize_text(text: str) -> str:
    """Normalize Arabic/English text for matching."""
    if not text:
        return ""
    # Remove diacritics
    t = re.sub(r"[\u064b-\u065f]", "", text)
    # Normalize alef variants
    t = re.sub(r"[أإآ]", "ا", t)
    # Normalize ta marbuta
    t = t.replace("ة", "ه")
    # Lowercase, strip whitespace
    return re.sub(r"\s+", " ", t).strip().lower()


def resolve_concept(
    raw_term: str,
    concepts: list,
    aliases: list,
    source_system: Optional[str] = None,
    sector: Optional[str] = None,
    language: str = "ar",
) -> Dict:
    """
    Match a raw term to the best concept via alias lookup.
    Returns: {concept_id, canonical_name_ar, match_type,
               confidence, boundary_status, authority_level}
    """
    normalized = normalize_text(raw_term)

    # Priority 1: exact alias match (system-specific)
    best = None
    best_confidence = 0.0

    for alias in aliases:
        alias_norm = normalize_text(alias.get("alias_text", ""))
        if alias_norm != normalized:
            continue

        confidence = float(alias.get("confidence_weight", 1.0))
        match_type = "exact_alias"

        # Boost for system-specific match
        if source_system and alias.get("source_system") == source_system:
            confidence = min(1.0, confidence + 0.05)
            match_type = "system_alias"

        # Boost for sector-specific match
        if sector and alias.get("sector_scope") == sector:
            confidence = min(1.0, confidence + 0.03)

        if alias.get("is_approved"):
            confidence = min(1.0, confidence + 0.02)

        if confidence > best_confidence:
            best_confidence = confidence
            best = {
                "concept_id": alias.get("concept_id"),
                "alias_id": alias.get("id"),
                "match_type": match_type,
                "confidence": round(confidence, 3),
                "boundary_status": "authoritative" if confidence >= 0.90 else "advisory",
            }

    if best:
        # Enrich with concept data
        for c in concepts:
            if c.get("id") == best["concept_id"]:
                best["canonical_name_ar"] = c.get("canonical_name_ar")
                best["canonical_name_en"] = c.get("canonical_name_en")
                best["authority_level"] = c.get("authority_level", "platform")
                best["domain_pack"] = c.get("domain_pack")
                break
        return best

    # Priority 2: partial match on canonical name
    for c in concepts:
        cn_ar = normalize_text(c.get("canonical_name_ar", ""))
        cn_en = normalize_text(c.get("canonical_name_en", ""))
        if normalized in cn_ar or cn_ar in normalized:
            return {
                "concept_id": c.get("id"),
                "canonical_name_ar": c.get("canonical_name_ar"),
                "canonical_name_en": c.get("canonical_name_en"),
                "authority_level": c.get("authority_level", "platform"),
                "domain_pack": c.get("domain_pack"),
                "match_type": "partial_canonical",
                "confidence": 0.60,
                "boundary_status": "advisory",
            }
        if normalized in cn_en or cn_en in normalized:
            return {
                "concept_id": c.get("id"),
                "canonical_name_ar": c.get("canonical_name_ar"),
                "canonical_name_en": c.get("canonical_name_en"),
                "authority_level": c.get("authority_level", "platform"),
                "domain_pack": c.get("domain_pack"),
                "match_type": "partial_english",
                "confidence": 0.55,
                "boundary_status": "advisory",
            }

    # No match — queue for review
    return {
        "concept_id": None,
        "canonical_name_ar": None,
        "canonical_name_en": None,
        "authority_level": None,
        "domain_pack": None,
        "match_type": "no_match",
        "confidence": 0.0,
        "boundary_status": "review_required",
        "review_note": f"Term '{raw_term}' not found — queued for terminology review",
    }


def detect_conflicts(rules: list) -> List[Dict]:
    """
    Detect conflicting rules within the same domain/scope.
    Returns list of conflict pairs with resolution hint.
    """
    conflicts = []
    checked = set()

    for i, r1 in enumerate(rules):
        for j, r2 in enumerate(rules):
            if i >= j:
                continue
            key = (min(r1["id"], r2["id"]), max(r1["id"], r2["id"]))
            if key in checked:
                continue
            checked.add(key)

            # Same domain + overlapping scope = potential conflict
            if r1.get("domain_pack") != r2.get("domain_pack"):
                continue

            logic1 = r1.get("rule_logic_json", {})
            logic2 = r2.get("rule_logic_json", {})
            target1 = logic1.get("target_class") or logic1.get("target")
            target2 = logic2.get("target_class") or logic2.get("target")

            if target1 and target1 == target2:
                # Check authority hierarchy to determine winner
                lvl1 = AUTHORITY_LEVELS.get(r1.get("authority_level", "platform"), 5)
                lvl2 = AUTHORITY_LEVELS.get(r2.get("authority_level", "platform"), 5)
                winner_id = r1["id"] if lvl1 <= lvl2 else r2["id"]
                loser_id = r2["id"] if lvl1 <= lvl2 else r1["id"]

                conflicts.append(
                    {
                        "rule_1_id": r1["id"],
                        "rule_2_id": r2["id"],
                        "domain_pack": r1["domain_pack"],
                        "target": target1,
                        "resolution": "authority_hierarchy",
                        "winner_rule_id": winner_id,
                        "loser_rule_id": loser_id,
                        "requires_review": lvl1 == lvl2,
                    }
                )

    return conflicts


def compute_boundary_status(
    confidence: float,
    authority_level: str,
    has_reference: bool,
    risk_level: str,
) -> str:
    """Determine boundary status for any output."""
    if risk_level == "critical":
        return "review_required"
    if not has_reference:
        return "uncertain"
    if authority_level in ("law", "regulation") and confidence >= 0.85:
        return "authoritative"
    if confidence >= 0.80 and has_reference:
        return "advisory"
    if confidence >= 0.60:
        return "suggestive"
    return "uncertain"


def requires_human_review(
    confidence: float,
    risk_level: str,
    boundary_status: str,
    has_conflict: bool,
    is_financial_impact: bool,
) -> Tuple[bool, str]:
    """
    Determine if human review is required.
    Returns (requires_review, reason).
    """
    if risk_level == "critical":
        return True, "critical_risk"
    if confidence < 0.60:
        return True, "low_confidence"
    if boundary_status == "review_required":
        return True, "boundary_review_required"
    if has_conflict:
        return True, "rule_conflict_detected"
    if is_financial_impact and confidence < 0.80:
        return True, "financial_impact_low_confidence"
    return False, ""


def score_risk(issues: list) -> str:
    """Compute overall risk level from list of issues."""
    if not issues:
        return "low"
    severities = [i.get("severity", "low") for i in issues]
    if "critical" in severities:
        return "critical"
    if "high" in severities:
        return "high"
    if "medium" in severities:
        return "medium"
    return "low"
