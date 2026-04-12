"""
APEX COA Engine v4.2 — Processing Pipeline (Section 3)
8-step pipeline from file reception to human review queue.

Step 0: File reception + validation (XLSX/XLS/CSV, <= 10MB, <= 5000 rows)
Step 1: Detect file pattern (12 patterns)
Step 2: Map & unify columns
Step 3: Normalize data (encoding + code cleanup)
Step 4: Build hierarchy tree
Step 5: Multi-layer classification (5 layers)
Step 6: Generate quality assessment
Step 7: Determine review status
"""

import io
import time
import logging
import pandas as pd
from typing import Dict, List, Optional, Tuple, Any

from app.coa_engine.services.pattern_detector import detect_pattern
from app.coa_engine.services.column_mapper import auto_detect_and_map, validate_mapping
from app.coa_engine.services.normalizer import normalize_dataframe, detect_encoding
from app.coa_engine.services.hierarchy_builder import build_hierarchy, validate_hierarchy
from app.coa_engine.services.classifier import classify_accounts
from app.coa_engine.services.error_detector import detect_errors, summarize_errors

logger = logging.getLogger(__name__)

# Constraints
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB
MAX_ROWS = 5000
ALLOWED_EXTENSIONS = {".xlsx", ".xls", ".csv"}
MIN_QUALITY_SCORE = 65  # Minimum for auto-approval

# Quality dimension weights (must sum to 1.0)
_QUALITY_WEIGHTS = {
    "classification_accuracy": 0.30,
    "error_severity": 0.35,
    "completeness": 0.20,
    "naming_quality": 0.10,
    "code_consistency": 0.05,
}

# Grade thresholds and Arabic labels
_GRADE_THRESHOLDS = [
    (90, "A", "ممتاز"),
    (80, "B", "جيد جداً"),
    (70, "C", "جيد"),
    (60, "D", "مقبول"),
    (0, "F", "ضعيف"),
]

# Standard code prefix pattern (digits, possibly dot-separated)
_STANDARD_CODE_RE = None  # Lazy-compiled below

def _get_code_re():
    global _STANDARD_CODE_RE
    if _STANDARD_CODE_RE is None:
        import re
        _STANDARD_CODE_RE = re.compile(r"^\d[\d./-]*$")
    return _STANDARD_CODE_RE


class PipelineError(Exception):
    """Base exception for pipeline errors."""

    def __init__(self, step: int, message: str, details: dict = None):
        self.step = step
        self.message = message
        self.details = details or {}
        super().__init__(f"Step {step}: {message}")


class PipelineResult:
    """Container for pipeline processing results."""

    def __init__(self):
        self.upload_id: Optional[int] = None
        self.status: str = "pending"  # pending | processing | completed | failed | rejected
        self.pattern: Optional[str] = None
        self.erp_system: Optional[str] = None
        self.encoding: Optional[str] = None
        self.column_mapping: Dict = {}
        self.accounts: List[Dict] = []
        self.hierarchy_stats: Dict = {}
        self.quality_score: float = 0.0
        self.quality_dimensions: Dict = {}
        self.errors: List[Dict] = []  # All detected errors (Wave 2)
        self.errors_summary: Dict = {"critical": 0, "high": 0, "medium": 0, "low": 0, "total": 0}
        self.confidence_avg: float = 0.0
        self.warnings: List[str] = []
        self.processing_ms: int = 0
        self.row_count: int = 0
        self.report_card: Dict = {}
        self.review_status: str = "pending"  # auto_approved | pending_review | rejected | blocked

    def to_dict(self) -> Dict:
        """Convert to API response format (TABLE 122)."""
        return {
            "upload_id": self.upload_id,
            "status": self.status,
            "pattern_detected": self.pattern,
            "erp_system": self.erp_system,
            "encoding_detected": self.encoding,
            "processing_ms": self.processing_ms,
            "row_count": self.row_count,
            "quality_score": round(self.quality_score, 2),
            "confidence_avg": round(self.confidence_avg, 4),
            "errors": self.errors,
            "errors_summary": self.errors_summary,
            "quality_dimensions": self.quality_dimensions,
            "report_card": self.report_card,
            "review_status": self.review_status,
            "warnings": self.warnings,
            "accounts": self.accounts,
        }


# =========================================================================
# Main entry point
# =========================================================================


