"""
Tests for APEX COA Engine v4.2 — Wave 1 Core Components
"""

import pytest
import pandas as pd
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))


# ── Pattern Detector ──
class TestPatternDetector:
    def test_generic_flat_detection(self):
        from app.coa_engine.services.pattern_detector import detect_pattern

        df = pd.DataFrame({"كود الحساب": ["1001", "1101"], "اسم الحساب": ["نقدية", "عملاء"]})
        result = detect_pattern(df)
        assert result["pattern"] == "GENERIC_FLAT"
        assert result["reject"] is False

    def test_odoo_flat_detection(self):
        from app.coa_engine.services.pattern_detector import detect_pattern

        df = pd.DataFrame(
            {
                "code": ["1001", "1101"],
                "name": ["Cash", "Receivables"],
                "user_type_id": ["asset_cash", "asset_receivable"],
            }
        )
        result = detect_pattern(df)
        assert result["pattern"] in ("ODOO_FLAT", "ENGLISH_WITH_CLASS", "GENERIC_FLAT")
        assert result["reject"] is False

    def test_migration_file_detection(self):
        from app.coa_engine.services.pattern_detector import detect_pattern

        df = pd.DataFrame(
            {
                "الكود القديم": ["100", "200"],
                "الكود الجديد": ["1001", "2001"],
                "اسم الحساب": ["نقدية", "موردين"],
            }
        )
        result = detect_pattern(df)
        assert result["pattern"] == "MIGRATION_FILE"

    def test_unknown_pattern(self):
        from app.coa_engine.services.pattern_detector import detect_pattern

        df = pd.DataFrame({"x": [1, 2], "y": [3, 4]})
        result = detect_pattern(df)
        assert result["pattern"] in ("UNKNOWN", "GENERIC_FLAT")


# ── Column Mapper ──
class TestColumnMapper:
    def test_arabic_column_mapping(self):
        from app.coa_engine.services.column_mapper import map_columns, validate_mapping

        cols = ["كود الحساب", "اسم الحساب", "كود الأب", "نوع الحساب"]
        mapping = map_columns(cols)
        valid, missing = validate_mapping(mapping)
        assert valid is True
        assert "code" in mapping
        assert "name" in mapping

    def test_english_column_mapping(self):
        from app.coa_engine.services.column_mapper import map_columns, validate_mapping

        cols = ["account code", "account name", "parent code", "account type"]
        mapping = map_columns(cols)
        valid, missing = validate_mapping(mapping)
        assert valid is True
        assert "code" in mapping
        assert "name" in mapping

    def test_missing_required_columns(self):
        from app.coa_engine.services.column_mapper import map_columns, validate_mapping

        cols = ["something", "else"]
        mapping = map_columns(cols)
        valid, missing = validate_mapping(mapping)
        assert valid is False
        assert len(missing) > 0


# ── Normalizer ──
class TestNormalizer:
    def test_normalize_code_float(self):
        from app.coa_engine.services.normalizer import normalize_code

        assert normalize_code("1100.0") == "1100"
        assert normalize_code(1100.0) == "1100"

    def test_normalize_code_scientific(self):
        from app.coa_engine.services.normalizer import normalize_code

        assert normalize_code("1.1e3") == "1100"

    def test_normalize_code_dash_separated(self):
        from app.coa_engine.services.normalizer import normalize_code

        result = normalize_code("1-1-0-0")
        assert result == "1100"

    def test_normalize_code_dot_hierarchical(self):
        from app.coa_engine.services.normalizer import normalize_code

        result = normalize_code("1.1.0.0")
        assert result == "1.1.0.0"

    def test_normalize_code_with_prefix(self):
        from app.coa_engine.services.normalizer import normalize_code

        result = normalize_code("ACC-1100")
        assert "1100" in result

    def test_normalize_name_arabic(self):
        from app.coa_engine.services.normalizer import normalize_account_name

        result = normalize_account_name("  النَّقْدِيَّة  ")
        assert "النقدي" in result or "النقديه" in result

    def test_normalize_name_strips_cancelled(self):
        from app.coa_engine.services.normalizer import normalize_account_name

        result = normalize_account_name("حساب قديم (ملغي)")
        assert "ملغي" not in result

    def test_encoding_detection(self):
        from app.coa_engine.services.normalizer import detect_encoding

        utf8_bytes = "النقدية".encode("utf-8")
        assert detect_encoding(utf8_bytes) == "utf-8"


# ── Hierarchy Builder ──
class TestHierarchyBuilder:
    def test_prefix_matching_hierarchy(self):
        from app.coa_engine.services.hierarchy_builder import build_hierarchy

        df = pd.DataFrame(
            {
                "code": ["1", "11", "1101", "1102", "12", "1201"],
                "name": ["أصول", "أصول متداولة", "نقدية", "بنوك", "أصول ثابتة", "أراضي"],
            }
        )
        mapping = {"code": "code", "name": "name"}
        result = build_hierarchy(df, mapping, "GENERIC_FLAT")
        assert len(result) == 6
        # Root should be level 1
        root = next(a for a in result if a["code"] == "1")
        assert root["level"] == 1
        assert root["parent_code"] is None

    def test_explicit_parent_hierarchy(self):
        from app.coa_engine.services.hierarchy_builder import build_hierarchy

        df = pd.DataFrame(
            {
                "code": ["1", "11", "1101"],
                "name": ["أصول", "أصول متداولة", "نقدية"],
                "parent_code": ["", "1", "11"],
            }
        )
        mapping = {"code": "code", "name": "name", "parent_code": "parent_code"}
        result = build_hierarchy(df, mapping, "HIERARCHICAL_NUMERIC_PARENT")
        assert len(result) == 3

    def test_empty_dataframe(self):
        from app.coa_engine.services.hierarchy_builder import build_hierarchy

        df = pd.DataFrame({"code": [], "name": []})
        mapping = {"code": "code", "name": "name"}
        result = build_hierarchy(df, mapping, "GENERIC_FLAT")
        assert len(result) == 0


