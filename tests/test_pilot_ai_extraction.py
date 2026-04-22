"""اختبارات لوحدة AI extraction — الدوال النقية (بدون استدعاء Claude)."""

from decimal import Decimal


def test_normalize_amount_handles_strings_and_numbers():
    from app.pilot.services.ai_extraction import _normalize_amount

    assert _normalize_amount("100.00") == Decimal("100.00")
    assert _normalize_amount("1,150.50") == Decimal("1150.50")
    assert _normalize_amount("1 500") == Decimal("1500.00")
    assert _normalize_amount(1500) == Decimal("1500.00")
    assert _normalize_amount(1500.5) == Decimal("1500.50")
    assert _normalize_amount(None) == Decimal("0.00")
    assert _normalize_amount("") == Decimal("0.00")
    assert _normalize_amount("-") == Decimal("0.00")
    assert _normalize_amount("not a number") == Decimal("0.00")


def test_normalize_amount_strips_currency_symbols():
    from app.pilot.services.ai_extraction import _normalize_amount

    assert _normalize_amount("1500 ر.س") == Decimal("1500.00")
    assert _normalize_amount("SAR 250.25") == Decimal("250.25")
    assert _normalize_amount("$99.99") == Decimal("99.99")
    assert _normalize_amount("500 ريال") == Decimal("500.00")


def test_safe_json_parse_accepts_bare_json():
    from app.pilot.services.ai_extraction import _safe_json_parse

    out = _safe_json_parse('{"ok": true, "n": 42}')
    assert out == {"ok": True, "n": 42}


def test_safe_json_parse_strips_markdown_fences():
    from app.pilot.services.ai_extraction import _safe_json_parse

    out = _safe_json_parse('```json\n{"x": 1}\n```')
    assert out == {"x": 1}

    out2 = _safe_json_parse('```\n{"y": 2}\n```')
    assert out2 == {"y": 2}


def test_safe_json_parse_extracts_first_balanced_object_with_prose():
    from app.pilot.services.ai_extraction import _safe_json_parse

    text = 'Here is the result:\n{"a": 1, "b": {"c": 2}}\nThanks.'
    out = _safe_json_parse(text)
    assert out == {"a": 1, "b": {"c": 2}}


def test_safe_json_parse_returns_none_for_invalid():
    from app.pilot.services.ai_extraction import _safe_json_parse

    assert _safe_json_parse("no json here") is None
    assert _safe_json_parse("") is None
    assert _safe_json_parse("{broken") is None


def test_b64_prefix_stripper_removes_data_uri_prefix():
    from app.pilot.services.ai_extraction import _b64_without_prefix

    assert _b64_without_prefix("data:image/jpeg;base64,ABCDE") == "ABCDE"
    assert _b64_without_prefix("ABCDE") == "ABCDE"


def test_strip_ar_normalizes_alef_and_taa_marbuta():
    from app.pilot.services.ai_extraction import _strip_ar

    assert _strip_ar("أحمد") == _strip_ar("احمد")
    assert _strip_ar("مدرسة") == _strip_ar("مدرسه")
    assert _strip_ar("يَحْيَى") == _strip_ar("يحيي")


def test_account_matcher_exact_match():
    from app.pilot.services.ai_extraction import _match_account

    class FakeAcc:
        def __init__(self, id, name_ar, type_="detail", active=True):
            self.id = id
            self.name_ar = name_ar
            self.type = type_
            self.is_active = active

    accounts = [
        FakeAcc("a1", "الصندوق"),
        FakeAcc("a2", "الموردون"),
        FakeAcc("a3", "مشتريات بضاعة"),
        FakeAcc("a4", "ضريبة قيمة مضافة مدخلة"),
    ]

    acc_id, conf = _match_account("الصندوق", accounts)
    assert acc_id == "a1"
    assert conf >= 0.9

    acc_id, conf = _match_account("ضريبة قيمة مضافة مدخلة", accounts)
    assert acc_id == "a4"
    assert conf >= 0.9


