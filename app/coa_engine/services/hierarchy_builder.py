"""
APEX COA Engine v4.2 — Hierarchy Builder (Section 3.1)
Builds hierarchical tree from any pattern using:
1. Explicit parent_code column (most reliable)
2. Code prefix matching (e.g., 1100 is child of 11, 11 is child of 1)
3. Level column + sequential ordering
4. Horizontal hierarchy columns
"""

import logging
import re
from collections import defaultdict, deque
from typing import Dict, List, Optional, Set, Tuple

import pandas as pd

logger = logging.getLogger(__name__)

# Patterns that use parent_code column directly
_PARENT_COLUMN_PATTERNS = {
    "HIERARCHICAL_NUMERIC_PARENT",
    "ODOO_WITH_ID",
    "ODOO_FLAT",
    "ZOHO_BOOKS",
}

# Patterns that use text-format parent ("1101 - Cash")
_TEXT_PARENT_PATTERNS = {
    "HIERARCHICAL_TEXT_PARENT",
}

# Patterns that use horizontal level columns
_HORIZONTAL_PATTERNS = {
    "HORIZONTAL_HIERARCHY",
    "SPARSE_COLUMNAR_HIERARCHY",
}

# Patterns that use pure prefix matching
_PREFIX_PATTERNS = {
    "GENERIC_FLAT",
    "ENGLISH_WITH_CLASS",
    "ACCOUNTS_WITH_JOURNALS",
}

# Rejected pattern — skip entirely
_REJECTED_PATTERNS = {
    "OPERATIONAL_INTEGRATED",
}

# Regex to extract numeric code prefix from text like "1101 - Cash" or "1101 – نقدية"
_TEXT_PARENT_RE = re.compile(r"^(\d+)\s*[-\u2013\u2014]\s*")

# Maximum hierarchy depth before warning
_MAX_SAFE_DEPTH = 10


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def build_hierarchy(
    df: pd.DataFrame,
    column_mapping: Dict[str, str],
    pattern: str,
) -> List[Dict]:
    """Build account hierarchy from *df* using detected *column_mapping* and *pattern*.

    Returns a list of account dicts, each containing:
        code, name, parent_code, level, is_header, children_codes
    """
    if df is None or df.empty:
        logger.warning("build_hierarchy called with empty DataFrame")
        return []

    if pattern in _REJECTED_PATTERNS:
        logger.warning("Pattern %s is rejected — cannot build hierarchy", pattern)
        return []

    code_col = column_mapping.get("code")
    name_col = column_mapping.get("name")
    parent_col = column_mapping.get("parent_code")

    if not code_col or code_col not in df.columns:
        logger.error("No 'code' column mapped — cannot build hierarchy")
        return []

    # --- Deduplicate codes (keep first occurrence) ---
    df = df.copy()
    df[code_col] = df[code_col].astype(str).str.strip()
    dup_mask = df[code_col].duplicated(keep="first")
    dup_count = dup_mask.sum()
    if dup_count > 0:
        dup_codes = df.loc[dup_mask, code_col].unique().tolist()
        logger.warning(
            "Duplicate codes found (%d rows) — keeping first occurrence: %s",
            dup_count,
            dup_codes[:10],
        )
        df = df[~dup_mask].reset_index(drop=True)

    # --- Drop rows with empty/NaN codes ---
    df = df[df[code_col].notna() & (df[code_col] != "") & (df[code_col] != "nan")]
    if df.empty:
        logger.warning("All rows had empty codes after cleaning")
        return []

    # --- Select strategy based on pattern ---
    hierarchy: Dict[str, Dict] = {}

    if pattern in _TEXT_PARENT_PATTERNS and parent_col and parent_col in df.columns:
        hierarchy = _build_from_text_parent(df, code_col, parent_col)

    elif pattern in _HORIZONTAL_PATTERNS:
        level_columns = _find_level_columns(df, column_mapping)
        if level_columns:
            hierarchy = _build_from_horizontal(df, level_columns)
        else:
            # Fallback to prefix matching
            logger.info("No level columns found for %s — falling back to prefix matching", pattern)
            hierarchy = _build_from_prefix_matching(df, code_col)

    elif pattern in _PARENT_COLUMN_PATTERNS and parent_col and parent_col in df.columns:
        hierarchy = _build_from_parent_column(df, code_col, parent_col)

    elif pattern == "MIGRATION_FILE":
        old_code_col = column_mapping.get("old_code")
        if old_code_col and old_code_col in df.columns:
            hierarchy = _build_from_prefix_matching(df, code_col)
        else:
            hierarchy = _build_from_prefix_matching(df, code_col)

    elif parent_col and parent_col in df.columns:
        # Any pattern with a parent column available — use it
        hierarchy = _build_from_parent_column(df, code_col, parent_col)

    else:
        # Default: prefix matching
        hierarchy = _build_from_prefix_matching(df, code_col)

    if not hierarchy:
        logger.warning("Hierarchy building produced no accounts")
        return []

    # --- Enrich with name column ---
    if name_col and name_col in df.columns:
        name_map = dict(zip(df[code_col].astype(str).str.strip(), df[name_col].astype(str)))
        for code, node in hierarchy.items():
            if "name" not in node or not node["name"]:
                node["name"] = name_map.get(code, "")

    # --- Post-processing pipeline ---
    orphans = _detect_orphans(hierarchy)
    if orphans:
        logger.warning("Orphan accounts detected (%d): %s", len(orphans), orphans[:10])

    cycles = _detect_cycles(hierarchy)
    if cycles:
        logger.warning("Cycles detected and broken (%d): %s", len(cycles), cycles[:5])

    hierarchy = _calculate_levels(hierarchy)
    hierarchy = _mark_header_accounts(hierarchy)

    # Check for deep hierarchies
    max_depth = max((n.get("level", 1) for n in hierarchy.values()), default=1)
    if max_depth > _MAX_SAFE_DEPTH:
        logger.warning("Very deep hierarchy detected: %d levels (max safe = %d)", max_depth, _MAX_SAFE_DEPTH)

    # --- Convert to sorted list ---
    result = []
    for code in sorted(hierarchy.keys()):
        node = hierarchy[code]
        result.append(
            {
                "code": code,
                "name": node.get("name", ""),
                "parent_code": node.get("parent_code"),
                "level": node.get("level", 1),
                "is_header": node.get("is_header", False),
                "children_codes": sorted(node.get("children_codes", [])),
            }
        )
    return result


