"""
APEX COA Engine v4.2 — File Pattern Detection (Section 2)
Detects 12 patterns in strict specificity order.
"""

import re
import unicodedata
from typing import Dict, List, Optional, Tuple

import pandas as pd

# 12 patterns in detection order (most specific -> least specific)
PATTERNS = [
    "OPERATIONAL_INTEGRATED",      # Mixed data, 14+ cols -> REJECT with EC5
    "ZOHO_BOOKS",                  # 19-digit Account ID + parent by name
    "MIGRATION_FILE",              # Old + New code columns
    "ACCOUNTS_WITH_JOURNALS",      # COA + Journal Entries mixed
    "HORIZONTAL_HIERARCHY",        # Each level in separate column + NaN-heavy
    "SPARSE_COLUMNAR_HIERARCHY",   # Levels in columns with NaN > 50%
    "HIERARCHICAL_TEXT_PARENT",    # Parent as "1101 - Cash" text
    "HIERARCHICAL_NUMERIC_PARENT", # Numeric parent_code column
    "ODOO_WITH_ID",                # Odoo + __export__.account_account_XXX
    "ENGLISH_WITH_CLASS",          # Account Number + Class field
    "ODOO_FLAT",                   # Flat Odoo export: code/name/type
    "GENERIC_FLAT",                # Code + name only
]

# ---------------------------------------------------------------------------
# Arabic tashkeel stripping
# ---------------------------------------------------------------------------
_TASHKEEL_RE = re.compile(r"[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E4\u06E7\u06E8\u06EA-\u06ED]")


def _strip_tashkeel(text: str) -> str:
    """Remove Arabic diacritical marks (tashkeel) from *text*."""
    return _TASHKEEL_RE.sub("", text)


# ---------------------------------------------------------------------------
# Column-matching helpers
# ---------------------------------------------------------------------------

def _normalize(text: str) -> str:
    """Lowercase, strip whitespace and tashkeel for comparison."""
    return _strip_tashkeel(str(text).strip().lower())


def _has_column(columns: List[str], patterns: List[str]) -> bool:
    """Return ``True`` if *any* column matches *any* pattern (regex)."""
    for col in columns:
        norm = _normalize(col)
        for pat in patterns:
            if re.search(pat, norm):
                return True
    return False


def _find_column(columns: List[str], patterns: List[str]) -> Optional[str]:
    """Return the first column name matching any pattern, or ``None``."""
    for col in columns:
        norm = _normalize(col)
        for pat in patterns:
            if re.search(pat, norm):
                return col
    return None


def _find_column_index(columns: List[str], patterns: List[str]) -> Optional[int]:
    """Return the index of the first column matching any pattern, or ``None``."""
    for idx, col in enumerate(columns):
        norm = _normalize(col)
        for pat in patterns:
            if re.search(pat, norm):
                return idx
    return None


def _nan_ratio(df: pd.DataFrame, col: str) -> float:
    """Return the fraction of NaN / empty values in *col* (0.0 .. 1.0)."""
    if col not in df.columns:
        return 1.0
    series = df[col]
    null_count = series.isna().sum() + (series.astype(str).str.strip() == "").sum()
    return float(null_count) / max(len(series), 1)


def _count_matching_columns(columns: List[str], patterns: List[str]) -> int:
    """Count how many columns match at least one pattern."""
    count = 0
    for col in columns:
        norm = _normalize(col)
        for pat in patterns:
            if re.search(pat, norm):
                count += 1
                break
    return count


# ---------------------------------------------------------------------------
# Shared column-name pattern lists
# ---------------------------------------------------------------------------
_ACCOUNT_CODE_PATTERNS = [
    r"(account|حساب).*(code|كود|رقم|رمز)",
    r"(code|كود|رقم|رمز).*(account|حساب)",
    r"^(code|كود|رقم الحساب|account.?code|account.?number|account.?no)$",
    r"^رقم$",
]

_ACCOUNT_NAME_PATTERNS = [
    r"(account|حساب).*(name|اسم|وصف)",
    r"(name|اسم).*(account|حساب)",
    r"^(name|اسم|اسم الحساب|account.?name|description)$",
]

