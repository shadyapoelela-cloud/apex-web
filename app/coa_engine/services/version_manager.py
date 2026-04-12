"""
APEX COA Engine v4.2 — Version Intelligence (Wave 4)
Tracks COA versions, detects changes between versions,
generates evolution logs with risk assessment.

Change types (TABLE 136):
  added       — New account not in previous version
  deleted     — Account removed from tree
  renamed     — Same code, different name
  reclassified — Changed section (asset↔liability...)
  reparented  — Changed parent in hierarchy
  rebalanced  — Changed nature (debit↔credit)
"""

import logging
from typing import Dict, List, Optional, Tuple, Set
from datetime import datetime, timezone

logger = logging.getLogger(__name__)

# Risk levels for change types
CHANGE_RISK = {
    "added": "Low",
    "deleted": "Critical",
    "renamed": "Low",
    "reclassified": "Critical",
    "reparented": "High",
    "rebalanced": "Critical",
}


class VersionSnapshot:
    """Immutable snapshot of a COA version for comparison."""

    def __init__(self, version_number: int, accounts: List[Dict], quality_score: float = 0.0,
                 label: str = "", created_at: str = None):
        self.version_number = version_number
        self.accounts = accounts
        self.quality_score = quality_score
        self.label = label
        self.created_at = created_at or datetime.now(timezone.utc).isoformat()
        # Build index by code for fast lookups
        self._code_index: Dict[str, Dict] = {}
        for acct in accounts:
            code = str(acct.get("code", "")).strip()
            if code:
                self._code_index[code] = acct

    @property
    def account_codes(self) -> Set[str]:
        return set(self._code_index.keys())

    def get_account(self, code: str) -> Optional[Dict]:
        return self._code_index.get(code)

    @property
    def total_accounts(self) -> int:
        return len(self._code_index)

    def to_dict(self) -> Dict:
        return {
            "version_number": self.version_number,
            "label": self.label,
            "total_accounts": self.total_accounts,
            "quality_score": self.quality_score,
            "created_at": self.created_at,
        }


class EvolutionChange:
    """A single change detected between two versions."""

    __slots__ = (
        "change_type", "account_code", "account_name",
        "old_value", "new_value", "risk_level", "description_ar",
    )

    def __init__(self, change_type: str, account_code: str, account_name: str = "",
                 old_value: str = "", new_value: str = "", description_ar: str = ""):
        self.change_type = change_type
        self.account_code = account_code
        self.account_name = account_name
        self.old_value = old_value
        self.new_value = new_value
        self.risk_level = CHANGE_RISK.get(change_type, "Medium")
        self.description_ar = description_ar

    def to_dict(self) -> Dict:
        return {
            "change_type": self.change_type,
            "account_code": self.account_code,
            "account_name": self.account_name,
            "old_value": self.old_value,
            "new_value": self.new_value,
            "risk_level": self.risk_level,
            "description_ar": self.description_ar,
        }