def validate_hierarchy(hierarchy: Dict[str, Dict]) -> Dict:
    """Return a validation summary for the given hierarchy dict.

    Returns:
        {total, roots, orphans, cycles, max_depth, warnings}
    """
    if not hierarchy:
        return {
            "total": 0,
            "roots": 0,
            "orphans": 0,
            "cycles": 0,
            "max_depth": 0,
            "warnings": ["Empty hierarchy"],
        }

    warnings: List[str] = []
    codes = set(hierarchy.keys())
    roots = [c for c, n in hierarchy.items() if not n.get("parent_code")]
    orphans = [
        c
        for c, n in hierarchy.items()
        if n.get("parent_code") and n["parent_code"] not in codes
    ]
    cycles = _detect_cycles_readonly(hierarchy)
    max_depth = max((n.get("level", 1) for n in hierarchy.values()), default=0)

    if not roots:
        warnings.append("No root accounts found")
    if orphans:
        warnings.append(f"{len(orphans)} orphan account(s) detected")
    if cycles:
        warnings.append(f"{len(cycles)} cycle(s) detected")
    if max_depth > _MAX_SAFE_DEPTH:
        warnings.append(f"Hierarchy depth {max_depth} exceeds recommended maximum of {_MAX_SAFE_DEPTH}")
    if len(hierarchy) == 1:
        warnings.append("Single-account hierarchy")

    return {
        "total": len(hierarchy),
        "roots": len(roots),
        "orphans": len(orphans),
        "cycles": len(cycles),
        "max_depth": max_depth,
        "warnings": warnings,
    }


# ---------------------------------------------------------------------------
# Strategy: Parent Column (direct mapping)
# ---------------------------------------------------------------------------


