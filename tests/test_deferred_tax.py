"""Deferred Tax (IAS 12) tests."""

from decimal import Decimal

import pytest

from app.core.deferred_tax_service import (
    TDItem, DeferredTaxInput, compute_deferred_tax,
)


class TestAssetTD:
    def test_dtl_from_asset_td(self):
        # PP&E CA=1000, TB=800 → taxable TD=200
        # @ 20% rate → DTL = 40
        r = compute_deferred_tax(DeferredTaxInput(
            entity_name="x", period_label="FY26",
            tax_rate_pct=Decimal("20"),
            items=[TDItem("PP&E", "asset_td",
                carrying_amount=Decimal("1000"), tax_base=Decimal("800"))],
        ))
        assert r.total_dtl == Decimal("40.00")
        assert r.total_dta_gross == Decimal("0.00")
        assert r.items[0].td_type == "taxable"

    def test_dta_from_asset_td(self):
        # Receivables CA=900 (after provision), TB=1000 → deductible TD=100
        # @ 20% → DTA = 20
        r = compute_deferred_tax(DeferredTaxInput(
            entity_name="x", period_label="FY26",
            tax_rate_pct=Decimal("20"),
            expected_future_profit=Decimal("100000"),
            items=[TDItem("AR allowance", "asset_td",
                carrying_amount=Decimal("900"), tax_base=Decimal("1000"))],
        ))
        assert r.total_dta_recognised == Decimal("20.00")
        assert r.total_dtl == Decimal("0.00")


class TestLiabilityTD:
    def test_dta_from_liability_td(self):
        # Warranty provision CA=500, TB=0 → deductible TD=500
        # @ 20% → DTA = 100
        r = compute_deferred_tax(DeferredTaxInput(
            entity_name="x", period_label="FY26",
            tax_rate_pct=Decimal("20"),
            expected_future_profit=Decimal("100000"),
            items=[TDItem("Warranty", "liability_td",
                carrying_amount=Decimal("500"), tax_base=Decimal("0"))],
        ))
        assert r.total_dta_recognised == Decimal("100.00")
        assert r.items[0].td_type == "deductible"


class TestLossCarryForward:
    def test_dta_from_loss(self):
        # 1000 loss, 20% rate → DTA 200
        r = compute_deferred_tax(DeferredTaxInput(
            entity_name="x", period_label="FY26",
            tax_rate_pct=Decimal("20"),
            expected_future_profit=Decimal("10000"),
            items=[TDItem("Operating loss 2025", "loss_carry_forward",
                carrying_amount=Decimal("1000"), tax_base=Decimal("0"))],
        ))
        assert r.total_dta_recognised == Decimal("200.00")

    def test_expired_loss_warning(self):
        r = compute_deferred_tax(DeferredTaxInput(
            entity_name="x", period_label="FY26",
            tax_rate_pct=Decimal("20"),
            expected_future_profit=Decimal("10000"),
            items=[TDItem("Expired loss", "loss_carry_forward",
                carrying_amount=Decimal("500"),
                expiry_years=0)],
        ))
        assert any("الترحيل انتهت" in w for w in r.warnings)


class TestRecoverability:
    def test_dta_capped_by_future_profit(self):
        # DTA wants 200 but expected profit only 500 × 20% = 100 cap
        r = compute_deferred_tax(DeferredTaxInput(
            entity_name="x", period_label="FY26",
            tax_rate_pct=Decimal("20"),
            expected_future_profit=Decimal("500"),
            items=[TDItem("Big loss", "loss_carry_forward",
                carrying_amount=Decimal("1000"))],
        ))
        assert r.total_dta_recognised == Decimal("100.00")
        assert r.total_dta_unrecognised == Decimal("100.00")
        assert any("الأرباح المستقبلية" in w for w in r.warnings)

    def test_missing_profit_warns(self):
        r = compute_deferred_tax(DeferredTaxInput(
            entity_name="x", period_label="FY26",
            tax_rate_pct=Decimal("20"),
            items=[TDItem("Loss", "loss_carry_forward",
                carrying_amount=Decimal("1000"))],
        ))
        assert any("تقدير" in w for w in r.warnings)


