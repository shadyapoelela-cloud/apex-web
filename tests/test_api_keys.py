"""APEX Platform -- app/core/api_keys.py unit tests.

Coverage target: ≥90% of 166 statements (G-T1.7b.3, Sprint 10).

HMAC + JSON-file persistence + ApiKey dataclass CRUD. Pure stdlib —
no external deps. We exercise:

  * `_load`, `_save` — empty, valid file, malformed JSON.
  * `_hash_secret`, `_generate_key` — deterministic / format checks.
  * `create_key` — happy + name validation + rate_limit validation.
  * `list_keys` — every filter (tenant_id, owner_user_id, include_revoked).
  * `get_key` — found / not found.
  * `revoke_key` — happy, already-revoked, missing.
  * `update_key_meta` — every field branch + rate_limit bounds +
    enabled-after-revoke guard + missing key.
  * `verify_key` — every reason branch: not_found (no apex_ prefix /
    wrong hash), revoked, disabled, expired, malformed expires_at,
    ip_not_allowed, ok (audit fields bumped).
  * `has_scope` — empty, exact, wildcard "*", namespace wildcard.
  * `stats` — counts.

Filesystem isolation: `_PATH = tmp_path / "api_keys.json"`; `_STORE`
reset between tests via fixture. No external mocks needed.
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone

import pytest

from app.core import api_keys as ak


# ══════════════════════════════════════════════════════════════
# Fixtures
# ══════════════════════════════════════════════════════════════


@pytest.fixture
def isolated(tmp_path, monkeypatch):
    """Redirect persistence to tmp_path + reset _STORE between tests."""
    p = tmp_path / "api_keys.json"
    monkeypatch.setattr(ak, "_PATH", str(p))
    monkeypatch.setattr(ak, "_STORE", {})
    return p


# ══════════════════════════════════════════════════════════════
# _load / _save persistence
# ══════════════════════════════════════════════════════════════


class TestPersistence:
    def test_load_no_file_starts_empty(self, isolated):
        ak._load()
        assert ak._STORE == {}

    def test_load_valid_file(self, isolated):
        rec = {
            "id": "k1", "name": "Test", "prefix": "apex_abc",
            "hashed_secret": "h", "scopes": ["read:invoices"],
        }
        isolated.write_text(
            json.dumps({"version": 1, "keys": [rec]}), encoding="utf-8"
        )
        ak._load()
        assert "k1" in ak._STORE
        assert ak._STORE["k1"].name == "Test"
        assert ak._STORE["k1"].scopes == ["read:invoices"]

    def test_load_malformed_json_falls_back_to_empty(self, isolated):
        isolated.write_text("{not valid", encoding="utf-8")
        ak._load()
        assert ak._STORE == {}

    def test_save_after_create_writes_file(self, isolated):
        ak.create_key(name="My Key")
        assert isolated.exists()
        raw = json.loads(isolated.read_text(encoding="utf-8"))
        assert raw["version"] == 1
        assert len(raw["keys"]) == 1


# ══════════════════════════════════════════════════════════════
# _hash_secret / _generate_key
# ══════════════════════════════════════════════════════════════


class TestHashing:
    def test_hash_secret_is_deterministic(self):
        assert ak._hash_secret("foo") == ak._hash_secret("foo")
        assert ak._hash_secret("foo") != ak._hash_secret("bar")
        # SHA-256 hex is 64 chars.
        assert len(ak._hash_secret("any")) == 64

    def test_generate_key_format(self):
        raw, prefix, hashed = ak._generate_key()
        assert raw.startswith("apex_")
        assert raw.count("_") >= 2  # apex_<prefix-8>_<secret-32>
        assert prefix == raw[:13]
        assert hashed == ak._hash_secret(raw)


# ══════════════════════════════════════════════════════════════
# create_key
# ══════════════════════════════════════════════════════════════


class TestCreateKey:
    def test_happy_path_returns_key_and_raw(self, isolated):
        key, raw = ak.create_key(
            name="Test API Key", scopes=["read:invoices", "write:journal"],
            tenant_id="t1", owner_user_id="u1",
            description="Production API",
            allowed_ips=["10.0.0.1"], rate_limit_per_minute=120,
        )
        assert key.id  # uuid set
        assert key.name == "Test API Key"
        assert key.prefix.startswith("apex_")
        assert key.hashed_secret == ak._hash_secret(raw)
        assert key.scopes == ["read:invoices", "write:journal"]
        assert key.tenant_id == "t1"
        assert key.owner_user_id == "u1"
        assert key.allowed_ips == ["10.0.0.1"]
        assert key.rate_limit_per_minute == 120
        # Raw is shown ONCE — must start with apex_
        assert raw.startswith("apex_")
        assert key.id in ak._STORE

    def test_name_required(self, isolated):
        with pytest.raises(ValueError, match="name is required"):
            ak.create_key(name="   ")
        with pytest.raises(ValueError, match="name is required"):
            ak.create_key(name="")

    def test_rate_limit_validated(self, isolated):
        with pytest.raises(ValueError, match="rate_limit_per_minute"):
            ak.create_key(name="X", rate_limit_per_minute=0)
        with pytest.raises(ValueError, match="rate_limit_per_minute"):
            ak.create_key(name="X", rate_limit_per_minute=10000)

    def test_name_is_stripped(self, isolated):
        key, _ = ak.create_key(name="  Padded Name  ")
        assert key.name == "Padded Name"


# ══════════════════════════════════════════════════════════════
# list_keys / get_key
# ══════════════════════════════════════════════════════════════


class TestListKeys:
    def test_filters_by_tenant_and_owner(self, isolated):
        ak.create_key(name="A", tenant_id="t1", owner_user_id="u1")
        ak.create_key(name="B", tenant_id="t1", owner_user_id="u2")
        ak.create_key(name="C", tenant_id="t2", owner_user_id="u1")
        # By tenant.
        names_t1 = {k.name for k in ak.list_keys(tenant_id="t1")}
        assert names_t1 == {"A", "B"}
        # By owner.
        names_u1 = {k.name for k in ak.list_keys(owner_user_id="u1")}
        assert names_u1 == {"A", "C"}
        # Both.
        names_t1_u1 = {k.name for k in ak.list_keys(
            tenant_id="t1", owner_user_id="u1"
        )}
        assert names_t1_u1 == {"A"}

    def test_excludes_revoked_by_default(self, isolated):
        k1, _ = ak.create_key(name="Active")
        k2, _ = ak.create_key(name="Revoked")
        ak.revoke_key(k2.id, reason="bye")
        active_only = ak.list_keys()
        assert len(active_only) == 1
        assert active_only[0].name == "Active"

    def test_include_revoked_returns_all(self, isolated):
        k1, _ = ak.create_key(name="A")
        k2, _ = ak.create_key(name="B")
        ak.revoke_key(k2.id)
        all_keys = ak.list_keys(include_revoked=True)
        assert len(all_keys) == 2

    def test_get_key_found_and_missing(self, isolated):
        k, _ = ak.create_key(name="X")
        assert ak.get_key(k.id) is k
        assert ak.get_key("nonexistent") is None


# ══════════════════════════════════════════════════════════════
# revoke_key
# ══════════════════════════════════════════════════════════════


class TestRevokeKey:
    def test_happy_path(self, isolated):
        k, _ = ak.create_key(name="X")
        assert ak.revoke_key(k.id, reason="compromised") is True
        rec = ak.get_key(k.id)
        assert rec.enabled is False
        assert rec.revoked_at is not None
        assert rec.revoked_reason == "compromised"

    def test_already_revoked_returns_false(self, isolated):
        k, _ = ak.create_key(name="X")
        assert ak.revoke_key(k.id) is True
        assert ak.revoke_key(k.id) is False

    def test_missing_returns_false(self, isolated):
        assert ak.revoke_key("nope") is False


# ══════════════════════════════════════════════════════════════
# update_key_meta
# ══════════════════════════════════════════════════════════════


class TestUpdateKeyMeta:
    def test_updates_simple_fields(self, isolated):
        k, _ = ak.create_key(name="Old", description="d", scopes=[])
        u = ak.update_key_meta(
            k.id,
            name="New", description="new desc",
            scopes=["read:invoices"],
            expires_at="2030-01-01T00:00:00+00:00",
            allowed_ips=["1.1.1.1"],
            rate_limit_per_minute=300,
        )
        assert u is not None
        assert u.name == "New"
        assert u.description == "new desc"
        assert u.scopes == ["read:invoices"]
        assert u.expires_at == "2030-01-01T00:00:00+00:00"
        assert u.allowed_ips == ["1.1.1.1"]
        assert u.rate_limit_per_minute == 300

    def test_enabled_can_be_turned_off(self, isolated):
        k, _ = ak.create_key(name="X")
        ak.update_key_meta(k.id, enabled=False)
        assert ak.get_key(k.id).enabled is False

    def test_cannot_undo_revocation_via_enabled_true(self, isolated):
        k, _ = ak.create_key(name="X")
        ak.revoke_key(k.id)
        ak.update_key_meta(k.id, enabled=True)
        # Should remain revoked + disabled.
        rec = ak.get_key(k.id)
        assert rec.revoked_at is not None
        assert rec.enabled is False

    def test_invalid_rate_limit_silently_ignored(self, isolated):
        k, _ = ak.create_key(name="X", rate_limit_per_minute=60)
        ak.update_key_meta(k.id, rate_limit_per_minute=0)  # invalid
        ak.update_key_meta(k.id, rate_limit_per_minute=10000)  # invalid
        assert ak.get_key(k.id).rate_limit_per_minute == 60  # unchanged

    def test_returns_none_for_missing_key(self, isolated):
        assert ak.update_key_meta("nope", name="X") is None


# ══════════════════════════════════════════════════════════════
# verify_key — every reason branch
# ══════════════════════════════════════════════════════════════


class TestVerifyKey:
    def test_no_apex_prefix_not_found(self, isolated):
        rec, reason = ak.verify_key("not-an-apex-key")
        assert rec is None
        assert reason == "not_found"

    def test_empty_string_not_found(self, isolated):
        rec, reason = ak.verify_key("")
        assert rec is None
        assert reason == "not_found"

    def test_unknown_hash_not_found(self, isolated):
        ak.create_key(name="X")
        rec, reason = ak.verify_key("apex_fake_unknown_string")
        assert rec is None
        assert reason == "not_found"

    def test_happy_path_bumps_audit_fields(self, isolated):
        key, raw = ak.create_key(name="X")
        before = key.use_count
        rec, reason = ak.verify_key(raw)
        assert reason == "ok"
        assert rec is key
        # use_count incremented + last_used_at set.
        assert rec.use_count == before + 1
        assert rec.last_used_at is not None

    def test_revoked_returns_revoked_reason(self, isolated):
        key, raw = ak.create_key(name="X")
        ak.revoke_key(key.id)
        rec, reason = ak.verify_key(raw)
        assert rec is None
        assert reason == "revoked"

    def test_disabled_returns_disabled_reason(self, isolated):
        key, raw = ak.create_key(name="X")
        ak.update_key_meta(key.id, enabled=False)
        rec, reason = ak.verify_key(raw)
        assert rec is None
        assert reason == "disabled"

    def test_expired_returns_expired_reason(self, isolated):
        key, raw = ak.create_key(name="X")
        past = (datetime.now(timezone.utc) - timedelta(days=1)).isoformat()
        ak.update_key_meta(key.id, expires_at=past)
        rec, reason = ak.verify_key(raw)
        assert rec is None
        assert reason == "expired"

    def test_future_expiry_passes(self, isolated):
        key, raw = ak.create_key(name="X")
        future = (datetime.now(timezone.utc) + timedelta(days=365)).isoformat()
        ak.update_key_meta(key.id, expires_at=future)
        rec, reason = ak.verify_key(raw)
        assert reason == "ok"

    def test_malformed_expires_at_treated_as_no_expiry(self, isolated):
        """The except path at line 282-283 swallows the parse error
        and lets verification proceed — defensive."""
        key, raw = ak.create_key(name="X")
        ak.update_key_meta(key.id, expires_at="not-a-date")
        rec, reason = ak.verify_key(raw)
        assert reason == "ok"

    def test_ip_not_allowed(self, isolated):
        key, raw = ak.create_key(name="X", allowed_ips=["10.0.0.1"])
        rec, reason = ak.verify_key(raw, request_ip="192.168.0.1")
        assert rec is None
        assert reason == "ip_not_allowed"

    def test_ip_allowed_passes(self, isolated):
        key, raw = ak.create_key(name="X", allowed_ips=["10.0.0.1"])
        rec, reason = ak.verify_key(raw, request_ip="10.0.0.1")
        assert reason == "ok"

    def test_no_ip_restriction_skips_ip_check(self, isolated):
        key, raw = ak.create_key(name="X")  # allowed_ips=[] (any)
        rec, reason = ak.verify_key(raw, request_ip="1.2.3.4")
        assert reason == "ok"


# ══════════════════════════════════════════════════════════════
# has_scope
# ══════════════════════════════════════════════════════════════


class TestHasScope:
    def _key(self, scopes):
        return ak.ApiKey(
            id="k", name="n", prefix="p", hashed_secret="h", scopes=scopes,
        )

    def test_empty_scopes_returns_false(self):
        assert ak.has_scope(self._key([]), "read:invoices") is False

    def test_exact_match(self):
        k = self._key(["read:invoices", "write:journal"])
        assert ak.has_scope(k, "read:invoices") is True
        assert ak.has_scope(k, "admin:approvals") is False

    def test_super_wildcard_grants_everything(self):
        assert ak.has_scope(self._key(["*"]), "anything:here") is True

    def test_namespace_wildcard(self):
        k = self._key(["admin:*"])
        assert ak.has_scope(k, "admin:approvals") is True
        assert ak.has_scope(k, "admin:users") is True
        assert ak.has_scope(k, "read:invoices") is False


# ══════════════════════════════════════════════════════════════
# stats
# ══════════════════════════════════════════════════════════════


class TestStats:
    def test_counts_active_revoked_disabled(self, isolated):
        k1, _ = ak.create_key(name="A")  # active
        k2, _ = ak.create_key(name="B")
        ak.revoke_key(k2.id)             # revoked
        k3, _ = ak.create_key(name="C")
        ak.update_key_meta(k3.id, enabled=False)  # disabled (not revoked)
        s = ak.stats()
        assert s["keys_total"] == 3
        assert s["keys_active"] == 1
        assert s["keys_revoked"] == 1
        assert s["keys_disabled"] == 1
        assert "storage_path" in s