def _build_from_parent_column(
    df: pd.DataFrame,
    code_col: str,
    parent_col: str,
) -> Dict[str, Dict]:
    """Build hierarchy using an explicit parent_code column."""
    hierarchy: Dict[str, Dict] = {}

    for _, row in df.iterrows():
        code = str(row[code_col]).strip()
        if not code or code == "nan":
            continue

        raw_parent = row.get(parent_col)
        parent_code: Optional[str] = None
        if pd.notna(raw_parent):
            parent_code = str(raw_parent).strip()
            if not parent_code or parent_code == "nan":
                parent_code = None
            # A code cannot be its own parent
            if parent_code == code:
                logger.warning("Account %s references itself as parent — treating as root", code)
                parent_code = None

        name_val = ""
        # Try to get name from any "name"-like column
        for col in df.columns:
            col_lower = col.lower()
            if "name" in col_lower or "اسم" in col_lower or "title" in col_lower:
                val = row.get(col)
                if pd.notna(val) and str(val).strip():
                    name_val = str(val).strip()
                    break

        hierarchy[code] = {
            "code": code,
            "name": name_val,
            "parent_code": parent_code,
            "children_codes": [],
        }

    # Populate children_codes
    for code, node in hierarchy.items():
        parent = node.get("parent_code")
        if parent and parent in hierarchy:
            hierarchy[parent]["children_codes"].append(code)

    return hierarchy


# ---------------------------------------------------------------------------
# Strategy: Prefix Matching
# ---------------------------------------------------------------------------


def _build_from_prefix_matching(
    df: pd.DataFrame,
    code_col: str,
) -> Dict[str, Dict]:
    """Build hierarchy by progressively shortening code prefixes.

    Algorithm:
        - Collect all codes into a set
        - Sort codes by length (shortest first = highest level)
        - For each code, try shortening the prefix one character at a time
        - First match found in the codes set = parent
        - No match = root account
    """
    hierarchy: Dict[str, Dict] = {}
    codes_set: Set[str] = set()

    # First pass: collect all codes
    for _, row in df.iterrows():
        code = str(row[code_col]).strip()
        if code and code != "nan":
            codes_set.add(code)

    if not codes_set:
        return hierarchy

    # Build name lookup
    name_map: Dict[str, str] = {}
    for _, row in df.iterrows():
        code = str(row[code_col]).strip()
        if code in codes_set:
            for col in df.columns:
                col_lower = col.lower()
                if "name" in col_lower or "اسم" in col_lower or "title" in col_lower:
                    val = row.get(col)
                    if pd.notna(val) and str(val).strip():
                        name_map[code] = str(val).strip()
                        break

    # Sort by length to process parents before children
    sorted_codes = sorted(codes_set, key=lambda c: (len(c), c))

    # Check if all codes are the same length (flat structure)
    lengths = {len(c) for c in codes_set}
    is_flat = len(lengths) == 1

    for code in sorted_codes:
        parent_code: Optional[str] = None

        if not is_flat:
            # Try progressively shorter prefixes
            for prefix_len in range(len(code) - 1, 0, -1):
                candidate = code[:prefix_len]
                if candidate in codes_set and candidate != code:
                    parent_code = candidate
                    break

        hierarchy[code] = {
            "code": code,
            "name": name_map.get(code, ""),
            "parent_code": parent_code,
            "children_codes": [],
        }

    # Populate children_codes
    for code, node in hierarchy.items():
        parent = node.get("parent_code")
        if parent and parent in hierarchy:
            hierarchy[parent]["children_codes"].append(code)

    return hierarchy


# ---------------------------------------------------------------------------
# Strategy: Text Parent (e.g., "1101 - Cash")
# ---------------------------------------------------------------------------


def _build_from_text_parent(
    df: pd.DataFrame,
    code_col: str,
    parent_col: str,
) -> Dict[str, Dict]:
    """Build hierarchy from a parent column containing text like ``"1101 - Cash"``."""
    hierarchy: Dict[str, Dict] = {}
    codes_set: Set[str] = set()

    # First pass: collect all valid codes
    for _, row in df.iterrows():
        code = str(row[code_col]).strip()
        if code and code != "nan":
            codes_set.add(code)

    for _, row in df.iterrows():
        code = str(row[code_col]).strip()
        if not code or code == "nan":
            continue

        raw_parent = row.get(parent_col)
        parent_code: Optional[str] = None

        if pd.notna(raw_parent):
            parent_str = str(raw_parent).strip()
            if parent_str and parent_str != "nan":
                # Try to extract numeric prefix: "1101 - Cash" -> "1101"
                m = _TEXT_PARENT_RE.match(parent_str)
                if m:
                    parent_code = m.group(1)
                else:
                    # Maybe the parent is just a plain code
                    candidate = parent_str.split()[0] if parent_str else ""
                    if candidate.isdigit() and candidate in codes_set:
                        parent_code = candidate

                # Validate: parent must exist in codes and not be self
                if parent_code:
                    if parent_code == code:
                        logger.warning("Account %s references itself as parent (text) — treating as root", code)
                        parent_code = None
                    elif parent_code not in codes_set:
                        logger.debug("Parent code '%s' for account %s not found in codes set", parent_code, code)
                        # Keep the reference — orphan detection handles it later

        name_val = ""
        for col in df.columns:
            col_lower = col.lower()
            if col != parent_col and ("name" in col_lower or "اسم" in col_lower or "title" in col_lower):
                val = row.get(col)
                if pd.notna(val) and str(val).strip():
                    name_val = str(val).strip()
                    break

        hierarchy[code] = {
            "code": code,
            "name": name_val,
            "parent_code": parent_code,
            "children_codes": [],
        }

    # Populate children_codes
    for code, node in hierarchy.items():
        parent = node.get("parent_code")
        if parent and parent in hierarchy:
            hierarchy[parent]["children_codes"].append(code)

    return hierarchy


