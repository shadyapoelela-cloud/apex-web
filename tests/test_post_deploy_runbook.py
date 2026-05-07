"""G-OPS-RUNBOOK — unit tests for `scripts/dev/post_deploy_runbook.py`.

The runbook makes real HTTP calls when invoked normally, which is
the wrong shape for a test suite — these tests stub `http_request`
so we exercise the orchestration logic (success / skip / fail
return values, exit codes, summary printout) without hitting any
network.

Importing the script
--------------------
The file lives in `scripts/dev/`, which isn't on the package
import path. We load it through `importlib` once at module level
so every test class shares the same `runbook` reference (cheaper
than re-loading per test, and lets `unittest.mock.patch` target a
stable attribute path).
"""

from __future__ import annotations

import importlib.util
import os
import sys
from pathlib import Path
from unittest.mock import patch

import pytest


# ────────────────────────────────────────────────────────────────────
# Load the runbook script as a regular module
# ────────────────────────────────────────────────────────────────────


_SCRIPT = (
    Path(__file__).resolve().parents[1]
    / "scripts"
    / "dev"
    / "post_deploy_runbook.py"
)


def _load_runbook():
    spec = importlib.util.spec_from_file_location(
        "post_deploy_runbook", _SCRIPT
    )
    assert spec and spec.loader, f"Could not locate {_SCRIPT}"
    mod = importlib.util.module_from_spec(spec)
    sys.modules["post_deploy_runbook"] = mod
    spec.loader.exec_module(mod)
    return mod


runbook = _load_runbook()


# ────────────────────────────────────────────────────────────────────
# Helpers — standard fake response payloads we'll reuse
# ────────────────────────────────────────────────────────────────────


def _bundle_with_all_sentinels() -> str:
    """Big enough to look like a real bundle and containing every
    sentinel string the verifier scans for. Pad with junk so the
    "size in MB" log line is non-trivial and the substring search
    actually has to scan."""
    pad = "x" * 100_000
    return (
        pad
        + "erp/finance/receipt-capture"
        + pad
        + "erp/finance/vat-return"
        + pad
        + "apexAuthRefresh"
        + pad
        + "seed-demo-data"
        + pad
    )


def _bundle_missing_two_sentinels() -> str:
    """Has only 2 of 4 sentinels — exercises the warning branch."""
    pad = "x" * 100_000
    return (
        pad
        + "erp/finance/receipt-capture"
        + pad
        + "apexAuthRefresh"
        + pad
    )


# ────────────────────────────────────────────────────────────────────
# step_verify_deploy
# ────────────────────────────────────────────────────────────────────


class TestVerifyDeploy:
    def test_passes_when_all_sentinels_present(self):
        with patch.object(
            runbook,
            "http_request",
            return_value=(200, _bundle_with_all_sentinels()),
        ):
            assert runbook.step_verify_deploy("http://api") is True

    def test_passes_with_warning_when_some_sentinels_missing(self):
        # Missing sentinels are a WARNING, not a failure — the script
        # might be pointed at staging or a custom build that didn't
        # include the latest PRs yet. Still returns True.
        with patch.object(
            runbook,
            "http_request",
            return_value=(200, _bundle_missing_two_sentinels()),
        ):
            assert runbook.step_verify_deploy("http://api") is True

    def test_fails_on_404(self):
        with patch.object(
            runbook,
            "http_request",
            return_value=(404, "Not Found"),
        ):
            assert runbook.step_verify_deploy("http://api") is False

    def test_fails_on_unexpected_json_response(self):
        # main.dart.js should never come back as JSON; if it does
        # something is very wrong with whatever proxy is in front.
        with patch.object(
            runbook,
            "http_request",
            return_value=(200, {"error": "wrong"}),
        ):
            assert runbook.step_verify_deploy("http://api") is False

    def test_fails_when_http_request_raises(self):
        # Network-level failures bubble up out of urllib; the step
        # wrapper must catch and convert to False.
        with patch.object(
            runbook,
            "http_request",
            side_effect=ConnectionError("DNS failure"),
        ):
            assert runbook.step_verify_deploy("http://api") is False


# ────────────────────────────────────────────────────────────────────
# step_login
# ────────────────────────────────────────────────────────────────────


