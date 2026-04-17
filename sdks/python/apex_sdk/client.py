"""APEX Python SDK — HTTP client."""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Any, Iterator, Optional

logger = logging.getLogger(__name__)

DEFAULT_TIMEOUT = 30.0


class ApexApiError(Exception):
    """Raised when the APEX API returns a 4xx / 5xx response."""

    def __init__(self, status_code: int, detail: Any, request_url: str = ""):
        self.status_code = status_code
        self.detail = detail
        self.request_url = request_url
        super().__init__(f"APEX API {status_code}: {detail}")


@dataclass
class CursorPage:
    """Result of a list call — matches the server's envelope."""

    items: list[dict]
    next_cursor: Optional[str]
    has_more: bool
    limit: int

    @classmethod
    def from_body(cls, body: dict) -> "CursorPage":
        return cls(
            items=body.get("data") or [],
            next_cursor=body.get("next_cursor"),
            has_more=bool(body.get("has_more")),
            limit=int(body.get("limit") or 25),
        )


class ApexClient:
    """Entry point for the SDK."""

    def __init__(
        self,
        *,
        base_url: str,
        api_key: Optional[str] = None,
        tenant_id: Optional[str] = None,
        timeout: float = DEFAULT_TIMEOUT,
    ):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.tenant_id = tenant_id
        self.timeout = timeout

        self.hr = _HrNamespace(self)
        self.webhooks = _WebhooksNamespace(self)
        self.saved_views = _SavedViewsNamespace(self)
        self.zatca = _ZatcaNamespace(self)

    # ── Low-level ────────────────────────────────────────

    def _headers(self, extra: Optional[dict] = None) -> dict:
        h = {"Accept": "application/json"}
        if self.api_key:
            h["Authorization"] = f"Bearer {self.api_key}"
        if self.tenant_id:
            h["X-Tenant-Id"] = self.tenant_id
        if extra:
            h.update(extra)
        return h

    def request(
        self,
        method: str,
        path: str,
        *,
        params: Optional[dict] = None,
        json_body: Optional[dict] = None,
    ) -> dict:
        try:
            import requests
        except ImportError as e:
            raise ApexApiError(0, "requests library required") from e
        url = f"{self.base_url}{path}"
        resp = requests.request(
            method,
            url,
            params=params,
            json=json_body,
            headers=self._headers(
                {"Content-Type": "application/json"} if json_body is not None else None
            ),
            timeout=self.timeout,
        )
        if resp.status_code >= 400:
            try:
                detail = resp.json()
            except ValueError:
                detail = resp.text
            raise ApexApiError(resp.status_code, detail, request_url=url)
        try:
            return resp.json() if resp.content else {}
        except ValueError:
            return {"raw": resp.text}

    def get(self, path: str, **kwargs) -> dict:
        return self.request("GET", path, **kwargs)

    def post(self, path: str, **kwargs) -> dict:
        return self.request("POST", path, **kwargs)

    def put(self, path: str, **kwargs) -> dict:
        return self.request("PUT", path, **kwargs)

    def delete(self, path: str, **kwargs) -> dict:
        return self.request("DELETE", path, **kwargs)

    # ── Helpers ──────────────────────────────────────────

    def paginate(
        self,
        path: str,
        *,
        limit: int = 25,
        params: Optional[dict] = None,
    ) -> Iterator[dict]:
        """Yield every item across all pages."""
        cursor: Optional[str] = None
        while True:
            q = dict(params or {})
            q["limit"] = limit
            if cursor:
                q["cursor"] = cursor
            body = self.get(path, params=q)
            page = CursorPage.from_body(body)
            yield from page.items
            if not page.has_more or not page.next_cursor:
                break
            cursor = page.next_cursor


# ── Resource namespaces ────────────────────────────────────


class _HrNamespace:
    def __init__(self, c: ApexClient):
        self._c = c
        self.employees = _HrEmployees(c)
        self.leave = _HrLeave(c)
        self.payroll = _HrPayroll(c)

    def calc_gosi(self, country: str, basic_salary, housing_allowance=0,
                  other_fixed=0, is_national: bool = True) -> dict:
        return self._c.post(
            "/hr/calc/gosi",
            json_body={
                "country": country,
                "basic_salary": str(basic_salary),
                "housing_allowance": str(housing_allowance),
                "other_fixed": str(other_fixed),
                "is_national": is_national,
            },
        )["data"]

    def calc_eosb(self, country: str, monthly_wage, years_of_service,
                  resigned: bool = False) -> dict:
        return self._c.post(
            "/hr/calc/eosb",
            json_body={
                "country": country,
                "monthly_wage": str(monthly_wage),
                "years_of_service": str(years_of_service),
                "resigned": resigned,
            },
        )["data"]