# ---------------------------------------------------------------------------
# Strategy: Horizontal Hierarchy (level columns)
# ---------------------------------------------------------------------------


def _find_level_columns(
    df: pd.DataFrame,
    column_mapping: Dict[str, str],
) -> List[str]:
    """Detect ordered level columns like 'المستوى 1', 'المستوى 2', 'Level 1', etc."""
    level_cols: List[Tuple[int, str]] = []

    for col in df.columns:
        col_lower = str(col).lower().strip()
        # Match Arabic: "المستوى 1", "المستوى 2"
        m = re.search(r"(?:المستوى|المستوي|level|lvl)\s*(\d+)", col_lower)
        if m:
            level_cols.append((int(m.group(1)), col))
            continue
        # Match numbered patterns: "L1", "L2"
        m = re.match(r"^l(\d+)$", col_lower)
        if m:
            level_cols.append((int(m.group(1)), col))

    # Sort by level number
    level_cols.sort(key=lambda x: x[0])
    return [col for _, col in level_cols]


def _build_from_horizontal(
    df: pd.DataFrame,
    level_columns: List[str],
) -> Dict[str, Dict]:
    """Build hierarchy from horizontal level columns.

    Each row has values in level columns; the rightmost non-null value
    is the account for that row. The value in the previous level column
    is the parent.
    """
    hierarchy: Dict[str, Dict] = {}
    # Track the last seen value at each level for parent resolution
    last_at_level: Dict[int, str] = {}

    for _, row in df.iterrows():
        account_code: Optional[str] = None
        account_level: int = 0
        parent_code: Optional[str] = None
        account_name: str = ""

        # Find rightmost non-null level column
        for lvl_idx, col in enumerate(level_columns):
            val = row.get(col)
            if pd.notna(val) and str(val).strip() and str(val).strip() != "nan":
                raw = str(val).strip()
                # The value might be code, or "code - name", or just name
                m = re.match(r"^(\d[\d.]*)", raw)
                if m:
                    account_code = m.group(1).rstrip(".")
                    # Name is remainder after code and separator
                    remainder = raw[m.end():].strip().lstrip("-\u2013\u2014").strip()
                    account_name = remainder if remainder else raw
                else:
                    account_code = raw
                    account_name = raw
                account_level = lvl_idx + 1

        if not account_code:
            continue

        # Parent is the last seen value at the previous level
        if account_level > 1:
            parent_code = last_at_level.get(account_level - 1)

        # Update tracking
        last_at_level[account_level] = account_code
        # Clear all deeper levels (new branch)
        for deeper in range(account_level + 1, len(level_columns) + 1):
            last_at_level.pop(deeper, None)

        if account_code in hierarchy:
            # Already seen — skip duplicate
            continue

        hierarchy[account_code] = {
            "code": account_code,
            "name": account_name,
            "parent_code": parent_code if parent_code != account_code else None,
            "children_codes": [],
        }

    # Populate children_codes
    for code, node in hierarchy.items():
        parent = node.get("parent_code")
        if parent and parent in hierarchy:
            hierarchy[parent]["children_codes"].append(code)

    return hierarchy


# ---------------------------------------------------------------------------
# Post-processing: Level Calculation
# ---------------------------------------------------------------------------