def test_account_matcher_synonym_match():
    from app.pilot.services.ai_extraction import _match_account

    class FakeAcc:
        def __init__(self, id, name_ar, type_="detail", active=True):
            self.id = id
            self.name_ar = name_ar
            self.type = type_
            self.is_active = active

    accounts = [
        FakeAcc("cash", "الصندوق"),
        FakeAcc("bank", "البنك الأهلي"),
    ]
    # "نقدية" ليس في الأسماء لكنه مرادف للصندوق
    acc_id, conf = _match_account("نقدية", accounts)
    assert acc_id == "cash"
    assert conf > 0


def test_account_matcher_ignores_header_and_inactive():
    from app.pilot.services.ai_extraction import _match_account

    class FakeAcc:
        def __init__(self, id, name_ar, type_="detail", active=True):
            self.id = id
            self.name_ar = name_ar
            self.type = type_
            self.is_active = active

    accounts = [
        FakeAcc("h", "الأصول", type_="header"),
        FakeAcc("i", "الصندوق", active=False),
        FakeAcc("d", "الصندوق النقدي"),
    ]
    acc_id, _ = _match_account("الصندوق", accounts)
    assert acc_id == "d"  # يتخطى الـ header والـ inactive


def test_account_matcher_returns_none_below_threshold():
    from app.pilot.services.ai_extraction import _match_account

    class FakeAcc:
        def __init__(self, id, name_ar, type_="detail", active=True):
            self.id = id
            self.name_ar = name_ar
            self.type = type_
            self.is_active = active

    accounts = [FakeAcc("a", "إهلاك آلات إنتاج")]
    # hint لا علاقة له بالحساب
    acc_id, conf = _match_account("مبيعات خارجية", accounts)
    assert acc_id is None
    assert conf == 0.0


def test_ai_health_endpoint(client):
    """/pilot/ai/health يعود بدون مصادقة."""
    r = client.get("/pilot/ai/health")
    assert r.status_code == 200
    body = r.json()
    assert "ai_enabled" in body
    assert "model" in body
    assert "supported_media_types" in body
    assert "image/jpeg" in body["supported_media_types"]
    assert "application/pdf" in body["supported_media_types"]


def test_extract_je_rejects_unsupported_media_type(client):
    """أنواع الملفات غير المدعومة تُرفض بـ 400 أو 404 للـ entity."""
    # بدون entity حقيقي، قد يعود 404 قبل الوصول لفحص media_type
    r = client.post(
        "/pilot/entities/non-existent-entity/ai/extract-je",
        json={
            "file_base64": "x" * 200,
            "media_type": "text/plain",
        },
    )
    # 404 entity not found، أو 400 bad media type إذا الـ entity check لا يسبق
    assert r.status_code in (400, 404)


def test_extract_je_rejects_short_base64(client):
    """file_base64 أقصر من 100 حرف يُرفض بواسطة Pydantic."""
    r = client.post(
        "/pilot/entities/any-entity/ai/extract-je",
        json={
            "file_base64": "short",
            "media_type": "image/jpeg",
        },
    )
    assert r.status_code == 422  # Pydantic validation


def test_read_document_rejects_unknown_entity(client):
    """/read-document يُرفض بسبب entity غير موجود قبل استدعاء Claude."""
    import io

    r = client.post(
        "/pilot/entities/does-not-exist/ai/read-document",
        files={
            "file": (
                "receipt.jpg",
                io.BytesIO(b"x" * 500),
                "image/jpeg",
            ),
        },
    )
    assert r.status_code == 404