_PARENT_PATTERNS = [
    r"parent",
    r"الحساب.*(الاب|الرئيسي|الام)",
    r"(اب|رئيسي|ام).*(حساب|كود)",
    r"parent.*(code|account|id)",
]


# ---------------------------------------------------------------------------
# Result builder
# ---------------------------------------------------------------------------

def _result(
    pattern: str,
    confidence: float,
    erp_system: Optional[str] = None,
    details: Optional[Dict] = None,
    reject: bool = False,
) -> Dict:
    """Build a standardised result dict."""
    return {
        "pattern": pattern,
        "confidence": confidence,
        "erp_system": erp_system,
        "details": details or {},
        "reject": reject,
    }


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def detect_pattern(df: pd.DataFrame) -> Dict:
    """
    Detect the file pattern of a COA upload DataFrame.

    Detectors run in strict specificity order so the most specific pattern
    wins.  Returns::

        {
            'pattern':    str,        # one of PATTERNS or 'UNKNOWN'
            'confidence': float,      # 0.0 .. 1.0
            'erp_system': str | None, # e.g. 'Zoho Books', 'Odoo'
            'details':    dict,       # detector-specific metadata
            'reject':     bool,       # True for OPERATIONAL_INTEGRATED
        }
    """
    columns = [str(c).strip().lower() for c in df.columns]
    col_count = len(columns)
    row_count = len(df)

    detectors = [
        _detect_operational_integrated,
        _detect_zoho_books,
        _detect_migration_file,
        _detect_accounts_with_journals,
        _detect_horizontal_hierarchy,
        _detect_sparse_columnar,
        _detect_text_parent,
        _detect_numeric_parent,
        _detect_odoo_with_id,
        _detect_english_class,
        _detect_odoo_flat,
        _detect_generic_flat,
    ]

    for detector in detectors:
        result = detector(df, columns, col_count, row_count)
        if result is not None:
            return result

    return _result("UNKNOWN", 0.0, details={"reason": "No pattern matched"})


# ===================================================================
# Individual detectors (1-12)
# ===================================================================

# 1 ---------------------------------------------------------------
def _detect_operational_integrated(
    df: pd.DataFrame,
    columns: List[str],
    col_count: int,
    row_count: int,
) -> Optional[Dict]:
    """
    OPERATIONAL_INTEGRATED: mixed operational data with 14+ columns.

    Signals: date columns, amount/debit/credit columns, journal/voucher
    references all present in the same sheet.  This is NOT a chart of
    accounts -- reject with error code EC5.
    """
    if col_count < 14:
        return None

    date_patterns = [r"date", r"تاريخ", r"period", r"فترة"]
    amount_patterns = [r"amount", r"مبلغ", r"debit", r"credit", r"مدين", r"دائن", r"balance", r"رصيد"]
    journal_patterns = [r"journal", r"قيد", r"voucher", r"سند", r"reference", r"مرجع", r"entry"]

    has_dates = _has_column(columns, date_patterns)
    has_amounts = _has_column(columns, amount_patterns)
    has_journals = _has_column(columns, journal_patterns)

    if has_dates and has_amounts and has_journals:
        return _result(
            "OPERATIONAL_INTEGRATED",
            0.95,
            erp_system=None,
            details={
                "col_count": col_count,
                "has_dates": True,
                "has_amounts": True,
                "has_journals": True,
                "error_code": "EC5",
                "reason": "File contains mixed operational data (dates, amounts, journal references)",
            },
            reject=True,
        )
    return None