# ── Classifier ──
class TestClassifier:
    def test_code_prefix_classification(self):
        from app.coa_engine.services.classifier import classify_accounts

        accounts = [
            {"code": "1001", "name": "نقدية", "name_normalized": "نقديه"},
            {"code": "2001", "name": "موردين", "name_normalized": "موردين"},
            {"code": "3001", "name": "رأس المال", "name_normalized": "راس المال"},
            {"code": "4001", "name": "مبيعات", "name_normalized": "مبيعات"},
            {"code": "5001", "name": "تكلفة المبيعات", "name_normalized": "تكلفه المبيعات"},
        ]
        result = classify_accounts(accounts, {}, "GENERIC_FLAT")
        assert len(result) == 5
        assert result[0]["main_class"] == "asset"
        assert result[1]["main_class"] == "liability"
        assert result[2]["main_class"] == "equity"
        assert result[3]["main_class"] == "revenue"
        assert result[4]["main_class"] == "cogs"

    def test_confidence_above_threshold(self):
        from app.coa_engine.services.classifier import classify_accounts

        accounts = [{"code": "1001", "name": "النقدية في الصندوق", "name_normalized": "النقديه في الصندوق"}]
        result = classify_accounts(accounts, {}, "GENERIC_FLAT")
        assert result[0]["confidence"] >= 0.70

    def test_erp_type_classification(self):
        from app.coa_engine.services.classifier import classify_accounts

        accounts = [{"code": "X1", "name": "Unknown", "name_normalized": "unknown", "type": "asset_cash"}]
        mapping = {"type": "type"}
        result = classify_accounts(accounts, mapping, "ODOO_FLAT", erp_system="Odoo")
        assert result[0]["main_class"] == "asset"


# ── Canonical Accounts Data ──
class TestCanonicalAccounts:
    def test_account_count(self):
        from app.coa_engine.data.canonical_accounts import CANONICAL_ACCOUNTS

        assert len(CANONICAL_ACCOUNTS) >= 150  # Should have 197+

    def test_concept_index(self):
        from app.coa_engine.data.canonical_accounts import CONCEPT_INDEX

        assert "CASH" in CONCEPT_INDEX
        assert "ACC_RECEIVABLE" in CONCEPT_INDEX
        assert "RETAINED_EARNINGS" in CONCEPT_INDEX

    def test_get_by_section(self):
        from app.coa_engine.data.canonical_accounts import get_accounts_by_section

        current_assets = get_accounts_by_section("current_asset")
        assert len(current_assets) >= 10


# ── Sectors Data ──
class TestSectors:
    def test_sector_count(self):
        from app.coa_engine.data.sectors import SECTORS

        assert len(SECTORS) >= 45

    def test_common_mandatory_accounts(self):
        from app.coa_engine.data.sectors import COMMON_MANDATORY_ACCOUNTS

        assert "CASH" in COMMON_MANDATORY_ACCOUNTS
        assert "ACC_RECEIVABLE" in COMMON_MANDATORY_ACCOUNTS

    def test_sector_has_mandatory(self):
        from app.coa_engine.data.sectors import get_sector

        retail = get_sector("RETAIL")
        assert retail is not None
        assert "INVENTORY" in retail["mandatory_accounts"]


# ── Pipeline (Integration) ──
class TestPipeline:
    def test_process_simple_coa(self):
        from app.coa_engine.services.pipeline import process_dataframe, PipelineResult

        df = pd.DataFrame(
            {
                "كود الحساب": ["1", "11", "1101", "1102", "2", "21", "2101", "3", "31", "4", "41", "5", "51"],
                "اسم الحساب": [
                    "أصول",
                    "أصول متداولة",
                    "نقدية",
                    "بنوك",
                    "التزامات",
                    "التزامات متداولة",
                    "موردين",
                    "حقوق ملكية",
                    "رأس المال",
                    "إيرادات",
                    "مبيعات",
                    "مصروفات",
                    "رواتب",
                ],
            }
        )
        result = process_dataframe(df, filename="test.xlsx")
        assert isinstance(result, PipelineResult)
        assert result.status == "completed"
        assert result.pattern is not None
        assert len(result.accounts) == 13
        assert result.quality_score > 0

    def test_process_empty_fails(self):
        from app.coa_engine.services.pipeline import process_dataframe

        df = pd.DataFrame()
        result = process_dataframe(df, filename="empty.xlsx")
        assert result.status == "failed"

    def test_pipeline_result_to_dict(self):
        from app.coa_engine.services.pipeline import PipelineResult

        result = PipelineResult()
        result.status = "completed"
        result.quality_score = 85.5
        d = result.to_dict()
        assert d["status"] == "completed"
        assert d["quality_score"] == 85.5
        assert "accounts" in d


# ── API Routes ──
class TestEngineRoutes:
    @pytest.fixture
    def client(self):
        from fastapi.testclient import TestClient
        from app.main import app

        return TestClient(app)

    def test_health_endpoint(self, client):
        resp = client.get("/api/coa-engine/health")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert "4.2" in data["data"]["version"]

    def test_patterns_endpoint(self, client):
        resp = client.get("/api/coa-engine/patterns")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert data["data"]["count"] >= 12

    def test_canonical_accounts_endpoint(self, client):
        resp = client.get("/api/coa-engine/canonical-accounts")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert data["data"]["count"] >= 100

    def test_canonical_accounts_filter(self, client):
        resp = client.get("/api/coa-engine/canonical-accounts?section=current_asset")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        for acct in data["data"]["accounts"]:
            assert acct["section"] == "current_asset"

    def test_sectors_endpoint(self, client):
        resp = client.get("/api/coa-engine/sectors")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert data["data"]["count"] >= 45

    def test_upload_requires_auth(self, client):
        resp = client.post("/api/coa-engine/upload")
        assert resp.status_code in (401, 403, 422)

    def test_analyze_requires_auth(self, client):
        resp = client.post("/api/coa-engine/analyze")
        assert resp.status_code in (401, 403, 422)


