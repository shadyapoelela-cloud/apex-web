"""OCR invoice extraction tests."""

from decimal import Decimal

import pytest

from app.core.ocr_service import OcrExtractionInput, extract_invoice


class TestOcr:
    def test_basic_extraction(self):
        text = """
        فاتورة رقم: INV-2026-00123
        التاريخ: 2026-04-15
        الرقم الضريبي للبائع: 300000000000003

        المجموع قبل الضريبة: 1000.00 SAR
        ضريبة VAT: 150.00 SAR
        الإجمالي: 1150.00 SAR
        """
        r = extract_invoice(OcrExtractionInput(text=text))
        assert r.invoice_number == "INV-2026-00123"
        assert r.invoice_date == "2026-04-15"
        assert r.seller_vat == "300000000000003"
        assert r.seller_vat_valid is True
        assert r.total_amount == Decimal("1150.00")
        assert r.vat_amount == Decimal("150.00")
        assert r.subtotal == Decimal("1000.00")

    def test_invalid_vat_warning(self):
        text = "الرقم الضريبي: 123456789012345 الإجمالي 100"
        r = extract_invoice(OcrExtractionInput(text=text))
        # 15 digits but doesn't start+end with 3 → not matched
        assert r.seller_vat is None
        # Warning should mention the seller's VAT. Substring "بائع" matches
        # both "البائع" and "للبائع" forms.
        assert any("بائع" in w for w in r.warnings)

    def test_arabic_digits_normalised(self):
        # Arabic-Indic digits should be converted
        text = "الرقم الضريبي للبائع: ٣٠٠٠٠٠٠٠٠٠٠٠٠٠٣ الإجمالي ١٠٠٠.٠٠"
        r = extract_invoice(OcrExtractionInput(text=text))
        assert r.seller_vat == "300000000000003"

    def test_consistency_check(self):
        text = """
        المجموع قبل الضريبة: 1000
        ضريبة VAT: 150
        الإجمالي: 2000
        """
        r = extract_invoice(OcrExtractionInput(text=text))
        # 1000 + 150 = 1150 ≠ 2000 → warning
        assert any("اتساق" in w for w in r.warnings)

    def test_empty_text_rejected(self):
        with pytest.raises(ValueError):
            extract_invoice(OcrExtractionInput(text=""))

    def test_two_vat_numbers_seller_and_buyer(self):
        text = """
        البائع: 300000000000003
        المشتري: 301234567890123
        الإجمالي: 500
        """
        r = extract_invoice(OcrExtractionInput(text=text))
        assert r.seller_vat == "300000000000003"
        assert r.buyer_vat == "301234567890123"

    def test_no_total_warning(self):
        text = "فاتورة بدون إجمالي"
        r = extract_invoice(OcrExtractionInput(text=text))
        assert r.total_amount is None
        assert any("إجمالي" in w for w in r.warnings)


class TestRoutes:
    def test_extract_requires_auth(self, client):
        r = client.post("/ocr/invoice/extract", json={"text": "test"})
        assert r.status_code == 401

    def test_extract_http(self, client, auth_header):
        r = client.post(
            "/ocr/invoice/extract",
            json={
                "text": "فاتورة رقم INV-1\nالرقم الضريبي: 300000000000003\nالإجمالي: 1150.00",
            },
            headers=auth_header,
        )
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["seller_vat"] == "300000000000003"
        assert d["total_amount"] == "1150.00"

    def test_empty_text_rejected_http(self, client, auth_header):
        r = client.post(
            "/ocr/invoice/extract",
            json={"text": ""},
            headers=auth_header,
        )
        assert r.status_code == 422
