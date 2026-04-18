"""
Tests for app/core/anomaly_detector.py (Wave 3 PR#1).

Each detector is exercised against hand-crafted transaction fixtures
so the pass/fail criteria are obvious at a glance.
"""

from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal

import pytest

from app.core.anomaly_detector import (
    AnomalyFinding,
    find_category_spikes,
    find_duplicate_payments,
    find_new_vendor_large_payment,
    find_off_hours_entries,
    find_round_number_anomalies,
    scan_all,
)


# ── Duplicate payments ────────────────────────────────────────────────


class TestDuplicatePayments:
    def test_same_vendor_amount_within_window_is_duplicate(self):
        txns = [
            {"id": "p1", "vendor": "STC Telecom", "amount": "1200", "date": "2026-04-10"},
            {"id": "p2", "vendor": "STC Telecom", "amount": "1200", "date": "2026-04-12"},
        ]
        fs = find_duplicate_payments(txns)
        assert len(fs) == 1
        assert fs[0].type == "duplicate_payment"
        assert set(fs[0].transaction_ids) == {"p1", "p2"}
        assert fs[0].severity == "medium"
        # Impact = one overpayment = 1200
        assert fs[0].impact == Decimal("1200")

    def test_three_matches_bumps_severity_to_high(self):
        txns = [
            {"id": str(i), "vendor": "ACME", "amount": "500", "date": "2026-04-10"}
            for i in range(3)
        ]
        fs = find_duplicate_payments(txns)
        assert len(fs) == 1
        assert fs[0].severity == "high"
        assert fs[0].impact == Decimal("1000")  # 2 overpayments

    def test_vendor_mismatch_not_flagged(self):
        txns = [
            {"id": "1", "vendor": "STC", "amount": "100", "date": "2026-04-10"},
            {"id": "2", "vendor": "Mobily", "amount": "100", "date": "2026-04-10"},
        ]
        assert find_duplicate_payments(txns) == []

    def test_outside_window_not_flagged(self):
        txns = [
            {"id": "1", "vendor": "X", "amount": "50", "date": "2026-04-01"},
            {"id": "2", "vendor": "X", "amount": "50", "date": "2026-04-20"},
        ]
        assert find_duplicate_payments(txns, window_days=7) == []

    def test_amount_tolerance(self):
        txns = [
            {"id": "1", "vendor": "X", "amount": "1000.00", "date": "2026-04-10"},
            {"id": "2", "vendor": "X", "amount": "1000.005", "date": "2026-04-11"},
        ]
        assert len(find_duplicate_payments(txns)) == 1

    def test_arabic_vendor_fold_alef_variants(self):
        # "آمازون" vs "امازون" should fold to the same normalized name.
        txns = [
            {"id": "1", "vendor": "آمازون", "amount": "300", "date": "2026-04-10"},
            {"id": "2", "vendor": "امازون", "amount": "300", "date": "2026-04-10"},
        ]
        fs = find_duplicate_payments(txns)
        assert len(fs) == 1

    def test_missing_vendor_skipped(self):
        txns = [
            {"id": "1", "amount": "100", "date": "2026-04-10"},
            {"id": "2", "amount": "100", "date": "2026-04-10"},
        ]
        assert find_duplicate_payments(txns) == []


# ── Round-number anomalies ────────────────────────────────────────────


class TestRoundNumberAnomalies:
    def test_exact_50k_is_high(self):
        fs = find_round_number_anomalies(
            [{"id": "1", "vendor": "X", "amount": "50000", "date": "2026-04-10"}]
        )
        assert len(fs) == 1
        assert fs[0].severity == "high"

    def test_exact_10k_is_medium(self):
        fs = find_round_number_anomalies(
            [{"id": "1", "vendor": "X", "amount": "10000", "date": "2026-04-10"}]
        )
        assert fs[0].severity == "medium"

    def test_exact_5k_is_low(self):
        fs = find_round_number_anomalies(
            [{"id": "1", "vendor": "X", "amount": "5000", "date": "2026-04-10"}]
        )
        assert fs[0].severity == "low"

    def test_non_round_not_flagged(self):
        assert (
            find_round_number_anomalies(
                [{"id": "1", "vendor": "X", "amount": "5123.45", "date": "2026-04-10"}]
            )
            == []
        )

    def test_below_min_threshold_not_flagged(self):
        assert (
            find_round_number_anomalies(
                [{"id": "1", "vendor": "X", "amount": "2000", "date": "2026-04-10"}]
            )
            == []
        )


# ── Off-hours entries ─────────────────────────────────────────────────