# ── Wave 2: Error Catalog ──
class TestErrorCatalog:
    def test_error_count(self):
        from app.coa_engine.data.error_catalog import ERROR_CATALOG

        assert len(ERROR_CATALOG) == 58

    def test_error_index(self):
        from app.coa_engine.data.error_catalog import ERROR_INDEX

        assert "E01" in ERROR_INDEX
        assert "E50" in ERROR_INDEX
        assert "EP1" in ERROR_INDEX
        assert "EC5" in ERROR_INDEX

    def test_error_structure(self):
        from app.coa_engine.data.error_catalog import ERROR_INDEX

        e01 = ERROR_INDEX["E01"]
        assert e01["severity"] == "Critical"
        assert e01["category"] == "structural"
        assert e01["auto_fixable"] is True
        assert "name_ar" in e01
        assert "name_en" in e01

    def test_category_index(self):
        from app.coa_engine.data.error_catalog import CATEGORY_INDEX

        assert "structural" in CATEGORY_INDEX
        assert "classification" in CATEGORY_INDEX
        assert len(CATEGORY_INDEX["structural"]) == 8  # E01-E08

    def test_score_impact(self):
        from app.coa_engine.data.error_catalog import SCORE_IMPACT

        assert SCORE_IMPACT["Critical"] == -15
        assert SCORE_IMPACT["High"] == -8
        assert SCORE_IMPACT["Medium"] == -3
        assert SCORE_IMPACT["Low"] == -1

    def test_get_error(self):
        from app.coa_engine.data.error_catalog import get_error

        e28 = get_error("E28")
        assert e28["name_en"] == "Missing ECL Provision"
        assert e28["category"] == "ifrs"
        assert "IFRS 9" in str(e28["references"])

    def test_get_nonexistent_error(self):
        from app.coa_engine.data.error_catalog import get_error

        assert get_error("E99") == {}


# ── Wave 2: Error Detector ──
class TestErrorDetector:
    def test_duplicate_code_detection(self):
        from app.coa_engine.services.error_detector import detect_errors

        accounts = [
            {"code": "1001", "name": "نقدية", "main_class": "asset", "nature": "debit", "confidence": 0.85},
            {"code": "1001", "name": "نقدية أخرى", "main_class": "asset", "nature": "debit", "confidence": 0.85},
        ]
        updated, errors = detect_errors(accounts, {"code": "code", "name": "name"}, "GENERIC_FLAT")
        error_codes = [e["error_code"] for e in errors]
        assert "E01" in error_codes

    def test_missing_code_detection(self):
        from app.coa_engine.services.error_detector import detect_errors

        accounts = [
            {"code": "", "name": "حساب بدون كود", "main_class": "asset", "nature": "debit", "confidence": 0.5},
        ]
        updated, errors = detect_errors(accounts, {"code": "code", "name": "name"}, "GENERIC_FLAT")
        error_codes = [e["error_code"] for e in errors]
        assert "E02" in error_codes

    def test_no_classification_detection(self):
        from app.coa_engine.services.error_detector import detect_errors

        accounts = [
            {"code": "9999", "name": "حساب غامض", "main_class": None, "nature": None, "confidence": 0.0},
        ]
        updated, errors = detect_errors(accounts, {"code": "code", "name": "name"}, "GENERIC_FLAT")
        error_codes = [e["error_code"] for e in errors]
        assert "E04" in error_codes

    def test_ambiguous_name_detection(self):
        from app.coa_engine.services.error_detector import detect_errors

        accounts = [
            {"code": "5999", "name": "أخرى", "main_class": "expense", "nature": "debit", "confidence": 0.7},
        ]
        updated, errors = detect_errors(accounts, {"code": "code", "name": "name"}, "GENERIC_FLAT")
        error_codes = [e["error_code"] for e in errors]
        assert "E21" in error_codes

    def test_duplicate_name_detection(self):
        from app.coa_engine.services.error_detector import detect_errors

        accounts = [
            {"code": "1001", "name": "نقدية", "main_class": "asset", "nature": "debit", "confidence": 0.85},
            {"code": "1002", "name": "نقدية", "main_class": "asset", "nature": "debit", "confidence": 0.85},
        ]
        updated, errors = detect_errors(accounts, {"code": "code", "name": "name"}, "GENERIC_FLAT")
        error_codes = [e["error_code"] for e in errors]
        assert "E22" in error_codes

    def test_nature_mismatch_detection(self):
        from app.coa_engine.services.error_detector import detect_errors

        accounts = [
            {"code": "4001", "name": "مبيعات", "main_class": "revenue", "nature": "debit",
             "concept_id": "SALES_REVENUE", "confidence": 0.85},
        ]
        updated, errors = detect_errors(accounts, {"code": "code", "name": "name"}, "GENERIC_FLAT")
        error_codes = [e["error_code"] for e in errors]
        assert "E19" in error_codes

    def test_cross_validation_missing_cogs(self):
        from app.coa_engine.services.error_detector import detect_errors

        accounts = [
            {"code": "4001", "name": "مبيعات", "main_class": "revenue", "nature": "credit",
             "concept_id": "SALES_REVENUE", "confidence": 0.85},
        ]
        # Has revenue but no COGS → E50
        updated, errors = detect_errors(accounts, {"code": "code", "name": "name"}, "GENERIC_FLAT")
        error_codes = [e["error_code"] for e in errors]
        assert "E50" in error_codes

    def test_broken_hierarchy_detection(self):
        from app.coa_engine.services.error_detector import detect_errors

        accounts = [
            {"code": "1101", "name": "نقدية", "main_class": "asset", "nature": "debit",
             "parent_code": "NONEXISTENT", "confidence": 0.85},
        ]
        updated, errors = detect_errors(accounts, {"code": "code", "name": "name"}, "GENERIC_FLAT")
        error_codes = [e["error_code"] for e in errors]
        assert "E08" in error_codes

    def test_error_injected_into_account(self):
        from app.coa_engine.services.error_detector import detect_errors

        accounts = [
            {"code": "1001", "name": "نقدية", "main_class": "asset", "nature": "debit", "confidence": 0.85},
            {"code": "1001", "name": "نقدية ثانية", "main_class": "asset", "nature": "debit", "confidence": 0.85},
        ]
        updated, errors = detect_errors(accounts, {"code": "code", "name": "name"}, "GENERIC_FLAT")
        assert "E01" in updated[0].get("errors", [])

    def test_summarize_errors(self):
        from app.coa_engine.services.error_detector import summarize_errors

        error_dicts = [
            {"severity": "Critical"}, {"severity": "Critical"},
            {"severity": "High"}, {"severity": "Medium"},
        ]
        summary = summarize_errors(error_dicts)
        assert summary["critical"] == 2
        assert summary["high"] == 1
        assert summary["medium"] == 1
        assert summary["total"] == 4


