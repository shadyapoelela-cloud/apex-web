"""Per-directory coverage gates.

The global --cov-fail-under=55 (see .github/workflows/ci.yml) catches
catastrophic drops but doesn't protect individual modules — a PR that
adds 500 tested statements in pilot/ while deleting 100 tested
statements in core/ can net out above 55% even though the real damage
is on the critical path.

This test closes that gap: read coverage.py's report per source file,
bucket by top-level directory under app/, and assert each bucket
meets its floor. Floors are calibrated from the 2026-04-24 baseline
with ~3pp buffer so routine fluctuations don't flake the gate.

How to update: when you add a new phase/sprint, add it to
``DIRECTORY_FLOORS`` with a floor that's a few points under the
first measured value. A directory without an entry is ignored,
so this test never blocks the addition of new code — only the
erosion of already-tested code.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest


# ══════════════════════════════════════════════════════════════════════
# Floors — calibrated from `pytest --cov=app` on 2026-04-24 with
# ~3-5pp buffer. Raise these over time as coverage improves; never
# lower them (that's what --cov-fail-under is for, the global catch).
# ══════════════════════════════════════════════════════════════════════
DIRECTORY_FLOORS: dict[str, float] = {
    # Tier 1 — critical path. Keep tight.
    "core":       85.0,   # was 88.0%
    "features":   85.0,   # was 90.2%
    "hr":         80.0,   # was 86.1%
    "ai":         80.0,   # was 84.0%
    "phase11":    68.0,   # was 71.6%
    "phase10":    68.0,   # was 70.8%
    "integrations": 70.0, # was 74.4%
    # Tier 2 — important, not yet gold.
    "coa_engine": 63.0,   # was 66.6%
    "phase1":     60.0,   # was 64.5%
    # Tier 3 — acknowledged gaps we don't want to widen.
    "phase4":     48.0,   # was 52.0%
    "copilot":    50.0,   # was 54.2%
    "phase2":     36.0,   # was 40.8%
    "phase7":     36.0,   # was 39.6%
    "phase9":     36.0,   # was 39.5%
    "pilot":      32.0,   # was 36.0%
    "phase8":     31.0,   # was 35.5%
    "phase3":     31.0,   # was 34.8%
    # Tier 4 — pre-existing 0–30% zones. Prevent regress-to-zero.
    "sprint4":    26.0,   # was 29.6%
    "sprint6_registry": 26.0,   # was 29.0%
    "sprint4_tb": 20.0,   # was 24.3%
    "phase6":     20.0,   # was 24.1%
    "phase5":     20.0,   # was 23.9%
    "sprint2":    17.0,   # was 20.3%
    # sprint1/3/5, knowledge_brain, services, ops intentionally omitted —
    # current coverage is <15%, floor would be near-zero and add no value.
    # Add them when they climb above 25%.
}


@pytest.fixture(scope="module")
def coverage_by_directory(tmp_path_factory) -> dict[str, tuple[int, int]]:
    """Run pytest with coverage and parse per-file totals into per-
    directory (statements, missing) tuples.

    Scoped module-level so the expensive pytest-in-pytest happens
    once. Coverage is written to a temp JSON file and parsed here.
    """
    if os.environ.get("SKIP_PER_DIR_COVERAGE") == "1":
        pytest.skip("SKIP_PER_DIR_COVERAGE=1 — intentional skip")
    try:
        import coverage  # noqa: F401
    except ImportError:
        pytest.skip("coverage.py not installed — skipping per-dir gate")

    repo_root = Path(__file__).resolve().parent.parent
    out_json = tmp_path_factory.mktemp("covreport") / "coverage.json"

    # Run pytest as a subprocess so it doesn't recurse into itself.
    # Exclude this file to avoid infinite recursion, and skip the
    # cookie-auth + openapi tests that pollute logs for nothing.
    env = {
        **os.environ,
        "JWT_SECRET": "apex-test-jwt-secret-32bytes-min-length",
        "ADMIN_SECRET": "test-admin",
        "ANTHROPIC_API_KEY": "sk-ant-fake",
        "SKIP_PER_DIR_COVERAGE": "1",  # prevent nested-fixture recursion
    }
    cmd = [
        sys.executable, "-m", "pytest",
        "tests/",
        "--ignore=tests/test_per_directory_coverage.py",
        "--cov=app",
        f"--cov-report=json:{out_json}",
        "--cov-report=",  # suppress terminal — we parse JSON
        "-q", "--tb=no",
        "-x",  # fail fast on unrelated regressions (not expected)
    ]
    proc = subprocess.run(
        cmd, cwd=repo_root, env=env, capture_output=True, text=True, timeout=600,
    )
    if proc.returncode != 0 and not out_json.exists():
        pytest.fail(
            f"coverage run failed (exit {proc.returncode}):\n"
            f"--- stdout tail ---\n{proc.stdout[-1200:]}\n"
            f"--- stderr tail ---\n{proc.stderr[-600:]}"
        )

    data = json.loads(out_json.read_text(encoding="utf-8"))
    files = data.get("files", {})
    buckets: dict[str, list[int]] = {}  # dir -> [stmts, miss]
    for fpath, fdata in files.items():
        # Normalise backslashes (Windows) + strip leading "app/"
        norm = fpath.replace("\\", "/")
        if not norm.startswith("app/"):
            continue
        parts = norm.split("/")
        if len(parts) < 2:
            continue
        top = parts[1]  # app/<TOP>/...
        # Treat top-level *.py (e.g. main.py) as its own bucket name.
        if top.endswith(".py"):
            top = top[:-3]
        summary = fdata.get("summary", {})
        stmts = summary.get("num_statements", 0)
        miss = summary.get("missing_lines", 0)
        if stmts == 0:
            continue
        buckets.setdefault(top, [0, 0])
        buckets[top][0] += stmts
        buckets[top][1] += miss

    return {k: (v[0], v[1]) for k, v in buckets.items()}


@pytest.mark.parametrize("directory,floor", sorted(DIRECTORY_FLOORS.items()))
def test_directory_meets_coverage_floor(
    directory: str, floor: float, coverage_by_directory: dict
) -> None:
    if directory not in coverage_by_directory:
        pytest.skip(f"{directory}/ reported no statements — nothing to gate")
    stmts, miss = coverage_by_directory[directory]
    if stmts == 0:
        pytest.skip(f"{directory}/ has 0 statements")
    cov_pct = 100.0 * (stmts - miss) / stmts
    assert cov_pct >= floor, (
        f"{directory}/ coverage {cov_pct:.1f}% fell below floor {floor:.1f}% "
        f"({stmts - miss}/{stmts} statements covered). "
        f"Either add tests to restore it, or — if the drop is intentional — "
        f"lower the floor in DIRECTORY_FLOORS with a justifying comment."
    )
