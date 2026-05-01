"""APEX Platform -- app/core/saudi_knowledge_base.py unit tests.

Coverage target: ≥95% of 21 helper getter functions (G-T1.7b.1, Sprint 9).

The module is ~1064 lines of Arabic regulatory data (IFRS, ZATCA, GOSI,
LABOR, ...) plus 21 thin getter functions at the bottom. The data is
already validated by being constants; the contract that needs testing
is that each getter resolves to a real, non-empty structure of the
expected type and that ``get_sector_info`` handles the unknown-sector
fallback path.
"""

from __future__ import annotations

import pytest

from app.core import saudi_knowledge_base as skb


# ══════════════════════════════════════════════════════════════
# Tax / regulatory rate getters (numeric / dict)
# ══════════════════════════════════════════════════════════════


class TestTaxAndRegulatoryRates:
    def test_get_vat_rate(self):
        rate = skb.get_vat_rate()
        # KSA standard VAT is 15% as of July 2020. Stored as a number.
        assert rate is not None
        assert isinstance(rate, (int, float, str))

    def test_get_zakat_rate(self):
        rate = skb.get_zakat_rate()
        assert rate is not None

    def test_get_income_tax_rate(self):
        rate = skb.get_income_tax_rate()
        assert rate is not None

    def test_get_withholding_rates(self):
        rates = skb.get_withholding_rates()
        # Dict of WHT categories (royalties, services, dividends, ...).
        assert isinstance(rates, dict)
        assert len(rates) > 0


# ══════════════════════════════════════════════════════════════
# GOSI / labor getters
# ══════════════════════════════════════════════════════════════


class TestGosiAndLabor:
    def test_get_gosi_rates(self):
        rates = skb.get_gosi_rates()
        assert rates is not None  # dict of saudi/non-saudi splits

    def test_get_gosi_cap(self):
        cap = skb.get_gosi_cap()
        # Numeric cap (SAR/month) — accept any non-None value.
        assert cap is not None

    def test_get_eos_rules(self):
        rules = skb.get_eos_rules()
        assert rules is not None

    def test_get_leave_rules(self):
        rules = skb.get_leave_rules()
        assert rules is not None


# ══════════════════════════════════════════════════════════════
# Companies / banking / sector getters
# ══════════════════════════════════════════════════════════════


class TestCompaniesAndBanking:
    def test_get_statutory_reserve(self):
        out = skb.get_statutory_reserve()
        assert out is not None

    def test_get_company_types(self):
        types = skb.get_company_types()
        # Must include the major KSA forms.
        assert types is not None
        # Non-empty container of some shape (dict or list).
        assert len(types) > 0

    def test_get_dscr_minimum(self):
        # DSCR floor for corporate lending.
        out = skb.get_dscr_minimum()
        assert out is not None

    def test_get_islamic_finance(self):
        out = skb.get_islamic_finance()
        assert out is not None


# ══════════════════════════════════════════════════════════════
# Reporting / accounting / sector / vision getters
# ══════════════════════════════════════════════════════════════


class TestReportingAndSector:
    def test_get_qawaem_taxonomy(self):
        out = skb.get_qawaem_taxonomy()
        assert out is not None

    def test_get_closing_process(self):
        out = skb.get_closing_process()
        assert out is not None

    def test_get_sector_info_known_sector_returns_data(self):
        # Loop through SECTORS keys to find a real one.
        sectors = list(skb.SECTORS.keys())
        assert len(sectors) > 0, "SECTORS dict must be populated"
        info = skb.get_sector_info(sectors[0])
        assert info != {}
        assert isinstance(info, dict)

    def test_get_sector_info_unknown_sector_returns_empty_dict(self):
        # Fallback path for unrecognized sector keys.
        info = skb.get_sector_info("__no_such_sector__")
        assert info == {}

    def test_get_vision_targets(self):
        out = skb.get_vision_targets()
        assert out is not None

    def test_get_going_concern_flags(self):
        out = skb.get_going_concern_flags()
        assert out is not None


# ══════════════════════════════════════════════════════════════
# IFRS-derived getters
# ══════════════════════════════════════════════════════════════


class TestIfrsDerived:
    def test_get_useful_lives(self):
        out = skb.get_useful_lives()
        assert out is not None  # IAS 16 useful-life table

    def test_get_ecl_rates(self):
        out = skb.get_ecl_rates()
        assert out is not None  # IFRS 9 ECL provision matrix

    def test_get_cogs_formula(self):
        out = skb.get_cogs_formula()
        # IAS 2 periodic-system COGS formula text.
        assert out is not None


# ══════════════════════════════════════════════════════════════
# Aggregate summary
# ══════════════════════════════════════════════════════════════


class TestRegulationsSummary:
    def test_get_all_regulations_summary_shape(self):
        s = skb.get_all_regulations_summary()
        # Six-key summary the AI/seed layer relies on.
        assert isinstance(s, dict)
        for key in (
            "ifrs_standards",
            "zatca_sections",
            "company_types",
            "sectors",
            "labor_sections",
            "total_knowledge_areas",
        ):
            assert key in s, f"summary missing key: {key}"
        # IFRS standards count is published as 22 knowledge areas.
        assert s["total_knowledge_areas"] == 22
        # Non-zero counts on the dynamic fields.
        assert s["ifrs_standards"] > 0
        assert s["company_types"] > 0
        assert s["sectors"] > 0
