"""
APEX Platform — Input Validators
═══════════════════════════════════════════════════════════════
Centralized validation utilities for:
  • Saudi-specific formats (CR, VAT TIN, IBAN, mobile)
  • Financial amount validation
  • Date range validation
  • String sanitization
"""

from __future__ import annotations

import re
from decimal import Decimal, InvalidOperation
from typing import Optional


# Saudi Commercial Registration: 10 digits starting with 10/40/70
_CR_PATTERN = re.compile(r"^[147]0\d{8}$")

# Saudi VAT TIN: 15 digits starting with 3, ending with 3
_VAT_TIN_PATTERN = re.compile(r"^3\d{13}3$")

# Saudi IBAN: SA followed by 22 digits
_IBAN_PATTERN = re.compile(r"^SA\d{22}$")

# Saudi mobile: +966 5XXXXXXXX
_MOBILE_PATTERN = re.compile(r"^\+?966\s?5\d{8}$")

# Email
_EMAIL_PATTERN = re.compile(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")


def validate_saudi_cr(cr: str) -> Optional[str]:
    """Validate Saudi Commercial Registration number."""
    cr = cr.strip()
    if not _CR_PATTERN.match(cr):
        return "رقم السجل التجاري غير صالح (يجب أن يبدأ بـ 10/40/70 ويتكون من 10 أرقام)"
    return None


def validate_vat_tin(tin: str) -> Optional[str]:
    """Validate Saudi VAT TIN (15 digits, starts/ends with 3)."""
    tin = tin.strip()
    if not _VAT_TIN_PATTERN.match(tin):
        return "الرقم الضريبي غير صالح (يجب أن يبدأ وينتهي بـ 3 ويتكون من 15 رقماً)"
    return None


def validate_saudi_iban(iban: str) -> Optional[str]:
    """Validate Saudi IBAN format."""
    iban = iban.strip().upper().replace(" ", "")
    if not _IBAN_PATTERN.match(iban):
        return "رقم الآيبان غير صالح (يبدأ بـ SA متبوعاً بـ 22 رقماً)"
    return None


def validate_saudi_mobile(mobile: str) -> Optional[str]:
    """Validate Saudi mobile number."""
    mobile = mobile.strip().replace(" ", "").replace("-", "")
    if not _MOBILE_PATTERN.match(mobile):
        return "رقم الجوال غير صالح (يجب أن يبدأ بـ +966 5 ويتكون من 9 أرقام)"
    return None


def validate_email(email: str) -> Optional[str]:
    """Validate email format."""
    if not _EMAIL_PATTERN.match(email.strip()):
        return "البريد الإلكتروني غير صالح"
    return None


def validate_amount(value: str, field_name: str = "المبلغ",
                    min_val: Optional[Decimal] = None,
                    max_val: Optional[Decimal] = None) -> Optional[str]:
    """Validate a financial amount string."""
    try:
        d = Decimal(str(value).strip())
    except (InvalidOperation, ValueError):
        return f"{field_name}: قيمة غير رقمية"

    if d.is_nan() or d.is_infinite():
        return f"{field_name}: قيمة غير صالحة"

    if min_val is not None and d < min_val:
        return f"{field_name}: يجب أن يكون أكبر من أو يساوي {min_val}"

    if max_val is not None and d > max_val:
        return f"{field_name}: يجب أن يكون أقل من أو يساوي {max_val}"

    return None


def validate_date_range(start: str, end: str) -> Optional[str]:
    """Validate that start <= end in YYYY-MM-DD format."""
    date_pattern = re.compile(r"^\d{4}-\d{2}-\d{2}$")
    if not date_pattern.match(start):
        return "تاريخ البداية غير صالح (YYYY-MM-DD)"
    if not date_pattern.match(end):
        return "تاريخ النهاية غير صالح (YYYY-MM-DD)"
    if start > end:
        return "تاريخ البداية يجب أن يكون قبل تاريخ النهاية"
    return None


def sanitize_string(s: str, max_length: int = 500) -> str:
    """Strip dangerous characters and enforce length."""
    s = s.strip()
    # Remove null bytes
    s = s.replace("\x00", "")
    # Truncate
    if len(s) > max_length:
        s = s[:max_length]
    return s


def validate_fiscal_year(year: str) -> Optional[str]:
    """Validate fiscal year format (YYYY or YYYY-YYYY)."""
    single = re.compile(r"^\d{4}$")
    range_pat = re.compile(r"^\d{4}-\d{4}$")
    if single.match(year):
        y = int(year)
        if y < 2000 or y > 2100:
            return "السنة المالية خارج النطاق المقبول"
        return None
    if range_pat.match(year):
        parts = year.split("-")
        if int(parts[0]) >= int(parts[1]):
            return "نطاق السنة المالية غير صالح"
        return None
    return "صيغة السنة المالية غير صالحة (YYYY أو YYYY-YYYY)"