def test_guess_mime_from_extension():
    """helper: _guess_mime يعرف الامتداد حين يكون content_type فارغ."""
    from app.pilot.routes.ai_routes import _guess_mime

    class _U:
        def __init__(self, ct, name):
            self.content_type = ct
            self.filename = name

    assert _guess_mime(_U("", "bill.pdf")) == "application/pdf"
    assert _guess_mime(_U("", "receipt.JPG")) == "image/jpeg"
    assert _guess_mime(_U("", "photo.webp")) == "image/webp"
    assert _guess_mime(_U("application/pdf", "x.pdf")) == "application/pdf"
    assert _guess_mime(_U("image/jpeg", "x.jpeg")) == "image/jpeg"
    # content_type غير معروف + امتداد غير معروف
    assert _guess_mime(_U("", "junk.bin")) == "application/octet-stream"


def test_shape_for_read_document_success_case():
    """_shape_for_read_document يُرجِع الشكل المتوقَّع من dazzling UI."""
    from app.pilot.routes.ai_routes import _shape_for_read_document

    class FakeAcc:
        def __init__(self, id, code, name_ar):
            self.id = id
            self.code = code
            self.name_ar = name_ar
            self.entity_id = "e1"
            self.is_active = True

    class FakeQuery:
        def __init__(self, rows):
            self._rows = rows

        def filter(self, *args):
            return self

        def all(self):
            return self._rows

    class FakeDb:
        def __init__(self, rows):
            self._rows = rows

        def query(self, _model):
            return FakeQuery(self._rows)

    class FakeEntity:
        id = "e1"

    raw = {
        "success": True,
        "confidence": 0.9,
        "document_type": "invoice",
        "suggested_kind": "manual",
        "suggested_memo_ar": "فاتورة شراء مكتبية",
        "suggested_date": "2026-04-22",
        "currency": "SAR",
        "total_amount": "1150.00",
        "vat_amount": "150.00",
        "vendor_or_customer": "مكتبة جرير",
        "document_number": "INV-42",
        "suggested_lines": [
            {
                "account_id": "a1",
                "account_hint": "مصروفات مكتبية",
                "match_confidence": 0.85,
                "debit": "1000.00",
                "credit": "0.00",
                "description": "قيمة الشراء",
            },
            {
                "account_id": None,
                "account_hint": "ضريبة مدخلة",
                "match_confidence": 0.0,
                "debit": "150.00",
                "credit": "0.00",
                "description": "VAT 15%",
            },
        ],
        "warnings": ["لم يُعثر على مطابقة لـ 'ضريبة مدخلة'"],
        "is_balanced": False,
        "total_debit": "1150.00",
        "total_credit": "0.00",
    }
    db = FakeDb([FakeAcc("a1", "5310", "مصروفات مكتبية")])
    out = _shape_for_read_document(db, FakeEntity(), raw)
    assert out["success"] is True
    d = out["data"]
    assert d["confidence"] == 0.9
    assert d["extracted"]["vendor"] == "مكتبة جرير"
    assert d["extracted"]["date"] == "2026-04-22"
    assert d["extracted"]["document_number"] == "INV-42"
    assert d["extracted"]["amount"] == 1150.0
    assert d["extracted"]["tax_amount"] == 150.0
    lines = d["proposed_je"]["lines"]
    assert len(lines) == 2
    assert lines[0]["account_id"] == "a1"
    assert lines[0]["account_code"] == "5310"
    assert lines[0]["account_name_resolved"] == "مصروفات مكتبية"
    assert lines[0]["debit"] == 1000.0
    # السطر الثاني: لا مطابقة
    assert lines[1]["account_id"] is None
    assert lines[1]["account_code"] is None
    assert lines[1]["account_name"] == "ضريبة مدخلة"
    assert "لم يُعثر" in d["warnings"][0]


def test_shape_for_read_document_failure_case():
    """_shape_for_read_document يُرجِع error عند فشل الاستخراج."""
    from app.pilot.routes.ai_routes import _shape_for_read_document

    class FakeEntity:
        id = "e1"

    raw = {"success": False, "reason": "الصورة مشوَّشة"}
    out = _shape_for_read_document(None, FakeEntity(), raw)
    assert out["success"] is False
    assert "مشوَّشة" in out["error"]
