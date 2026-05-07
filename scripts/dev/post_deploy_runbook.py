#!/usr/bin/env python3
"""APEX post-deploy operations runbook.

After every merge to `main`, ops have to run a small handful of HTTP
calls to finish the rollout: verify the gh-pages bundle is current,
backfill tenants for users created before ERR-2 Phase 3 (PR #169),
seed the caller's tenant with demo data so dashboards aren't empty,
and smoke-test a couple of well-known endpoints. Each one was a
copy-pasted `curl` recipe in a different PR description before this
script existed; this consolidates them with structured output and a
single exit code.

Why this is a script and not a CI job:
  * `--seed-demo` writes into a real user's tenant. CI doesn't have
    a stable test account credentials.
  * `--migrate-legacy` is a one-shot per deploy, not per PR. Running
    on every CI invocation would spam the audit log.
  * Ops want to run it interactively against staging on demand.

Usage examples
--------------

    # Recommended after each merge (uses env vars where available,
    # prompts for whatever's missing):
    python3 scripts/dev/post_deploy_runbook.py --all

    # Just one step:
    python3 scripts/dev/post_deploy_runbook.py --verify-deploy
    python3 scripts/dev/post_deploy_runbook.py --migrate-legacy
    python3 scripts/dev/post_deploy_runbook.py --seed-demo
    python3 scripts/dev/post_deploy_runbook.py --smoke-test

    # Custom API base (e.g. staging):
    python3 scripts/dev/post_deploy_runbook.py --all \\
        --api https://apex-api-staging.example.com

Environment variables (each has a corresponding CLI flag too):
    APEX_API_URL    - default https://apex-api-ootk.onrender.com
    ADMIN_SECRET    - required for --migrate-legacy
    APEX_USERNAME   - prompted if missing
    APEX_PASSWORD   - prompted (silently) if missing

Stdlib only — no `requests` dep, so the script runs against the
same Python the rest of `scripts/dev/*.py` use without forcing
ops to install anything.
"""

from __future__ import annotations

import argparse
import getpass
import json
import os
import ssl
import sys
from typing import Any, Optional, Union
from urllib import error, request


# ────────────────────────────────────────────────────────────────────
# Config
# ────────────────────────────────────────────────────────────────────

DEFAULT_API: str = os.getenv(
    "APEX_API_URL", "https://apex-api-ootk.onrender.com"
)
DEFAULT_PAGES_URL: str = (
    "https://shadyapoelela-cloud.github.io/apex-web/main.dart.js"
)


# ANSI colors. Disabled when stdout isn't a tty so log redirects
# stay clean.
def _color_supported() -> bool:
    return sys.stdout.isatty() and os.getenv("NO_COLOR") is None


_USE_COLOR = _color_supported()


def _c(code: str) -> str:
    return code if _USE_COLOR else ""


GREEN = _c("\033[92m")
RED = _c("\033[91m")
YELLOW = _c("\033[93m")
BLUE = _c("\033[94m")
RESET = _c("\033[0m")
BOLD = _c("\033[1m")


# ────────────────────────────────────────────────────────────────────
# Logging + HTTP
# ────────────────────────────────────────────────────────────────────


def log(msg: str = "", color: str = "") -> None:
    print(f"{color}{msg}{RESET}", flush=True)


