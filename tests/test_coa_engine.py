"""
APEX COA Engine v4.3 — Integration Tests
==========================================
Tests pattern detection, normalization, lexicon, error checks, and full pipeline.
Runs on 12 sample Excel files from app/coa_engine/sample_files/.
"""
import asyncio
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))

from app.coa_engine.engine import COAEngine, detect_pattern, read_file, map_columns, normalize_code
from app.coa_engine.lexicon_loader import get_lexicon, normalize_ar, reset_lexicon
from app.coa_engine.error_checks import run_all_checks, summarize_errors
from app.coa_engine.advanced_checks import (
    SECTOR_TEMPLATES, compare_coa_versions, compute_version_impact,
    detect_fp08_partner_drawings, check_trial_balance, FraudAlert,
)
from app.coa_engine.governance import (
    propose_rule, approve_rule, deprecate_rule, get_active_rules,
    get_governance_stats, run_ab_test, shadow_release,
    check_auto_rollback, notify_governance_alert,
)
from app.coa_engine.report_card import generate_report_card, _grade, _headline
from app.coa_engine.db import Database, SECTOR_BENCHMARKS_SEED
from app.coa_engine.migration_bridge import build_migration_map, detect_tb_linkage_breaks
from app.coa_engine.knowledge_graph import (
    KNOWLEDGE_GRAPH, COA_ONTOLOGY, validate_ontology,
    get_graph_context, classify_with_graph,
)
from app.coa_engine.financial_simulation import (
    simulate_financial_statements, run_compliance_check,
    generate_implementation_roadmap, COMPLIANCE_RULES,
)

SAMPLE_DIR = Path(__file__).parent.parent / "app" / "coa_engine" / "sample_files"


@pytest.fixture(scope="module")
def engine():
    return COAEngine()


@pytest.fixture(scope="module")
def lexicon():
    reset_lexicon()
    return get_lexicon()


def _load(fname: str) -> bytes:
    return (SAMPLE_DIR / fname).read_bytes()


# ─────────────────────────────────────────────────────────────
# Pattern Detection Tests
# ─────────────────────────────────────────────────────────────
class TestPatternDetection:
    def _detect(self, fname: str) -> str:
        rows, _ = read_file(_load(fname), fname)
        return detect_pattern(rows)

    def test_odoo_flat(self):
        assert self._detect("01_ODOO_FLAT.xlsx") == "ODOO_FLAT"

    def test_odoo_with_id(self):
        assert self._detect("02_ODOO_WITH_ID.xlsx") == "ODOO_WITH_ID"

    def test_hierarchical_numeric(self):
        assert self._detect("03_HIERARCHICAL_NUMERIC_PARENT.xlsx") == "HIERARCHICAL_NUMERIC_PARENT"

    def test_hierarchical_text(self):
        assert self._detect("04_HIERARCHICAL_TEXT_PARENT.xlsx") == "HIERARCHICAL_TEXT_PARENT"

    def test_zoho(self):
        assert self._detect("06_ZOHO_BOOKS.xlsx") == "ZOHO_BOOKS"

    def test_english_class(self):
        assert self._detect("07_ENGLISH_WITH_CLASS.xlsx") == "ENGLISH_WITH_CLASS"

    def test_migration(self):
        assert self._detect("08_MIGRATION_FILE.xlsx") == "MIGRATION_FILE"

    def test_generic_flat(self):
        assert self._detect("11_GENERIC_FLAT.xlsx") == "GENERIC_FLAT"

    def test_operational_rejected(self):
        assert self._detect("12_OPERATIONAL_INTEGRATED.xlsx") == "OPERATIONAL_INTEGRATED"


# ─────────────────────────────────────────────────────────────
# Normalize Code Tests
# ─────────────────────────────────────────────────────────────
class TestNormalizeCode:
    def test_float(self):        assert normalize_code("1100.0") == "1100"
    def test_arabic_digits(self): assert normalize_code("١١٠٠") == "1100"
    def test_comma(self):         assert normalize_code("1,100") == "1100"
    def test_scientific(self):    assert normalize_code("1.1e3") == "1100"
    def test_hierarchical(self):  assert normalize_code("1.1.1") == "1.1.1"
    def test_spaces(self):        assert normalize_code("  1100  ") == "1100"
    def test_nan(self):           assert normalize_code("nan") is None
    def test_none(self):          assert normalize_code(None) is None
    def test_empty(self):         assert normalize_code("") is None
    def test_normal(self):        assert normalize_code("1100") == "1100"


# ─────────────────────────────────────────────────────────────
# Lexicon Tests
# ─────────────────────────────────────────────────────────────
class TestLexicon:
    CASES = [
        ("النقد",                     "CASH"),
        ("نقدية",                     "CASH"),
        ("صندوق نثرية",               "PETTY_CASH"),
        ("بنك الراجحي",               "BANK"),
        ("ذمم مدينة تجارية",           "ACC_RECEIVABLE"),
        ("مدينون تجاريون",             "ACC_RECEIVABLE"),
        ("ذمم دائنة تجارية",           "ACC_PAYABLE"),
        ("مخزون بضاعة",               "INVENTORY"),
        ("مواد خام",                  "RAW_MATERIALS"),
        ("مجمع إهلاك المباني",        "ACCUM_DEPR_BUILDINGS"),
        ("مجمع إهلاك عام",            "ACCUM_DEPR_GENERAL"),
        ("رأس المال",                 "PAID_IN_CAPITAL"),
        ("أرباح مبقاة",               "RETAINED_EARNINGS"),
        ("إيرادات المبيعات",           "SALES_REVENUE"),
        ("تكلفة البضاعة المباعة",     "COGS"),
        ("رواتب وأجور",               "SALARIES_WAGES"),
        ("مصروف إهلاك",               "DEPRECIATION_EXPENSE"),
        ("فوائد دين مدفوعة",          "INTEREST_EXPENSE"),
        ("ض.ق.م مدخلات",              "VAT_INPUT"),
        ("accounts receivable",       "ACC_RECEIVABLE"),
        ("accumulated depreciation",  "ACCUM_DEPR_GENERAL"),
        ("cost of sales",             "COGS"),
        ("interest expense",          "INTEREST_EXPENSE"),
        ("VAT input",                 "VAT_INPUT"),
    ]

    @pytest.mark.parametrize("name,expected", CASES)
    def test_match(self, lexicon, name: str, expected: str):
        result = lexicon.match(name)
        assert result.concept_id == expected, \
            f"'{name}' → {result.concept_id} (expected {expected}) [{result.method}]"


