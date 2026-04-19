"""APEX Python SDK — thin wrapper around /api/v1/* endpoints.

Install (once published):
    pip install apex-sdk

Use:
    from apex_sdk import ApexClient

    apex = ApexClient(
        base_url="https://api.apex-app.com",
        api_key="apex_live_...",
        tenant_id="t_123",
    )

    # List employees with cursor pagination
    page = apex.hr.employees.list(limit=25)
    while page.has_more:
        for emp in page.items:
            print(emp["name_ar"])
        page = apex.hr.employees.list(limit=25, cursor=page.next_cursor)

    # Register a webhook
    sub = apex.webhooks.subscribe(
        url="https://yourapp.com/hooks/apex",
        events=["invoice.created", "invoice.paid"],
    )
    print("Keep this secret:", sub["secret"])

The SDK is intentionally thin — it mirrors the REST surface 1:1 so the
public API is the source of truth. New endpoints appear here without
SDK changes if you use client.get/post/... directly.
"""

from .client import ApexClient, ApexApiError, CursorPage

__version__ = "0.1.0"

__all__ = ["ApexClient", "ApexApiError", "CursorPage"]