def process_file(file_bytes: bytes, filename: str, client_id: int = None) -> PipelineResult:
    """Run the full 8-step pipeline on an uploaded file.

    Args:
        file_bytes: Raw file content.
        filename:   Original filename (used for extension detection).
        client_id:  Optional client identifier for logging/tracking.

    Returns:
        PipelineResult with all processing outcomes.
    """
    result = PipelineResult()
    start_time = time.time()

    logger.info(
        "Pipeline started — file=%s size=%d client_id=%s",
        filename,
        len(file_bytes),
        client_id,
    )

    try:
        # Step 0: Validate
        df = _step0_validate(file_bytes, filename, result)

        # Step 1: Detect pattern
        _step1_detect_pattern(df, result)

        # Check for rejection (OPERATIONAL_INTEGRATED)
        if result.status == "rejected":
            result.processing_ms = int((time.time() - start_time) * 1000)
            logger.warning("Pipeline rejected file at step 1 — pattern=%s", result.pattern)
            return result

        # Step 2: Map columns
        _step2_map_columns(df, result)

        # Step 3: Normalize
        df = _step3_normalize(df, result)

        # Step 4: Build hierarchy
        _step4_build_hierarchy(df, result)

        # Step 5: Classify
        _step5_classify(result)

        # Step 5b: Detect errors (Wave 2)
        _step5b_detect_errors(result)

        # Step 6: Quality assessment
        _step6_assess_quality(result)

        # Step 7: Determine final status
        _step7_determine_status(result)

        result.status = "completed"

    except PipelineError as e:
        result.status = "failed"
        result.warnings.append(f"Pipeline failed at step {e.step}: {e.message}")
        logger.error("Pipeline error at step %d: %s details=%s", e.step, e.message, e.details, exc_info=True)
    except Exception as e:
        result.status = "failed"
        result.warnings.append(f"Unexpected error: {str(e)}")
        logger.error("Pipeline unexpected error: %s", e, exc_info=True)

    result.processing_ms = int((time.time() - start_time) * 1000)
    logger.info(
        "Pipeline finished — status=%s quality=%.2f ms=%d rows=%d",
        result.status,
        result.quality_score,
        result.processing_ms,
        result.row_count,
    )
    return result


def process_dataframe(df: pd.DataFrame, filename: str = "uploaded.xlsx", client_id: int = None) -> PipelineResult:
    """Process an already-loaded DataFrame (for testing/internal use).

    Skips step 0 (file validation) and runs steps 1-7 on the given DataFrame.

    Args:
        df:         Pre-loaded DataFrame.
        filename:   Logical filename for pattern detection context.
        client_id:  Optional client identifier.

    Returns:
        PipelineResult with all processing outcomes.
    """
    result = PipelineResult()
    start_time = time.time()

    if df is None or df.empty:
        result.status = "failed"
        result.warnings.append("Empty DataFrame provided")
        result.processing_ms = int((time.time() - start_time) * 1000)
        return result

    result.row_count = len(df)
    logger.info("Pipeline (DataFrame mode) started — rows=%d client_id=%s", len(df), client_id)

    try:
        # Step 1: Detect pattern
        _step1_detect_pattern(df, result)

        if result.status == "rejected":
            result.processing_ms = int((time.time() - start_time) * 1000)
            return result

        # Step 2: Map columns
        _step2_map_columns(df, result)

        # Step 3: Normalize
        df = _step3_normalize(df, result)

        # Step 4: Build hierarchy
        _step4_build_hierarchy(df, result)

        # Step 5: Classify
        _step5_classify(result)

        # Step 5b: Detect errors (Wave 2)
        _step5b_detect_errors(result)

        # Step 6: Quality assessment
        _step6_assess_quality(result)

        # Step 7: Determine final status
        _step7_determine_status(result)

        result.status = "completed"

    except PipelineError as e:
        result.status = "failed"
        result.warnings.append(f"Pipeline failed at step {e.step}: {e.message}")
        logger.error("Pipeline error at step %d: %s", e.step, e.message, exc_info=True)
    except Exception as e:
        result.status = "failed"
        result.warnings.append(f"Unexpected error: {str(e)}")
        logger.error("Pipeline unexpected error: %s", e, exc_info=True)

    result.processing_ms = int((time.time() - start_time) * 1000)
    logger.info(
        "Pipeline (DataFrame) finished — status=%s quality=%.2f ms=%d",
        result.status,
        result.quality_score,
        result.processing_ms,
    )
    return result