class TestLogin:
    def test_returns_token_from_legacy_shape(self):
        with patch.object(
            runbook,
            "http_request",
            return_value=(200, {"token": "jwt_legacy"}),
        ):
            assert (
                runbook.step_login("http://api", "u", "p") == "jwt_legacy"
            )

    def test_returns_token_from_current_tokens_shape(self):
        # auth_service.login() returns {tokens: {access_token: ...}}.
        with patch.object(
            runbook,
            "http_request",
            return_value=(
                200,
                {"tokens": {"access_token": "jwt_current"}},
            ),
        ):
            assert (
                runbook.step_login("http://api", "u", "p")
                == "jwt_current"
            )

    def test_returns_none_on_401(self):
        with patch.object(
            runbook,
            "http_request",
            return_value=(401, {"detail": "invalid credentials"}),
        ):
            assert runbook.step_login("http://api", "u", "wrong") is None

    def test_returns_none_when_response_has_no_token_field(self):
        with patch.object(
            runbook,
            "http_request",
            return_value=(200, {"user": {"id": "u1"}}),
        ):
            assert runbook.step_login("http://api", "u", "p") is None


# ────────────────────────────────────────────────────────────────────
# step_migrate_legacy
# ────────────────────────────────────────────────────────────────────


class TestMigrateLegacy:
    def test_skips_when_no_secret_returns_true(self):
        # SKIP is not a failure — runbook doesn't require ADMIN_SECRET
        # to be present on every box.
        with patch.object(runbook, "http_request") as mock:
            assert runbook.step_migrate_legacy("http://api", "") is True
            mock.assert_not_called()

    def test_passes_on_success_response(self):
        with patch.object(
            runbook,
            "http_request",
            return_value=(
                200,
                {
                    "success": True,
                    "data": {
                        "total_legacy": 3,
                        "migrated": 3,
                        "failed": 0,
                        "details": [],
                        "failures": [],
                    },
                },
            ),
        ):
            assert (
                runbook.step_migrate_legacy("http://api", "secret")
                is True
            )

    def test_fails_on_403(self):
        with patch.object(
            runbook,
            "http_request",
            return_value=(403, {"detail": "Invalid admin secret"}),
        ):
            assert (
                runbook.step_migrate_legacy("http://api", "wrong-secret")
                is False
            )

    def test_fails_on_unexpected_response_shape(self):
        with patch.object(
            runbook,
            "http_request",
            return_value=(200, "not-a-dict"),
        ):
            assert (
                runbook.step_migrate_legacy("http://api", "secret")
                is False
            )


# ────────────────────────────────────────────────────────────────────
# step_seed_demo
# ────────────────────────────────────────────────────────────────────


class TestSeedDemo:
    def test_passes_when_seeded_with_master_data(self):
        with patch.object(
            runbook,
            "http_request",
            return_value=(
                200,
                {
                    "success": True,
                    "data": {
                        "skipped": False,
                        "summary": {
                            "master_data": {
                                "customers": 5,
                                "vendors": 5,
                                "products": 15,
                            },
                            "deferred": {
                                "_note": "GL + invoice deferred to V2"
                            },
                        },
                    },
                },
            ),
        ):
            assert (
                runbook.step_seed_demo("http://api", "jwt") is True
            )

    def test_passes_when_skipped_idempotency_path(self):
        # `skipped` is the expected response on a re-run — the
        # tenant already has data. The runbook treats this as
        # success, not failure.
        with patch.object(
            runbook,
            "http_request",
            return_value=(
                200,
                {
                    "success": True,
                    "data": {
                        "skipped": True,
                        "reason": "Tenant already has seeded master data.",
                    },
                },
            ),
        ):
            assert (
                runbook.step_seed_demo("http://api", "jwt") is True
            )

    def test_fails_on_400_legacy_token(self):
        # A JWT without the ERR-2 tenant_id claim hits this 400.
        with patch.object(
            runbook,
            "http_request",
            return_value=(
                400,
                {"detail": "Your account has no tenant_id…"},
            ),
        ):
            assert (
                runbook.step_seed_demo("http://api", "jwt") is False
            )

    def test_force_flag_threads_through_to_query_string(self):
        captured: dict = {}

        def _capture(method, url, **kwargs):
            captured["url"] = url
            return (
                200,
                {
                    "success": True,
                    "data": {
                        "skipped": False,
                        "summary": {
                            "master_data": {
                                "customers": 5,
                                "vendors": 5,
                                "products": 15,
                            }
                        },
                    },
                },
            )

        with patch.object(runbook, "http_request", side_effect=_capture):
            runbook.step_seed_demo("http://api", "jwt", force=True)
        assert "force=true" in captured["url"]


# ────────────────────────────────────────────────────────────────────
# step_smoke_test
# ────────────────────────────────────────────────────────────────────