# 2 ---------------------------------------------------------------
def _detect_zoho_books(
    df: pd.DataFrame,
    columns: List[str],
    col_count: int,
    row_count: int,
) -> Optional[Dict]:
    """
    ZOHO_BOOKS: Zoho Books export with 19-digit Account IDs and
    parent-by-name linking.
    """
    # Check column names for Zoho signals
    zoho_name_hit = _has_column(columns, [r"account_id", r"zoho", r"account\s*id"])

    # Check for 19-digit numeric IDs in any column
    id_col: Optional[str] = None
    for col_name in df.columns:
        sample = df[col_name].dropna().head(10)
        if sample.empty:
            continue
        str_vals = sample.astype(str).str.strip()
        match_count = str_vals.str.match(r"^\d{17,19}$").sum()
        if match_count >= min(3, len(sample)):
            id_col = str(col_name)
            break

    if id_col is not None or zoho_name_hit:
        confidence = 0.90 if (id_col and zoho_name_hit) else 0.75
        return _result(
            "ZOHO_BOOKS",
            confidence,
            erp_system="Zoho Books",
            details={
                "id_column": id_col,
                "zoho_keyword_in_headers": zoho_name_hit,
            },
        )
    return None


# 3 ---------------------------------------------------------------
def _detect_migration_file(
    df: pd.DataFrame,
    columns: List[str],
    col_count: int,
    row_count: int,
) -> Optional[Dict]:
    """
    MIGRATION_FILE: contains both old-code and new-code columns,
    indicating a chart migration / mapping file.
    """
    old_patterns = [
        r"الكود\s*القديم",
        r"old\s*code",
        r"legacy\s*code",
        r"from\s*code",
        r"old\s*account",
        r"الحساب\s*القديم",
    ]
    new_patterns = [
        r"الكود\s*الجديد",
        r"new\s*code",
        r"target\s*code",
        r"to\s*code",
        r"new\s*account",
        r"الحساب\s*الجديد",
    ]

    old_col = _find_column(columns, old_patterns)
    new_col = _find_column(columns, new_patterns)

    if old_col is not None and new_col is not None:
        return _result(
            "MIGRATION_FILE",
            0.92,
            erp_system=None,
            details={"old_column": old_col, "new_column": new_col},
        )
    return None


# 4 ---------------------------------------------------------------
def _detect_accounts_with_journals(
    df: pd.DataFrame,
    columns: List[str],
    col_count: int,
    row_count: int,
) -> Optional[Dict]:
    """
    ACCOUNTS_WITH_JOURNALS: a COA sheet that also contains journal /
    transaction columns (debit, credit, journal reference).
    """
    journal_cols = [r"debit", r"credit", r"مدين", r"دائن", r"journal", r"قيد"]
    account_cols = _ACCOUNT_CODE_PATTERNS + _ACCOUNT_NAME_PATTERNS

    has_journal = _has_column(columns, journal_cols)
    has_account = _has_column(columns, account_cols)

    if has_journal and has_account:
        # Check that debit/credit columns actually contain numeric data
        debit_col = _find_column(columns, [r"debit", r"مدين"])
        credit_col = _find_column(columns, [r"credit", r"دائن"])
        has_numeric_amounts = False
        for tc in [debit_col, credit_col]:
            if tc is not None:
                actual_col = df.columns[columns.index(tc)]
                numeric_vals = pd.to_numeric(df[actual_col], errors="coerce").dropna()
                if len(numeric_vals) > 0:
                    has_numeric_amounts = True
                    break

        if has_numeric_amounts:
            return _result(
                "ACCOUNTS_WITH_JOURNALS",
                0.88,
                erp_system=None,
                details={
                    "has_debit_credit": True,
                    "has_account_columns": True,
                },
            )
    return None


# 5 ---------------------------------------------------------------
def _detect_horizontal_hierarchy(
    df: pd.DataFrame,
    columns: List[str],
    col_count: int,
    row_count: int,
) -> Optional[Dict]:
    """
    HORIZONTAL_HIERARCHY: each hierarchy level occupies its own column,
    with heavy NaN usage (accounts only appear at their level).
    """
    level_patterns = [
        r"المستوى\s*\d",
        r"المستوى\s*(الاول|الثاني|الثالث|الرابع|الخامس)",
        r"level\s*\d",
        r"الحساب\s*الرئيسي",
        r"main\s*account",
        r"sub\s*account",
        r"الحساب\s*الفرعي",
    ]

    matching = _count_matching_columns(columns, level_patterns)
    if matching < 2:
        return None

    # Verify high NaN ratio across level columns
    high_nan_count = 0
    for idx, col in enumerate(columns):
        norm = _normalize(col)
        for pat in level_patterns:
            if re.search(pat, norm):
                ratio = _nan_ratio(df, df.columns[idx])
                if ratio > 0.50:
                    high_nan_count += 1
                break

    if high_nan_count >= 2:
        return _result(
            "HORIZONTAL_HIERARCHY",
            0.88,
            erp_system=None,
            details={
                "level_columns_found": matching,
                "high_nan_columns": high_nan_count,
            },
        )
    return None


