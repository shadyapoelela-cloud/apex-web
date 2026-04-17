"""APEX load test suite — Locust scenarios for the critical paths.

Run against a local dev server:
    locust -f tests/load/locustfile.py --host=http://localhost:8000

Or run a headless smoke with 10 users for 30 seconds:
    locust -f tests/load/locustfile.py --headless \
        --host=http://localhost:8000 --users=10 --spawn-rate=2 --run-time=30s

Scenarios (weight proportional to realistic traffic mix):
  • FastPathUser    (80%) — read-heavy: notifications, activity list, health
  • WriteUser       (15%) — posts comments, triggers scans, submits invoices
  • ZatcaSubmitter   (5%) — heavy: full submit-e2e cycle with QR + PDF
"""
from __future__ import annotations

import random
import uuid

try:
    from locust import HttpUser, between, task
except ImportError as e:  # pragma: no cover
    raise SystemExit(
        "locust is not installed. Run: pip install locust"
    ) from e


# ── Fixtures ────────────────────────────────────────────


def _tenant_id() -> str:
    # Each simulated user gets a sticky tenant_id for the duration of
    # their locust session — so RLS behaviour is exercised realistically
    # (many tenants, each only seeing their own rows).
    return f"tenant-{uuid.uuid4().hex[:8]}"


def _user_id() -> str:
    return f"u-{uuid.uuid4().hex[:8]}"


def _invoice_payload(invoice_number: str) -> dict:
    return {
        "client_id": 1,
        "fiscal_year": 2026,
        "invoice_number": invoice_number,
        "seller": {
            "name": "APEX Load Test",
            "vat_number": "300000000000003",
            "cr_number": "1010101010",
            "address_street": "Test St",
            "address_city": "Riyadh",
            "address_postal": "11564",
            "country_code": "SA",
        },
        "lines": [
            {"name": "widget", "quantity": "1", "unit_price": "100",
             "vat_rate": "15"},
        ],
    }


# ── User classes ────────────────────────────────────────


class FastPathUser(HttpUser):
    """Read-heavy user — 80% of real traffic. Should be sub-50ms on a
    warm server."""

    weight = 80
    wait_time = between(0.5, 2.0)

    def on_start(self):
        self.tenant = _tenant_id()
        self.user = _user_id()
        self.headers = {"X-Tenant-Id": self.tenant}

    @task(5)
    def list_notifications(self):
        self.client.get(
            f"/api/v1/notifications?user_id={self.user}&limit=30",
            headers=self.headers,
            name="/notifications [list]",
        )

    @task(3)
    def list_recent_activity(self):
        self.client.get(
            "/api/v1/activity/recent/invoice",
            headers=self.headers,
            name="/activity/recent",
        )

    @task(2)
    def get_tenant_branding(self):
        self.client.get(
            "/api/v1/tenant/branding",
            headers=self.headers,
            name="/tenant/branding [GET]",
        )

    @task(1)
    def system_health(self):
        self.client.get(
            "/api/v1/system/health",
            headers=self.headers,
            name="/system/health",
        )


class WriteUser(HttpUser):
    """Mixed-write user — 15% of traffic. Posts comments, triggers
    AI scans, downloads reports."""

    weight = 15
    wait_time = between(1, 3)

    def on_start(self):
        self.tenant = _tenant_id()
        self.user = _user_id()
        self.headers = {
            "X-Tenant-Id": self.tenant,
            "Content-Type": "application/json",
        }

    @task(5)
    def post_comment(self):
        eid = f"c-{uuid.uuid4().hex[:8]}"
        self.client.post(
            f"/api/v1/activity/client/{eid}/comment",
            json={
                "body": f"عمل روتيني — load test {random.randint(0, 9999)}",
                "user_id": self.user,
                "user_name": "Locust",
            },
            headers=self.headers,
            name="/activity/.../comment [POST]",
        )

    @task(2)
    def download_csv_report(self):
        report = random.choice([
            "trial_balance_2026-04_csv",
            "profit_and_loss_2026-Q1_csv",
            "aging_report_2026-04-30_csv",
        ])
        self.client.get(
            f"/api/v1/reports/download/{report}",
            headers=self.headers,
            name="/reports/download [csv]",
        )

    @task(1)
    def trigger_scan(self):
        self.client.post(
            "/api/v1/ai/scan?emit_activity=false",
            headers=self.headers,
            name="/ai/scan [admin trigger]",
        )

    @task(1)
    def save_filter_view(self):
        self.client.post(
            f"/api/v1/saved-views?user_id={self.user}",
            json={
                "screen": "clients",
                "name": f"view-{uuid.uuid4().hex[:6]}",
                "payload": {"search": "test"},
                "is_shared": False,
            },
            headers=self.headers,
            name="/saved-views [POST]",
        )


class ZatcaSubmitter(HttpUser):
    """Heavy user — 5% of traffic. Full ZATCA submit-e2e cycle."""

    weight = 5
    wait_time = between(2, 5)

    def on_start(self):
        self.tenant = _tenant_id()
        self.headers = {
            "X-Tenant-Id": self.tenant,
            "Content-Type": "application/json",
        }

    @task
    def submit_and_poll(self):
        inv_no = f"INV-LT-{uuid.uuid4().hex[:6]}"
        with self.client.post(
            "/api/v1/zatca/submit-e2e",
            json=_invoice_payload(inv_no),
            headers=self.headers,
            name="/zatca/submit-e2e",
            catch_response=True,
        ) as r:
            if r.status_code != 200:
                r.failure(f"submit-e2e {r.status_code}")
                return
            sid = r.json().get("data", {}).get("submission_id")
            if not sid:
                r.failure("no submission_id in response")
                return

        # Poll status
        self.client.get(
            f"/api/v1/zatca/submission/{sid}",
            headers=self.headers,
            name="/zatca/submission [poll]",
        )
        # Download the PDF
        self.client.get(
            f"/api/v1/zatca/submission/{sid}/pdf",
            headers=self.headers,
            name="/zatca/submission/pdf",
        )