# ─────────────────────────────────────────────────────────────
# Error Checks E01-E20 Tests
# ─────────────────────────────────────────────────────────────
class TestErrorChecks:
    def _accounts(self, overrides=None):
        base = [
            {"code": "1000", "name": "الأصول", "section": "asset", "nature": "debit", "account_level": "header"},
            {"code": "1100", "name": "النقد", "section": "current_asset", "nature": "debit", "account_level": "detail"},
            {"code": "2000", "name": "الخصوم", "section": "liability", "nature": "credit", "account_level": "header"},
            {"code": "4000", "name": "الإيرادات", "section": "revenue", "nature": "credit", "account_level": "header"},
            {"code": "4100", "name": "المبيعات", "section": "revenue", "nature": "credit", "account_level": "detail"},
            {"code": "6000", "name": "المصروفات", "section": "expense", "nature": "debit", "account_level": "header"},
        ]
        if overrides:
            base.append(overrides)
        return base

    def test_E01_duplicate(self):
        accs = self._accounts()
        accs.append({"code": "1100", "name": "نقد مكرر", "section": "asset", "nature": "debit", "account_level": "detail"})
        errors = run_all_checks(accs)
        assert any(e.error_code == "E01" for e in errors)

    def test_E02_missing_code(self):
        accs = self._accounts({"code": "", "name": "بلا كود", "section": "asset", "nature": "debit", "account_level": "detail"})
        errors = run_all_checks(accs)
        assert any(e.error_code == "E02" for e in errors)

    def test_E08_broken_hierarchy(self):
        accs = self._accounts({"code": "3100", "name": "رأس المال", "parent_code": "9999",
                                "section": "equity", "nature": "credit", "account_level": "detail"})
        errors = run_all_checks(accs)
        assert any(e.error_code == "E08" for e in errors)

    def test_E09_asset_as_liability(self):
        accs = self._accounts({"code": "1200", "name": "مدينون", "section": "liability",
                                "nature": "debit", "account_level": "detail"})
        errors = run_all_checks(accs)
        assert any(e.error_code in ("E09", "E14") for e in errors)

    def test_E10_revenue_as_expense(self):
        accs = self._accounts({"code": "4200", "name": "إيرادات أخرى", "section": "expense",
                                "nature": "debit", "account_level": "detail"})
        errors = run_all_checks(accs)
        assert any(e.error_code == "E10" for e in errors)

    def test_E15_equity_as_liability(self):
        accs = self._accounts({"code": "3100", "name": "رأس المال", "section": "liability",
                                "nature": "credit", "account_level": "detail"})
        errors = run_all_checks(accs)
        assert any(e.error_code == "E15" for e in errors)

    def test_E17_reversed_nature(self):
        accs = self._accounts({"code": "1300", "name": "مخزون", "section": "asset",
                                "nature": "credit", "account_level": "detail"})
        errors = run_all_checks(accs)
        assert any(e.error_code == "E17" for e in errors)

    def test_E18_provision_debit(self):
        accs = self._accounts({"code": "2500", "name": "مخصص ديون مشكوك", "section": "liability",
                                "nature": "debit", "account_level": "detail"})
        errors = run_all_checks(accs)
        assert any(e.error_code == "E18" for e in errors)

    def test_E19_revenue_debit(self):
        accs = self._accounts({"code": "4300", "name": "إيراد خدمات", "section": "revenue",
                                "nature": "debit", "account_level": "detail"})
        errors = run_all_checks(accs)
        assert any(e.error_code == "E19" for e in errors)

    def test_E20_expense_credit(self):
        accs = self._accounts({"code": "6100", "name": "رواتب", "section": "expense",
                                "nature": "credit", "account_level": "detail"})
        errors = run_all_checks(accs)
        assert any(e.error_code == "E20" for e in errors)

    def test_no_false_positives_clean_file(self):
        accs = [
            {"code": "1000", "name": "الأصول", "section": "asset", "nature": "debit", "account_level": "header"},
            {"code": "1100", "name": "النقد", "section": "current_asset", "nature": "debit", "account_level": "detail"},
            {"code": "2000", "name": "الخصوم", "section": "liability", "nature": "credit", "account_level": "header"},
            {"code": "3000", "name": "حقوق الملكية", "section": "equity", "nature": "credit", "account_level": "header"},
            {"code": "4000", "name": "الإيرادات", "section": "revenue", "nature": "credit", "account_level": "header"},
            {"code": "6000", "name": "المصروفات", "section": "expense", "nature": "debit", "account_level": "header"},
        ]
        errors = run_all_checks(accs)
        summary = summarize_errors(errors)
        assert summary["critical"] == 0


# ─────────────────────────────────────────────────────────────
# Full Pipeline Tests (async)
# ─────────────────────────────────────────────────────────────
class TestPipeline:
    def _run(self, engine, fname: str, erp=None):
        return asyncio.run(
            engine.process(_load(fname), erp_system=erp, filename=fname)
        )

    def test_odoo_flat_processes(self, engine):
        r = self._run(engine, "01_ODOO_FLAT.xlsx", "Odoo")
        assert r.file_pattern == "ODOO_FLAT"
        assert len(r.accounts) > 0
        assert r.quality_score > 0
        assert r.processing_ms < 10_000

    def test_hierarchical_numeric(self, engine):
        r = self._run(engine, "03_HIERARCHICAL_NUMERIC_PARENT.xlsx")
        assert r.file_pattern == "HIERARCHICAL_NUMERIC_PARENT"
        assert len(r.accounts) > 0

    def test_zoho_books(self, engine):
        r = self._run(engine, "06_ZOHO_BOOKS.xlsx")
        assert r.file_pattern == "ZOHO_BOOKS"
        assert len(r.accounts) > 0

    def test_english_with_class(self, engine):
        r = self._run(engine, "07_ENGLISH_WITH_CLASS.xlsx")
        assert r.file_pattern == "ENGLISH_WITH_CLASS"

    def test_migration_file(self, engine):
        r = self._run(engine, "08_MIGRATION_FILE.xlsx")
        assert r.file_pattern == "MIGRATION_FILE"

    def test_generic_flat(self, engine):
        r = self._run(engine, "11_GENERIC_FLAT.xlsx")
        assert r.file_pattern == "GENERIC_FLAT"
        assert len(r.accounts) > 0

    def test_operational_rejected(self, engine):
        r = self._run(engine, "12_OPERATIONAL_INTEGRATED.xlsx")
        assert r.status == "rejected"
        assert len(r.accounts) == 0

    def test_quality_score_range(self, engine):
        r = self._run(engine, "01_ODOO_FLAT.xlsx")
        assert 0 <= r.quality_score <= 100

    def test_quality_grade_valid(self, engine):
        r = self._run(engine, "07_ENGLISH_WITH_CLASS.xlsx")
        assert r.quality_grade in ("A", "B", "C", "D", "F")

    def test_session_health_fields(self, engine):
        r = self._run(engine, "01_ODOO_FLAT.xlsx")
        assert "pass_one_rate" in r.session_health
        assert "pass_two_rate" in r.session_health
        assert "llm_rate" in r.session_health

    def test_processing_speed(self, engine):
        for fname in ["01_ODOO_FLAT.xlsx", "07_ENGLISH_WITH_CLASS.xlsx", "11_GENERIC_FLAT.xlsx"]:
            r = self._run(engine, fname)
            assert r.processing_ms < 5_000, f"{fname}: {r.processing_ms}ms"

    def test_errors_have_required_fields(self, engine):
        r = self._run(engine, "01_ODOO_FLAT.xlsx")
        for e in r.errors:
            assert e.error_code
            assert e.severity in ("Critical", "High", "Medium", "Low")
            assert e.description_ar

    def test_accounts_have_required_fields(self, engine):
        r = self._run(engine, "01_ODOO_FLAT.xlsx")
        for a in r.accounts:
            assert a.code
            assert a.name_raw
            assert 0 <= a.confidence <= 1, f"confidence out of range: {a.confidence}"
            assert a.review_status in ("auto_approved", "auto_classified", "pending", "pending_review", "rejected_pending", "rejected", "resolved")

    def test_pipeline_result_to_api_response(self, engine):
        r = self._run(engine, "01_ODOO_FLAT.xlsx")
        api = r.to_api_response()
        assert "upload_id" in api
        assert "accounts" in api
        assert "errors" in api
        assert "quality_score" in api
        assert isinstance(api["accounts"], list)

    def test_all_12_files_process_without_error(self, engine):
        files = [
            "01_ODOO_FLAT.xlsx", "02_ODOO_WITH_ID.xlsx",
            "03_HIERARCHICAL_NUMERIC_PARENT.xlsx", "04_HIERARCHICAL_TEXT_PARENT.xlsx",
            "05_HORIZONTAL_HIERARCHY.xlsx", "06_ZOHO_BOOKS.xlsx",
            "07_ENGLISH_WITH_CLASS.xlsx", "08_MIGRATION_FILE.xlsx",
            "09_SPARSE_COLUMNAR_HIERARCHY.xlsx", "10_ACCOUNTS_WITH_JOURNALS.xlsx",
            "11_GENERIC_FLAT.xlsx", "12_OPERATIONAL_INTEGRATED.xlsx",
        ]
        for fname in files:
            try:
                r = self._run(engine, fname)
                assert r.upload_id, f"{fname}: missing upload_id"
                assert r.file_pattern != "UNKNOWN" or r.status == "rejected", \
                    f"{fname}: unknown pattern and not rejected"
            except Exception as e:
                pytest.fail(f"{fname} failed: {e}")