def http_request(
    method: str,
    url: str,
    *,
    headers: Optional[dict] = None,
    body: Optional[dict] = None,
    timeout: int = 60,
) -> tuple[int, Union[dict, str]]:
    """Tiny urllib wrapper — returns `(status_code, body)`.

    `body` is parsed JSON when possible, raw decoded text otherwise.
    HTTPError responses are converted into normal `(status, body)`
    tuples so callers see the same shape on success vs. failure.
    Network-level errors propagate (`URLError`, timeout, etc.) so
    they're caught by the step wrapper and surfaced cleanly.
    """
    headers = dict(headers or {})
    data: Optional[bytes] = None
    if body is not None:
        headers.setdefault("Content-Type", "application/json")
        data = json.dumps(body).encode("utf-8")

    req = request.Request(url, data=data, headers=headers, method=method)
    ctx = ssl.create_default_context()

    try:
        with request.urlopen(req, context=ctx, timeout=timeout) as resp:
            raw = resp.read()
            try:
                return resp.status, json.loads(raw)
            except (json.JSONDecodeError, ValueError):
                return resp.status, raw.decode("utf-8", errors="replace")
    except error.HTTPError as e:
        # 4xx / 5xx come through here. Read the body so the caller
        # can still surface a useful message.
        raw = b""
        try:
            raw = e.read()
        except Exception:
            pass
        try:
            return e.code, json.loads(raw)
        except (json.JSONDecodeError, ValueError):
            return e.code, raw.decode("utf-8", errors="replace")


# ────────────────────────────────────────────────────────────────────
# Steps — each returns True on success, False on failure.
# Exceptions are caught and logged at the call site in `main`.
# ────────────────────────────────────────────────────────────────────


def step_verify_deploy(api: str) -> bool:
    """Confirm the gh-pages bundle is fresh by checking for sentinel
    strings dropped by recent PRs. Missing strings warn but don't
    fail the step — a stale bundle isn't a blocker for the rest of
    the runbook (it might just mean the user is running this
    against a non-Pages target)."""
    log()
    log("[1/4] Verifying deploy", BLUE + BOLD)

    try:
        status, body = http_request("GET", DEFAULT_PAGES_URL)
    except Exception as e:
        log(f"  FAIL: bundle fetch raised {type(e).__name__}: {e}", RED)
        return False

    if status != 200:
        log(f"  FAIL: bundle returned HTTP {status}", RED)
        return False

    if isinstance(body, dict):
        # Shouldn't happen — main.dart.js isn't JSON.
        log("  FAIL: expected JS bundle, got JSON", RED)
        return False

    size_mb = len(body) / 1_048_576
    log(f"  Bundle size: {size_mb:.2f} MB", GREEN)

    # Sentinel substrings dropped by recent PRs. Each row is
    # (substring, source ticket — surfaces context when missing).
    sentinels = [
        ("erp/finance/receipt-capture", "G-CHIPS-WIRE-FIN-1"),
        ("erp/finance/vat-return", "G-CHIPS-WIRE-FIN-1"),
        ("apexAuthRefresh", "ERR-1"),
        ("seed-demo-data", "G-DEMO-DATA-SEEDER"),
    ]
    missing = []
    for needle, source in sentinels:
        present = needle in body
        mark = f"{GREEN}OK{RESET}" if present else f"{RED}MISS{RESET}"
        log(f"  [{mark}] {needle}  ({source})")
        if not present:
            missing.append((needle, source))

    if missing:
        log(
            f"  WARNING: {len(missing)} sentinel(s) missing — bundle "
            "may be stale or built from an older branch.",
            YELLOW,
        )
    else:
        log("  All sentinels present.", GREEN)
    return True


def step_login(api: str, username: str, password: str) -> Optional[str]:
    """Authenticate and return a JWT. Returns None on failure (the
    step wrapper logs and the calling step decides whether to
    continue). Tries common token field names so the script works
    against both the legacy `{token: …}` and the current
    `{tokens: {access_token: …}}` shapes."""
    log()
    log(f"  Logging in as {username}", BLUE)

    try:
        status, body = http_request(
            "POST",
            f"{api}/auth/login",
            body={"username_or_email": username, "password": password},
        )
    except Exception as e:
        log(f"  FAIL: login raised {type(e).__name__}: {e}", RED)
        return None

    if status != 200 or not isinstance(body, dict):
        log(f"  Login failed: HTTP {status}: {body}", RED)
        return None

    token = (
        body.get("token")
        or body.get("access_token")
        or (body.get("tokens") or {}).get("access_token")
        or (body.get("data") or {}).get("token")
    )
    if not token:
        log(f"  Login response missing token: {list(body.keys())}", RED)
        return None

    log("  Login OK", GREEN)
    return token


