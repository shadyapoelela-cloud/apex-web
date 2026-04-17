"""
APEX Platform — Centralized Error Messages (Arabic)
═══════════════════════════════════════════════════════════════
Single source of truth for user-facing error messages. Import
from here instead of repeating literal strings across services.

Usage:
    from app.core.error_messages import Errors
    return {"success": False, "error": Errors.INTERNAL}
"""

from __future__ import annotations


class Errors:
    """Arabic user-facing error messages."""

    # ── Generic ──
    INTERNAL = "خطأ داخلي في الخادم — حاول لاحقاً أو تواصل مع الدعم"
    BAD_REQUEST = "طلب غير صحيح"
    NOT_FOUND = "المورد المطلوب غير موجود"
    FORBIDDEN = "غير مصرَّح بالوصول إلى هذه العملية"

    # ── Auth ──
    INVALID_CREDENTIALS = "اسم المستخدم أو كلمة المرور غير صحيحة"
    ACCOUNT_SUSPENDED = "الحساب موقوف — تواصل مع الدعم"
    ACCOUNT_DEACTIVATED = "الحساب معطّل"
    USER_EXISTS = "اسم المستخدم أو البريد مسجل مسبقاً"
    TOKEN_EXPIRED = "انتهت صلاحية الجلسة — يرجى تسجيل الدخول مجدداً"
    TOKEN_INVALID = "جلسة غير صالحة"
    UNAUTHORIZED = "يجب تسجيل الدخول"

    # ── Password / 2FA ──
    PASSWORD_WEAK = "كلمة المرور ضعيفة — يجب أن تحتوي على 8 أحرف وحرف كبير ورقم ورمز"
    OTP_INVALID = "رمز التحقق غير صحيح"
    OTP_EXPIRED = "انتهت صلاحية رمز التحقق"

    # ── Registration ──
    SCHEMA_UPDATE_REQUIRED = (
        "تعذّر حفظ الحساب. قد تحتاج قاعدة البيانات إلى تحديث الـ schema. "
        "تواصل مع الدعم."
    )

    # ── Lockout ──
    @staticmethod
    def account_locked(minutes_remaining: int) -> str:
        return f"الحساب مقفل — حاول بعد {minutes_remaining} دقيقة"

    # ── Validation ──
    FIELD_REQUIRED = "هذا الحقل مطلوب"
    INVALID_EMAIL = "البريد الإلكتروني غير صحيح"
    INVALID_PHONE = "رقم الجوال غير صحيح"

    # ── Business logic ──
    ENTRY_NOT_BALANCED = "القيد غير متوازن — مجموع المدين يجب أن يساوي مجموع الدائن"
    INSUFFICIENT_BALANCE = "الرصيد غير كافٍ"
    DUPLICATE_RECORD = "السجل موجود مسبقاً"
    PERIOD_LOCKED = "هذه الفترة المحاسبية مقفلة — لا يمكن التعديل"