# ─────────────────────────────────────────────────────────────
# Wave 3: Sector Intelligence Tests
# ─────────────────────────────────────────────────────────────
class TestWave3SectorTemplates:
    def test_sector_templates_count(self):
        """At least 45 sector templates must be defined."""
        assert len(SECTOR_TEMPLATES) >= 45, f"Expected ≥45, got {len(SECTOR_TEMPLATES)}"

    def test_each_template_has_mandatory(self):
        """Every sector template must have 'mandatory' patterns."""
        for code, tmpl in SECTOR_TEMPLATES.items():
            assert "mandatory" in tmpl, f"{code} missing 'mandatory'"
            assert len(tmpl["mandatory"]) > 0, f"{code} has empty mandatory list"


class TestWave3ReportCard:
    def _mock_result(self, score=85, critical=0, high=1):
        return {
            "quality_score": score,
            "quality_grade": _grade(score),
            "quality_dimensions": {
                "classification_accuracy": 85,
                "completeness": 92,
                "naming_quality": 78,
                "code_consistency": 72,
                "error_penalty": 90,
            },
            "errors_summary": {"critical": critical, "high": high, "medium": 2, "low": 3},
            "errors": [],
            "recommendations": ["حسّن أسماء الحسابات"],
            "total_accounts": 150,
            "confidence_avg": 0.87,
            "sector_detected": "RETAIL",
        }

    def test_report_card_grade_A(self):
        card = generate_report_card(self._mock_result(score=92))
        assert card["grade"] == "A"
        assert "ممتازة" in card["headline_ar"]

    def test_report_card_grade_B(self):
        card = generate_report_card(self._mock_result(score=85))
        assert card["grade"] == "B"
        assert "جيدة" in card["headline_ar"]

    def test_report_card_grade_C(self):
        card = generate_report_card(self._mock_result(score=72))
        assert card["grade"] == "C"
        assert "مقبولة" in card["headline_ar"]

    def test_report_card_grade_D(self):
        card = generate_report_card(self._mock_result(score=66))
        assert card["grade"] == "D"

    def test_report_card_grade_F(self):
        card = generate_report_card(self._mock_result(score=50))
        assert card["grade"] == "F"
        assert "إعادة هيكلة" in card["headline_ar"]

    def test_report_card_actions_sorted_by_impact(self):
        card = generate_report_card(self._mock_result(score=60, critical=3, high=5))
        actions = card["priority_actions"]
        if len(actions) >= 2:
            # Extract numeric impact from each action
            def _impact_num(a):
                try:
                    return int(a["impact"].replace("+", "").replace(" نقاط", "").replace(" نقطة", ""))
                except (ValueError, AttributeError):
                    return 0
            impacts = [_impact_num(a) for a in actions]
            assert impacts == sorted(impacts, reverse=True), "Actions not sorted by impact"

    def test_report_card_readiness_blocked(self):
        card = generate_report_card(self._mock_result(score=85, critical=2))
        assert card["readiness"] == "blocked"

    def test_report_card_readiness_approved(self):
        card = generate_report_card(self._mock_result(score=85, critical=0))
        assert card["readiness"] == "approved"

    def test_report_card_readiness_pending(self):
        card = generate_report_card(self._mock_result(score=70, critical=0))
        assert card["readiness"] == "pending_review"

    def test_report_card_sector_comparison(self):
        benchmark = {
            "sector_name_ar": "التجزئة والجملة",
            "avg_score": 72.0,
            "sample_size": 25,
        }
        card = generate_report_card(self._mock_result(score=85), sector_benchmark=benchmark)
        assert card["sector_comparison"] is not None
        assert card["sector_comparison"]["your_score"] == 85
        assert card["sector_comparison"]["sector_avg"] == 72.0


class TestWave3SectorBenchmark:
    def test_sector_benchmark_seed_count(self):
        """Seed data should have at least 25 entries."""
        assert len(SECTOR_BENCHMARKS_SEED) >= 25

    def test_sector_benchmark_seed_structure(self):
        """Each seed entry should have 6 fields."""
        for entry in SECTOR_BENCHMARKS_SEED:
            assert len(entry) == 6, f"Expected 6 fields, got {len(entry)}: {entry}"

    def test_db_seed_and_get(self):
        """Integration test: seed + get_sector_benchmark."""
        import tempfile, os
        try:
            import aiosqlite  # noqa: F401
        except ImportError:
            pytest.skip("aiosqlite not installed")
        db_path = os.path.join(tempfile.gettempdir(), "test_wave3_benchmark.db")
        try:
            db = Database(db_path)
            asyncio.run(db.connect())
            asyncio.run(db.initialize_schema())
            # Verify seed worked
            result = asyncio.run(db.get_sector_benchmark("RETAIL"))
            assert result is not None
            assert result["sector_code"] == "RETAIL"
            assert result["avg_score"] == 72.0
            assert result["sector_name_ar"] == "التجزئة والجملة"
            # Non-existent sector
            missing = asyncio.run(db.get_sector_benchmark("NONEXISTENT"))
            assert missing is None
            asyncio.run(db.disconnect())
        finally:
            if os.path.exists(db_path):
                os.remove(db_path)