def _calculate_levels(hierarchy: Dict[str, Dict]) -> Dict[str, Dict]:
    """BFS from root nodes to assign levels. Root = 1, children = parent + 1."""
    if not hierarchy:
        return hierarchy

    # Find roots: no parent or parent not in hierarchy
    codes = set(hierarchy.keys())
    roots = [
        c
        for c, n in hierarchy.items()
        if not n.get("parent_code") or n["parent_code"] not in codes
    ]

    # Initialize all levels to 0 (unvisited)
    for node in hierarchy.values():
        node["level"] = 0

    # BFS
    queue: deque = deque()
    for root in roots:
        hierarchy[root]["level"] = 1
        queue.append(root)

    visited: Set[str] = set(roots)

    while queue:
        current = queue.popleft()
        current_level = hierarchy[current]["level"]
        for child_code in hierarchy[current].get("children_codes", []):
            if child_code in visited:
                continue
            if child_code in hierarchy:
                hierarchy[child_code]["level"] = current_level + 1
                visited.add(child_code)
                queue.append(child_code)

    # Handle any unvisited nodes (disconnected components)
    for code, node in hierarchy.items():
        if node["level"] == 0:
            logger.debug("Unvisited node %s — assigning level 1 (disconnected)", code)
            node["level"] = 1

    return hierarchy


# ---------------------------------------------------------------------------
# Post-processing: Orphan Detection
# ---------------------------------------------------------------------------


def _detect_orphans(hierarchy: Dict[str, Dict]) -> List[str]:
    """Find accounts whose parent_code doesn't exist in the code set.

    Orphaned accounts have their parent set to ``None`` and are treated
    as potential root accounts.
    """
    if not hierarchy:
        return []

    codes = set(hierarchy.keys())
    orphans: List[str] = []

    for code, node in hierarchy.items():
        parent = node.get("parent_code")
        if parent and parent not in codes:
            orphans.append(code)
            node["parent_code"] = None

    return orphans


# ---------------------------------------------------------------------------
# Post-processing: Cycle Detection
# ---------------------------------------------------------------------------


def _detect_cycles(hierarchy: Dict[str, Dict]) -> List[List[str]]:
    """Detect and break cycles using DFS with in-stack tracking.

    When a cycle is found, the last node in the cycle has its parent
    set to ``None`` to break the cycle.

    Returns a list of detected cycles (each cycle is a list of codes).
    """
    if not hierarchy:
        return []

    visited: Set[str] = set()
    in_stack: Set[str] = set()
    cycles: List[List[str]] = []

    def _dfs(code: str, path: List[str]) -> None:
        if code in in_stack:
            # Found a cycle — extract it
            cycle_start = path.index(code)
            cycle = path[cycle_start:]
            cycles.append(cycle)
            # Break cycle: set the parent of the node that completes
            # the cycle to None
            if cycle:
                breaker = cycle[-1]
                hierarchy[breaker]["parent_code"] = None
                # Also remove from parent's children
                for c, n in hierarchy.items():
                    if breaker in n.get("children_codes", []):
                        n["children_codes"].remove(breaker)
                logger.warning("Cycle broken at account %s: %s", breaker, cycle)
            return

        if code in visited:
            return

        visited.add(code)
        in_stack.add(code)
        path.append(code)

        # Follow parent chain upward
        parent = hierarchy.get(code, {}).get("parent_code")
        if parent and parent in hierarchy:
            _dfs(parent, path)

        path.pop()
        in_stack.discard(code)

    for code in hierarchy:
        if code not in visited:
            _dfs(code, [])

    return cycles


def _detect_cycles_readonly(hierarchy: Dict[str, Dict]) -> List[List[str]]:
    """Detect cycles without modifying the hierarchy (for validation)."""
    if not hierarchy:
        return []

    visited: Set[str] = set()
    in_stack: Set[str] = set()
    cycles: List[List[str]] = []

    def _dfs(code: str, path: List[str]) -> None:
        if code in in_stack:
            cycle_start = path.index(code)
            cycles.append(path[cycle_start:])
            return
        if code in visited:
            return

        visited.add(code)
        in_stack.add(code)
        path.append(code)

        parent = hierarchy.get(code, {}).get("parent_code")
        if parent and parent in hierarchy:
            _dfs(parent, path)

        path.pop()
        in_stack.discard(code)

    for code in hierarchy:
        if code not in visited:
            _dfs(code, [])

    return cycles


# ---------------------------------------------------------------------------
# Post-processing: Header Detection
# ---------------------------------------------------------------------------


def _mark_header_accounts(hierarchy: Dict[str, Dict]) -> Dict[str, Dict]:
    """Mark accounts as header (has children) or detail (no children)."""
    for code, node in hierarchy.items():
        node["is_header"] = bool(node.get("children_codes"))
    return hierarchy