# ── Wave 2: Pipeline with Errors ──
class TestPipelineWithErrors:
    def test_pipeline_detects_errors(self):
        from app.coa_engine.services.pipeline import process_dataframe

        df = pd.DataFrame(
            {
                "كود الحساب": ["1", "11", "1101", "1101", "2", "21", "2101", "3", "31", "4", "41", "5", "51"],
                "اسم الحساب": [
                    "أصول",
                    "أصول متداولة",
                    "نقدية",
                    "نقدية مكررة",
                    "التزامات",
                    "التزامات متداولة",
                    "موردين",
                    "حقوق ملكية",
                    "رأس المال",
                    "إيرادات",
                    "مبيعات",
                    "مصروفات",
                    "رواتب",
                ],
            }
        )
        result = process_dataframe(df, filename="test_errors.xlsx")
        assert result.status == "completed"
        assert result.errors_summary["total"] > 0  # Should detect duplicate E01

    def test_pipeline_result_includes_errors(self):
        from app.coa_engine.services.pipeline import process_dataframe

        df = pd.DataFrame(
            {
                "كود الحساب": ["1", "11", "1101", "2", "21", "2101"],
                "اسم الحساب": ["أصول", "أصول متداولة", "نقدية", "التزامات", "التزامات متداولة", "موردين"],
            }
        )
        result = process_dataframe(df, filename="test.xlsx")
        d = result.to_dict()
        assert "errors" in d
        assert "errors_summary" in d
        assert isinstance(d["errors"], list)


# ── Wave 2: Error API Routes ──
class TestErrorRoutes:
    @pytest.fixture
    def client(self):
        from fastapi.testclient import TestClient
        from app.main import app

        return TestClient(app)

    def test_errors_endpoint(self, client):
        resp = client.get("/api/coa-engine/errors")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert data["data"]["count"] == 58

    def test_errors_filter_by_category(self, client):
        resp = client.get("/api/coa-engine/errors?category=structural")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert data["data"]["count"] == 8
        for err in data["data"]["errors"]:
            assert err["category"] == "structural"

    def test_errors_filter_by_severity(self, client):
        resp = client.get("/api/coa-engine/errors?severity=Critical")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert all(e["severity"] == "Critical" for e in data["data"]["errors"])

    def test_error_detail_endpoint(self, client):
        resp = client.get("/api/coa-engine/errors/E01")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert data["data"]["error_code"] == "E01"
        assert data["data"]["severity"] == "Critical"

    def test_error_detail_not_found(self, client):
        resp = client.get("/api/coa-engine/errors/E99")
        assert resp.status_code == 404

    def test_error_categories_endpoint(self, client):
        resp = client.get("/api/coa-engine/error-categories")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert data["data"]["count"] >= 10


# ── Wave 3: Sector Detector ──
class TestSectorDetector:
    def test_detect_retail_sector(self):
        from app.coa_engine.services.sector_detector import detect_sector

        accounts = [
            {"concept_id": "INVENTORY"},
            {"concept_id": "COGS"},
            {"concept_id": "SALES_RETURNS"},
            {"concept_id": "PURCHASE_RETURNS"},
            {"concept_id": "CASH"},
        ]
        result = detect_sector(accounts)
        assert result["sector_code"] == "RETAIL"
        assert result["confidence"] > 0.5

    def test_detect_unknown_sector(self):
        from app.coa_engine.services.sector_detector import detect_sector

        accounts = [{"concept_id": "CASH"}, {"concept_id": "BANK"}]
        result = detect_sector(accounts)
        # Common accounts only — no sector-specific match
        assert result["sector_code"] in ("UNKNOWN", "RETAIL", "ECOMMERCE")

    def test_detect_empty_accounts(self):
        from app.coa_engine.services.sector_detector import detect_sector

        result = detect_sector([])
        assert result["sector_code"] == "UNKNOWN"
        assert result["confidence"] == 0.0

    def test_missing_accounts_identified(self):
        from app.coa_engine.services.sector_detector import detect_sector

        # Only partial retail accounts
        accounts = [{"concept_id": "INVENTORY"}, {"concept_id": "COGS"}]
        result = detect_sector(accounts)
        if result["sector_code"] == "RETAIL":
            assert len(result["missing_accounts"]) > 0


class TestSimilarityEngine:
    def test_similarity_score(self):
        from app.coa_engine.services.sector_detector import calculate_similarity

        accounts = [
            {"concept_id": "CASH", "main_class": "asset", "parent_code": None, "name": "نقدية"},
            {"concept_id": "BANK", "main_class": "asset", "parent_code": None, "name": "بنوك"},
            {"concept_id": "INVENTORY", "main_class": "asset", "parent_code": None, "name": "مخزون"},
            {"concept_id": "COGS", "main_class": "cogs", "parent_code": None, "name": "تكلفة"},
        ]
        result = calculate_similarity(accounts, "RETAIL")
        assert result["overall_score"] > 0
        assert result["grade"] in ("A", "B", "C", "D", "F")
        assert "mandatory_coverage" in result["dimensions"]

    def test_similarity_empty(self):
        from app.coa_engine.services.sector_detector import calculate_similarity

        result = calculate_similarity([], "RETAIL")
        assert result["overall_score"] == 0.0
        assert result["grade"] == "F"


class TestSectorReport:
    def test_report_card_structure(self):
        from app.coa_engine.services.sector_detector import build_sector_report

        accounts = [{"main_class": "asset", "review_status": "auto_approved"}]
        sector = {"sector_code": "RETAIL", "sector_name_ar": "تجارة", "sector_name_en": "Retail", "confidence": 0.8, "missing_accounts": ["INVENTORY"]}
        similarity = {"overall_score": 75.0, "dimensions": {"mandatory_coverage": 50}}
        report = build_sector_report(accounts, sector, similarity, 75.0, {"critical": 0, "high": 1, "medium": 0, "low": 0})
        assert "grade" in report
        assert "sector" in report
        assert "top_actions" in report
        assert "executive_summary_ar" in report
        assert "benchmark" in report

    def test_report_with_critical_errors(self):
        from app.coa_engine.services.sector_detector import build_sector_report

        accounts = [{"main_class": "asset", "review_status": "pending"}]
        sector = {"sector_code": "RETAIL", "sector_name_ar": "تجارة", "sector_name_en": "Retail", "confidence": 0.5, "missing_accounts": []}
        similarity = {"overall_score": 40.0, "dimensions": {}}
        report = build_sector_report(accounts, sector, similarity, 40.0, {"critical": 3, "high": 2, "medium": 0, "low": 0})
        assert report["grade"] == "F"
        assert len(report["top_actions"]) > 0
        assert report["top_actions"][0]["severity"] == "Critical"