class TestWave3Versioning:
    def test_versioning_increments(self):
        """Version numbers should auto-increment per client."""
        import tempfile, os
        try:
            import aiosqlite  # noqa: F401
        except ImportError:
            pytest.skip("aiosqlite not installed")
        db_path = os.path.join(tempfile.gettempdir(), "test_wave3_versions.db")
        try:
            db = Database(db_path)
            asyncio.run(db.connect())
            asyncio.run(db.initialize_schema())
            v1 = asyncio.run(db.save_coa_version("client-A", "upload-1", 75.0, 100))
            assert v1 == 1
            v2 = asyncio.run(db.save_coa_version("client-A", "upload-2", 82.0, 120))
            assert v2 == 2
            v3 = asyncio.run(db.save_coa_version("client-A", "upload-3", 88.0, 130))
            assert v3 == 3
            # Different client starts at 1
            v1b = asyncio.run(db.save_coa_version("client-B", "upload-4", 70.0, 90))
            assert v1b == 1
            # Verify get_coa_versions returns all, desc order
            versions = asyncio.run(db.get_coa_versions("client-A"))
            assert len(versions) == 3
            assert versions[0]["version_number"] == 3
            assert versions[2]["version_number"] == 1
            asyncio.run(db.disconnect())
        finally:
            if os.path.exists(db_path):
                os.remove(db_path)

    def test_compare_versions(self):
        """compare_coa_versions should detect added/removed/modified accounts."""
        old_coa = [
            {"code": "1000", "name": "الأصول", "section": "asset", "nature": "debit"},
            {"code": "1100", "name": "النقد", "section": "current_asset", "nature": "debit"},
            {"code": "2000", "name": "الخصوم", "section": "liability", "nature": "credit"},
        ]
        new_coa = [
            {"code": "1000", "name": "الأصول", "section": "asset", "nature": "debit"},
            {"code": "1100", "name": "النقدية", "section": "current_asset", "nature": "debit"},  # renamed
            {"code": "3000", "name": "حقوق الملكية", "section": "equity", "nature": "credit"},  # added
            # 2000 removed
        ]
        report = compare_coa_versions(old_coa, new_coa)
        assert report.total_changes > 0
        change_types = {c.change_type for c in report.changes}
        assert "added" in change_types
        assert "removed" in change_types or "deleted" in change_types


# ─────────────────────────────────────────────────────────────
# Wave 4: Version Intelligence Tests
# ─────────────────────────────────────────────────────────────
class TestWave4MigrationMap:
    """Tests for build_migration_map — ملحق ص.3"""

    OLD_COA = [
        {"code": "1000", "name": "الأصول", "section": "asset", "nature": "debit", "concept_id": "ASSETS"},
        {"code": "1100", "name": "النقد", "section": "current_asset", "nature": "debit", "concept_id": "CASH"},
        {"code": "2000", "name": "الخصوم", "section": "liability", "nature": "credit", "concept_id": "LIABILITIES"},
        {"code": "4000", "name": "الإيرادات", "section": "revenue", "nature": "credit", "concept_id": "REVENUE"},
        {"code": "5000", "name": "المشتريات", "section": "cogs", "nature": "debit", "concept_id": "PURCHASES"},
    ]

    def test_migration_map_same(self):
        """Code unchanged, name/section/nature unchanged → SAME."""
        new_coa = list(self.OLD_COA)  # identical
        mappings = build_migration_map(self.OLD_COA, new_coa)
        same_maps = [m for m in mappings if m["map_type"] == "SAME"]
        assert len(same_maps) == 5

    def test_migration_map_renamed(self):
        """Same code, different name → RENAMED."""
        new_coa = [
            {"code": "1000", "name": "الأصول", "section": "asset", "nature": "debit", "concept_id": "ASSETS"},
            {"code": "1100", "name": "النقدية والبنوك", "section": "current_asset", "nature": "debit", "concept_id": "CASH"},
            {"code": "2000", "name": "الخصوم", "section": "liability", "nature": "credit", "concept_id": "LIABILITIES"},
            {"code": "4000", "name": "الإيرادات", "section": "revenue", "nature": "credit", "concept_id": "REVENUE"},
            {"code": "5000", "name": "المشتريات", "section": "cogs", "nature": "debit", "concept_id": "PURCHASES"},
        ]
        mappings = build_migration_map(self.OLD_COA, new_coa)
        renamed = [m for m in mappings if m["map_type"] == "RENAMED"]
        assert len(renamed) >= 1
        assert renamed[0]["old_code"] == "1100"
        assert renamed[0]["confidence"] == 0.99

    def test_migration_map_reclassified(self):
        """Same code, different section → RECLASSIFIED."""
        new_coa = [
            {"code": "1000", "name": "الأصول", "section": "asset", "nature": "debit", "concept_id": "ASSETS"},
            {"code": "1100", "name": "النقد", "section": "liability", "nature": "credit", "concept_id": "CASH"},  # changed!
            {"code": "2000", "name": "الخصوم", "section": "liability", "nature": "credit", "concept_id": "LIABILITIES"},
            {"code": "4000", "name": "الإيرادات", "section": "revenue", "nature": "credit", "concept_id": "REVENUE"},
            {"code": "5000", "name": "المشتريات", "section": "cogs", "nature": "debit", "concept_id": "PURCHASES"},
        ]
        mappings = build_migration_map(self.OLD_COA, new_coa)
        recl = [m for m in mappings if m["map_type"] == "RECLASSIFIED"]
        assert len(recl) >= 1
        assert recl[0]["old_code"] == "1100"
        assert recl[0]["source_natures_conflict"] is True

    def test_migration_map_deleted(self):
        """Code in old but not in new → DELETED."""
        new_coa = [
            {"code": "1000", "name": "الأصول", "section": "asset", "nature": "debit", "concept_id": "ASSETS"},
            {"code": "1100", "name": "النقد", "section": "current_asset", "nature": "debit", "concept_id": "CASH"},
            {"code": "2000", "name": "الخصوم", "section": "liability", "nature": "credit", "concept_id": "LIABILITIES"},
            # 4000 and 5000 deleted
        ]
        mappings = build_migration_map(self.OLD_COA, new_coa)
        deleted = [m for m in mappings if m["map_type"] == "DELETED"]
        assert len(deleted) == 2
        deleted_codes = {m["old_code"] for m in deleted}
        assert "4000" in deleted_codes
        assert "5000" in deleted_codes

    def test_migration_map_recoded(self):
        """Same concept_id, different code → RECODED."""
        new_coa = [
            {"code": "1000", "name": "الأصول", "section": "asset", "nature": "debit", "concept_id": "ASSETS"},
            {"code": "1110", "name": "النقد", "section": "current_asset", "nature": "debit", "concept_id": "CASH"},  # new code!
            {"code": "2000", "name": "الخصوم", "section": "liability", "nature": "credit", "concept_id": "LIABILITIES"},
            {"code": "4000", "name": "الإيرادات", "section": "revenue", "nature": "credit", "concept_id": "REVENUE"},
            {"code": "5000", "name": "المشتريات", "section": "cogs", "nature": "debit", "concept_id": "PURCHASES"},
        ]
        mappings = build_migration_map(self.OLD_COA, new_coa)
        recoded = [m for m in mappings if m["map_type"] == "RECODED"]
        assert len(recoded) >= 1
        assert recoded[0]["old_code"] == "1100"
        assert recoded[0]["new_code"] == "1110"
        assert recoded[0]["confidence"] == 0.90