# =========================================================================
# Step 0: File reception + validation
# =========================================================================


def _step0_validate(file_bytes: bytes, filename: str, result: PipelineResult) -> pd.DataFrame:
    """Validate the uploaded file and read it into a DataFrame.

    Checks:
        - Extension is .xlsx, .xls, or .csv
        - File size <= 10 MB
        - File is not empty
        - Row count <= 5000
        - At least 2 rows (header + 1 data row)

    Returns:
        Parsed pd.DataFrame.

    Raises:
        PipelineError(step=0) on any validation failure.
    """
    step = 0
    logger.info("Step 0: Validating file — filename=%s size=%d bytes", filename, len(file_bytes))

    # --- Extension check ---
    import os

    ext = os.path.splitext(filename.lower())[1]
    if ext not in ALLOWED_EXTENSIONS:
        raise PipelineError(
            step=step,
            message=f"Unsupported file extension '{ext}'. Allowed: {', '.join(sorted(ALLOWED_EXTENSIONS))}",
            details={"extension": ext},
        )

    # --- Size check ---
    if len(file_bytes) > MAX_FILE_SIZE:
        size_mb = round(len(file_bytes) / (1024 * 1024), 2)
        raise PipelineError(
            step=step,
            message=f"File too large ({size_mb} MB). Maximum allowed: {MAX_FILE_SIZE // (1024 * 1024)} MB",
            details={"size_bytes": len(file_bytes), "max_bytes": MAX_FILE_SIZE},
        )

    # --- Empty file check ---
    if len(file_bytes) == 0:
        raise PipelineError(step=step, message="File is empty (0 bytes)")

    # --- Read into DataFrame ---
    try:
        if ext == ".xlsx":
            df = pd.read_excel(io.BytesIO(file_bytes), engine="openpyxl")
        elif ext == ".xls":
            df = pd.read_excel(io.BytesIO(file_bytes), engine="xlrd")
        elif ext == ".csv":
            # Detect encoding for CSV files
            encoding = detect_encoding(file_bytes)
            result.encoding = encoding
            logger.info("Step 0: CSV encoding detected as '%s'", encoding)
            df = pd.read_csv(io.BytesIO(file_bytes), encoding=encoding)
        else:
            raise PipelineError(step=step, message=f"Unhandled extension: {ext}")
    except PipelineError:
        raise
    except Exception as e:
        raise PipelineError(
            step=step,
            message=f"Failed to parse file: {str(e)}",
            details={"parse_error": str(e)},
        )

    # --- Row count checks ---
    if df.empty or len(df) < 1:
        raise PipelineError(
            step=step,
            message="File contains no data rows (only header or completely empty)",
        )

    if len(df) > MAX_ROWS:
        raise PipelineError(
            step=step,
            message=f"Too many rows ({len(df)}). Maximum allowed: {MAX_ROWS}",
            details={"row_count": len(df), "max_rows": MAX_ROWS},
        )

    result.row_count = len(df)
    logger.info("Step 0: Validation passed — %d rows, %d columns", len(df), len(df.columns))
    return df


# =========================================================================
# Step 1: Detect file pattern
# =========================================================================


def _step1_detect_pattern(df: pd.DataFrame, result: PipelineResult) -> None:
    """Detect the COA file pattern (12 patterns supported).

    Sets result.pattern, result.erp_system.
    Marks result.status = 'rejected' for OPERATIONAL_INTEGRATED.
    """
    logger.info("Step 1: Detecting file pattern...")

    detection = detect_pattern(df)

    result.pattern = detection.get("pattern", "UNKNOWN")
    result.erp_system = detection.get("erp_system")

    logger.info(
        "Step 1: Pattern=%s confidence=%.2f erp=%s reject=%s",
        result.pattern,
        detection.get("confidence", 0),
        result.erp_system,
        detection.get("reject", False),
    )

    if detection.get("reject"):
        result.status = "rejected"
        result.review_status = "rejected"
        result.warnings.append(
            f"File rejected: pattern '{result.pattern}' contains mixed operational data "
            "that cannot be processed as a Chart of Accounts (error EC5)"
        )
        return

    if result.pattern == "UNKNOWN":
        result.warnings.append(
            "Unrecognized file pattern — using generic processing. "
            "Classification accuracy may be reduced."
        )