class TestPipelineWithSector:
    def test_pipeline_detects_sector(self):
        from app.coa_engine.services.pipeline import process_dataframe

        df = pd.DataFrame(
            {
                "كود الحساب": ["1", "11", "1101", "1102", "2", "21", "2101", "3", "31", "4", "41", "5", "51"],
                "اسم الحساب": [
                    "أصول", "أصول متداولة", "نقدية", "بنوك",
                    "التزامات", "التزامات متداولة", "موردين",
                    "حقوق ملكية", "رأس المال",
                    "إيرادات", "مبيعات",
                    "مصروفات", "رواتب",
                ],
            }
        )
        result = process_dataframe(df, filename="test_sector.xlsx")
        assert result.status == "completed"
        assert result.sector_detected is not None
        d = result.to_dict()
        assert "sector_detected" in d
        assert "sector_similarity" in d
        assert "report_card" in d


class TestSectorRoutes:
    @pytest.fixture
    def client(self):
        from fastapi.testclient import TestClient
        from app.main import app

        return TestClient(app)

    def test_sector_detail_endpoint(self, client):
        resp = client.get("/api/coa-engine/sectors/RETAIL")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert data["data"]["code"] == "RETAIL"
        assert "mandatory_accounts" in data["data"]

    def test_sector_detail_not_found(self, client):
        resp = client.get("/api/coa-engine/sectors/NONEXISTENT")
        assert resp.status_code == 404


# ── Wave 4: Version Manager ──
class TestVersionManager:
    def test_version_snapshot(self):
        from app.coa_engine.services.version_manager import VersionSnapshot

        accounts = [
            {"code": "1001", "name": "نقدية", "main_class": "asset", "nature": "debit"},
            {"code": "2001", "name": "موردين", "main_class": "liability", "nature": "credit"},
        ]
        snap = VersionSnapshot(1, accounts, quality_score=80.0)
        assert snap.total_accounts == 2
        assert snap.get_account("1001") is not None
        assert "1001" in snap.account_codes

    def test_compare_added_accounts(self):
        from app.coa_engine.services.version_manager import VersionSnapshot, compare_versions

        old = VersionSnapshot(1, [
            {"code": "1001", "name": "نقدية", "main_class": "asset", "nature": "debit"},
        ], quality_score=70.0)
        new = VersionSnapshot(2, [
            {"code": "1001", "name": "نقدية", "main_class": "asset", "nature": "debit"},
            {"code": "1002", "name": "بنوك", "main_class": "asset", "nature": "debit"},
        ], quality_score=75.0)
        result = compare_versions(old, new)
        assert result["total_changes"] >= 1
        assert "added" in result["change_summary"]
        assert result["quality_trend"]["trend"] == "stable" or result["quality_trend"]["delta"] > 0

    def test_compare_deleted_accounts(self):
        from app.coa_engine.services.version_manager import VersionSnapshot, compare_versions

        old = VersionSnapshot(1, [
            {"code": "1001", "name": "نقدية", "main_class": "asset", "nature": "debit"},
            {"code": "1002", "name": "بنوك", "main_class": "asset", "nature": "debit"},
        ], quality_score=80.0)
        new = VersionSnapshot(2, [
            {"code": "1001", "name": "نقدية", "main_class": "asset", "nature": "debit"},
        ], quality_score=75.0)
        result = compare_versions(old, new)
        assert "deleted" in result["change_summary"]
        assert result["risk_summary"]["Critical"] > 0

    def test_compare_renamed(self):
        from app.coa_engine.services.version_manager import VersionSnapshot, compare_versions

        old = VersionSnapshot(1, [{"code": "1001", "name": "نقدية", "main_class": "asset"}])
        new = VersionSnapshot(2, [{"code": "1001", "name": "الصندوق النقدي", "main_class": "asset"}])
        result = compare_versions(old, new)
        assert "renamed" in result["change_summary"]

    def test_compare_reclassified(self):
        from app.coa_engine.services.version_manager import VersionSnapshot, compare_versions

        old = VersionSnapshot(1, [{"code": "1001", "name": "حساب", "main_class": "asset", "nature": "debit"}])
        new = VersionSnapshot(2, [{"code": "1001", "name": "حساب", "main_class": "liability", "nature": "credit"}])
        result = compare_versions(old, new)
        types = result["change_summary"]
        assert "reclassified" in types or "rebalanced" in types
        assert result["overall_risk"] == "Critical"

    def test_compare_no_changes(self):
        from app.coa_engine.services.version_manager import VersionSnapshot, compare_versions

        accts = [{"code": "1001", "name": "نقدية", "main_class": "asset", "nature": "debit"}]
        old = VersionSnapshot(1, accts, quality_score=80)
        new = VersionSnapshot(2, accts, quality_score=80)
        result = compare_versions(old, new)
        assert result["total_changes"] == 0
        assert result["overall_risk"] == "None"