def step_migrate_legacy(api: str, admin_secret: str) -> bool:
    """POST /admin/migrate-legacy-tenants. SKIP (still True) when no
    secret is configured — a fresh dev box without ADMIN_SECRET
    shouldn't fail the runbook."""
    log()
    log("[2/4] Migrating legacy tenants", BLUE + BOLD)

    if not admin_secret:
        log("  SKIP: ADMIN_SECRET not set — pass --admin-secret or "
            "set the env var.", YELLOW)
        return True

    try:
        status, body = http_request(
            "POST",
            f"{api}/admin/migrate-legacy-tenants",
            headers={"X-Admin-Secret": admin_secret},
        )
    except Exception as e:
        log(f"  FAIL: request raised {type(e).__name__}: {e}", RED)
        return False

    if status != 200:
        log(f"  FAIL: HTTP {status}: {body}", RED)
        return False

    if not isinstance(body, dict) or not body.get("success"):
        log(f"  FAIL: unexpected response shape: {body}", RED)
        return False

    data = body.get("data") or {}
    log(f"  Total legacy users: {data.get('total_legacy', '?')}", GREEN)
    log(f"  Migrated:           {data.get('migrated', '?')}", GREEN)
    log(f"  Failed:             {data.get('failed', '?')}", GREEN)
    if data.get("failures"):
        log(f"  Failures: {data['failures']}", YELLOW)
    return True


def step_seed_demo(api: str, jwt: str, *, force: bool = False) -> bool:
    """POST /api/v1/account/seed-demo-data using the caller's JWT.

    `skipped` from the service is a SUCCESS path — the tenant
    already has data. The runbook mirrors that: skipped → True,
    not False.
    """
    log()
    log("[3/4] Seeding demo data on caller's tenant", BLUE + BOLD)

    qs = "?force=true" if force else ""
    try:
        status, body = http_request(
            "POST",
            f"{api}/api/v1/account/seed-demo-data{qs}",
            headers={"Authorization": f"Bearer {jwt}"},
        )
    except Exception as e:
        log(f"  FAIL: request raised {type(e).__name__}: {e}", RED)
        return False

    if status not in (200, 201):
        log(f"  FAIL: HTTP {status}: {body}", RED)
        return False

    if not isinstance(body, dict):
        log(f"  FAIL: unexpected response: {body}", RED)
        return False

    data = body.get("data") or body
    if data.get("skipped"):
        log(
            f"  SKIPPED: {data.get('reason', 'tenant already has data')}",
            YELLOW,
        )
        log("  Pass --force-seed to append another batch.", YELLOW)
        return True

    summary = (data.get("summary") or {})
    master = summary.get("master_data") or {}
    log(f"  Customers: {master.get('customers', 0)}", GREEN)
    log(f"  Vendors:   {master.get('vendors', 0)}", GREEN)
    log(f"  Products:  {master.get('products', 0)}", GREEN)

    # The seeder surfaces a `deferred` block when only the master-data
    # tier ran (G-DEMO-DATA-SEEDER v1). Print the note so ops can
    # see what's coming in V2.
    deferred = summary.get("deferred") or {}
    if deferred and "_note" in deferred:
        log(f"  ({deferred['_note']})", YELLOW)
    return True


