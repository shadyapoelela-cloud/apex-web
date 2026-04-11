"""
APEX Platform -- Unit tests for utility modules
"""

from datetime import datetime, timezone


def test_remove_diacritics_strips_arabic_diacritics():
    from app.core.text_utils import remove_diacritics

    # Arabic text with diacritics (fatha, kasra, damma, shadda, sukun)
    text_with_diacritics = "\u0645\u064f\u062d\u064e\u0645\u0651\u064e\u062f\u064c"  # محمد with tashkeel
    result = remove_diacritics(text_with_diacritics)
    assert "\u064f" not in result  # damma removed
    assert "\u064e" not in result  # fatha removed
    assert "\u0651" not in result  # shadda removed
    assert "\u064c" not in result  # tanwin removed
    assert "\u0645" in result  # base letter preserved
    assert "\u062d" in result  # base letter preserved


def test_remove_diacritics_empty_string():
    from app.core.text_utils import remove_diacritics

    assert remove_diacritics("") == ""
    assert remove_diacritics(None) == ""


def test_normalize_arabic_unifies_letters():
    from app.core.text_utils import normalize_arabic

    # alef variants should all become plain alef
    assert "\u0627" in normalize_arabic("\u0623")  # hamza above -> alef
    assert "\u0627" in normalize_arabic("\u0625")  # hamza below -> alef
    assert "\u0627" in normalize_arabic("\u0622")  # madda -> alef


def test_normalize_arabic_collapses_whitespace():
    from app.core.text_utils import normalize_arabic

    assert normalize_arabic("  hello   world  ") == "hello world"


def test_normalize_arabic_empty_string():
    from app.core.text_utils import normalize_arabic

    assert normalize_arabic("") == ""
    assert normalize_arabic(None) == ""


def test_utc_now_returns_aware_datetime():
    from app.core.db_utils import utc_now

    now = utc_now()
    assert isinstance(now, datetime)
    assert now.tzinfo is not None
    assert now.tzinfo == timezone.utc


def test_utc_now_iso_returns_iso_string():
    from app.core.db_utils import utc_now_iso

    iso = utc_now_iso()
    assert isinstance(iso, str)
    # Should be parseable as ISO datetime
    parsed = datetime.fromisoformat(iso)
    assert parsed.tzinfo is not None