class TestOffHoursEntries:
    def test_midnight_entry_flagged(self):
        fs = find_off_hours_entries(
            [
                {
                    "id": "1",
                    "vendor": "X",
                    "amount": "5000",
                    "created_at": datetime(2026, 4, 10, 2, 30, tzinfo=timezone.utc),
                }
            ]
        )
        assert len(fs) == 1
        assert fs[0].type == "off_hours_entry"

    def test_large_off_hours_is_high(self):
        fs = find_off_hours_entries(
            [
                {
                    "id": "1",
                    "vendor": "X",
                    "amount": "25000",
                    "created_at": datetime(2026, 4, 10, 23, 30),
                }
            ]
        )
        assert fs[0].severity == "high"

    def test_business_hours_not_flagged(self):
        fs = find_off_hours_entries(
            [
                {
                    "id": "1",
                    "vendor": "X",
                    "amount": "5000",
                    "created_at": datetime(2026, 4, 10, 14, 0),
                }
            ]
        )
        assert fs == []


# ── New vendor large payment ──────────────────────────────────────────


class TestNewVendorLarge:
    def test_first_payment_above_threshold_flagged(self):
        fs = find_new_vendor_large_payment(
            [{"id": "1", "vendor": "Unknown Co", "amount": "75000", "date": "2026-04-10"}]
        )
        assert len(fs) == 1
        assert fs[0].severity == "high"

    def test_second_payment_to_same_vendor_ignored(self):
        txns = [
            {"id": "1", "vendor": "Known", "amount": "100", "date": "2026-04-01"},
            {"id": "2", "vendor": "Known", "amount": "80000", "date": "2026-04-10"},
        ]
        assert find_new_vendor_large_payment(txns) == []

    def test_below_threshold_not_flagged(self):
        fs = find_new_vendor_large_payment(
            [{"id": "1", "vendor": "X", "amount": "10000", "date": "2026-04-10"}]
        )
        assert fs == []


# ── Category spikes ───────────────────────────────────────────────────


class TestCategorySpikes:
    def _baseline_txn(self, i: int, cat: str, amt: str, day: int):
        return {
            "id": f"b{i}",
            "vendor": "anybody",
            "amount": amt,
            "category": cat,
            "date": f"2026-02-{day:02d}",
        }

    def test_5x_current_spike_flagged(self):
        txns = [
            # Baseline Feb: 5 transactions, 1000 each = 5000 total, avg 1000 → monthly baseline ~30k
            *(self._baseline_txn(i, "Travel", "1000", i + 1) for i in range(5)),
            # Current April: one huge entry
            {
                "id": "c1",
                "vendor": "anybody",
                "amount": "200000",
                "category": "Travel",
                "date": "2026-04-10",
            },
        ]
        fs = find_category_spikes(txns)
        assert len(fs) == 1
        assert fs[0].type == "category_spike"
        assert fs[0].severity == "high"

    def test_no_baseline_no_finding(self):
        txns = [
            {
                "id": "c1",
                "amount": "5000",
                "category": "NewCat",
                "date": "2026-04-10",
            }
        ]
        assert find_category_spikes(txns) == []


# ── Coordinator ───────────────────────────────────────────────────────


class TestScanAll:
    def test_sorts_high_first(self):
        txns = [
            # low-severity round-number
            {"id": "a", "vendor": "X", "amount": "5000", "date": "2026-04-10"},
            # high-severity new-vendor large
            {"id": "b", "vendor": "ACME NEW", "amount": "80000", "date": "2026-04-10"},
        ]
        fs = scan_all(txns)
        assert fs[0].severity == "high"

    def test_empty_input_empty_output(self):
        assert scan_all([]) == []


# ── Route integration ─────────────────────────────────────────────────


class TestAnomalyRoute:
    def test_auth_required(self, client):
        r = client.post("/anomalies/scan", json={"transactions": []})
        assert r.status_code == 401

    def test_returns_findings(self, client, auth_header):
        body = {
            "transactions": [
                {"id": "1", "vendor": "X", "amount": "1000", "date": "2026-04-10"},
                {"id": "2", "vendor": "X", "amount": "1000", "date": "2026-04-12"},
                {"id": "3", "vendor": "Y", "amount": "50000", "date": "2026-04-10"},
            ]
        }
        r = client.post("/anomalies/scan", json=body, headers=auth_header)
        assert r.status_code == 200, r.text
        data = r.json()["data"]
        assert data["count"] >= 2
        assert sum(data["by_severity"].values()) == data["count"]

    def test_bad_business_hours_rejected(self, client, auth_header):
        body = {
            "transactions": [],
            "business_hours_start": 22,
            "business_hours_end": 6,
        }
        r = client.post("/anomalies/scan", json=body, headers=auth_header)
        assert r.status_code == 400