def step_smoke_test(api: str, jwt: Optional[str]) -> bool:
    """Hit a handful of well-known endpoints and check the status
    codes are sane. Anything that returns a 5xx fails the step.
    `4xx` (incl. 401, 403, 404) are noted as warnings but don't
    fail — the runbook is meant to be a quick health probe, not
    an integration test."""
    log()
    log("[4/4] Smoke test on key endpoints", BLUE + BOLD)

    checks = [
        ("GET", "/health", None, [200]),
        ("GET", "/", None, [200]),
    ]
    if jwt:
        auth = {"Authorization": f"Bearer {jwt}"}
        checks += [
            ("GET", "/api/v1/account/profile", auth, [200, 404]),
            ("GET", "/api/v1/dashboard/widgets", auth, [200, 404]),
        ]

    all_ok = True
    for method, path, headers, expected in checks:
        try:
            status, _ = http_request(
                method, f"{api}{path}", headers=headers, timeout=15
            )
        except Exception as e:
            log(f"  [{RED}EXC{RESET}] {method} {path}  →  {e}", RED)
            all_ok = False
            continue

        if status in expected:
            mark = f"{GREEN}OK{RESET}"
        elif status >= 500:
            mark = f"{RED}5xx{RESET}"
            all_ok = False
        else:
            mark = f"{YELLOW}{status}{RESET}"
        log(f"  [{mark}] {method} {path}  →  HTTP {status}")

    return all_ok


# ────────────────────────────────────────────────────────────────────
# CLI
# ────────────────────────────────────────────────────────────────────


def parse_args(argv: Optional[list] = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="APEX post-deploy operations runbook",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument("--all", action="store_true", help="Run all steps")
    p.add_argument("--verify-deploy", action="store_true")
    p.add_argument("--migrate-legacy", action="store_true")
    p.add_argument("--seed-demo", action="store_true")
    p.add_argument("--smoke-test", action="store_true")
    p.add_argument(
        "--force-seed",
        action="store_true",
        help="Append another seed batch even if tenant already has data",
    )
    p.add_argument(
        "--api",
        default=DEFAULT_API,
        help=f"API base URL (default: {DEFAULT_API})",
    )
    p.add_argument("--username", default=os.getenv("APEX_USERNAME"))
    p.add_argument("--password", default=os.getenv("APEX_PASSWORD"))
    p.add_argument("--admin-secret", default=os.getenv("ADMIN_SECRET"))
    args = p.parse_args(argv)

    # No specific flag → --all is implied. Keeps the typical case
    # ergonomic: `python post_deploy_runbook.py` does the right thing.
    if not any(
        [
            args.verify_deploy,
            args.migrate_legacy,
            args.seed_demo,
            args.smoke_test,
        ]
    ):
        args.all = True
    return args


def main(argv: Optional[list] = None) -> int:
    args = parse_args(argv)

    log(f"{BOLD}APEX Post-Deploy Runbook{RESET}")
    log(f"API: {args.api}")

    needs_jwt = args.all or args.seed_demo or args.smoke_test
    jwt: Optional[str] = None

    if needs_jwt:
        if not args.username:
            args.username = input("Username: ").strip()
        if not args.password:
            args.password = getpass.getpass("Password: ")
        jwt = step_login(args.api, args.username, args.password)
        # `--seed-demo` truly needs the JWT. `--smoke-test` can
        # still hit anonymous endpoints, so we only hard-fail for
        # the seed path.
        if not jwt and (args.all or args.seed_demo):
            log(
                f"\n{RED}Cannot continue without a JWT — login failed."
                f"{RESET}",
                RED,
            )
            return 1

    results: dict[str, bool] = {}

    if args.all or args.verify_deploy:
        results["verify_deploy"] = step_verify_deploy(args.api)

    if args.all or args.migrate_legacy:
        results["migrate_legacy"] = step_migrate_legacy(
            args.api, args.admin_secret or ""
        )

    if (args.all or args.seed_demo) and jwt:
        results["seed_demo"] = step_seed_demo(
            args.api, jwt, force=args.force_seed
        )

    if args.all or args.smoke_test:
        results["smoke_test"] = step_smoke_test(args.api, jwt)

    # Summary table — single place to scan after a long run.
    log()
    log(f"{BOLD}Summary:{RESET}")
    all_ok = True
    for step, ok in results.items():
        mark = f"{GREEN}OK{RESET}" if ok else f"{RED}FAIL{RESET}"
        log(f"  {step:20s} {mark}")
        if not ok:
            all_ok = False

    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
