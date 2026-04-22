"""Transfer Pricing tests."""

from decimal import Decimal

import pytest

from app.core.transfer_pricing_service import (
    TPTransaction, TPInput, analyse_transfer_pricing,
)


class TestTP:
    def test_within_arm_length(self):
        r = analyse_transfer_pricing(TPInput(
            group_name="G", local_entity_name="L", fiscal_year="2026",
            group_consolidated_revenue=Decimal("100000000"),
            local_entity_revenue=Decimal("10000000"),
            transactions=[TPTransaction(
                description="RP service fee",
                transaction_type="services",
                related_party_name="Alpha", related_party_jurisdiction="UAE",
                method="TNMM",
                controlled_price=Decimal("5000000"),
                arm_length_lower=Decimal("4500000"),
                arm_length_upper=Decimal("5500000"),
                arm_length_median=Decimal("5000000"),
            )],
        ))
        assert r.transactions[0].within_range is True
        assert r.transactions[0].adjustment_required == Decimal("0.00")
        assert r.compliance_status == "compliant"

    def test_below_range_triggers_upward_adjustment(self):
        r = analyse_transfer_pricing(TPInput(
            group_name="G", local_entity_name="L", fiscal_year="2026",
            group_consolidated_revenue=Decimal("100000000"),
            local_entity_revenue=Decimal("10000000"),
            transactions=[TPTransaction(
                description="Underpriced",
                transaction_type="goods",
                related_party_name="Beta", related_party_jurisdiction="KSA",
                method="CUP",
                controlled_price=Decimal("1000000"),
                arm_length_lower=Decimal("1200000"),
                arm_length_upper=Decimal("1500000"),
                arm_length_median=Decimal("1350000"),
            )],
        ))
        assert r.transactions[0].within_range is False
        assert r.transactions[0].direction == "upward"
        assert r.transactions[0].adjustment_required == Decimal("200000.00")
        assert r.compliance_status == "adjustments_needed"

    def test_above_range_triggers_downward(self):
        r = analyse_transfer_pricing(TPInput(
            group_name="G", local_entity_name="L", fiscal_year="2026",
            group_consolidated_revenue=Decimal("100000000"),
            local_entity_revenue=Decimal("10000000"),
            transactions=[TPTransaction(
                description="Overpriced",
                transaction_type="royalties",
                related_party_name="Gamma", related_party_jurisdiction="BH",
                method="cost_plus",
                controlled_price=Decimal("800000"),
                arm_length_lower=Decimal("500000"),
                arm_length_upper=Decimal("700000"),
                arm_length_median=Decimal("600000"),
            )],
        ))
        assert r.transactions[0].direction == "downward"
        assert r.transactions[0].adjustment_required == Decimal("100000.00")

    def test_disclosure_threshold(self):
        r = analyse_transfer_pricing(TPInput(
            group_name="G", local_entity_name="L", fiscal_year="2026",
            group_consolidated_revenue=Decimal("100000000"),
            local_entity_revenue=Decimal("10000000"),
            transactions=[TPTransaction(
                description="Big",
                transaction_type="goods",
                related_party_name="RP", related_party_jurisdiction="UAE",
                method="CUP",
                controlled_price=Decimal("7000000"),  # > 6M threshold
                arm_length_lower=Decimal("6500000"),
                arm_length_upper=Decimal("7500000"),
                arm_length_median=Decimal("7000000"),
            )],
        ))
        assert r.disclosure_form_required is True

    def test_local_file_threshold(self):
        r = analyse_transfer_pricing(TPInput(
            group_name="G", local_entity_name="L", fiscal_year="2026",
            group_consolidated_revenue=Decimal("500000000"),
            local_entity_revenue=Decimal("10000000"),
            transactions=[TPTransaction(
                description="Huge",
                transaction_type="services",
                related_party_name="RP", related_party_jurisdiction="UAE",
                method="TNMM",
                controlled_price=Decimal("150000000"),
                arm_length_lower=Decimal("140000000"),
                arm_length_upper=Decimal("160000000"),
                arm_length_median=Decimal("150000000"),
            )],
        ))
        assert r.local_file_required is True

    def test_cbcr_threshold(self):
        r = analyse_transfer_pricing(TPInput(
            group_name="BigGroup", local_entity_name="L", fiscal_year="2026",
            group_consolidated_revenue=Decimal("4000000000"),  # > 3.2B
            local_entity_revenue=Decimal("100000000"),
            transactions=[TPTransaction(
                description="Normal",
                transaction_type="services",
                related_party_name="RP", related_party_jurisdiction="UAE",
                method="TNMM",
                controlled_price=Decimal("1000000"),
                arm_length_lower=Decimal("900000"),
                arm_length_upper=Decimal("1100000"),
                arm_length_median=Decimal("1000000"),
            )],
        ))
        assert r.cbcr_required is True
        assert r.master_file_required is True

    def test_bad_method_rejected(self):
        with pytest.raises(ValueError, match="method"):
            analyse_transfer_pricing(TPInput(
                group_name="G", local_entity_name="L", fiscal_year="2026",
                group_consolidated_revenue=Decimal("0"),
                local_entity_revenue=Decimal("0"),
                transactions=[TPTransaction(
                    description="x", transaction_type="services",
                    related_party_name="x", related_party_jurisdiction="X",
                    method="magic",
                    controlled_price=Decimal("1"),
                    arm_length_lower=Decimal("1"),
                    arm_length_upper=Decimal("1"),
                    arm_length_median=Decimal("1"),
                )],
            ))

    def test_bad_range_rejected(self):
        with pytest.raises(ValueError, match="arm_length"):
            analyse_transfer_pricing(TPInput(
                group_name="G", local_entity_name="L", fiscal_year="2026",
                group_consolidated_revenue=Decimal("0"),
                local_entity_revenue=Decimal("0"),
                transactions=[TPTransaction(
                    description="x", transaction_type="goods",
                    related_party_name="x", related_party_jurisdiction="X",
                    method="CUP",
                    controlled_price=Decimal("100"),
                    arm_length_lower=Decimal("200"),
                    arm_length_upper=Decimal("100"),  # inverted
                    arm_length_median=Decimal("150"),
                )],
            ))

    def test_materiality_levels(self):
        r = analyse_transfer_pricing(TPInput(
            group_name="G", local_entity_name="L", fiscal_year="2026",
            group_consolidated_revenue=Decimal("0"),
            local_entity_revenue=Decimal("0"),
            transactions=[
                TPTransaction(description="low", transaction_type="goods",
                    related_party_name="x", related_party_jurisdiction="X",
                    method="CUP", controlled_price=Decimal("100000"),
                    arm_length_lower=Decimal("100000"),
                    arm_length_upper=Decimal("100000"),
                    arm_length_median=Decimal("100000")),
                TPTransaction(description="high", transaction_type="goods",
                    related_party_name="x", related_party_jurisdiction="X",
                    method="CUP", controlled_price=Decimal("15000000"),
                    arm_length_lower=Decimal("15000000"),
                    arm_length_upper=Decimal("15000000"),
                    arm_length_median=Decimal("15000000")),
            ],
        ))
        assert r.transactions[0].materiality == "low"
        assert r.transactions[1].materiality == "high"


class TestRoutes:
    def test_requires_auth(self, client):
        r = client.post("/tp/analyse", json={})
        assert r.status_code == 401

    def test_analyse_http(self, client, auth_header):
        r = client.post("/tp/analyse", json={
            "group_name": "G", "local_entity_name": "L",
            "fiscal_year": "2026",
            "group_consolidated_revenue": "100000000",
            "local_entity_revenue": "10000000",
            "transactions": [{
                "description": "RP service",
                "transaction_type": "services",
                "related_party_name": "RP",
                "related_party_jurisdiction": "UAE",
                "method": "TNMM",
                "controlled_price": "5000000",
                "arm_length_lower": "4500000",
                "arm_length_upper": "5500000",
                "arm_length_median": "5000000",
            }],
        }, headers=auth_header)
        assert r.status_code == 200
        assert r.json()["data"]["compliance_status"] == "compliant"

    def test_methods_endpoint(self, client, auth_header):
        r = client.get("/tp/methods", headers=auth_header)
        assert r.status_code == 200
        assert "TNMM" in r.json()["data"]["methods"]
