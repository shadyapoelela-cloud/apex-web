"""G-S1 — bcrypt rounds bump (10 -> 12) + opportunistic rehash on login."""
from __future__ import annotations

import bcrypt as _bcrypt

from app.phase1.services.auth_service import (
    BCRYPT_ROUNDS,
    hash_password,
    password_needs_rehash,
    verify_password,
)


def _hash_at(rounds: int, password: str) -> str:
    return _bcrypt.hashpw(password.encode(), _bcrypt.gensalt(rounds=rounds)).decode()


def _cost_of(bcrypt_hash: str) -> int:
    return int(bcrypt_hash.split("$", 3)[2])


def test_constant_is_twelve():
    assert BCRYPT_ROUNDS == 12


def test_new_hash_uses_target_rounds():
    h = hash_password("Aa@123456")
    assert h.startswith("$2")
    assert _cost_of(h) == BCRYPT_ROUNDS


def test_verify_works_for_modern_hash():
    h = hash_password("Aa@123456")
    assert verify_password("Aa@123456", h) is True
    assert verify_password("wrong", h) is False


def test_verify_works_for_legacy_10_round_hash():
    legacy = _hash_at(10, "Aa@123456")
    assert verify_password("Aa@123456", legacy) is True


def test_needs_rehash_for_lower_cost():
    legacy_10 = _hash_at(10, "x")
    legacy_11 = _hash_at(11, "x")
    current_12 = _hash_at(BCRYPT_ROUNDS, "x")

    assert password_needs_rehash(legacy_10) is True
    assert password_needs_rehash(legacy_11) is True
    assert password_needs_rehash(current_12) is False


def test_needs_rehash_for_sha256_legacy_fallback():
    # Format: <salt>$<sha256> — produced by the pre-bcrypt path in hash_password().
    sha_hash = "deadbeef$" + ("a" * 64)
    assert password_needs_rehash(sha_hash) is True


def test_needs_rehash_for_empty_or_garbage():
    assert password_needs_rehash("") is False
    assert password_needs_rehash("$2b$") is False
    assert password_needs_rehash("$2b$xx$abc") is False
