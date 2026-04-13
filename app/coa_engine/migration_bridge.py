"""
ملحق ص — COA Migration Bridge
خوارزمية بناء خريطة الهجرة بين نسختين من شجرة الحسابات.
4 مراحل مطابقة: كود مباشر → canonical_id → تشابه الاسم → ما تبقى.
"""
from __future__ import annotations

import re
import unicodedata
from typing import Dict, List, Optional, Set

# ─────────────────────────────────────────────────────────────
# Arabic normalization (lightweight, standalone)
# ─────────────────────────────────────────────────────────────
_DIACRITICS = re.compile(r"[\u064B-\u065F\u0670]")
_ALEF_VARS = re.compile(r"[إأآٱ]")
_TA_MARBUTA = re.compile(r"ة")
_YA_VARS = re.compile(r"[ىئ]")


def _norm_ar(text: str) -> str:
    """Normalize Arabic text for fuzzy comparison."""
    if not text:
        return ""
    text = _DIACRITICS.sub("", text)
    text = _ALEF_VARS.sub("ا", text)
    text = _TA_MARBUTA.sub("ه", text)
    text = _YA_VARS.sub("ي", text)
    text = unicodedata.normalize("NFKC", text)
    return re.sub(r"\s+", " ", text).strip().lower()


def _similarity(a: str, b: str) -> float:
    """Simple character-level similarity ratio."""
    if not a or not b:
        return 0.0
    na, nb = _norm_ar(a), _norm_ar(b)
    if na == nb:
        return 1.0
    # Longest common subsequence ratio
    m, n = len(na), len(nb)
    if m == 0 or n == 0:
        return 0.0
    # Use set intersection for speed (good enough for names)
    sa, sb = set(na), set(nb)
    inter = len(sa & sb)
    union = len(sa | sb)
    jaccard = inter / union if union else 0.0
    # Also check prefix match
    prefix_len = 0
    for ca, cb in zip(na, nb):
        if ca == cb:
            prefix_len += 1
        else:
            break
    prefix_ratio = prefix_len / max(m, n)
    # Weighted blend
    return 0.5 * jaccard + 0.5 * prefix_ratio