def compare_versions(
    old_version: VersionSnapshot,
    new_version: VersionSnapshot,
) -> Dict:
    """Compare two COA versions and generate evolution log.

    Detects 6 change types:
      added, deleted, renamed, reclassified, reparented, rebalanced

    Args:
        old_version: Previous COA version snapshot.
        new_version: Current COA version snapshot.

    Returns:
        Dict with: changes, summary, risk_assessment, quality_trend
    """
    changes: List[EvolutionChange] = []

    old_codes = old_version.account_codes
    new_codes = new_version.account_codes

    # Detect added accounts
    added_codes = new_codes - old_codes
    for code in sorted(added_codes):
        acct = new_version.get_account(code)
        name = acct.get("name", acct.get("name_normalized", "")) if acct else ""
        changes.append(EvolutionChange(
            "added", code, name,
            old_value="", new_value=f"added in v{new_version.version_number}",
            description_ar=f"حساب جديد مُضاف: {name}",
        ))

    # Detect deleted accounts
    deleted_codes = old_codes - new_codes
    for code in sorted(deleted_codes):
        acct = old_version.get_account(code)
        name = acct.get("name", acct.get("name_normalized", "")) if acct else ""
        changes.append(EvolutionChange(
            "deleted", code, name,
            old_value=f"existed in v{old_version.version_number}", new_value="deleted",
            description_ar=f"حساب محذوف: {name} — تحقق من وجود رصيد أو قيود",
        ))

    # Detect changes in common accounts
    common_codes = old_codes & new_codes
    for code in sorted(common_codes):
        old_acct = old_version.get_account(code)
        new_acct = new_version.get_account(code)
        if not old_acct or not new_acct:
            continue

        # Check renamed
        old_name = str(old_acct.get("name", old_acct.get("name_normalized", ""))).strip()
        new_name = str(new_acct.get("name", new_acct.get("name_normalized", ""))).strip()
        if old_name and new_name and old_name != new_name:
            changes.append(EvolutionChange(
                "renamed", code, new_name,
                old_value=old_name, new_value=new_name,
                description_ar=f"إعادة تسمية: '{old_name}' → '{new_name}'",
            ))

        # Check reclassified (main_class changed)
        old_class = old_acct.get("main_class", "")
        new_class = new_acct.get("main_class", "")
        if old_class and new_class and old_class != new_class:
            changes.append(EvolutionChange(
                "reclassified", code, new_name or old_name,
                old_value=old_class, new_value=new_class,
                description_ar=f"إعادة تصنيف: {old_class} → {new_class} — يستلزم موافقة المدقق",
            ))

        # Check reparented
        old_parent = str(old_acct.get("parent_code", "") or "").strip()
        new_parent = str(new_acct.get("parent_code", "") or "").strip()
        if old_parent != new_parent and (old_parent or new_parent):
            changes.append(EvolutionChange(
                "reparented", code, new_name or old_name,
                old_value=old_parent or "(root)", new_value=new_parent or "(root)",
                description_ar=f"إعادة هيكلة: الأب تغير من '{old_parent or 'جذر'}' إلى '{new_parent or 'جذر'}'",
            ))

        # Check rebalanced (nature changed)
        old_nature = old_acct.get("nature", "")
        new_nature = new_acct.get("nature", "")
        if old_nature and new_nature and old_nature != new_nature:
            changes.append(EvolutionChange(
                "rebalanced", code, new_name or old_name,
                old_value=old_nature, new_value=new_nature,
                description_ar=f"تغيير الطبيعة: {old_nature} → {new_nature} — يُوقف الاعتماد فوراً",
            ))

    # Summary
    change_counts = {}
    risk_counts = {"Critical": 0, "High": 0, "Medium": 0, "Low": 0}
    for c in changes:
        change_counts[c.change_type] = change_counts.get(c.change_type, 0) + 1
        risk_counts[c.risk_level] = risk_counts.get(c.risk_level, 0) + 1

    # Quality trend
    quality_delta = new_version.quality_score - old_version.quality_score
    if quality_delta > 5:
        trend = "improving"
        trend_ar = "تحسن"
    elif quality_delta < -5:
        trend = "declining"
        trend_ar = "تراجع"
    else:
        trend = "stable"
        trend_ar = "مستقر"

    # Risk assessment
    has_critical = risk_counts["Critical"] > 0
    has_high = risk_counts["High"] > 0
    if has_critical:
        overall_risk = "Critical"
        risk_ar = "تحتاج مراجعة المدقق قبل الاعتماد"
    elif has_high:
        overall_risk = "High"
        risk_ar = "تحتاج مراجعة المحاسب الرئيسي"
    elif changes:
        overall_risk = "Low"
        risk_ar = "تغييرات بسيطة — مراجعة سريعة كافية"
    else:
        overall_risk = "None"
        risk_ar = "لا توجد تغييرات"

    logger.info(
        "Version comparison v%d→v%d: %d changes, risk=%s, quality_delta=%.1f",
        old_version.version_number, new_version.version_number,
        len(changes), overall_risk, quality_delta,
    )

    return {
        "from_version": old_version.version_number,
        "to_version": new_version.version_number,
        "total_changes": len(changes),
        "change_summary": change_counts,
        "risk_summary": risk_counts,
        "overall_risk": overall_risk,
        "risk_description_ar": risk_ar,
        "quality_trend": {
            "old_score": round(old_version.quality_score, 2),
            "new_score": round(new_version.quality_score, 2),
            "delta": round(quality_delta, 2),
            "trend": trend,
            "trend_ar": trend_ar,
        },
        "changes": [c.to_dict() for c in changes],
        "old_version": old_version.to_dict(),
        "new_version": new_version.to_dict(),
    }