class _HrEmployees:
    def __init__(self, c: ApexClient):
        self._c = c

    def list(self, *, limit: int = 25, cursor: Optional[str] = None,
             status: Optional[str] = None) -> CursorPage:
        params = {"limit": limit}
        if cursor:
            params["cursor"] = cursor
        if status:
            params["status"] = status
        return CursorPage.from_body(self._c.get("/hr/employees", params=params))

    def create(self, **fields) -> dict:
        return self._c.post("/hr/employees", json_body=fields)["data"]

    def get(self, emp_id: str) -> dict:
        return self._c.get(f"/hr/employees/{emp_id}")["data"]

    def update(self, emp_id: str, **fields) -> dict:
        return self._c.put(f"/hr/employees/{emp_id}", json_body=fields)["data"]

    def terminate(self, emp_id: str) -> dict:
        return self._c.delete(f"/hr/employees/{emp_id}")["data"]


class _HrLeave:
    def __init__(self, c: ApexClient):
        self._c = c

    def create(self, employee_id: str, leave_type: str, start_date: str,
               end_date: str, reason: Optional[str] = None) -> dict:
        return self._c.post("/hr/leave-requests", json_body={
            "employee_id": employee_id,
            "leave_type": leave_type,
            "start_date": start_date,
            "end_date": end_date,
            "reason": reason,
        })["data"]

    def list(self, status: Optional[str] = None) -> list[dict]:
        params = {"status": status} if status else None
        return self._c.get("/hr/leave-requests", params=params)["data"]

    def approve(self, request_id: str) -> dict:
        return self._c.post(f"/hr/leave-requests/{request_id}/approve")["data"]

    def reject(self, request_id: str, reason: str) -> dict:
        return self._c.post(
            f"/hr/leave-requests/{request_id}/reject",
            params={"reason": reason},
        )["data"]


class _HrPayroll:
    def __init__(self, c: ApexClient):
        self._c = c

    def run(self, period: str) -> dict:
        return self._c.post("/hr/payroll/run", json_body={"period": period})["data"]

    def get(self, period: str) -> dict:
        return self._c.get(f"/hr/payroll/{period}")["data"]

    def approve(self, period: str) -> dict:
        return self._c.post(f"/hr/payroll/{period}/approve")["data"]


class _WebhooksNamespace:
    def __init__(self, c: ApexClient):
        self._c = c

    def subscribe(self, url: str, events: list[str], name: Optional[str] = None) -> dict:
        return self._c.post(
            "/api/v1/webhooks/subscriptions",
            json_body={"url": url, "events": events, "name": name},
        )["data"]

    def list_subscriptions(self) -> list[dict]:
        return self._c.get("/api/v1/webhooks/subscriptions")["data"]

    def unsubscribe(self, subscription_id: str) -> dict:
        return self._c.delete(f"/api/v1/webhooks/subscriptions/{subscription_id}")["data"]

    def deliveries(self, status: Optional[str] = None, limit: int = 50) -> list[dict]:
        params = {"limit": limit}
        if status:
            params["status"] = status
        return self._c.get("/api/v1/webhooks/deliveries", params=params)["data"]

    def retry_delivery(self, delivery_id: str) -> dict:
        return self._c.post(f"/api/v1/webhooks/deliveries/{delivery_id}/retry")["data"]


class _SavedViewsNamespace:
    def __init__(self, c: ApexClient):
        self._c = c

    def list(self, screen: str) -> list[dict]:
        return self._c.get("/api/v1/saved-views", params={"screen": screen})["data"]

    def create(self, screen: str, name: str, payload: dict, is_shared: bool = False) -> dict:
        return self._c.post("/api/v1/saved-views", json_body={
            "screen": screen,
            "name": name,
            "payload": payload,
            "is_shared": is_shared,
        })["data"]

    def update(self, view_id: str, screen: str, name: str, payload: dict,
               is_shared: bool = False) -> dict:
        return self._c.put(f"/api/v1/saved-views/{view_id}", json_body={
            "screen": screen,
            "name": name,
            "payload": payload,
            "is_shared": is_shared,
        })["data"]

    def delete(self, view_id: str) -> dict:
        return self._c.delete(f"/api/v1/saved-views/{view_id}")["data"]


class _ZatcaNamespace:
    def __init__(self, c: ApexClient):
        self._c = c

    # Placeholder — wire when /zatca/* endpoints are public.
