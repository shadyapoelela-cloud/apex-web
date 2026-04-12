"""
APEX COA Engine v4.2 -- Column Mapper (Appendix A)
Maps raw column names to 12 standardized roles.
"""

import logging
import re
from typing import Any, Dict, List, Optional, Tuple

logger = logging.getLogger(__name__)

REQUIRED_ROLES = ["code", "name"]
OPTIONAL_ROLES = [
    "parent_code",
    "type",
    "balance",
    "level",
    "is_posting",
    "description",
    "id",
    "account_id",
    "old_code",
    "new_code",
]

# ---------------------------------------------------------------------------
# Pattern dictionary: role -> list of regex patterns (most specific first)
# Each pattern is compiled case-insensitively after normalization.
# Arabic patterns come first so they get priority in mixed-language files.
# ---------------------------------------------------------------------------

COLUMN_PATTERNS: Dict[str, List[str]] = {
    # ── REQUIRED ──────────────────────────────────────────────────────────
    "code": [
        # Arabic (specific to general)
        r"^كود\s*الحساب$",
        r"^رقم\s*الحساب$",
        r"^رمز\s*الحساب$",
        r"^رقم\s*الحسا$",
        r"^الكود$",
        r"^الرمز$",
        r"^كود$",
        r"^كد$",
        r"^رقم$",
        # English (specific to general)
        r"^account\s*code$",
        r"^account\s*number$",
        r"^account\s*no\.?$",
        r"^account\s*id$",
        r"^acc\s*code$",
        r"^acct\s*no\.?$",
        r"^code$",
        r"^number$",
    ],
    "name": [
        # Arabic
        r"^اسم\s*الحساب$",
        r"^وصف\s*الحساب$",
        r"^عنوان\s*الحساب$",
        r"^مسمى\s*الحساب$",
        r"^الاسم$",
        r"^التسمية$",
        r"^اسم$",
        r"^بيان$",
        # English
        r"^account\s*name$",
        r"^account\s*title$",
        r"^account\s*desc$",
        r"^name$",
        r"^description$",
        r"^title$",
        r"^label$",
    ],
    # ── OPTIONAL ──────────────────────────────────────────────────────────
    "parent_code": [
        # Arabic
        r"^كود\s*الاب$",
        r"^رمز\s*الاب$",
        r"^حساب\s*الاب$",
        r"^الحساب\s*الرئيسي$",
        r"^المجموعة\s*الاب$",
        r"^parent$",
        r"^اب$",
        # English
        r"^parent\s*account\s*code$",
        r"^parent\s*account$",
        r"^parent\s*code$",
        r"^parent\s*id$",
        r"^parent\s*no\.?$",
        r"^master\s*account$",
    ],
    "type": [
        # Arabic
        r"^نوع\s*الحساب$",
        r"^طبيعة\s*الحساب$",
        r"^فئة\s*الحساب$",
        r"^النوع$",
        r"^التصنيف$",
        r"^تصنيف$",
        # English (Odoo user_type_id compatible)
        r"^account\s*type$",
        r"^user\s*type$",
        r"^account\s*class$",
        r"^type$",
        r"^category$",
        r"^classification$",
        r"^nature$",
    ],
    "balance": [
        # Arabic
        r"^الطبيعة$",
        r"^مدين\s*دائن$",
        r"^الميزان\s*الطبيعي$",
        r"^جانب\s*الحساب$",
        r"^طبيعة\s*الرصيد$",
        # English
        r"^normal\s*balance$",
        r"^balance\s*type$",
        r"^debit\s*credit$",
        r"^dr\s*cr$",
        r"^account\s*side$",
    ],
    "level": [
        # Arabic
        r"^مستوى\s*الحساب$",
        r"^المستوى$",
        r"^مستوى$",
        r"^درجة$",
        r"^مرتبة$",
        # English
        r"^account\s*level$",
        r"^hierarchy\s*level$",
        r"^level$",
        r"^degree$",
        r"^tier$",
        r"^depth$",
    ],
    "is_posting": [
        # Arabic
        r"^قيد\s*مباشر$",
        r"^قابل\s*للترحيل$",
        r"^header\s*posting$",
        r"^ترحيل$",
        r"^نهائي$",
        # English
        r"^is\s*posting$",
        r"^allow\s*posting$",
        r"^account\s*type\s*header$",
        r"^posting$",
        r"^leaf$",
        r"^reconcile$",
    ],
    "description": [
        # Arabic
        r"^بيان\s*تفصيلي$",
        r"^الوصف$",
        r"^ملاحظات$",
        r"^ملاحظة$",
        r"^تعليق$",
        r"^شرح$",
        # English
        r"^description$",
        r"^explanation$",
        r"^remarks$",
        r"^comment$",
        r"^details$",
        r"^notes$",
        r"^memo$",
    ],
    "id": [
        # Odoo-specific
        r"^external\s*id$",
        r"^xml\s*id$",
        r"^__export__$",
        r"^id$",
    ],
    "account_id": [
        # Zoho-specific
        r"^zoho\s*account\s*id$",
        r"^account\s*id$",
        r"^account_id$",
    ],
    "old_code": [
        # Arabic
        r"^الكود\s*القديم$",
        r"^الرقم\s*القديم$",
        r"^كود\s*سابق$",
        r"^الكود\s*الحالي$",
        # English
        r"^old\s*account$",
        r"^old\s*code$",
        r"^previous\s*code$",
        r"^legacy\s*code$",
        r"^from\s*code$",
    ],
    "new_code": [
        # Arabic
        r"^الكود\s*الجديد$",
        r"^الرقم\s*الجديد$",
        r"^كود\s*مقترح$",
        r"^كود\s*مستهدف$",
        # English
        r"^new\s*account$",
        r"^new\s*code$",
        r"^target\s*code$",
        r"^to\s*code$",
        r"^proposed\s*code$",
    ],
}