class TestWave4VersionImpact:
    """Tests for compute_version_impact — ملحق ع"""

    def test_version_impact_improvement(self):
        """Fixing errors should show score_delta > 0."""
        old_coa = [
            {"code": "1000", "name": "الأصول", "section": "asset", "nature": "debit"},
        ]
        new_coa = [
            {"code": "1000", "name": "الأصول", "section": "asset", "nature": "debit"},
            {"code": "1100", "name": "النقد", "section": "current_asset", "nature": "debit"},
            {"code": "2000", "name": "الخصوم", "section": "liability", "nature": "credit"},
        ]
        evolution = compare_coa_versions(old_coa, new_coa)
        old_report = {"quality_score": 55.0, "quality_grade": "F"}
        new_report = {"quality_score": 75.0, "quality_grade": "C"}
        impact = compute_version_impact(old_report, new_report, evolution)
        assert impact["score_delta"] > 0
        assert impact["direction"] == "improved"
        assert len(impact["top_improvements"]) > 0

    def test_version_impact_degradation(self):
        """Deleting mandatory accounts should show degradation."""
        old_coa = [
            {"code": "1000", "name": "الأصول", "section": "asset", "nature": "debit"},
            {"code": "1100", "name": "النقد", "section": "current_asset", "nature": "debit"},
            {"code": "2000", "name": "الخصوم", "section": "liability", "nature": "credit"},
        ]
        new_coa = [
            {"code": "1000", "name": "الأصول", "section": "asset", "nature": "debit"},
        ]
        evolution = compare_coa_versions(old_coa, new_coa)
        old_report = {"quality_score": 80.0, "quality_grade": "B"}
        new_report = {"quality_score": 60.0, "quality_grade": "D"}
        impact = compute_version_impact(old_report, new_report, evolution)
        assert impact["score_delta"] < 0
        assert impact["direction"] == "degraded"
        assert len(impact["critical_regressions"]) > 0


class TestWave4TBBreaks:
    """Tests for detect_tb_linkage_breaks — ملحق ع.3"""

    def test_tb_breaks_rebalanced(self):
        """Nature changed → NATURE_REVERSAL break detected."""
        migration = [{
            "old_code": "1100",
            "new_code": "1100",
            "map_type": "RECLASSIFIED",
            "old_section": "asset",
            "new_section": "expense",
            "old_nature": "debit",
            "new_nature": "credit",
            "source_natures_conflict": True,
        }]
        breaks = detect_tb_linkage_breaks(migration)
        break_types = {b["break_type"] for b in breaks}
        assert "NATURE_REVERSAL" in break_types
        # asset→expense = balance_sheet→income_statement = cross-statement move
        assert "CROSS_STATEMENT_MOVE" in break_types
        # All should require journal entries
        assert all(b["requires_journal_entry"] for b in breaks)

    def test_tb_breaks_deleted(self):
        """Deleted account → ORPHANED_BALANCE break."""
        migration = [{
            "old_code": "4100",
            "new_code": None,
            "map_type": "DELETED",
            "old_section": "revenue",
            "new_section": None,
            "old_nature": "credit",
            "new_nature": None,
            "source_natures_conflict": False,
        }]
        breaks = detect_tb_linkage_breaks(migration)
        assert len(breaks) == 1
        assert breaks[0]["break_type"] == "ORPHANED_BALANCE"
        assert breaks[0]["severity"] == "High"

    def test_tb_breaks_no_breaks_for_same(self):
        """SAME mapping should produce no breaks."""
        migration = [{
            "old_code": "1000",
            "new_code": "1000",
            "map_type": "SAME",
            "old_section": "asset",
            "new_section": "asset",
            "old_nature": "debit",
            "new_nature": "debit",
            "source_natures_conflict": False,
        }]
        breaks = detect_tb_linkage_breaks(migration)
        assert len(breaks) == 0


class TestWave4HealthTrend:
    """Tests for get_quality_trend — health trend."""

    def test_health_trend_ascending(self):
        """Quality scores should increase after fixes."""
        try:
            import aiosqlite  # noqa: F401
        except ImportError:
            pytest.skip("aiosqlite not installed")
        import tempfile, os
        db_path = os.path.join(tempfile.gettempdir(), "test_wave4_trend.db")
        try:
            db = Database(db_path)
            asyncio.run(db.connect())
            asyncio.run(db.initialize_schema())
            # Save 3 versions with increasing scores
            asyncio.run(db.save_coa_version("client-T", "up-1", 60.0, 100))
            asyncio.run(db.save_coa_version("client-T", "up-2", 72.0, 120))
            asyncio.run(db.save_coa_version("client-T", "up-3", 85.0, 130))
            trend = asyncio.run(db.get_quality_trend("client-T"))
            assert len(trend) == 3
            assert trend[0]["version"] == 1
            assert trend[0]["score"] == 60.0
            assert trend[1]["score"] == 72.0
            assert trend[2]["score"] == 85.0
            # Ascending
            scores = [t["score"] for t in trend]
            assert scores == sorted(scores), "Scores should be ascending after fixes"
            asyncio.run(db.disconnect())
        finally:
            if os.path.exists(db_path):
                os.remove(db_path)