def build_migration_map(
    old_version: VersionSnapshot,
    new_version: VersionSnapshot,
) -> List[Dict]:
    """Build code migration mapping between two COA versions.

    For each old account, determines:
      SAME        — Code exists unchanged in new version
      RENAMED     — Same code, different name
      RECODED     — Different code, matched by name similarity
      RECLASSIFIED — Same code, different classification
      DELETED     — No match found in new version

    Also identifies new accounts (ADDED) in the new version.

    Returns:
        List of migration map entries.
    """
    migration_map: List[Dict] = []

    old_codes = old_version.account_codes
    new_codes = new_version.account_codes

    # Build name-to-code index for fuzzy matching
    new_name_index: Dict[str, str] = {}
    for code in new_codes:
        acct = new_version.get_account(code)
        if acct:
            name = str(acct.get("name", acct.get("name_normalized", ""))).strip().lower()
            if name:
                new_name_index[name] = code

    # Process old accounts
    for old_code in sorted(old_codes):
        old_acct = old_version.get_account(old_code)
        if not old_acct:
            continue

        old_name = str(old_acct.get("name", old_acct.get("name_normalized", ""))).strip()
        old_class = old_acct.get("main_class", "")

        if old_code in new_codes:
            # Code exists in new version
            new_acct = new_version.get_account(old_code)
            new_name = str(new_acct.get("name", new_acct.get("name_normalized", ""))).strip()
            new_class = new_acct.get("main_class", "")

            if old_name.lower() == new_name.lower() and old_class == new_class:
                map_type = "SAME"
            elif old_name.lower() != new_name.lower() and old_class == new_class:
                map_type = "RENAMED"
            elif old_class != new_class:
                map_type = "RECLASSIFIED"
            else:
                map_type = "SAME"

            migration_map.append({
                "old_code": old_code,
                "new_code": old_code,
                "old_name": old_name,
                "new_name": new_name,
                "old_section": old_class,
                "new_section": new_class,
                "map_type": map_type,
                "confidence": 1.0,
                "auto_matched": True,
            })
        else:
            # Code not in new version — try name match
            name_lower = old_name.strip().lower()
            matched_code = new_name_index.get(name_lower)

            if matched_code:
                new_acct = new_version.get_account(matched_code)
                new_name = str(new_acct.get("name", "")).strip() if new_acct else ""
                migration_map.append({
                    "old_code": old_code,
                    "new_code": matched_code,
                    "old_name": old_name,
                    "new_name": new_name,
                    "old_section": old_class,
                    "new_section": new_acct.get("main_class", "") if new_acct else "",
                    "map_type": "RECODED",
                    "confidence": 0.85,
                    "auto_matched": True,
                })
            else:
                migration_map.append({
                    "old_code": old_code,
                    "new_code": None,
                    "old_name": old_name,
                    "new_name": None,
                    "old_section": old_class,
                    "new_section": None,
                    "map_type": "DELETED",
                    "confidence": 1.0,
                    "auto_matched": True,
                })

    # Add new accounts (not in old version)
    added_codes = new_codes - old_codes
    # Exclude codes already matched via RECODED
    recoded_new = {m["new_code"] for m in migration_map if m["map_type"] == "RECODED" and m["new_code"]}
    for code in sorted(added_codes - recoded_new):
        acct = new_version.get_account(code)
        if not acct:
            continue
        name = str(acct.get("name", "")).strip()
        migration_map.append({
            "old_code": None,
            "new_code": code,
            "old_name": None,
            "new_name": name,
            "old_section": None,
            "new_section": acct.get("main_class", ""),
            "map_type": "ADDED",
            "confidence": 1.0,
            "auto_matched": True,
        })

    logger.info(
        "Migration map built: %d entries (SAME=%d, RENAMED=%d, RECODED=%d, RECLASSIFIED=%d, DELETED=%d, ADDED=%d)",
        len(migration_map),
        sum(1 for m in migration_map if m["map_type"] == "SAME"),
        sum(1 for m in migration_map if m["map_type"] == "RENAMED"),
        sum(1 for m in migration_map if m["map_type"] == "RECODED"),
        sum(1 for m in migration_map if m["map_type"] == "RECLASSIFIED"),
        sum(1 for m in migration_map if m["map_type"] == "DELETED"),
        sum(1 for m in migration_map if m["map_type"] == "ADDED"),
    )

    return migration_map


def summarize_migration(migration_map: List[Dict]) -> Dict:
    """Summarize a migration map for reporting."""
    type_counts = {}
    for entry in migration_map:
        mt = entry["map_type"]
        type_counts[mt] = type_counts.get(mt, 0) + 1

    total = len(migration_map)
    same = type_counts.get("SAME", 0)
    stability = (same / total * 100) if total else 0

    return {
        "total_entries": total,
        "type_counts": type_counts,
        "stability_pct": round(stability, 2),
        "needs_review": sum(
            1 for m in migration_map
            if m["map_type"] in ("DELETED", "RECLASSIFIED", "RECODED")
        ),
        "auto_matched_pct": round(
            sum(1 for m in migration_map if m.get("auto_matched")) / total * 100
            if total else 0, 2
        ),
    }