# 6 ---------------------------------------------------------------
def _detect_sparse_columnar(
    df: pd.DataFrame,
    columns: List[str],
    col_count: int,
    row_count: int,
) -> Optional[Dict]:
    """
    SPARSE_COLUMNAR_HIERARCHY: similar to horizontal hierarchy but less
    structured.  Columns contain "level" / "مستوى" keywords with overall
    high NaN ratio (>50%).
    """
    level_kw = [r"level", r"مستوى"]
    matching = _count_matching_columns(columns, level_kw)
    if matching < 2:
        return None

    # Overall NaN ratio across the entire DataFrame
    total_cells = df.shape[0] * df.shape[1]
    if total_cells == 0:
        return None
    total_nan = df.isna().sum().sum() + (df.astype(str) == "").sum().sum()
    overall_ratio = float(total_nan) / total_cells

    if overall_ratio > 0.50:
        return _result(
            "SPARSE_COLUMNAR_HIERARCHY",
            0.82,
            erp_system=None,
            details={
                "level_keyword_columns": matching,
                "overall_nan_ratio": round(overall_ratio, 3),
            },
        )
    return None


# 7 ---------------------------------------------------------------
def _detect_text_parent(
    df: pd.DataFrame,
    columns: List[str],
    col_count: int,
    row_count: int,
) -> Optional[Dict]:
    """
    HIERARCHICAL_TEXT_PARENT: parent column values contain
    ``"1101 - Cash"`` or ``"1100 \u2013 \u0646\u0642\u062f"`` style text (code + separator + name).
    """
    parent_col_idx = _find_column_index(columns, _PARENT_PATTERNS)
    if parent_col_idx is None:
        return None

    actual_col = df.columns[parent_col_idx]
    sample = df[actual_col].dropna().head(20).astype(str).str.strip()
    if sample.empty:
        return None

    # Pattern: digits, optional spaces, separator (- or -- or \u2013 or \u2014), optional spaces, text
    text_parent_re = re.compile(r"^\d+\s*[-\u2013\u2014]+\s*\S")
    match_count = sample.apply(lambda v: bool(text_parent_re.search(v))).sum()

    if match_count >= min(3, len(sample)):
        return _result(
            "HIERARCHICAL_TEXT_PARENT",
            0.85,
            erp_system=None,
            details={
                "parent_column": str(actual_col),
                "text_parent_matches": int(match_count),
                "sample_size": len(sample),
            },
        )
    return None


# 8 ---------------------------------------------------------------
def _detect_numeric_parent(
    df: pd.DataFrame,
    columns: List[str],
    col_count: int,
    row_count: int,
) -> Optional[Dict]:
    """
    HIERARCHICAL_NUMERIC_PARENT: parent column with purely numeric codes
    (no accompanying text).
    """
    parent_col_idx = _find_column_index(columns, _PARENT_PATTERNS)
    if parent_col_idx is None:
        return None

    actual_col = df.columns[parent_col_idx]
    non_null = df[actual_col].dropna()
    if non_null.empty:
        return None

    sample = non_null.head(20).astype(str).str.strip()
    numeric_re = re.compile(r"^\d+$")
    match_count = sample.apply(lambda v: bool(numeric_re.match(v))).sum()

    if match_count >= min(3, len(sample)):
        return _result(
            "HIERARCHICAL_NUMERIC_PARENT",
            0.85,
            erp_system=None,
            details={
                "parent_column": str(actual_col),
                "numeric_matches": int(match_count),
                "sample_size": len(sample),
            },
        )
    return None


