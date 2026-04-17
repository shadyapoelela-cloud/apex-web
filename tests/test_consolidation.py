"""Consolidation (IFRS 10) tests."""

from decimal import Decimal

import pytest

from app.core.consolidation_service import (
    ConsolLine, Entity, IntercoEntry, ConsolidationInput, consolidate,
)


def _balanced_entity(eid: str, name: str, is_parent: bool = False,
                     ownership: str = "100",
                     assets: str = "1000", liab: str = "400",
                     equity: str = "300", rev: str = "500", exp: str = "200") -> Entity:
    """Build a balanced entity (A = L + E and Rev − Exp is already in equity)."""
    return Entity(
        entity_id=eid, entity_name=name,
        ownership_pct=Decimal(ownership), is_parent=is_parent,
        lines=[
            ConsolLine("1000", "Assets", "asset", Decimal(assets)),
            ConsolLine("2000", "Liab", "liability", -Decimal(liab)),
            ConsolLine("3000", "Equity", "equity", -Decimal(equity)),
            ConsolLine("4000", "Rev", "revenue", -Decimal(rev)),
            ConsolLine("5000", "Exp", "expense", Decimal(exp)),
        ],
    )


class TestSingleParent:
    def test_100pct_sub_no_interco(self):
        inp = ConsolidationInput(
            group_name="Group", period_label="FY26",
            entities=[
                _balanced_entity("P", "Parent", is_parent=True,
                    assets="2000", liab="800", equity="600", rev="1000", exp="400"),
                _balanced_entity("S1", "Sub", ownership="100",
                    assets="1000", liab="400", equity="300", rev="500", exp="200"),
            ],
        )
        r = consolidate(inp)
        # Total assets: 2000 + 1000 = 3000
        # Total liab: 800 + 400 = 1200
        # Equity: 600 + 300 = 900; NI = (1000+500) - (400+200) = 900
        # Parent's NI portion (100% owned): 900
        # Total equity_parent = 900 + 900 − 0 = 1800
        # NCI = 0 (100% owned)
        # Check: 3000 = 1200 + 1800 + 0 ✓
        assert r.total_assets == Decimal("3000.00")
        assert r.total_liabilities == Decimal("1200.00")
        assert r.total_nci == Decimal("0.00")
        assert r.consolidated_net_income == Decimal("900.00")
        assert r.net_income_to_nci == Decimal("0.00")
        assert r.is_balanced is True

    def test_80pct_sub_gets_nci(self):
        inp = ConsolidationInput(
            group_name="Group", period_label="FY26",
            entities=[
                _balanced_entity("P", "Parent", is_parent=True,
                    assets="2000", liab="800", equity="600", rev="1000", exp="400"),
                _balanced_entity("S1", "Sub", ownership="80",
                    assets="1000", liab="400", equity="300", rev="500", exp="200"),
            ],
        )
        r = consolidate(inp)
        # Sub NI = 500 - 200 = 300
        # NCI share of NI: 300 × 20% = 60
        assert r.net_income_to_nci == Decimal("60.00")
        assert r.net_income_to_parent == Decimal("840.00")
        # NCI of sub equity: (1000 − 400) × 20% = 120
        assert r.total_nci == Decimal("120.00")
        assert r.is_balanced is True


class TestIntercompany:
    def test_ic_sales_elimination(self):
        # Parent sold to Sub for 100. Before elim:
        # Parent AR: +100, Parent Revenue: -100
        # Sub AP: -100, Sub Expense: +100
        # Elim: remove IC AR/AP (100) and IC Rev/Exp (100) — but
        # in our model we pass ONE elim entry per balance-sheet pair
        # and one per P&L pair.
        inp = ConsolidationInput(
            group_name="G", period_label="FY26",
            entities=[
                Entity("P", "Parent", is_parent=True, lines=[
                    ConsolLine("1100", "Cash", "asset", Decimal("500")),
                    ConsolLine("1200", "IC_AR", "asset", Decimal("100")),
                    ConsolLine("2100", "AP", "liability", Decimal("-200")),
                    ConsolLine("3000", "Equity", "equity", Decimal("-300")),
                    ConsolLine("4000", "IC_Rev", "revenue", Decimal("-100")),
                ]),
                Entity("S", "Sub", ownership_pct=Decimal("100"), lines=[
                    ConsolLine("1100", "Cash", "asset", Decimal("300")),
                    ConsolLine("2200", "IC_AP", "liability", Decimal("-100")),
                    ConsolLine("3000", "Equity", "equity", Decimal("-100")),
                    ConsolLine("5000", "IC_Exp", "expense", Decimal("100")),
                ]),
            ],
            intercompany=[
                IntercoEntry("IC Receivable elim",
                    from_entity="P", to_entity="S", amount=Decimal("100"),
                    dr_account="1200", cr_account="2200"),
                IntercoEntry("IC Revenue elim",
                    from_entity="P", to_entity="S", amount=Decimal("100"),
                    dr_account="4000", cr_account="5000"),
            ],
        )
        r = consolidate(inp)
        # After elim:
        # IC_AR should be 100 − 100 = 0
        # IC_AP should be -100 + 100 = 0
        ic_ar = next(b for b in r.consolidated_lines if b.account_code == "1200")
        ic_ap = next(b for b in r.consolidated_lines if b.account_code == "2200")
        assert ic_ar.consolidated == Decimal("0.00")
        assert ic_ap.consolidated == Decimal("0.00")
        # Total eliminations = 200 (100 AR + 100 Rev)
        assert r.total_eliminations == Decimal("200.00")

    def test_unknown_ic_account_flagged(self):
        inp = ConsolidationInput(
            group_name="G", period_label="FY26",
            entities=[
                Entity("P", "P", is_parent=True, lines=[
                    ConsolLine("1100", "Cash", "asset", Decimal("100")),
                    ConsolLine("3000", "Eq", "equity", Decimal("-100")),
                ]),
                Entity("S", "S", ownership_pct=Decimal("100"), lines=[
                    ConsolLine("1100", "Cash", "asset", Decimal("50")),
                    ConsolLine("3000", "Eq", "equity", Decimal("-50")),
                ]),
            ],
            intercompany=[
                IntercoEntry("Bad ref", from_entity="P", to_entity="S",
                    amount=Decimal("10"),
                    dr_account="9999", cr_account="8888"),
            ],
        )
        r = consolidate(inp)
        assert any("not found" in w for w in r.warnings)


