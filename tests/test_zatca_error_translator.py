"""
Tests for app/core/zatca_error_translator.py (Wave 2 PR#4).

Covers:
- Curated codes return their Arabic title + action.
- Unknown codes fall through to the "not translated" stub.
- Heuristic keyword matching handles unknown codes with hint messages.
- Full rejection payloads across all 3 shapes:
  validationResults, flat errors/warnings, and single-error flat.
- Route integration via /zatca/errors/explain and /errors/translate.
"""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.core.zatca_error_translator import (
    explain_code,
    translate_error,
    translate_rejection,
)


class TestKnownCodes:
    def test_seller_vat_missing(self):
        r = translate_error("BR-KSA-01", "Seller VAT Number is missing")
        assert r.code == "BR-KSA-01"
        assert r.category == "seller_identity"
        assert "رقم الضريبة" in r.title_ar
        assert "الإعدادات" in r.action_ar
        assert r.severity == "error"

    def test_buyer_vat_missing(self):
        r = translate_error("BR-KSA-24", "Buyer VAT missing for B2B")
        assert r.category == "buyer_identity"
        # The catalog spells it "للمشتري" (lil-mushtari); match the root.
        assert "مشتري" in r.title_ar

    def test_cryptography_code(self):
        r = translate_error("BR-KSA-51", "Stamp missing")
        assert r.category == "cryptography"

    def test_transport_rate_limit(self):
        r = translate_error("RATE_LIMIT", "Too many attempts")
        assert r.category == "transport"

    def test_code_case_insensitive(self):
        r = translate_error("br-ksa-01", "seller vat missing")
        assert r.code == "BR-KSA-01"
        assert r.category == "seller_identity"


class TestHeuristicFallback:
    def test_unknown_code_seller_vat_keyword_matches(self):
        r = translate_error("BR-KSA-999", "Seller VAT format is wrong")
        # Catalog doesn't have 999, but the heuristic catches "seller vat".
        assert r.code == "BR-KSA-999"
        assert r.category == "heuristic"
        assert "بائع" in r.title_ar or "البائع" in r.title_ar

    def test_unknown_code_buyer_keyword(self):
        r = translate_error("BR-KSA-888", "Buyer VAT is invalid")
        assert r.category == "heuristic"
        assert "مشتري" in r.title_ar

    def test_unknown_code_no_keyword_falls_back_to_unknown(self):
        r = translate_error(
            "BR-KSA-777", "Some cryptic rule about field cardinality"
        )
        assert r.category == "unknown"
        assert "غير معروف" in r.title_ar

    def test_empty_code_and_message(self):
        r = translate_error(None, None)
        assert r.code == "UNKNOWN"
        assert r.category == "unknown"


class TestTranslateRejection:
    def test_validation_results_shape(self):
        payload = {
            "validationResults": {
                "errorMessages": [
                    {"code": "BR-KSA-01", "message": "Seller VAT missing"},
                    {"code": "BR-KSA-30", "message": "Total mismatch"},
                ],
                "warningMessages": [
                    {"code": "BR-KSA-50", "message": "QR regenerate"},
                ],
            },
            "clearanceStatus": "NOT_CLEARED",
        }
        s = translate_rejection(payload)
        assert not s.cleared
        assert len(s.errors) == 2
        assert len(s.warnings) == 1
        assert "2 خطأ" in s.headline_ar

    def test_flat_errors_shape(self):
        payload = {
            "errors": [{"errorCode": "BR-KSA-24", "errorMessage": "Buyer VAT"}],
            "warnings": [],
        }
        s = translate_rejection(payload)
        assert len(s.errors) == 1
        assert s.errors[0].code == "BR-KSA-24"

    def test_single_error_flat_shape(self):
        payload = {
            "errorCode": "BR-KSA-61",
            "errorMessage": "Previous hash broken",
        }
        s = translate_rejection(payload)
        assert len(s.errors) == 1
        assert s.errors[0].category == "chain"

    def test_cleared_no_issues(self):
        payload = {"clearanceStatus": "CLEARED"}
        s = translate_rejection(payload)
        assert s.cleared is True
        assert s.errors == []
        assert "قبول" in s.headline_ar

    def test_cleared_with_warnings(self):
        payload = {
            "clearanceStatus": "CLEARED",
            "validationResults": {
                "warningMessages": [
                    {"code": "X", "message": "Minor"}
                ]
            },
        }
        s = translate_rejection(payload)
        assert s.cleared is True
        assert len(s.warnings) == 1
        assert "ملاحظة" in s.headline_ar or "تحذير" in s.headline_ar

    def test_errors_always_block_clearance(self):
        # Even if clearanceStatus says CLEARED, any error flips it.
        payload = {
            "clearanceStatus": "CLEARED",
            "validationResults": {
                "errorMessages": [{"code": "BR-KSA-01", "message": "x"}]
            },
        }
        s = translate_rejection(payload)
        assert s.cleared is False

    def test_empty_payload_is_safe(self):
        s = translate_rejection({})
        assert s.cleared is False
        assert s.errors == []


class TestExplainCode:
    def test_known_code(self):
        r = explain_code("BR-KSA-01")
        assert r["known"] is True
        assert r["category"] == "seller_identity"

    def test_unknown_code(self):
        r = explain_code("BR-KSA-NOPE")
        assert r["known"] is False
        assert "غير مُترجم" in r["title_ar"] or "دعم" in r["action_ar"]


class TestRoutes:
    def test_explain_requires_auth(self, client: TestClient):
        r = client.get("/zatca/errors/explain?code=BR-KSA-01")
        assert r.status_code == 401

    def test_explain_returns_translation(
        self, client: TestClient, auth_header
    ):
        r = client.get(
            "/zatca/errors/explain?code=BR-KSA-01", headers=auth_header
        )
        assert r.status_code == 200, r.text
        body = r.json()
        assert body["success"] is True
        assert body["data"]["known"] is True
        assert body["data"]["category"] == "seller_identity"

    def test_translate_rejection_route(
        self, client: TestClient, auth_header
    ):
        payload = {
            "payload": {
                "validationResults": {
                    "errorMessages": [
                        {"code": "BR-KSA-40", "message": "Empty line"}
                    ]
                }
            }
        }
        r = client.post(
            "/zatca/errors/translate",
            json=payload,
            headers=auth_header,
        )
        assert r.status_code == 200
        body = r.json()
        assert body["data"]["cleared"] is False
        assert len(body["data"]["errors"]) == 1
        assert body["data"]["errors"][0]["category"] == "line_item"