# ─────────────────────────────────────────────────────────────
# Wave 5: Knowledge Graph Tests
# ─────────────────────────────────────────────────────────────
class TestWave5KnowledgeGraph:
    """Tests for KNOWLEDGE_GRAPH — ملحق م"""

    def test_knowledge_graph_coverage(self):
        """At least 50 nodes in the knowledge graph."""
        assert len(KNOWLEDGE_GRAPH) >= 50, f"Expected ≥50, got {len(KNOWLEDGE_GRAPH)}"

    def test_each_node_has_required_fields(self):
        """Every node must have concept_id, name_ar, section, nature, relations."""
        for cid, node in KNOWLEDGE_GRAPH.items():
            assert node["concept_id"] == cid, f"{cid}: concept_id mismatch"
            assert node.get("name_ar"), f"{cid}: missing name_ar"
            assert node.get("section"), f"{cid}: missing section"
            assert node.get("nature"), f"{cid}: missing nature"
            assert "relations" in node, f"{cid}: missing relations"

    def test_ontology_validates_requires(self):
        """ACC_RECEIVABLE without ECL_PROVISION → E28 error."""
        accounts = [
            {"concept_id": "ACC_RECEIVABLE", "code": "1200", "name": "ذمم مدينة", "section": "current_asset"},
            {"concept_id": "CASH", "code": "1100", "name": "النقد", "section": "current_asset"},
        ]
        errors = validate_ontology(accounts)
        e28 = [e for e in errors if e["error_code"] == "E28"
               and "ECL_PROVISION" in e.get("suggestion_ar", "")]
        assert len(e28) >= 1, "Should detect missing ECL_PROVISION"

    def test_ontology_validates_ifrs_pair(self):
        """ROU_ASSET without LEASE_LIABILITY → E27 error."""
        accounts = [
            {"concept_id": "ROU_ASSET", "code": "1500", "name": "حق استخدام", "section": "fixed_asset"},
            {"concept_id": "CASH", "code": "1100", "name": "النقد", "section": "current_asset"},
        ]
        errors = validate_ontology(accounts)
        e27 = [e for e in errors if e["error_code"] == "E27"]
        assert len(e27) >= 1, "Should detect missing LEASE_LIABILITY_NC"

    def test_ontology_no_errors_when_complete(self):
        """Complete pair should not produce REQUIRES/IFRS errors."""
        accounts = [
            {"concept_id": "ACC_RECEIVABLE", "code": "1200", "name": "ذمم مدينة"},
            {"concept_id": "ECL_PROVISION", "code": "1201", "name": "مخصص خسائر ائتمانية"},
            {"concept_id": "ROU_ASSET", "code": "1500", "name": "حق استخدام"},
            {"concept_id": "LEASE_LIABILITY_NC", "code": "2500", "name": "التزام إيجار"},
            {"concept_id": "BUILDINGS", "code": "1300", "name": "المباني"},
            {"concept_id": "ACCUM_DEPR_BUILDINGS", "code": "1301", "name": "مجمع إهلاك المباني"},
            {"concept_id": "SALES_REVENUE", "code": "4100", "name": "مبيعات"},
            {"concept_id": "COGS", "code": "5100", "name": "تكلفة المبيعات"},
            {"concept_id": "EOSB_PROVISION", "code": "2600", "name": "مخصص نهاية الخدمة"},
            {"concept_id": "EOSB_EXPENSE", "code": "6200", "name": "مصروف نهاية الخدمة"},
            {"concept_id": "INVENTORY", "code": "1400", "name": "المخزون"},
        ]
        errors = validate_ontology(accounts)
        requires_errors = [e for e in errors if e["error_code"] in ("E27", "E28")]
        assert len(requires_errors) == 0, f"Should not have REQUIRES errors but got: {requires_errors}"


class TestWave5BFS:
    """Tests for BFS graph traversal — ملحق غ"""

    def test_bfs_depth_1(self):
        """get_graph_context('CASH', depth=1) should return siblings including BANK."""
        ctx = get_graph_context("CASH", depth=1)
        assert ctx["found"] is True
        assert ctx["center"] == "CASH"
        assert "BANK" in ctx["siblings"]
        assert "PETTY_CASH" in ctx["siblings"]

    def test_bfs_depth_2(self):
        """get_graph_context('ACC_RECEIVABLE', depth=2) should find ECL_PROVISION in requires."""
        ctx = get_graph_context("ACC_RECEIVABLE", depth=2)
        assert ctx["found"] is True
        assert "ECL_PROVISION" in ctx["requires"]
        # At depth 2, should also find related nodes
        related_ids = {r["concept_id"] for r in ctx["related"]}
        assert len(related_ids) > 0

    def test_bfs_unknown_concept(self):
        """Unknown concept should return found=False."""
        ctx = get_graph_context("NONEXISTENT_CONCEPT", depth=1)
        assert ctx["found"] is False

    def test_bfs_has_confidence_boost(self):
        """Context with many relations should have positive boost."""
        ctx = get_graph_context("BUILDINGS", depth=2)
        assert ctx["confidence_boost"] > 0


class TestWave5GraphClassification:
    """Tests for graph-enhanced classification."""

    def test_graph_boosts_confidence(self):
        """Account with matching parent section should get confidence boost."""
        account = {"code": "1100", "name": "النقدية", "section": "current_asset"}
        ctx = get_graph_context("CASH", depth=1)
        layer3_result = {
            "concept_id": "CASH",
            "section": "current_asset",
            "nature": "debit",
            "confidence": 0.80,
        }
        result = classify_with_graph(account, ctx, layer3_result)
        assert result["confidence"] > 0.80, \
            f"Expected confidence > 0.80, got {result['confidence']}"
        assert result["graph_boost"] > 0

    def test_graph_penalizes_conflict(self):
        """Account classified in wrong section should get slight penalty."""
        account = {"code": "1100", "name": "النقدية", "section": "expense"}
        ctx = get_graph_context("CASH", depth=1)
        layer3_result = {
            "concept_id": "CASH",
            "section": "expense",  # wrong!
            "nature": "debit",
            "confidence": 0.80,
        }
        result = classify_with_graph(account, ctx, layer3_result)
        assert result["graph_boost"] < 0
        assert len(result["graph_warnings"]) > 0


# ─────────────────────────────────────────────────────────────
# Wave 6: Financial Simulation & Compliance Tests
# ─────────────────────────────────────────────────────────────
class TestWave6Simulation:
    """Tests for simulate_financial_statements — ملحق ن"""

    def _full_coa(self):
        """A reasonably complete COA."""
        return [
            {"concept_id": "CASH", "section": "current_asset", "nature": "debit"},
            {"concept_id": "BANK", "section": "current_asset", "nature": "debit"},
            {"concept_id": "ACC_RECEIVABLE", "section": "current_asset", "nature": "debit"},
            {"concept_id": "ECL_PROVISION", "section": "current_asset", "nature": "credit"},
            {"concept_id": "INVENTORY", "section": "current_asset", "nature": "debit"},
            {"concept_id": "BUILDINGS", "section": "fixed_asset", "nature": "debit"},
            {"concept_id": "ACCUM_DEPR_BUILDINGS", "section": "fixed_asset", "nature": "credit"},
            {"concept_id": "ACC_PAYABLE", "section": "current_liability", "nature": "credit"},
            {"concept_id": "VAT_INPUT", "section": "current_asset", "nature": "debit"},
            {"concept_id": "VAT_OUTPUT", "section": "current_liability", "nature": "credit"},
            {"concept_id": "PAID_IN_CAPITAL", "section": "equity", "nature": "credit"},
            {"concept_id": "RETAINED_EARNINGS", "section": "equity", "nature": "credit"},
            {"concept_id": "LEGAL_RESERVE", "section": "equity", "nature": "credit"},
            {"concept_id": "ZAKAT_PAYABLE", "section": "current_liability", "nature": "credit"},
            {"concept_id": "SALES_REVENUE", "section": "revenue", "nature": "credit"},
            {"concept_id": "COGS", "section": "cogs", "nature": "debit"},
            {"concept_id": "SALARIES_WAGES", "section": "expense", "nature": "debit"},
            {"concept_id": "DEPRECIATION_EXPENSE", "section": "expense", "nature": "debit"},
            {"concept_id": "EOSB_PROVISION", "section": "non_current_liability", "nature": "credit"},
            {"concept_id": "EOSB_EXPENSE", "section": "expense", "nature": "debit"},
        ]

    def test_simulation_detects_missing_cogs(self):
        """Revenue without COGS → MISSING_COGS gap."""
        accounts = [
            {"concept_id": "CASH", "section": "current_asset", "nature": "debit"},
            {"concept_id": "SALES_REVENUE", "section": "revenue", "nature": "credit"},
            {"concept_id": "PAID_IN_CAPITAL", "section": "equity", "nature": "credit"},
        ]
        sim = simulate_financial_statements(accounts)
        gap_types = [g["gap"] for g in sim["structural_gaps"]]
        assert "MISSING_COGS" in gap_types

    def test_simulation_equation_valid(self):
        """Balanced COA → equation_valid = True."""
        sim = simulate_financial_statements(self._full_coa())
        assert sim["balance_sheet"]["equation_valid"] is True

    def test_simulation_readiness_score(self):
        """Readiness score should be 0-100."""
        sim = simulate_financial_statements(self._full_coa())
        assert 0 <= sim["readiness_score"] <= 100

    def test_simulation_no_cogs_gap_when_present(self):
        """Complete COA should not have MISSING_COGS."""
        sim = simulate_financial_statements(self._full_coa())
        gap_types = [g["gap"] for g in sim["structural_gaps"]]
        assert "MISSING_COGS" not in gap_types

    def test_simulation_cash_flow_indicators(self):
        """Full COA should have cash flow indicators."""
        sim = simulate_financial_statements(self._full_coa())
        cf = sim["cash_flow_indicators"]
        assert cf["has_cash_accounts"] is True
        assert cf["has_depreciation"] is True
        assert cf["has_working_capital"] is True


