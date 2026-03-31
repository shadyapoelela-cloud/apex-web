"""
APEX Sprint 1 — COA Normalizer
═══════════════════════════════════════════════════════════════
Text normalization, account code cleanup, boolean parsing,
normal balance parsing, level parsing.
Per Sprint 1 Build Spec §9.3-9.7.
"""
import re
import unicodedata
from typing import Any, Optional, Tuple, List


def normalize_text(value: Any) -> Optional[str]:
    """Strip whitespace, collapse spaces, convert empty-like values to None."""
    if value is None:
        return None
    s = str(value).strip()
    # Empty-like values
    if s.lower() in ("", "none", "null", "n/a", "-", "لا يوجد", "nan", "na"):
        return None
    # Collapse multiple spaces and remove line breaks
    s = re.sub(r"[\r\n]+", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def normalize_account_code(value: Any) -> Optional[str]:
    """Keep as string, remove trailing .0 from Excel floats, preserve leading zeros."""
    if value is None:
        return None
    s = str(value).strip()
    if s.lower() in ("", "none", "null", "n/a", "-", "nan"):
        return None
    # Remove trailing .0 from Excel float codes: 1101.0 -> 1101
    if re.match(r"^\d+\.0+$", s):
        s = s.split(".")[0]
    return s


def normalize_account_name(value: Any) -> Tuple[Optional[str], Optional[str]]:
    """Return (raw, normalized). Normalized = lowercase, no diacritics, unified Arabic chars."""
    raw = normalize_text(value)
    if raw is None:
        return (None, None)
    
    # Build normalized version
    n = raw.lower()
    # Remove Arabic diacritics (tashkeel)
    n = re.sub(r"[\u0610-\u061A\u064B-\u065F\u0670]", "", n)
    # Unify common Arabic chars
    n = n.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا")
    n = n.replace("ى", "ي")
    n = n.replace("ة", "ه")
    # Remove non-meaningful punctuation
    n = re.sub(r"[()\[\]{}<>\-_/\\.,;:!?'\"#&*]+", " ", n)
    # Collapse spaces
    n = re.sub(r"\s+", " ", n).strip()
    return (raw, n)


def normalize_normal_balance(value: Any) -> Tuple[Optional[str], List[str]]:
    """Parse debit/credit from various formats. Returns (normalized, issues)."""
    issues = []
    if value is None:
        return (None, issues)
    s = str(value).strip().lower()
    if s in ("", "none", "null", "n/a", "-", "nan"):
        return (None, issues)
    
    DEBIT_VALUES = {"debit", "dr", "مدين", "مد", "d", "debet"}
    CREDIT_VALUES = {"credit", "cr", "دائن", "دا", "c", "kredit"}
    
    if s in DEBIT_VALUES:
        return ("debit", issues)
    if s in CREDIT_VALUES:
        return ("credit", issues)
    
    issues.append("invalid_normal_balance")
    return (None, issues)


def normalize_active_flag(value: Any) -> Tuple[bool, List[str]]:
    """Parse boolean from various formats. Returns (flag, issues)."""
    issues = []
    if value is None:
        issues.append("active_flag_defaulted")
        return (True, issues)
    
    s = str(value).strip().lower()
    if s in ("", "none", "null", "nan"):
        issues.append("active_flag_defaulted")
        return (True, issues)
    
    TRUE_VALUES = {"true", "1", "yes", "active", "نعم", "مفعل", "فعال", "صح"}
    FALSE_VALUES = {"false", "0", "no", "inactive", "لا", "غير مفعل", "معطل", "خطأ"}
    
    if s in TRUE_VALUES:
        return (True, issues)
    if s in FALSE_VALUES:
        return (False, issues)
    
    issues.append("active_flag_defaulted")
    return (True, issues)


def normalize_level(value: Any) -> Tuple[Optional[int], List[str]]:
    """Parse integer level. Returns (level, issues)."""
    issues = []
    if value is None:
        return (None, issues)
    s = str(value).strip()
    if s in ("", "none", "null", "nan"):
        return (None, issues)
    try:
        # Handle float: 2.0 -> 2
        return (int(float(s)), issues)
    except (ValueError, TypeError):
        issues.append("invalid_account_level")
        return (None, issues)