class TestMigrationMap:
    def test_migration_same(self):
        from app.coa_engine.services.version_manager import VersionSnapshot, build_migration_map

        accts = [{"code": "1001", "name": "نقدية", "main_class": "asset"}]
        old = VersionSnapshot(1, accts)
        new = VersionSnapshot(2, accts)
        mmap = build_migration_map(old, new)
        assert len(mmap) == 1
        assert mmap[0]["map_type"] == "SAME"

    def test_migration_deleted_and_added(self):
        from app.coa_engine.services.version_manager import VersionSnapshot, build_migration_map

        old = VersionSnapshot(1, [{"code": "1001", "name": "نقدية", "main_class": "asset"}])
        new = VersionSnapshot(2, [{"code": "1002", "name": "بنوك", "main_class": "asset"}])
        mmap = build_migration_map(old, new)
        types = {m["map_type"] for m in mmap}
        assert "DELETED" in types or "RECODED" in types
        assert "ADDED" in types or "RECODED" in types

    def test_migration_recoded_by_name(self):
        from app.coa_engine.services.version_manager import VersionSnapshot, build_migration_map

        old = VersionSnapshot(1, [{"code": "100", "name": "نقدية", "main_class": "asset"}])
        new = VersionSnapshot(2, [{"code": "1001", "name": "نقدية", "main_class": "asset"}])
        mmap = build_migration_map(old, new)
        recoded = [m for m in mmap if m["map_type"] == "RECODED"]
        assert len(recoded) == 1
        assert recoded[0]["old_code"] == "100"
        assert recoded[0]["new_code"] == "1001"

    def test_summarize_migration(self):
        from app.coa_engine.services.version_manager import summarize_migration

        mmap = [
            {"map_type": "SAME", "auto_matched": True},
            {"map_type": "SAME", "auto_matched": True},
            {"map_type": "RENAMED", "auto_matched": True},
            {"map_type": "DELETED", "auto_matched": True},
        ]
        summary = summarize_migration(mmap)
        assert summary["total_entries"] == 4
        assert summary["stability_pct"] == 50.0
        assert summary["needs_review"] == 1


# ── Wave 5: Knowledge Graph ──
class TestKnowledgeGraph:
    def test_graph_construction(self):
        from app.coa_engine.services.knowledge_graph import KnowledgeGraph

        g = KnowledgeGraph()
        g.add_node("1001", {"name": "نقدية"})
        g.add_node("1002", {"name": "بنوك"})
        g.add_edge("1001", "1002", "PARENT_OF")
        assert g.node_count == 2
        assert g.edge_count == 1

    def test_bfs_traversal(self):
        from app.coa_engine.services.knowledge_graph import KnowledgeGraph

        g = KnowledgeGraph()
        g.add_node("A", {})
        g.add_node("B", {})
        g.add_node("C", {})
        g.add_edge("A", "B", "PARENT_OF")
        g.add_edge("B", "C", "PARENT_OF")
        results = g.bfs("A")
        assert len(results) == 3
        assert results[0]["node_id"] == "A"
        assert results[0]["depth"] == 0
        assert results[2]["depth"] == 2

    def test_find_dependencies(self):
        from app.coa_engine.services.knowledge_graph import KnowledgeGraph

        g = KnowledgeGraph()
        g.add_node("PPE", {})
        g.add_node("DEPR", {})
        g.add_edge("PPE", "DEPR", "REQUIRES", {"error_code": "E48"})
        deps = g.find_dependencies("PPE")
        assert len(deps["requires"]) == 1
        assert deps["requires"][0]["target"] == "DEPR"

    def test_impact_analysis(self):
        from app.coa_engine.services.knowledge_graph import KnowledgeGraph

        g = KnowledgeGraph()
        g.add_node("REC", {})
        g.add_node("ECL", {})
        g.add_edge("REC", "ECL", "REQUIRES", {"error_code": "E28"})
        impacts = g.impact_analysis("ECL")
        assert len(impacts) >= 1
        assert impacts[0]["impacted_node"] == "REC"

    def test_build_from_accounts(self):
        from app.coa_engine.services.knowledge_graph import build_graph_from_accounts

        accounts = [
            {"code": "1", "name": "أصول", "concept_id": None, "main_class": "asset", "parent_code": None},
            {"code": "11", "name": "متداولة", "concept_id": None, "main_class": "asset", "parent_code": "1"},
            {"code": "1101", "name": "نقدية", "concept_id": "CASH", "main_class": "asset", "parent_code": "11", "nature": "debit"},
            {"code": "1111", "name": "ذمم مدينة", "concept_id": "ACC_RECEIVABLE", "main_class": "asset", "parent_code": "11", "nature": "debit"},
        ]
        graph = build_graph_from_accounts(accounts)
        assert graph.node_count > 4  # accounts + section nodes
        assert graph.edge_count >= 2  # at least PARENT_OF edges
        # Check PARENT_OF edge
        neighbors = graph.get_neighbors("1", "PARENT_OF")
        assert any(t == "11" for t, _, _ in neighbors)

    def test_graph_serialization(self):
        from app.coa_engine.services.knowledge_graph import KnowledgeGraph

        g = KnowledgeGraph()
        g.add_node("A", {"name": "test"})
        g.add_node("B", {"name": "test2"})
        g.add_edge("A", "B", "REQUIRES")
        d = g.to_dict()
        assert d["node_count"] == 2
        assert d["edge_count"] == 1
        assert len(d["nodes"]) == 2
        assert len(d["edges"]) == 1

    def test_ontology_rules_loaded(self):
        from app.coa_engine.services.knowledge_graph import ONTOLOGY_RULES, SECTION_MEMBERSHIP

        assert len(ONTOLOGY_RULES) >= 15
        assert "current_asset" in SECTION_MEMBERSHIP
        assert "CASH" in SECTION_MEMBERSHIP["current_asset"]


class TestOntologyRoute:
    @pytest.fixture
    def client(self):
        from fastapi.testclient import TestClient
        from app.main import app

        return TestClient(app)

    def test_ontology_endpoint(self, client):
        resp = client.get("/api/coa-engine/ontology")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert data["data"]["rules_count"] >= 15
        assert "sections" in data["data"]


# ══════════════════════════════════════════════════════════════
# Wave 6: Financial Statement Simulator + Compliance
# ══════════════════════════════════════════════════════════════