class TestWave6Compliance:
    """Tests for run_compliance_check — ملحق ل2"""

    def test_compliance_zatca_vat_fails(self):
        """Revenue without VAT → ZATCA_VAT_SEPARATION fails."""
        accounts = [
            {"concept_id": "SALES_REVENUE", "section": "revenue"},
            {"concept_id": "CASH", "section": "current_asset"},
        ]
        result = run_compliance_check(accounts)
        failed_ids = [f["id"] for f in result["failed"]]
        assert "ZATCA_VAT_SEPARATION" in failed_ids

    def test_compliance_ifrs16_fails(self):
        """ROU_ASSET without lease liability → IFRS16_LEASE fails."""
        accounts = [
            {"concept_id": "ROU_ASSET", "section": "fixed_asset"},
            {"concept_id": "CASH", "section": "current_asset"},
        ]
        result = run_compliance_check(accounts)
        failed_ids = [f["id"] for f in result["failed"]]
        assert "IFRS16_LEASE" in failed_ids

    def test_compliance_score_range(self):
        """Compliance score should be 0-100."""
        accounts = [
            {"concept_id": "CASH", "section": "current_asset"},
            {"concept_id": "ACC_RECEIVABLE", "section": "current_asset"},
        ]
        result = run_compliance_check(accounts)
        assert 0 <= result["compliance_score"] <= 100

    def test_compliance_all_pass_when_complete(self):
        """Complete COA should pass most rules."""
        accounts = [
            {"concept_id": "CASH", "section": "current_asset"},
            {"concept_id": "ACC_RECEIVABLE", "section": "current_asset"},
            {"concept_id": "ECL_PROVISION", "section": "current_asset"},
            {"concept_id": "VAT_INPUT", "section": "current_asset"},
            {"concept_id": "VAT_OUTPUT", "section": "current_liability"},
            {"concept_id": "PAID_IN_CAPITAL", "section": "equity"},
            {"concept_id": "LEGAL_RESERVE", "section": "equity"},
            {"concept_id": "ZAKAT_PAYABLE", "section": "current_liability"},
            {"concept_id": "ROU_ASSET", "section": "fixed_asset"},
            {"concept_id": "LEASE_LIABILITY_NC", "section": "non_current_liability"},
            {"concept_id": "SALARIES_WAGES", "section": "expense"},
            {"concept_id": "EOSB_PROVISION", "section": "non_current_liability"},
        ]
        result = run_compliance_check(accounts)
        assert result["compliance_score"] >= 80, \
            f"Expected ≥80, got {result['compliance_score']}. Failed: {[f['id'] for f in result['failed']]}"


class TestWave6Roadmap:
    """Tests for generate_implementation_roadmap — ملحق ن2"""

    def test_roadmap_sorted_by_priority(self):
        """Roadmap items should be sorted by priority (rank ascending)."""
        sim = simulate_financial_statements([
            {"concept_id": "SALES_REVENUE", "section": "revenue"},
            {"concept_id": "CASH", "section": "current_asset"},
        ])
        comp = run_compliance_check([
            {"concept_id": "SALES_REVENUE", "section": "revenue"},
            {"concept_id": "CASH", "section": "current_asset"},
        ])
        roadmap = generate_implementation_roadmap([], sim, comp)
        if len(roadmap) >= 2:
            ranks = [item["rank"] for item in roadmap]
            assert ranks == sorted(ranks), "Roadmap should be sorted by rank"

    def test_roadmap_has_effort(self):
        """Every roadmap item should have effort field."""
        sim = simulate_financial_statements([
            {"concept_id": "SALES_REVENUE", "section": "revenue"},
            {"concept_id": "CASH", "section": "current_asset"},
        ])
        comp = run_compliance_check([
            {"concept_id": "SALES_REVENUE", "section": "revenue"},
        ])
        roadmap = generate_implementation_roadmap([], sim, comp)
        valid_efforts = {"سهل", "متوسط", "صعب"}
        for item in roadmap:
            assert "effort" in item, f"Missing effort: {item}"
            assert item["effort"] in valid_efforts, f"Invalid effort: {item['effort']}"

    def test_roadmap_has_score_impact(self):
        """Every roadmap item should have score_impact."""
        sim = simulate_financial_statements([
            {"concept_id": "CASH", "section": "current_asset"},
            {"concept_id": "SALES_REVENUE", "section": "revenue"},
        ])
        comp = run_compliance_check([{"concept_id": "CASH"}])
        roadmap = generate_implementation_roadmap([], sim, comp)
        for item in roadmap:
            assert "score_impact" in item