# =========================================================================
# Step 2: Map & unify columns
# =========================================================================


def _step2_map_columns(df: pd.DataFrame, result: PipelineResult) -> None:
    """Auto-detect header row and map columns to canonical roles.

    Sets result.column_mapping. Raises PipelineError(step=2) if
    required columns (code, name) cannot be identified.
    """
    logger.info("Step 2: Mapping columns...")

    mapping_result = auto_detect_and_map(df)

    mapping = mapping_result.get("mapping", {})
    header_row = mapping_result.get("header_row", 0)
    valid = mapping_result.get("valid", False)
    map_warnings = mapping_result.get("warnings", [])

    result.column_mapping = mapping
    result.warnings.extend(map_warnings)

    if header_row > 0:
        logger.info("Step 2: Header detected at row %d (not row 0)", header_row)

    logger.info(
        "Step 2: Mapped %d columns — code=%s name=%s valid=%s",
        len(mapping),
        mapping.get("code"),
        mapping.get("name"),
        valid,
    )

    if not valid:
        missing = [r for r in ("code", "name") if r not in mapping]
        raise PipelineError(
            step=2,
            message=f"Required columns not found: {', '.join(missing)}. Cannot process file.",
            details={"mapping": mapping, "missing": missing},
        )


# =========================================================================
# Step 3: Normalize data
# =========================================================================


def _step3_normalize(df: pd.DataFrame, result: PipelineResult) -> pd.DataFrame:
    """Normalize encoding, clean codes, standardize Arabic text.

    Returns:
        Normalized DataFrame.
    """
    logger.info("Step 3: Normalizing data...")

    normalized_df = normalize_dataframe(df, result.column_mapping)

    # encoding may already be set from CSV detection in step 0
    if not result.encoding:
        result.encoding = "utf-8"  # Default for Excel files

    row_diff = len(df) - len(normalized_df) if normalized_df is not None else 0
    if row_diff > 0:
        result.warnings.append(f"Normalization removed {row_diff} invalid row(s)")
        result.row_count = len(normalized_df)

    logger.info("Step 3: Normalization complete — %d rows remaining", len(normalized_df))
    return normalized_df


# =========================================================================
# Step 4: Build hierarchy tree
# =========================================================================


def _step4_build_hierarchy(df: pd.DataFrame, result: PipelineResult) -> None:
    """Build the account hierarchy tree and validate it.

    Populates result.accounts and result.hierarchy_stats.
    """
    logger.info("Step 4: Building hierarchy tree...")

    accounts = build_hierarchy(df, result.column_mapping, result.pattern)

    if not accounts:
        result.warnings.append("Hierarchy builder returned no accounts")
        result.accounts = []
        result.hierarchy_stats = {"total": 0, "roots": 0, "orphans": 0, "cycles": 0, "max_depth": 0}
        logger.warning("Step 4: No accounts produced from hierarchy builder")
        return

    # Build a lookup dict for validate_hierarchy (expects {code: node_dict})
    hierarchy_dict = {}
    for acct in accounts:
        code = acct.get("code", "")
        if code:
            hierarchy_dict[code] = acct

    validation = validate_hierarchy(hierarchy_dict)
    result.hierarchy_stats = {
        "total": validation.get("total", 0),
        "roots": validation.get("roots", 0),
        "orphans": validation.get("orphans", 0),
        "cycles": validation.get("cycles", 0),
        "max_depth": validation.get("max_depth", 0),
    }

    # Propagate hierarchy validation warnings
    for w in validation.get("warnings", []):
        result.warnings.append(f"Hierarchy: {w}")

    result.accounts = accounts

    logger.info(
        "Step 4: Hierarchy built — %d accounts, %d roots, %d orphans, depth=%d",
        result.hierarchy_stats["total"],
        result.hierarchy_stats["roots"],
        result.hierarchy_stats["orphans"],
        result.hierarchy_stats["max_depth"],
    )


# =========================================================================
# Step 5: Multi-layer classification
# =========================================================================