class TestSmokeTest:
    def test_passes_when_all_endpoints_return_200(self):
        with patch.object(
            runbook,
            "http_request",
            return_value=(200, {"ok": True}),
        ):
            assert (
                runbook.step_smoke_test("http://api", "jwt") is True
            )

    def test_passes_when_authenticated_endpoints_return_404(self):
        # Profile / widgets returning 404 is acceptable in the
        # smoke test — the user might not have those wired yet.
        # Only 5xx fails the step.
        responses = iter(
            [
                (200, "ok"),
                (200, "ok"),
                (404, {}),
                (404, {}),
            ]
        )
        with patch.object(
            runbook,
            "http_request",
            side_effect=lambda *a, **kw: next(responses),
        ):
            assert (
                runbook.step_smoke_test("http://api", "jwt") is True
            )

    def test_fails_on_5xx(self):
        with patch.object(
            runbook,
            "http_request",
            return_value=(500, "internal error"),
        ):
            assert (
                runbook.step_smoke_test("http://api", "jwt") is False
            )

    def test_fails_on_network_exception(self):
        with patch.object(
            runbook,
            "http_request",
            side_effect=ConnectionError("DNS failure"),
        ):
            assert (
                runbook.step_smoke_test("http://api", "jwt") is False
            )

    def test_skips_authenticated_checks_when_no_jwt(self):
        called = []

        def _capture(method, url, **kwargs):
            called.append(url)
            return (200, "ok")

        with patch.object(
            runbook, "http_request", side_effect=_capture
        ):
            runbook.step_smoke_test("http://api", None)
        # Without a JWT, only the 2 anonymous endpoints get hit.
        assert len(called) == 2
        # And neither of them is the profile or widgets endpoint.
        assert not any("profile" in u for u in called)
        assert not any("dashboard/widgets" in u for u in called)


# ────────────────────────────────────────────────────────────────────
# main() — overall orchestration + exit code
# ────────────────────────────────────────────────────────────────────


class TestMain:
    def test_default_invocation_implies_all_with_clean_run(self):
        # No CLI flags → --all is implied. With every step mocked to
        # succeed, main() should exit 0.
        with patch.object(
            runbook, "step_verify_deploy", return_value=True
        ), patch.object(
            runbook, "step_migrate_legacy", return_value=True
        ), patch.object(
            runbook, "step_seed_demo", return_value=True
        ), patch.object(
            runbook, "step_smoke_test", return_value=True
        ), patch.object(
            runbook, "step_login", return_value="fake-jwt"
        ):
            # Provide creds via argv so main() doesn't prompt.
            rc = runbook.main(
                [
                    "--username",
                    "alice",
                    "--password",
                    "p",
                    "--admin-secret",
                    "s",
                ]
            )
        assert rc == 0

    def test_returns_1_when_a_step_fails(self):
        with patch.object(
            runbook, "step_verify_deploy", return_value=False
        ), patch.object(
            runbook, "step_migrate_legacy", return_value=True
        ), patch.object(
            runbook, "step_seed_demo", return_value=True
        ), patch.object(
            runbook, "step_smoke_test", return_value=True
        ), patch.object(
            runbook, "step_login", return_value="fake-jwt"
        ):
            rc = runbook.main(
                [
                    "--username",
                    "alice",
                    "--password",
                    "p",
                    "--admin-secret",
                    "s",
                ]
            )
        assert rc == 1

    def test_verify_only_flag_skips_other_steps(self):
        called = {
            "verify": False,
            "migrate": False,
            "seed": False,
            "smoke": False,
        }

        def _verify(*a, **kw):
            called["verify"] = True
            return True

        def _migrate(*a, **kw):
            called["migrate"] = True
            return True

        def _seed(*a, **kw):
            called["seed"] = True
            return True

        def _smoke(*a, **kw):
            called["smoke"] = True
            return True

        with patch.object(
            runbook, "step_verify_deploy", side_effect=_verify
        ), patch.object(
            runbook, "step_migrate_legacy", side_effect=_migrate
        ), patch.object(
            runbook, "step_seed_demo", side_effect=_seed
        ), patch.object(
            runbook, "step_smoke_test", side_effect=_smoke
        ):
            rc = runbook.main(["--verify-deploy"])
        assert rc == 0
        assert called == {
            "verify": True,
            "migrate": False,
            "seed": False,
            "smoke": False,
        }

    def test_seed_demo_aborts_when_login_fails(self):
        # Without a JWT, `--seed-demo` cannot proceed — main() must
        # exit 1 rather than silently skipping the step.
        with patch.object(runbook, "step_login", return_value=None):
            rc = runbook.main(
                [
                    "--seed-demo",
                    "--username",
                    "alice",
                    "--password",
                    "wrong",
                ]
            )
        assert rc == 1
