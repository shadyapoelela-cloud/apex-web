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
