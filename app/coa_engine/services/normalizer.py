"""
APEX COA Engine v4.2 — Normalizer (Section 6.3 + Appendix B)
Arabic encoding detection + account code normalization.
"""

import re
import unicodedata
from typing import Dict, List, Optional, Tuple


# ---------------------------------------------------------------------------
# Arabic Unicode ranges
# ---------------------------------------------------------------------------
_ARABIC_BLOCK = re.compile(r"[\u0600-\u06FF]")

# Tashkeel (diacritics) to strip during name normalization
_TASHKEEL = re.compile(
    r"[\u0610-\u061A\u064B-\u065F\u0670]"
)

# Parenthetical notes to remove — e.g. "(ملغي)" or "(cancelled)"
_PAREN_NOTE = re.compile(r"\s*\(.*?\)\s*")

# Non-numeric prefix pattern — e.g. "ACC-", "حساب-"
_NON_NUMERIC_PREFIX = re.compile(r"^[^\d]+[-–—]\s*")

# Dash-separated numeric segments — e.g. "1-1-0-0"
_DASH_SEPARATED = re.compile(r"^\d+(-\d+){1,}$")

# Scientific notation — e.g. "1.1e3", "2.5E+4"
_SCIENTIFIC = re.compile(r"^[+-]?\d+(\.\d+)?[eE][+-]?\d+$")

# Arabic letter normalizations: target -> set of source chars
_ARABIC_NORM_MAP: Dict[str, str] = {
    "\u064A": "\u0649",           # ى → ي
    "\u0647": "\u0629",           # ة → ه
    "\u0627": "\u0623\u0625\u0622",  # أ إ آ → ا
}

# Build a single translation table for Arabic letter normalization
_ARABIC_TRANS = str.maketrans(
    {src: tgt for tgt, sources in _ARABIC_NORM_MAP.items() for src in sources}
)


# =========================================================================
# A. Arabic Encoding Detection
# =========================================================================

# BOM markers
_BOM_UTF8 = b"\xef\xbb\xbf"
_BOM_UTF16_LE = b"\xff\xfe"
_BOM_UTF16_BE = b"\xfe\xff"

# Candidate encodings tried in order after BOM check
_CANDIDATE_ENCODINGS: List[str] = [
    "utf-8",
    "windows-1256",
    "iso-8859-6",
    "cp720",
]


def _contains_arabic(text: str) -> bool:
    """Return True if *text* contains at least one Arabic-block character."""
    return bool(_ARABIC_BLOCK.search(text))


def detect_encoding(file_bytes: bytes) -> str:
    """Detect the most likely encoding for *file_bytes*.

    Detection strategy (ordered):
    1. BOM markers (UTF-8 BOM, UTF-16 LE/BE).
    2. Attempt UTF-8 decode — accept if Arabic characters are present.
    3. Attempt Windows-1256 decode — accept if Arabic characters are present.
    4. Attempt ISO-8859-6 decode.
    5. Fallback to ``'utf-8'``.

    Args:
        file_bytes: Raw bytes read from a file.

    Returns:
        An encoding name suitable for ``bytes.decode()``.
    """
    if not file_bytes:
        return "utf-8"

    # 1. Check BOM markers
    if file_bytes[:3] == _BOM_UTF8:
        return "utf-8-sig"
    if file_bytes[:2] == _BOM_UTF16_LE:
        return "utf-16-le"
    if file_bytes[:2] == _BOM_UTF16_BE:
        return "utf-16-be"

    # 2-4. Try candidate encodings
    for enc in _CANDIDATE_ENCODINGS:
        try:
            decoded = file_bytes.decode(enc)
            if _contains_arabic(decoded):
                return enc
        except (UnicodeDecodeError, LookupError):
            continue

    # 5. Fallback
    return "utf-8"


def read_file_with_encoding(file_path: str) -> Tuple[str, str]:
    """Read a file and return its decoded text along with the detected encoding.

    Args:
        file_path: Path to the file on disk.

    Returns:
        A tuple ``(decoded_text, encoding_used)``.

    Raises:
        FileNotFoundError: If *file_path* does not exist.
        UnicodeDecodeError: If decoding fails even with the detected encoding.
    """
    with open(file_path, "rb") as fh:
        raw = fh.read()

    encoding = detect_encoding(raw)

    # For BOM-based encodings the codec handles stripping automatically
    decoded = raw.decode(encoding)
    return decoded, encoding


# =========================================================================
# B. Account Code Normalization  (Section 6.3-A — 10 cases)
# =========================================================================