def _step5_classify(result: PipelineResult) -> None:
    """Run 5-layer classification on all accounts.

    Updates result.accounts in-place with classification fields.
    Calculates result.confidence_avg.
    """
    logger.info("Step 5: Classifying %d accounts...", len(result.accounts))

    if not result.accounts:
        logger.warning("Step 5: No accounts to classify")
        return

    result.accounts = classify_accounts(
        result.accounts,
        result.column_mapping,
        result.pattern,
        result.erp_system,
    )

    # Calculate average confidence
    confidences = [
        acct.get("confidence", 0.0)
        for acct in result.accounts
        if isinstance(acct.get("confidence"), (int, float))
    ]
    result.confidence_avg = sum(confidences) / len(confidences) if confidences else 0.0

    # Count review statuses from classification
    pending_count = sum(1 for a in result.accounts if a.get("review_status") == "pending")
    auto_count = sum(1 for a in result.accounts if a.get("review_status") == "auto_approved")

    logger.info(
        "Step 5: Classification complete — avg_confidence=%.4f auto_approved=%d pending=%d",
        result.confidence_avg,
        auto_count,
        pending_count,
    )


# =========================================================================
# Step 5b: Error detection (Wave 2)
# =========================================================================


def _step5b_detect_errors(result: PipelineResult) -> None:
    """Run 58-type error detection on classified accounts.

    Populates result.errors and result.errors_summary.
    Also injects per-account error codes into each account's 'errors' field.
    """
    logger.info("Step 5b: Detecting errors on %d accounts...", len(result.accounts))

    if not result.accounts:
        logger.warning("Step 5b: No accounts to check for errors")
        return

    result.accounts, error_dicts = detect_errors(
        result.accounts,
        result.column_mapping,
        result.pattern,
        result.erp_system,
    )

    result.errors = error_dicts
    result.errors_summary = summarize_errors(error_dicts)

    logger.info(
        "Step 5b: Error detection complete — %d errors (Critical=%d, High=%d, Medium=%d, Low=%d)",
        result.errors_summary["total"],
        result.errors_summary["critical"],
        result.errors_summary["high"],
        result.errors_summary["medium"],
        result.errors_summary["low"],
    )


# =========================================================================
# Step 6: Quality assessment
# =========================================================================


def _step6_assess_quality(result: PipelineResult) -> None:
    """Calculate quality dimensions, overall score, and report card.

    Dimensions (weights):
        - classification_accuracy (0.30): % of accounts with confidence >= 0.70
        - error_severity (0.35): deductions from low-confidence accounts
        - completeness (0.20): % of accounts that received a classification
        - naming_quality (0.10): % of names normalized without issues
        - code_consistency (0.05): % of codes matching standard prefix patterns
    """
    logger.info("Step 6: Assessing quality...")

    total = len(result.accounts)
    if total == 0:
        result.quality_score = 0.0
        result.quality_dimensions = {k: 0.0 for k in _QUALITY_WEIGHTS}
        result.report_card = _build_report_card(0.0, result)
        logger.warning("Step 6: No accounts — quality score is 0")
        return

    # --- classification_accuracy: % with confidence >= 0.70 ---
    high_conf_count = sum(
        1 for a in result.accounts if a.get("confidence", 0) >= 0.70
    )
    classification_accuracy = (high_conf_count / total) * 100

    # --- error_severity: start at 100, deduct based on detected errors ---
    # Use real error counts from Step 5b (Wave 2) instead of confidence-only heuristic
    critical_count = result.errors_summary.get("critical", 0)
    high_count = result.errors_summary.get("high", 0)
    medium_count = result.errors_summary.get("medium", 0)
    low_count = result.errors_summary.get("low", 0)
    # Score impact: Critical=-15, High=-8, Medium=-3, Low=-1
    error_deduction = (critical_count * 15) + (high_count * 8) + (medium_count * 3) + (low_count * 1)
    error_severity = max(0, 100 - error_deduction)

    # --- completeness: % of accounts that got classified ---
    classified_count = sum(
        1 for a in result.accounts if a.get("main_class") is not None
    )
    completeness = (classified_count / total) * 100

    # --- naming_quality: % of names that look clean (non-empty, no encoding artifacts) ---
    clean_names = 0
    name_key = result.column_mapping.get("name", "name")
    for acct in result.accounts:
        name_val = acct.get(name_key, acct.get("name", ""))
        if isinstance(name_val, str) and len(name_val.strip()) > 0:
            # Check for encoding artifacts (replacement chars, garbled bytes)
            if "\ufffd" not in name_val and "Ã" not in name_val:
                clean_names += 1
    naming_quality = (clean_names / total) * 100

    # --- code_consistency: % of codes that match standard numeric patterns ---
    code_re = _get_code_re()
    code_key = result.column_mapping.get("code", "code")
    consistent_codes = 0
    for acct in result.accounts:
        code_val = str(acct.get(code_key, acct.get("code", ""))).strip()
        if code_val and code_re.match(code_val):
            consistent_codes += 1
    code_consistency = (consistent_codes / total) * 100

    # --- Store dimensions ---
    result.quality_dimensions = {
        "classification_accuracy": round(classification_accuracy, 2),
        "error_severity": round(error_severity, 2),
        "completeness": round(completeness, 2),
        "naming_quality": round(naming_quality, 2),
        "code_consistency": round(code_consistency, 2),
    }

    # --- Weighted overall score ---
    result.quality_score = (
        classification_accuracy * _QUALITY_WEIGHTS["classification_accuracy"]
        + error_severity * _QUALITY_WEIGHTS["error_severity"]
        + completeness * _QUALITY_WEIGHTS["completeness"]
        + naming_quality * _QUALITY_WEIGHTS["naming_quality"]
        + code_consistency * _QUALITY_WEIGHTS["code_consistency"]
    )
    # Clamp to [0, 100]
    result.quality_score = max(0.0, min(100.0, result.quality_score))

    # --- Report card ---
    result.report_card = _build_report_card(result.quality_score, result)

    logger.info(
        "Step 6: Quality score=%.2f grade=%s dimensions=%s",
        result.quality_score,
        result.report_card.get("grade", "?"),
        result.quality_dimensions,
    )