class TestSimulator:
    """Tests for simulate_financial_statements()."""

    def _make_accounts(self):
        return [
            {"code": "1001", "name": "نقدية", "main_class": "asset", "sub_class": "current_asset", "nature": "debit", "concept_id": "CASH"},
            {"code": "1101", "name": "ذمم مدينة", "main_class": "asset", "sub_class": "current_asset", "nature": "debit", "concept_id": "ACC_RECEIVABLE"},
            {"code": "1501", "name": "أصول ثابتة", "main_class": "asset", "sub_class": "non_current_asset", "nature": "debit", "concept_id": "PPE"},
            {"code": "2001", "name": "ذمم دائنة", "main_class": "liability", "sub_class": "current_liability", "nature": "credit", "concept_id": "ACC_PAYABLE"},
            {"code": "3001", "name": "رأس المال", "main_class": "equity", "sub_class": "equity", "nature": "credit", "concept_id": "SHARE_CAPITAL"},
            {"code": "3101", "name": "أرباح مبقاة", "main_class": "equity", "sub_class": "equity", "nature": "credit", "concept_id": "RETAINED_EARNINGS"},
            {"code": "4001", "name": "إيرادات", "main_class": "revenue", "nature": "credit", "concept_id": "SALES_REVENUE"},
            {"code": "5001", "name": "تكلفة مبيعات", "main_class": "cogs", "nature": "debit", "concept_id": "COGS"},
            {"code": "6001", "name": "مصروفات عمومية", "main_class": "expense", "nature": "debit", "concept_id": "GENERAL_EXPENSE"},
        ]

    def test_simulate_complete_coa(self):
        from app.coa_engine.services.simulator import simulate_financial_statements

        result = simulate_financial_statements(self._make_accounts())
        assert result["completeness_score"] > 50
        assert result["bs_sections_filled"] >= 3
        assert result["is_sections_filled"] >= 3
        assert "balance_sheet" in result
        assert "income_statement" in result
        assert result["balance_sheet"]["current_assets"]["count"] == 2

    def test_simulate_missing_sections(self):
        from app.coa_engine.services.simulator import simulate_financial_statements

        # Only assets — missing liabilities, equity, revenue
        accounts = [
            {"code": "1001", "name": "نقدية", "main_class": "asset", "sub_class": "current_asset", "nature": "debit"},
        ]
        result = simulate_financial_statements(accounts)
        assert result["completeness_score"] < 50
        assert len(result["issues"]) >= 2  # missing liabilities, revenue

    def test_simulate_issues_detection(self):
        from app.coa_engine.services.simulator import simulate_financial_statements

        # Revenue without COGS
        accounts = [
            {"code": "1001", "name": "نقدية", "main_class": "asset", "nature": "debit"},
            {"code": "2001", "name": "خصوم", "main_class": "liability", "nature": "credit"},
            {"code": "3001", "name": "ملكية", "main_class": "equity", "nature": "credit"},
            {"code": "4001", "name": "إيرادات", "main_class": "revenue", "nature": "credit"},
        ]
        result = simulate_financial_statements(accounts)
        issue_types = [i["issue"] for i in result["issues"]]
        assert "MISSING_COGS" in issue_types

    def test_simulate_empty(self):
        from app.coa_engine.services.simulator import simulate_financial_statements

        result = simulate_financial_statements([])
        assert result["total_accounts"] == 0
        assert result["completeness_score"] == 0


class TestCompliance:
    """Tests for check_compliance()."""

    def test_compliance_all_pass(self):
        from app.coa_engine.services.simulator import check_compliance

        accounts = [
            {"concept_id": "VAT"},
            {"concept_id": "INCOME_TAX"},
            {"concept_id": "ECL_PROVISION"},
            {"concept_id": "ACC_RECEIVABLE"},
            {"concept_id": "LEASE_LIABILITY"},
            {"concept_id": "RENT_EXPENSE"},
            {"concept_id": "ACCUM_DEPRECIATION"},
            {"concept_id": "DEPRECIATION_EXP"},
            {"concept_id": "PPE"},
            {"concept_id": "END_OF_SERVICE"},
            {"concept_id": "SALARIES_EXPENSE"},
            {"concept_id": "COGS"},
            {"concept_id": "SALES_REVENUE"},
            {"concept_id": "RETAINED_EARNINGS"},
            {"concept_id": "SHARE_CAPITAL"},
        ]
        result = check_compliance(accounts)
        assert result["compliance_score"] == 100.0
        assert result["failed"] == 0

    def test_compliance_trigger_not_applicable(self):
        from app.coa_engine.services.simulator import check_compliance

        # No trigger concepts — conditional rules should be not_applicable
        accounts = [
            {"concept_id": "VAT"},
            {"concept_id": "INCOME_TAX"},
            {"concept_id": "RETAINED_EARNINGS"},
            {"concept_id": "SHARE_CAPITAL"},
        ]
        result = check_compliance(accounts)
        not_applicable = [d for d in result["details"] if d["status"] == "not_applicable"]
        assert len(not_applicable) >= 3  # IFRS9, IFRS16, IAS16, EOS, accounting cycle triggers missing

    def test_compliance_failure(self):
        from app.coa_engine.services.simulator import check_compliance

        # Has receivables but no ECL — IFRS9 should fail
        accounts = [
            {"concept_id": "ACC_RECEIVABLE"},
            {"concept_id": "VAT"},
            {"concept_id": "INCOME_TAX"},
        ]
        result = check_compliance(accounts)
        failed_rules = [d for d in result["details"] if d["status"] == "failed"]
        failed_ids = [d["rule_id"] for d in failed_rules]
        assert "IFRS9_ECL" in failed_ids

    def test_compliance_empty(self):
        from app.coa_engine.services.simulator import check_compliance

        result = check_compliance([])
        # Rules without triggers (VAT, ZAKAT, RETAINED_EARNINGS, SHARE_CAPITAL) still apply and fail
        assert result["rules_checked"] > 0
        assert result["failed"] >= 1


class TestSimulatorRoutes:
    @pytest.fixture
    def client(self):
        from fastapi.testclient import TestClient
        from app.main import app

        return TestClient(app)

    @pytest.fixture
    def auth_header(self):
        import jwt as pyjwt
        from app.core.auth_utils import JWT_SECRET, JWT_ALGORITHM

        token = pyjwt.encode({"sub": "test-user"}, JWT_SECRET, algorithm=JWT_ALGORITHM)
        return {"Authorization": f"Bearer {token}"}

    def test_simulate_endpoint(self, client, auth_header):
        payload = {
            "accounts": [
                {"code": "1001", "name": "نقدية", "main_class": "asset", "nature": "debit"},
                {"code": "4001", "name": "إيرادات", "main_class": "revenue", "nature": "credit"},
            ]
        }
        resp = client.post("/api/coa-engine/simulate", json=payload, headers=auth_header)
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert "balance_sheet" in data["data"]
        assert "income_statement" in data["data"]

    def test_compliance_endpoint(self, client, auth_header):
        payload = {
            "accounts": [
                {"concept_id": "VAT"},
                {"concept_id": "INCOME_TAX"},
            ]
        }
        resp = client.post("/api/coa-engine/compliance", json=payload, headers=auth_header)
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert "compliance_score" in data["data"]

    def test_compliance_rules_endpoint(self, client):
        resp = client.get("/api/coa-engine/compliance-rules")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert data["data"]["count"] == 9