# 9 ---------------------------------------------------------------
def _detect_odoo_with_id(
    df: pd.DataFrame,
    columns: List[str],
    col_count: int,
    row_count: int,
) -> Optional[Dict]:
    """
    ODOO_WITH_ID: Odoo export containing ``__export__`` identifiers
    (e.g. ``__export__.account_account_42``).
    """
    # Check for __export__ pattern in column names
    export_col = _find_column(columns, [r"__export__", r"external\s*id", r"id/external"])

    # Also check cell values in "id" or first column
    id_col_idx = _find_column_index(columns, [r"^id$", r"^\.id$", r"external.?id"])
    export_in_data = False
    check_idx = id_col_idx if id_col_idx is not None else 0

    if check_idx < len(df.columns):
        sample = df.iloc[:, check_idx].dropna().head(10).astype(str)
        export_in_data = sample.str.contains(r"__export__", regex=True).any()
        if not export_in_data:
            export_in_data = sample.str.contains(r"account\.account_\d+", regex=True).any()

    if export_col is not None or export_in_data:
        return _result(
            "ODOO_WITH_ID",
            0.90,
            erp_system="Odoo",
            details={
                "export_column": export_col,
                "export_in_data": export_in_data,
            },
        )
    return None


# 10 --------------------------------------------------------------
def _detect_english_class(
    df: pd.DataFrame,
    columns: List[str],
    col_count: int,
    row_count: int,
) -> Optional[Dict]:
    """
    ENGLISH_WITH_CLASS: English COA with Account Number + Class /
    Classification column.
    """
    class_patterns = [r"^class$", r"account\s*class", r"classification", r"^type$"]
    number_patterns = [r"account\s*number", r"account\s*no", r"account\s*#", r"acct\s*no"]

    has_class = _has_column(columns, class_patterns)
    has_number = _has_column(columns, number_patterns)

    if has_class and has_number:
        return _result(
            "ENGLISH_WITH_CLASS",
            0.85,
            erp_system=None,
            details={
                "class_column": _find_column(columns, class_patterns),
                "number_column": _find_column(columns, number_patterns),
            },
        )
    return None


# 11 --------------------------------------------------------------
def _detect_odoo_flat(
    df: pd.DataFrame,
    columns: List[str],
    col_count: int,
    row_count: int,
) -> Optional[Dict]:
    """
    ODOO_FLAT: flat Odoo export with code, name, and account type columns
    but no hierarchy / parent columns.
    """
    code_hit = _has_column(columns, [r"^code$", r"account.?code"])
    name_hit = _has_column(columns, [r"^name$", r"account.?name"])
    type_hit = _has_column(columns, [r"user_type", r"account.?type", r"internal.?type"])
    parent_hit = _has_column(columns, _PARENT_PATTERNS)

    if code_hit and name_hit and type_hit and not parent_hit:
        return _result(
            "ODOO_FLAT",
            0.82,
            erp_system="Odoo",
            details={
                "code_column": _find_column(columns, [r"^code$", r"account.?code"]),
                "name_column": _find_column(columns, [r"^name$", r"account.?name"]),
                "type_column": _find_column(columns, [r"user_type", r"account.?type", r"internal.?type"]),
            },
        )
    return None


# 12 --------------------------------------------------------------
def _detect_generic_flat(
    df: pd.DataFrame,
    columns: List[str],
    col_count: int,
    row_count: int,
) -> Optional[Dict]:
    """
    GENERIC_FLAT: fallback pattern -- at minimum a code column and a name
    column are present.
    """
    code_hit = _has_column(columns, _ACCOUNT_CODE_PATTERNS + [r"^code$"])
    name_hit = _has_column(columns, _ACCOUNT_NAME_PATTERNS + [r"^name$"])

    if code_hit and name_hit:
        return _result(
            "GENERIC_FLAT",
            0.70,
            erp_system=None,
            details={
                "code_column": _find_column(columns, _ACCOUNT_CODE_PATTERNS + [r"^code$"]),
                "name_column": _find_column(columns, _ACCOUNT_NAME_PATTERNS + [r"^name$"]),
            },
        )
    return None