class TestFxTranslation:
    def test_closing_rate_applied(self):
        inp = ConsolidationInput(
            group_name="G", period_label="FY26",
            presentation_currency="SAR",
            entities=[
                Entity("P", "Parent", is_parent=True,
                    fx_rate_to_presentation=Decimal("1"),
                    avg_fx_rate=Decimal("1"),
                    lines=[
                        ConsolLine("1100", "Cash", "asset", Decimal("1000")),
                        ConsolLine("3000", "Eq", "equity", Decimal("-1000")),
                    ]),
                Entity("S_USD", "Sub USD",
                    ownership_pct=Decimal("100"),
                    fx_rate_to_presentation=Decimal("3.75"),
                    avg_fx_rate=Decimal("3.70"),
                    lines=[
                        ConsolLine("1100", "Cash", "asset", Decimal("100")),
                        ConsolLine("3000", "Eq", "equity", Decimal("-100")),
                        ConsolLine("4000", "Rev", "revenue", Decimal("-200")),
                        ConsolLine("5000", "Exp", "expense", Decimal("50")),
                    ]),
            ],
        )
        r = consolidate(inp)
        cash = next(b for b in r.consolidated_lines if b.account_code == "1100")
        # Parent 1000 + Sub translated 100 × 3.75 = 375 → 1375
        assert cash.consolidated == Decimal("1375.00")
        # Revenue: -200 × 3.70 (avg) = -740 USD (translated)
        rev = next(b for b in r.consolidated_lines if b.account_code == "4000")
        assert rev.consolidated == Decimal("-740.00")


class TestValidation:
    def test_empty_entities_rejected(self):
        with pytest.raises(ValueError, match="entities is required"):
            consolidate(ConsolidationInput(
                group_name="g", period_label="p", entities=[]))

    def test_no_parent_rejected(self):
        with pytest.raises(ValueError, match="is_parent"):
            consolidate(ConsolidationInput(
                group_name="g", period_label="p",
                entities=[_balanced_entity("S", "Sub", is_parent=False)],
            ))

    def test_two_parents_rejected(self):
        with pytest.raises(ValueError, match="is_parent"):
            consolidate(ConsolidationInput(
                group_name="g", period_label="p",
                entities=[
                    _balanced_entity("P1", "P1", is_parent=True),
                    _balanced_entity("P2", "P2", is_parent=True),
                ],
            ))

    def test_duplicate_entity_id_rejected(self):
        with pytest.raises(ValueError, match="duplicate"):
            consolidate(ConsolidationInput(
                group_name="g", period_label="p",
                entities=[
                    _balanced_entity("X", "X1", is_parent=True),
                    _balanced_entity("X", "X2", ownership="100"),
                ],
            ))

    def test_invalid_ownership_rejected(self):
        with pytest.raises(ValueError, match="ownership_pct"):
            consolidate(ConsolidationInput(
                group_name="g", period_label="p",
                entities=[
                    _balanced_entity("P", "P", is_parent=True),
                    _balanced_entity("S", "S", ownership="150"),
                ],
            ))


class TestRoutes:
    def test_requires_auth(self, client):
        r = client.post("/consol/build", json={})
        assert r.status_code == 401

    def test_build_http(self, client, auth_header):
        payload = {
            "group_name": "Group",
            "period_label": "FY 2026",
            "presentation_currency": "SAR",
            "entities": [
                {
                    "entity_id": "P", "entity_name": "Parent",
                    "ownership_pct": "100", "is_parent": True,
                    "lines": [
                        {"account_code": "1100", "account_name": "Cash",
                         "classification": "asset", "amount": "1000"},
                        {"account_code": "3000", "account_name": "Equity",
                         "classification": "equity", "amount": "-1000"},
                    ],
                },
                {
                    "entity_id": "S", "entity_name": "Sub",
                    "ownership_pct": "100",
                    "lines": [
                        {"account_code": "1100", "account_name": "Cash",
                         "classification": "asset", "amount": "500"},
                        {"account_code": "3000", "account_name": "Equity",
                         "classification": "equity", "amount": "-500"},
                    ],
                },
            ],
            "intercompany": [],
        }
        r = client.post("/consol/build", json=payload, headers=auth_header)
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["total_assets"] == "1500.00"
        assert d["is_balanced"] is True

    def test_bad_ownership_http(self, client, auth_header):
        payload = {
            "group_name": "g", "period_label": "p",
            "entities": [
                {"entity_id": "P", "entity_name": "P", "is_parent": True,
                 "ownership_pct": "100",
                 "lines": [{"account_code": "1", "account_name": "a",
                            "classification": "asset", "amount": "1"}]},
                {"entity_id": "S", "entity_name": "S",
                 "ownership_pct": "150",
                 "lines": [{"account_code": "1", "account_name": "a",
                            "classification": "asset", "amount": "1"}]},
            ],
        }
        r = client.post("/consol/build", json=payload, headers=auth_header)
        assert r.status_code == 422
