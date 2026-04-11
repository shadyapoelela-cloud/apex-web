"""
APEX Sprint 1 — COA Parser
═══════════════════════════════════════════════════════════════
Converts raw rows into normalized structured records.
Per Sprint 1 Build Spec §17.2.
"""

from typing import Dict, Any, List, Optional, Tuple
from app.sprint1.services.coa.coa_normalizer import (
    normalize_text,
    normalize_account_code,
    normalize_account_name,
    normalize_normal_balance,
    normalize_active_flag,
    normalize_level,
)


class ParsedRow:
    """Result of parsing a single row."""

    def __init__(self):
        self.source_row_number: int = 0
        self.account_code: Optional[str] = None
        self.account_name_raw: Optional[str] = None
        self.account_name_normalized: Optional[str] = None
        self.parent_code: Optional[str] = None
        self.parent_name: Optional[str] = None
        self.account_level: Optional[int] = None
        self.account_type_raw: Optional[str] = None
        self.normal_balance: Optional[str] = None
        self.active_flag: bool = True
        self.notes: Optional[str] = None
        self.issues: List[str] = []
        self.record_status: str = "parsed"
        self.is_rejected: bool = False
        self.rejection_reasons: List[str] = []


class ParseResult:
    """Result of parsing an entire upload."""

    def __init__(self):
        self.parsed_rows: List[ParsedRow] = []
        self.rejected_rows: List[Dict[str, Any]] = []
        self.total_detected: int = 0
        self.total_parsed: int = 0
        self.total_rejected: int = 0
        self.warnings: List[str] = []
        self.duplicate_codes: Dict[str, int] = {}


def parse_row(raw_row: Dict[str, Any], source_row_number: int, column_mapping: Dict[str, str]) -> ParsedRow:
    """Parse a single raw row using the column mapping."""
    result = ParsedRow()
    result.source_row_number = source_row_number

    def get_val(standard_field: str) -> Any:
        raw_col = column_mapping.get(standard_field)
        if raw_col and raw_col in raw_row:
            return raw_row[raw_col]
        return None

    # account_code — always string
    result.account_code = normalize_account_code(get_val("account_code"))

    # account_name — required
    raw_name, norm_name = normalize_account_name(get_val("account_name"))
    result.account_name_raw = raw_name
    result.account_name_normalized = norm_name

    if not raw_name:
        result.is_rejected = True
        result.rejection_reasons.append("missing_account_name")
        result.record_status = "rejected"
        return result

    # parent
    result.parent_code = normalize_account_code(get_val("parent_code"))
    result.parent_name = normalize_text(get_val("parent_name"))

    # level
    level, level_issues = normalize_level(get_val("level"))
    result.account_level = level
    result.issues.extend(level_issues)

    # account_type
    result.account_type_raw = normalize_text(get_val("account_type"))

    # normal_balance
    nb, nb_issues = normalize_normal_balance(get_val("normal_balance"))
    result.normal_balance = nb
    result.issues.extend(nb_issues)

    # active_flag
    af, af_issues = normalize_active_flag(get_val("active_flag"))
    result.active_flag = af
    result.issues.extend(af_issues)

    # notes
    result.notes = normalize_text(get_val("notes"))

    # Set status based on issues
    if result.issues:
        result.record_status = "parsed_with_issue"

    # Check for blank account_code (warn but don't reject)
    if not result.account_code:
        result.issues.append("account_code_blank")

    # Parent reference check
    if result.parent_code is None and result.parent_name is None and result.account_level and result.account_level > 1:
        result.issues.append("parent_reference_incomplete")

    return result


def parse_upload(
    rows_iterator,
    column_mapping: Dict[str, str],
    max_rows: int = 100000,
) -> ParseResult:
    """Parse all rows from an upload."""
    result = ParseResult()
    code_counts: Dict[str, int] = {}
    row_num = 0

    for raw_row in rows_iterator:
        row_num += 1
        if row_num > max_rows:
            result.warnings.append(f"Row limit reached ({max_rows}). Remaining rows skipped.")
            break

        result.total_detected += 1

        # Skip completely blank rows
        values = [v for v in raw_row.values() if v is not None and str(v).strip() != ""]
        if not values:
            continue

        parsed = parse_row(raw_row, row_num, column_mapping)

        if parsed.is_rejected:
            result.rejected_rows.append(
                {
                    "source_row_number": row_num,
                    "raw_row": {k: str(v)[:200] if v else None for k, v in raw_row.items()},
                    "reasons": parsed.rejection_reasons,
                }
            )
            result.total_rejected += 1
        else:
            # Track duplicate codes
            if parsed.account_code:
                code_counts[parsed.account_code] = code_counts.get(parsed.account_code, 0) + 1
                if code_counts[parsed.account_code] > 1:
                    parsed.issues.append("duplicate_account_code_in_upload")
                    parsed.record_status = "parsed_with_issue"

            result.parsed_rows.append(parsed)
            result.total_parsed += 1

    # Add duplicate warnings
    dups = {k: v for k, v in code_counts.items() if v > 1}
    if dups:
        result.warnings.append(f"{len(dups)} duplicate account codes found in upload")
        result.duplicate_codes = dups

    if result.total_rejected > 0:
        result.warnings.append(f"{result.total_rejected} rows were rejected due to missing account_name")

    return result