def normalize_code(raw_code: object) -> str:
    """Normalize a raw account code into a canonical string form.

    Handles the ten messy-format cases from Section 6.3-A:

    1. Convert to string and strip whitespace.
    2. Float trailing ``.0`` removal (``"1100.0"`` -> ``"1100"``).
    3. Scientific notation expansion (``"1.1e3"`` -> ``"1100"``).
    4. Strip surrounding quotes.
    5. Strip leading zeros when the remaining numeric part is >= 3 digits.
    6. Remove non-numeric prefixes (``"ACC-1100"`` -> ``"1100"``).
    7. Join dash-separated segments (``"1-1-0-0"`` -> ``"1100"``).
    8. Preserve dot-separated hierarchical codes as-is (``"1.1.0.0"``).
    9. Remove Unicode control characters.
    10. Return empty string if no digits remain.

    Args:
        raw_code: The raw value (str, int, float, or other).

    Returns:
        The normalised account code string, or ``""`` if invalid.
    """
    if raw_code is None:
        return ""

    code = str(raw_code).strip()

    if not code:
        return ""

    # 9. Strip Unicode control characters (Cc category) early
    code = "".join(ch for ch in code if unicodedata.category(ch) != "Cc")

    # 4. Remove surrounding quotes (single or double)
    code = code.strip("'\"")

    # 3. Scientific notation → integer string
    if _SCIENTIFIC.match(code):
        try:
            val = float(code)
            if val == int(val):
                code = str(int(val))
            else:
                code = str(val)
        except (ValueError, OverflowError):
            pass

    # 2. Float trailing ".0" removal
    if re.match(r"^-?\d+\.0+$", code):
        code = code.split(".")[0]

    # 6. Remove non-numeric prefixes like "ACC-" or "حساب-"
    code = _NON_NUMERIC_PREFIX.sub("", code)

    # 7. Dash-separated numeric segments → join (must check BEFORE leading-zero strip)
    if _DASH_SEPARATED.match(code):
        code = code.replace("-", "")

    # 5. Strip leading zeros only when remaining numeric part is >= 3 digits
    if re.match(r"^0+\d{3,}$", code):
        code = code.lstrip("0") or code  # keep at least the original if all zeros

    # 8. Dot-separated hierarchical codes are kept as-is (no transformation)
    #    — they contain dots but are NOT floats / scientific notation

    # 10. Return empty string if result contains no digits
    if not re.search(r"\d", code):
        return ""

    return code


def normalize_account_name(raw_name: str) -> str:
    """Normalize an Arabic/English account name.

    Steps:
    1. Strip leading/trailing whitespace.
    2. Remove Arabic tashkeel (diacritical marks).
    3. Normalize Arabic letter variants (ى→ي, ة→ه, أ/إ/آ→ا).
    4. Collapse multiple whitespace characters into a single space.
    5. Remove surrounding quotes and parenthetical notes such as
       ``(ملغي)`` or ``(cancelled)``.

    Args:
        raw_name: The raw account name string.

    Returns:
        The cleaned, normalized name.
    """
    if not raw_name:
        return ""

    name = raw_name.strip()

    # 2. Remove tashkeel
    name = _TASHKEEL.sub("", name)

    # 3. Normalize Arabic letter variants
    name = name.translate(_ARABIC_TRANS)

    # 4. Collapse whitespace
    name = re.sub(r"\s+", " ", name).strip()

    # 5. Strip quotes
    name = name.strip("'\"")

    # 5b. Remove parenthetical notes
    name = _PAREN_NOTE.sub("", name).strip()

    return name


def normalize_dataframe(
    df: "object",
    column_mapping: Dict[str, str],
) -> "object":
    """Apply code and name normalization to a pandas DataFrame.

    The *column_mapping* maps **logical** column names to **actual** column
    names in *df*.  Recognised logical names:

    * ``"code"``        — account code column (normalized via :func:`normalize_code`).
    * ``"name"``        — account name column (normalized; original kept as ``name_raw``).
    * ``"parent_code"`` — optional parent code column (normalized via :func:`normalize_code`).

    Example::

        mapping = {"code": "AcctNo", "name": "AcctName", "parent_code": "ParentNo"}
        df = normalize_dataframe(df, mapping)

    Args:
        df: A :class:`pandas.DataFrame`.
        column_mapping: Mapping of logical names to actual DataFrame column names.

    Returns:
        The modified DataFrame with normalized columns and an added
        ``name_normalized`` column (if a ``"name"`` mapping was provided).
    """
    import pandas as pd  # local import — pandas is heavy

    if not isinstance(df, pd.DataFrame):
        raise TypeError(f"Expected pandas DataFrame, got {type(df).__name__}")

    # Normalize code column
    code_col = column_mapping.get("code")
    if code_col and code_col in df.columns:
        df[code_col] = df[code_col].apply(normalize_code)

    # Normalize name column — keep original as 'name_raw'
    name_col = column_mapping.get("name")
    if name_col and name_col in df.columns:
        df["name_raw"] = df[name_col]
        df["name_normalized"] = df[name_col].astype(str).apply(normalize_account_name)

    # Normalize parent_code column
    parent_col = column_mapping.get("parent_code")
    if parent_col and parent_col in df.columns:
        df[parent_col] = df[parent_col].apply(normalize_code)

    return df