class TestMovement:
    def test_movement_calculation(self):
        r = compute_deferred_tax(DeferredTaxInput(
            entity_name="x", period_label="FY26",
            tax_rate_pct=Decimal("20"),
            expected_future_profit=Decimal("100000"),
            opening_dta=Decimal("50"), opening_dtl=Decimal("30"),
            items=[
                TDItem("PP&E", "asset_td",
                    carrying_amount=Decimal("1000"), tax_base=Decimal("800")),
                TDItem("Warranty", "liability_td",
                    carrying_amount=Decimal("500"), tax_base=Decimal("0")),
            ],
        ))
        # Current DTA=100, DTL=40
        # Δ DTA = 100 - 50 = 50
        # Δ DTL = 40 - 30 = 10
        # P&L expense = 10 - 50 = -40 (credit — tax benefit)
        assert r.movement_dta == Decimal("50.00")
        assert r.movement_dtl == Decimal("10.00")
        assert r.deferred_tax_expense == Decimal("-40.00")

    def test_net_position(self):
        r = compute_deferred_tax(DeferredTaxInput(
            entity_name="x", period_label="FY26",
            tax_rate_pct=Decimal("20"),
            expected_future_profit=Decimal("100000"),
            items=[
                TDItem("DTL item", "asset_td",
                    carrying_amount=Decimal("1000"), tax_base=Decimal("800")),
                TDItem("DTA item", "liability_td",
                    carrying_amount=Decimal("300"), tax_base=Decimal("0")),
            ],
        ))
        # DTL = 40, DTA = 60 → net = 20 asset
        assert r.total_dtl == Decimal("40.00")
        assert r.total_dta_recognised == Decimal("60.00")
        assert r.net_deferred_tax == Decimal("20.00")


class TestValidation:
    def test_bad_rate_rejected(self):
        with pytest.raises(ValueError, match="tax_rate_pct"):
            compute_deferred_tax(DeferredTaxInput(
                entity_name="x", period_label="p",
                tax_rate_pct=Decimal("150"),
                items=[TDItem("a", "asset_td")],
            ))

    def test_empty_items_rejected(self):
        with pytest.raises(ValueError, match="items is required"):
            compute_deferred_tax(DeferredTaxInput(
                entity_name="x", period_label="p",
                tax_rate_pct=Decimal("20"),
                items=[],
            ))

    def test_bad_category_rejected(self):
        with pytest.raises(ValueError, match="category"):
            compute_deferred_tax(DeferredTaxInput(
                entity_name="x", period_label="p",
                tax_rate_pct=Decimal("20"),
                items=[TDItem("x", "nonsense")],
            ))


class TestRoutes:
    def test_requires_auth(self, client):
        r = client.post("/dt/compute", json={})
        assert r.status_code == 401

    def test_compute_http(self, client, auth_header):
        r = client.post("/dt/compute", json={
            "entity_name": "Co", "period_label": "FY 2026",
            "tax_rate_pct": "20",
            "expected_future_profit": "100000",
            "items": [
                {"description": "PP&E",
                 "category": "asset_td",
                 "carrying_amount": "1000",
                 "tax_base": "800"},
            ],
        }, headers=auth_header)
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["total_dtl"] == "40.00"

    def test_categories_http(self, client, auth_header):
        r = client.get("/dt/categories", headers=auth_header)
        assert r.status_code == 200
        lst = r.json()["data"]
        assert "asset_td" in lst
        assert "loss_carry_forward" in lst

    def test_bad_category_http(self, client, auth_header):
        r = client.post("/dt/compute", json={
            "entity_name": "x", "period_label": "p",
            "tax_rate_pct": "20",
            "items": [{"description": "x", "category": "junk",
                      "carrying_amount": "0", "tax_base": "0"}],
        }, headers=auth_header)
        assert r.status_code == 422