class TestWave6Pipeline:
    """Test that pipeline includes simulation/compliance/roadmap."""

    def test_pipeline_includes_simulation(self, engine):
        r = asyncio.run(
            engine.process(
                (Path(__file__).parent.parent / "app" / "coa_engine" / "sample_files" / "01_ODOO_FLAT.xlsx").read_bytes(),
                filename="01_ODOO_FLAT.xlsx",
            )
        )
        assert r.simulation is not None, "Pipeline should include simulation"
        assert "balance_sheet" in r.simulation
        assert "structural_gaps" in r.simulation
        assert 0 <= r.simulation["readiness_score"] <= 100

    def test_pipeline_includes_compliance(self, engine):
        r = asyncio.run(
            engine.process(
                (Path(__file__).parent.parent / "app" / "coa_engine" / "sample_files" / "01_ODOO_FLAT.xlsx").read_bytes(),
                filename="01_ODOO_FLAT.xlsx",
            )
        )
        assert r.compliance is not None, "Pipeline should include compliance"
        assert 0 <= r.compliance["compliance_score"] <= 100

    def test_pipeline_roadmap_is_list(self, engine):
        r = asyncio.run(
            engine.process(
                (Path(__file__).parent.parent / "app" / "coa_engine" / "sample_files" / "01_ODOO_FLAT.xlsx").read_bytes(),
                filename="01_ODOO_FLAT.xlsx",
            )
        )
        assert isinstance(r.roadmap, list)


# ═══════════════════════════════════════════════════════════════
# Wave 7 Tests — Fraud Layer + Governance
# ═══════════════════════════════════════════════════════════════

class TestWave7FP08:
    """FP08 partner drawings detection."""

    def test_fp08_no_drawings(self):
        accounts = [{"code": "1101", "name_raw": "نقد", "nature": "asset"}]
        result = detect_fp08_partner_drawings(accounts)
        assert result is None

    def test_fp08_proactive_without_tb(self):
        accounts = [
            {"code": "3201", "name_raw": "سحوبات الشريك أحمد", "nature": "equity"},
            {"code": "3100", "name_raw": "رأس المال", "nature": "equity"},
        ]
        result = detect_fp08_partner_drawings(accounts)
        assert result is not None
        assert result.pattern_id == "FP08"
        assert result.risk == "Medium"

    def test_fp08_critical_with_tb(self):
        accounts = [
            {"code": "3201", "name_raw": "سحوبات الشريك", "nature": "equity"},
            {"code": "3100", "name_raw": "رأس المال", "nature": "equity"},
        ]
        tb = {
            "3201": {"debit": 600000, "credit": 0},
            "3100": {"debit": 0, "credit": 1000000},
        }
        result = detect_fp08_partner_drawings(accounts, trial_balance=tb)
        assert result is not None
        assert result.risk == "Critical"
        assert "60.0%" in result.message

    def test_fp08_safe_with_tb(self):
        accounts = [
            {"code": "3201", "name_raw": "سحوبات الشريك", "nature": "equity"},
            {"code": "3100", "name_raw": "رأس المال", "nature": "equity"},
        ]
        tb = {
            "3201": {"debit": 100000, "credit": 0},
            "3100": {"debit": 0, "credit": 1000000},
        }
        result = detect_fp08_partner_drawings(accounts, trial_balance=tb)
        assert result is None  # 10% < 50% threshold


class TestWave7TrialBalance:
    """Trial balance check."""

    def test_balanced(self):
        tb = {
            "1101": {"debit": 50000, "credit": 0},
            "2101": {"debit": 0, "credit": 30000},
            "3100": {"debit": 0, "credit": 20000},
        }
        result = check_trial_balance(tb)
        assert result["is_balanced"] is True
        assert result["difference"] < 0.01
        assert result["account_count"] == 3

    def test_unbalanced(self):
        tb = {
            "1101": {"debit": 50000, "credit": 0},
            "2101": {"debit": 0, "credit": 30000},
        }
        result = check_trial_balance(tb)
        assert result["is_balanced"] is False
        assert result["difference"] == 20000.0


class TestWave7Governance:
    """Governance lifecycle: propose → approve → deprecate."""

    def test_propose_rule(self):
        rule = propose_rule("E99_CUSTOM", description_ar="قاعدة مخصصة")
        assert rule["rule_id"].startswith("R-")
        assert rule["status"] == "draft"
        assert rule["rule_name"] == "E99_CUSTOM"

    def test_approve_rule(self):
        rule = propose_rule("E99_TEST")
        result = approve_rule(rule, approved_by="admin")
        assert result["success"] is True
        assert result["new_status"] == "active"

    def test_approve_non_draft_fails(self):
        rule = propose_rule("E99_TEST")
        rule["status"] = "active"
        result = approve_rule(rule)
        assert result["success"] is False

    def test_deprecate_rule(self):
        rule = propose_rule("E99_TEST")
        rule["status"] = "active"
        result = deprecate_rule(rule, reason="لم يعد مطلوباً")
        assert result["success"] is True
        assert result["new_status"] == "deprecated"

    def test_get_active_rules(self):
        rules = [
            {"status": "draft", "rule_id": "R1"},
            {"status": "active", "rule_id": "R2"},
            {"status": "deprecated", "rule_id": "R3"},
            {"status": "active", "rule_id": "R4"},
        ]
        active = get_active_rules(rules)
        assert len(active) == 2

    def test_governance_stats(self):
        rules = [
            {"status": "active", "rule_type": "error_check", "severity": "High",
             "execution_count": 100, "success_rate": 0.9},
            {"status": "draft", "rule_type": "fraud", "severity": "Critical",
             "execution_count": 0, "success_rate": 0.0},
        ]
        stats = get_governance_stats(rules)
        assert stats["total_rules"] == 2
        assert stats["by_status"]["active"] == 1
        assert stats["total_executions"] == 100


class TestWave7ABTest:
    """A/B testing framework."""

    def test_ab_test_basic(self):
        rule_a = {"rule_id": "RA", "severity": "Medium"}
        rule_b = {"rule_id": "RB", "severity": "High"}
        result = run_ab_test(rule_a, rule_b, [])
        assert result["winner"] in ("A", "B")
        assert result["winning_rule_id"] in ("RA", "RB")

    def test_shadow_release_safe(self):
        baseline = {"rule_id": "R_BASE", "severity": "Medium"}
        new_rule = {"rule_id": "R_NEW", "severity": "Medium"}
        result = shadow_release(new_rule, baseline, [], threshold=0.9)
        assert result["safe_to_deploy"] is True


class TestWave7AutoRollback:
    """Auto-rollback checks."""

    def test_rollback_low_success(self):
        rule = {"rule_id": "R1", "status": "active", "execution_count": 50, "success_rate": 0.3}
        result = check_auto_rollback(rule, min_executions=10, min_success_rate=0.7)
        assert result["should_rollback"] is True

    def test_no_rollback_good_performance(self):
        rule = {"rule_id": "R2", "status": "active", "execution_count": 50, "success_rate": 0.95}
        result = check_auto_rollback(rule, min_executions=10, min_success_rate=0.7)
        assert result["should_rollback"] is False

    def test_no_rollback_insufficient_data(self):
        rule = {"rule_id": "R3", "status": "active", "execution_count": 5, "success_rate": 0.1}
        result = check_auto_rollback(rule, min_executions=10)
        assert result["should_rollback"] is False

    def test_governance_alert_created(self):
        alert = notify_governance_alert(
            rule_id="R1", alert_type="auto_rollback",
            message="نسبة النجاح منخفضة", severity="Critical",
        )
        assert alert["alert_id"].startswith("GA-")
        assert alert["rule_id"] == "R1"
        assert alert["resolved"] is False
