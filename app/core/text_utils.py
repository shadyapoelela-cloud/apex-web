"""
APEX Platform — Shared Arabic Text Utilities
═══════════════════════════════════════════════════════════════
Consolidates duplicate _remove_diacritics() and _norm() helpers
used across sprint2, sprint3, sprint4 services.
"""

import re


def remove_diacritics(text: str) -> str:
    """Remove Arabic diacritics (tashkeel) for matching."""
    if not text:
        return ""
    return re.sub(
        r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E4\u06E7\u06E8\u06EA-\u06ED]',
        '', text,
    )


def normalize_arabic(text: str) -> str:
    """Normalize Arabic text: strip, lowercase, remove diacritics, unify letters, collapse whitespace."""
    if not text:
        return ""
    t = remove_diacritics(text.strip().lower())
    t = t.replace("\u0623", "\u0627").replace("\u0625", "\u0627").replace("\u0622", "\u0627")  # أإآ → ا
    t = t.replace("\u0649", "\u064a").replace("\u0629", "\u0647")  # ى → ي, ة → ه
    return re.sub(r"\s+", " ", t)
