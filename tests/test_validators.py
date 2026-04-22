"""Tests for input validators."""

import pytest
from decimal import Decimal
from app.core.validators import (
    validate_saudi_cr, validate_vat_tin, validate_saudi_iban,
    validate_saudi_mobile, validate_email, validate_amount,
    validate_date_range, sanitize_string, validate_fiscal_year,
)


class TestSaudiCR:
    def test_valid_cr(self):
        assert validate_saudi_cr("1010000001") is None
        assert validate_saudi_cr("4010000001") is None
        assert validate_saudi_cr("7010000001") is None

    def test_invalid_cr(self):
        assert validate_saudi_cr("2010000001") is not None
        assert validate_saudi_cr("101") is not None
        assert validate_saudi_cr("abc") is not None


class TestVATTIN:
    def test_valid_tin(self):
        assert validate_vat_tin("300000000000003") is None
        assert validate_vat_tin("312345678901233") is None

    def test_invalid_tin(self):
        assert validate_vat_tin("200000000000003") is not None  # doesn't start with 3
        assert validate_vat_tin("300000000000001") is not None  # doesn't end with 3
        assert validate_vat_tin("30000000000003") is not None   # too short


class TestIBAN:
    def test_valid_iban(self):
        assert validate_saudi_iban("SA0380000000608010167519") is None
        assert validate_saudi_iban("sa0380000000608010167519") is None  # lowercase ok

    def test_invalid_iban(self):
        assert validate_saudi_iban("AE0380000000608010167519") is not None
        assert validate_saudi_iban("SA038000") is not None


class TestMobile:
    def test_valid_mobile(self):
        assert validate_saudi_mobile("+966501234567") is None
        assert validate_saudi_mobile("966512345678") is None

    def test_invalid_mobile(self):
        assert validate_saudi_mobile("+966601234567") is not None  # not starting with 5
        assert validate_saudi_mobile("+966501") is not None  # too short


class TestEmail:
    def test_valid_email(self):
        assert validate_email("user@example.com") is None
        assert validate_email("user.name@company.co.sa") is None

    def test_invalid_email(self):
        assert validate_email("not-an-email") is not None
        assert validate_email("@no-user.com") is not None


class TestAmount:
    def test_valid_amount(self):
        assert validate_amount("1000.50") is None
        assert validate_amount("0") is None

    def test_invalid_amount(self):
        assert validate_amount("not-a-number") is not None
        assert validate_amount("NaN") is not None

    def test_range(self):
        assert validate_amount("100", min_val=Decimal("0")) is None
        assert validate_amount("-1", min_val=Decimal("0")) is not None
        assert validate_amount("1000001", max_val=Decimal("1000000")) is not None


class TestDateRange:
    def test_valid_range(self):
        assert validate_date_range("2026-01-01", "2026-12-31") is None
        assert validate_date_range("2026-06-01", "2026-06-01") is None

    def test_invalid_range(self):
        assert validate_date_range("2026-12-31", "2026-01-01") is not None

    def test_invalid_format(self):
        assert validate_date_range("2026/01/01", "2026-12-31") is not None


class TestSanitize:
    def test_strips_null_bytes(self):
        assert "\x00" not in sanitize_string("hello\x00world")

    def test_truncates(self):
        assert len(sanitize_string("a" * 1000, max_length=100)) == 100

    def test_strips_whitespace(self):
        assert sanitize_string("  hello  ") == "hello"


class TestFiscalYear:
    def test_valid_single(self):
        assert validate_fiscal_year("2026") is None

    def test_valid_range(self):
        assert validate_fiscal_year("2025-2026") is None

    def test_invalid(self):
        assert validate_fiscal_year("26") is not None
        assert validate_fiscal_year("2026-2025") is not None  # end before start