def _build_report_card(score: float, result: PipelineResult) -> Dict:
    """Generate a report card with grade, Arabic label, and executive summary."""
    grade = "F"
    label_ar = "ضعيف"

    for threshold, g, label in _GRADE_THRESHOLDS:
        if score >= threshold:
            grade = g
            label_ar = label
            break

    # Executive summary
    total = len(result.accounts)
    classified = sum(1 for a in result.accounts if a.get("main_class") is not None)
    pending = sum(1 for a in result.accounts if a.get("review_status") == "pending")

    if grade in ("A", "B"):
        summary = (
            f"Chart of Accounts processed successfully with high quality ({score:.1f}/100). "
            f"{classified}/{total} accounts classified. Ready for approval."
        )
    elif grade == "C":
        summary = (
            f"Chart of Accounts processed with acceptable quality ({score:.1f}/100). "
            f"{classified}/{total} accounts classified, {pending} need review."
        )
    elif grade == "D":
        summary = (
            f"Chart of Accounts processed with marginal quality ({score:.1f}/100). "
            f"Manual review recommended for {pending} accounts."
        )
    else:
        summary = (
            f"Chart of Accounts quality is below threshold ({score:.1f}/100). "
            f"Significant manual review required."
        )

    return {
        "grade": grade,
        "label_ar": label_ar,
        "score": round(score, 2),
        "total_accounts": total,
        "classified_accounts": classified,
        "pending_review": pending,
        "executive_summary": summary,
    }


# =========================================================================
# Step 7: Determine review status
# =========================================================================


def _step7_determine_status(result: PipelineResult) -> None:
    """Determine the overall review status based on quality and account statuses.

    Rules:
        - quality_score >= MIN_QUALITY_SCORE and no pending accounts -> auto_approved
        - Any critical errors -> blocked
        - Any accounts with review_status == 'pending' -> pending_review
        - Otherwise -> pending_review
    """
    logger.info("Step 7: Determining review status...")

    has_critical = result.errors_summary.get("critical", 0) > 0
    pending_accounts = sum(1 for a in result.accounts if a.get("review_status") == "pending")

    if has_critical and result.errors_summary["critical"] > (len(result.accounts) * 0.2):
        # More than 20% of accounts have critical errors
        result.review_status = "blocked"
        result.warnings.append(
            f"Review blocked: {result.errors_summary['critical']} account(s) with critical errors "
            f"(>{int(len(result.accounts) * 0.2)} threshold)"
        )
    elif result.quality_score >= MIN_QUALITY_SCORE and pending_accounts == 0:
        result.review_status = "auto_approved"
    elif pending_accounts > 0:
        result.review_status = "pending_review"
    else:
        result.review_status = "pending_review"

    logger.info(
        "Step 7: Review status=%s quality=%.2f pending_accounts=%d critical=%d",
        result.review_status,
        result.quality_score,
        pending_accounts,
        result.errors_summary.get("critical", 0),
    )