# ─────────────────────────────────────────────────────────────
# Main builder
# ─────────────────────────────────────────────────────────────
def build_migration_map(
    old_coa: List[Dict],
    new_coa: List[Dict],
    canonical_registry: Optional[Dict] = None,
) -> List[Dict]:
    """
    4 مراحل مطابقة حسب ملحق ص.3:

    المرحلة 1: كود مباشر — confidence 99%
    المرحلة 2: canonical_id — confidence 90%
    المرحلة 3: تشابه الاسم ≥ 85% — confidence 75%
    المرحلة 4: ما تبقى → DELETED
    """
    old_map: Dict[str, Dict] = {}
    for a in old_coa:
        code = str(a.get("account_code") or a.get("code") or "").strip()
        if code:
            old_map[code] = a

    new_map: Dict[str, Dict] = {}
    for a in new_coa:
        code = str(a.get("account_code") or a.get("code") or "").strip()
        if code:
            new_map[code] = a

    mappings: List[Dict] = []
    matched_old: Set[str] = set()
    matched_new: Set[str] = set()

    def _get(d: Dict, key: str, alt: str = "") -> str:
        return str(d.get(key) or d.get(alt) or "").strip()

    def _name(d: Dict) -> str:
        return _get(d, "name_raw", "name") or _get(d, "name_normalized", "name")

    def _section(d: Dict) -> str:
        return _get(d, "section")

    def _nature(d: Dict) -> str:
        return _get(d, "nature")

    def _concept(d: Dict) -> str:
        return _get(d, "concept_id")

    # ── المرحلة 1: مطابقة بالكود المباشر ──
    for code, old_acc in old_map.items():
        if code in new_map:
            new_acc = new_map[code]
            old_name = _name(old_acc)
            new_name = _name(new_acc)
            old_sec = _section(old_acc)
            new_sec = _section(new_acc)
            old_nat = _nature(old_acc)
            new_nat = _nature(new_acc)

            natures_conflict = old_nat != new_nat and old_nat and new_nat

            if natures_conflict:
                map_type = "RECLASSIFIED"
            elif old_sec != new_sec and old_sec and new_sec:
                map_type = "RECLASSIFIED"
            elif _norm_ar(old_name) != _norm_ar(new_name) and old_name and new_name:
                map_type = "RENAMED"
            else:
                map_type = "SAME"

            mappings.append({
                "old_code": code,
                "new_code": code,
                "map_type": map_type,
                "confidence": 0.99,
                "canonical_id": _concept(new_acc) or _concept(old_acc),
                "old_name": old_name,
                "new_name": new_name,
                "old_section": old_sec,
                "new_section": new_sec,
                "old_nature": old_nat,
                "new_nature": new_nat,
                "source_natures_conflict": bool(natures_conflict),
                "auto_matched": True,
            })
            matched_old.add(code)
            matched_new.add(code)

    # ── المرحلة 2: مطابقة بـ canonical_id ──
    unmatched_old = {c: a for c, a in old_map.items() if c not in matched_old}
    unmatched_new = {c: a for c, a in new_map.items() if c not in matched_new}

    # Build concept → code maps for unmatched
    old_by_concept: Dict[str, List[str]] = {}
    for code, acc in unmatched_old.items():
        cid = _concept(acc)
        if cid:
            old_by_concept.setdefault(cid, []).append(code)

    new_by_concept: Dict[str, List[str]] = {}
    for code, acc in unmatched_new.items():
        cid = _concept(acc)
        if cid:
            new_by_concept.setdefault(cid, []).append(code)

    for concept_id, old_codes in old_by_concept.items():
        if concept_id in new_by_concept:
            new_codes = new_by_concept[concept_id]
            # Simple 1:1 matching (first available)
            for oc in old_codes:
                if oc in matched_old:
                    continue
                for nc in new_codes:
                    if nc in matched_new:
                        continue
                    old_acc = old_map[oc]
                    new_acc = new_map[nc]
                    old_nat = _nature(old_acc)
                    new_nat = _nature(new_acc)
                    mappings.append({
                        "old_code": oc,
                        "new_code": nc,
                        "map_type": "RECODED",
                        "confidence": 0.90,
                        "canonical_id": concept_id,
                        "old_name": _name(old_acc),
                        "new_name": _name(new_acc),
                        "old_section": _section(old_acc),
                        "new_section": _section(new_acc),
                        "old_nature": old_nat,
                        "new_nature": new_nat,
                        "source_natures_conflict": bool(old_nat != new_nat and old_nat and new_nat),
                        "auto_matched": True,
                    })
                    matched_old.add(oc)
                    matched_new.add(nc)
                    break

    # ── المرحلة 3: مطابقة بتشابه الاسم ≥ 85% ──
    remaining_old = [(c, old_map[c]) for c in old_map if c not in matched_old]
    remaining_new = [(c, new_map[c]) for c in new_map if c not in matched_new]

    for oc, old_acc in remaining_old:
        best_score = 0.0
        best_nc = None
        best_new_acc = None
        old_name = _name(old_acc)
        if not old_name:
            continue
        for nc, new_acc in remaining_new:
            if nc in matched_new:
                continue
            new_name = _name(new_acc)
            if not new_name:
                continue
            score = _similarity(old_name, new_name)
            if score > best_score:
                best_score = score
                best_nc = nc
                best_new_acc = new_acc

        if best_score >= 0.85 and best_nc and best_new_acc:
            old_nat = _nature(old_acc)
            new_nat = _nature(best_new_acc)
            mappings.append({
                "old_code": oc,
                "new_code": best_nc,
                "map_type": "RECODED",
                "confidence": 0.75,
                "canonical_id": _concept(best_new_acc) or _concept(old_acc),
                "old_name": old_name,
                "new_name": _name(best_new_acc),
                "old_section": _section(old_acc),
                "new_section": _section(best_new_acc),
                "old_nature": old_nat,
                "new_nature": new_nat,
                "source_natures_conflict": bool(old_nat != new_nat and old_nat and new_nat),
                "auto_matched": True,
            })
            matched_old.add(oc)
            matched_new.add(best_nc)

    # ── المرحلة 4: ما تبقى ──
    for code in old_map:
        if code not in matched_old:
            old_acc = old_map[code]
            mappings.append({
                "old_code": code,
                "new_code": None,
                "map_type": "DELETED",
                "confidence": 1.0,
                "canonical_id": _concept(old_acc),
                "old_name": _name(old_acc),
                "new_name": None,
                "old_section": _section(old_acc),
                "new_section": None,
                "old_nature": _nature(old_acc),
                "new_nature": None,
                "source_natures_conflict": False,
                "auto_matched": True,
            })

    # Sort: SAME first, then by old_code
    type_order = {"SAME": 0, "RENAMED": 1, "RECODED": 2, "RECLASSIFIED": 3, "MERGED": 4, "SPLIT": 5, "DELETED": 6}
    mappings.sort(key=lambda m: (type_order.get(m["map_type"], 9), m["old_code"]))

    return mappings