# ══════════════════════════════════════════════════════════════
# Wave 7: Fraud Pattern Detector + Rule Governance
# ══════════════════════════════════════════════════════════════


class TestFraudDetector:
    """Tests for detect_fraud_patterns()."""

    def test_fp01_hidden_revenue(self):
        from app.coa_engine.services.fraud_detector import detect_fraud_patterns

        accounts = [
            {"code": "5001", "name": "إيراد مخفي", "main_class": "expense", "nature": "credit", "concept_id": "MISC"},
        ]
        result = detect_fraud_patterns(accounts)
        alerts = result["alerts"]
        assert any(a["pattern_id"] == "FP01" for a in alerts)

    def test_fp02_hidden_expense(self):
        from app.coa_engine.services.fraud_detector import detect_fraud_patterns

        accounts = [
            {"code": "1501", "name": "مصروفات صيانة", "main_class": "asset", "nature": "debit", "concept_id": "OTHER"},
        ]
        result = detect_fraud_patterns(accounts)
        alerts = result["alerts"]
        assert any(a["pattern_id"] == "FP02" for a in alerts)

    def test_fp06_asset_inflation(self):
        from app.coa_engine.services.fraud_detector import detect_fraud_patterns

        accounts = [
            {"code": "1001", "name": "أصل غريب", "main_class": "asset", "nature": "credit", "concept_id": "OTHER"},
        ]
        result = detect_fraud_patterns(accounts)
        alerts = result["alerts"]
        assert any(a["pattern_id"] == "FP06" for a in alerts)

    def test_fp06_excludes_contra(self):
        from app.coa_engine.services.fraud_detector import detect_fraud_patterns

        # Accumulated depreciation is contra — should NOT trigger FP06
        accounts = [
            {"code": "1599", "name": "مجمع الإهلاك", "main_class": "asset", "nature": "credit", "concept_id": "ACCUM_DEPRECIATION"},
        ]
        result = detect_fraud_patterns(accounts)
        alerts = result["alerts"]
        assert not any(a["pattern_id"] == "FP06" for a in alerts)

    def test_fp07_hidden_receivables(self):
        from app.coa_engine.services.fraud_detector import detect_fraud_patterns

        accounts = [
            {"code": "1101", "name": "ذمم مدينة", "main_class": "asset", "nature": "debit", "concept_id": "ACC_RECEIVABLE"},
        ]
        result = detect_fraud_patterns(accounts)
        alerts = result["alerts"]
        assert any(a["pattern_id"] == "FP07" for a in alerts)

    def test_no_fraud_clean_coa(self):
        from app.coa_engine.services.fraud_detector import detect_fraud_patterns

        accounts = [
            {"code": "1001", "name": "نقدية", "main_class": "asset", "nature": "debit", "concept_id": "CASH"},
            {"code": "2001", "name": "دائنون", "main_class": "liability", "nature": "credit", "concept_id": "ACC_PAYABLE"},
            {"code": "4001", "name": "مبيعات", "main_class": "revenue", "nature": "credit", "concept_id": "SALES_REVENUE"},
        ]
        result = detect_fraud_patterns(accounts)
        assert result["risk_level"] == "None"
        assert result["alerts_count"] == 0

    def test_fraud_summary_structure(self):
        from app.coa_engine.services.fraud_detector import detect_fraud_patterns

        result = detect_fraud_patterns([])
        assert "patterns_checked" in result
        assert result["patterns_checked"] == 8
        assert "risk_summary" in result


class TestRuleGovernance:
    """Tests for engine rule governance."""

    def test_get_engine_rules(self):
        from app.coa_engine.services.fraud_detector import get_engine_rules

        rules = get_engine_rules()
        assert len(rules) == 12
        assert all("rule_code" in r for r in rules)
        assert all("precision_score" in r for r in rules)

    def test_get_rule_stats(self):
        from app.coa_engine.services.fraud_detector import get_rule_stats

        stats = get_rule_stats()
        assert stats["total_rules"] == 12
        assert stats["active"] == 12
        assert stats["avg_precision"] > 0.5
        assert "rule_types" in stats
        assert "classification" in stats["rule_types"]

    def test_fraud_patterns_loaded(self):
        from app.coa_engine.services.fraud_detector import FRAUD_PATTERNS, FRAUD_PATTERN_INDEX

        assert len(FRAUD_PATTERNS) == 8
        assert "FP01" in FRAUD_PATTERN_INDEX
        assert "FP08" in FRAUD_PATTERN_INDEX
        assert FRAUD_PATTERN_INDEX["FP01"]["risk"] == "Critical"


class TestFraudRoutes:
    @pytest.fixture
    def client(self):
        from fastapi.testclient import TestClient
        from app.main import app

        return TestClient(app)

    @pytest.fixture
    def auth_header(self):
        import jwt as pyjwt
        from app.core.auth_utils import JWT_SECRET, JWT_ALGORITHM

        token = pyjwt.encode({"sub": "test-user"}, JWT_SECRET, algorithm=JWT_ALGORITHM)
        return {"Authorization": f"Bearer {token}"}

    def test_fraud_scan_endpoint(self, client, auth_header):
        payload = {
            "accounts": [
                {"code": "5001", "name": "إيراد مخفي", "main_class": "expense", "nature": "credit", "concept_id": "MISC"},
            ]
        }
        resp = client.post("/api/coa-engine/fraud-scan", json=payload, headers=auth_header)
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert data["data"]["patterns_checked"] == 8
        assert data["data"]["alerts_count"] >= 1

    def test_fraud_patterns_endpoint(self, client):
        resp = client.get("/api/coa-engine/fraud-patterns")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert data["data"]["count"] == 8

    def test_engine_rules_endpoint(self, client):
        resp = client.get("/api/coa-engine/engine-rules")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert len(data["data"]["rules"]) == 12
        assert "stats" in data["data"]
        assert data["data"]["stats"]["total_rules"] == 12