# Pre-compile all patterns for performance
_COMPILED_PATTERNS: Dict[str, List[re.Pattern]] = {
    role: [re.compile(p, re.IGNORECASE) for p in patterns] for role, patterns in COLUMN_PATTERNS.items()
}

# Roles ordered from most specific (fewest false positives) to least specific.
# This ensures that ambiguous columns like "description" or "id" are only
# claimed when more specific roles have already been resolved.
_ROLE_PRIORITY = [
    "old_code",
    "new_code",
    "parent_code",
    "account_id",
    "id",
    "is_posting",
    "balance",
    "level",
    "type",
    "description",
    "code",
    "name",
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_TASHKEEL_RE = re.compile(r"[\u0610-\u061A\u064B-\u065F\u0670]")
_WHITESPACE_RE = re.compile(r"[\s_]+")


def normalize_column_name(name: str) -> str:
    """Lowercase, strip, remove Arabic tashkeel, collapse whitespace/underscores."""
    if not isinstance(name, str):
        name = str(name)
    text = name.strip().lower()
    text = _TASHKEEL_RE.sub("", text)
    text = _WHITESPACE_RE.sub(" ", text)
    return text.strip()


# ---------------------------------------------------------------------------
# Core mapping
# ---------------------------------------------------------------------------


def map_columns(raw_columns: List[str]) -> Dict[str, str]:
    """
    Map a list of raw column names to standardized roles.

    Returns a dict ``{role: original_column_name}``.
    Each column can only be assigned to one role.  Roles are processed in
    priority order (most specific first) so that ambiguous names like
    ``"description"`` do not shadow more important roles.
    """
    mapping: Dict[str, str] = {}
    used_columns: set = set()

    # Build normalized lookup: normalized -> original
    norm_to_orig: Dict[str, str] = {}
    for col in raw_columns:
        norm = normalize_column_name(col)
        if norm and norm not in norm_to_orig:
            norm_to_orig[norm] = col

    for role in _ROLE_PRIORITY:
        compiled = _COMPILED_PATTERNS.get(role, [])
        for norm, orig in norm_to_orig.items():
            if orig in used_columns:
                continue
            for pattern in compiled:
                if pattern.search(norm):
                    mapping[role] = orig
                    used_columns.add(orig)
                    break
            if role in mapping:
                break

    return mapping


def validate_mapping(mapping: Dict[str, str]) -> Tuple[bool, List[str]]:
    """
    Check that all ``REQUIRED_ROLES`` are present in *mapping*.

    Returns ``(valid, missing_roles)`` where *valid* is ``True`` when
    every required role has been mapped.
    """
    missing = [r for r in REQUIRED_ROLES if r not in mapping]
    return (len(missing) == 0, missing)


# ---------------------------------------------------------------------------
# Header-row detection
# ---------------------------------------------------------------------------


def _score_row(row_values: List[Any]) -> int:
    """Return the number of values in *row_values* that match any column pattern."""
    hits = 0
    for val in row_values:
        if val is None:
            continue
        norm = normalize_column_name(str(val))
        if not norm:
            continue
        for compiled_list in _COMPILED_PATTERNS.values():
            matched = False
            for pattern in compiled_list:
                if pattern.search(norm):
                    hits += 1
                    matched = True
                    break
            if matched:
                break
    return hits


def detect_header_row(df: Any, max_rows: int = 10) -> int:
    """
    Scan the first *max_rows* rows of a DataFrame to find the row that
    best matches known column patterns.

    Returns the 0-based row index.  If row 0 (the existing header) scores
    highest, ``0`` is returned (meaning the current header is correct).
    """
    best_idx = 0
    best_score = _score_row(list(df.columns))

    scan_limit = min(max_rows, len(df))
    for i in range(scan_limit):
        row_vals = [str(v) for v in df.iloc[i].tolist()]
        score = _score_row(row_vals)
        if score > best_score:
            best_score = score
            best_idx = i + 1  # +1 because row 0 in data is row index 1 relative to header

    return best_idx


# ---------------------------------------------------------------------------
# High-level auto-detect
# ---------------------------------------------------------------------------


def auto_detect_and_map(df: Any) -> Dict[str, Any]:
    """
    Combine header detection and column mapping.

    Returns::

        {
            "mapping":    {role: col_name, ...},
            "header_row": int,
            "valid":      bool,
            "warnings":   [str, ...],
        }
    """
    warnings: List[str] = []

    # 1. Detect the real header row
    header_row = detect_header_row(df)

    # 2. If the header is not row 0, re-read with the correct header
    if header_row > 0:
        warnings.append(f"Header detected at row {header_row} (not row 0). Adjusting.")
        # Promote the detected row to column headers
        new_headers = [str(v) for v in df.iloc[header_row - 1].tolist()]
        working_df = df.iloc[header_row:].copy()
        working_df.columns = new_headers
    else:
        working_df = df

    raw_columns = [str(c) for c in working_df.columns.tolist()]

    # 3. Map columns
    mapping = map_columns(raw_columns)

    # 4. Validate
    valid, missing = validate_mapping(mapping)
    if missing:
        warnings.append(f"Missing required columns: {', '.join(missing)}")

    # 5. Warn about unmapped columns
    mapped_originals = set(mapping.values())
    unmapped = [c for c in raw_columns if c not in mapped_originals and normalize_column_name(c)]
    if unmapped:
        warnings.append(f"Unmapped columns (ignored): {', '.join(unmapped)}")

    logger.debug("Column mapping result: mapping=%s header_row=%d valid=%s", mapping, header_row, valid)

    return {
        "mapping": mapping,
        "header_row": header_row,
        "valid": valid,
        "warnings": warnings,
    }