# ─────────────────────────────────────────────────────────────
# TB Linkage Break Detection — ملحق ع.3
# ─────────────────────────────────────────────────────────────
_MAJOR_SECTIONS = {"asset", "current_asset", "fixed_asset", "liability", "current_liability",
                   "equity", "revenue", "expense", "cogs", "other_income", "other_expense"}

_BALANCE_SHEET = {"asset", "current_asset", "fixed_asset", "liability", "current_liability", "equity"}
_INCOME_STMT = {"revenue", "expense", "cogs", "other_income", "other_expense"}


def _section_group(section: str) -> str:
    s = (section or "").lower().strip()
    if s in _BALANCE_SHEET:
        return "balance_sheet"
    if s in _INCOME_STMT:
        return "income_statement"
    return "other"


def detect_tb_linkage_breaks(migration_map: List[Dict]) -> List[Dict]:
    """
    يكتشف تغييرات ستكسر ربط ميزان المراجعة:
    1. DELETED/RECODED → رصيد تاريخي مفقود
    2. RECLASSIFIED بين أقسام رئيسية مختلفة → تغيير ميزانية
    3. طبيعة تغيّرت → قلب إشارة الأرصدة
    """
    breaks: List[Dict] = []

    for m in migration_map:
        map_type = m.get("map_type", "")
        old_code = m.get("old_code", "")
        new_code = m.get("new_code")
        old_section = m.get("old_section", "")
        new_section = m.get("new_section", "")
        old_nature = m.get("old_nature", "")
        new_nature = m.get("new_nature", "")

        # 1. DELETED → historical balance lost
        if map_type == "DELETED":
            breaks.append({
                "account_code": old_code,
                "break_type": "ORPHANED_BALANCE",
                "severity": "High",
                "old_value": old_code,
                "new_value": None,
                "message_ar": f"الحساب {old_code} حُذف — كل الأرصدة التاريخية ستُفقد",
                "requires_journal_entry": True,
            })

        # 2. RECODED → code change needs balance migration
        elif map_type == "RECODED":
            breaks.append({
                "account_code": old_code,
                "break_type": "CODE_CHANGE",
                "severity": "Medium",
                "old_value": old_code,
                "new_value": new_code,
                "message_ar": f"الحساب {old_code} تغيّر كوده إلى {new_code} — يحتاج ترحيل الأرصدة",
                "requires_journal_entry": True,
            })

        # 3. RECLASSIFIED between major statement groups
        if map_type == "RECLASSIFIED" and old_section and new_section:
            old_group = _section_group(old_section)
            new_group = _section_group(new_section)
            if old_group != new_group:
                breaks.append({
                    "account_code": old_code,
                    "break_type": "CROSS_STATEMENT_MOVE",
                    "severity": "Critical",
                    "old_value": f"{old_section} ({old_group})",
                    "new_value": f"{new_section} ({new_group})",
                    "message_ar": (
                        f"الحساب {old_code} انتقل من {old_section} إلى {new_section}"
                        f" — تغيير في القوائم المالية التاريخية"
                    ),
                    "requires_journal_entry": True,
                })

        # 4. Nature conflict → sign reversal
        if m.get("source_natures_conflict"):
            breaks.append({
                "account_code": old_code,
                "break_type": "NATURE_REVERSAL",
                "severity": "Critical",
                "old_value": old_nature,
                "new_value": new_nature,
                "message_ar": (
                    f"الحساب {old_code} تغيّرت طبيعته من {old_nature} إلى {new_nature}"
                    f" — قلب إشارة جميع الأرصدة"
                ),
                "requires_journal_entry": True,
            })

    # Sort by severity
    sev_order = {"Critical": 0, "High": 1, "Medium": 2, "Low": 3}
    breaks.sort(key=lambda b: (sev_order.get(b["severity"], 9), b["account_code"]))

    return breaks
