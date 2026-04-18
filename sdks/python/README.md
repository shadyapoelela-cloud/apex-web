# APEX Python SDK

Thin, typed client for the APEX Financial Platform API.

## Install

```bash
pip install apex-sdk
```

## Quick start

```python
from apex_sdk import ApexClient

apex = ApexClient(
    base_url="https://api.apex-app.com",
    api_key="apex_live_xxxxxxxxxxxx",
    tenant_id="t_your_tenant",
)

# List employees with cursor pagination
for emp in apex.paginate("/hr/employees", limit=50):
    print(emp["employee_number"], emp["name_ar"])

# Create an employee
new_emp = apex.hr.employees.create(
    employee_number="EMP-001",
    name_ar="أحمد علي",
    hire_date="2026-01-01",
    basic_salary="8000",
    housing_allowance="2000",
)

# Saudi GOSI calculation
result = apex.hr.calc_gosi(
    country="ksa",
    basic_salary=8000,
    housing_allowance=2000,
    is_national=True,
)
print(result["employee_contribution"])  # '1000.00'

# Subscribe to webhooks
sub = apex.webhooks.subscribe(
    url="https://yourapp.com/hooks/apex",
    events=["invoice.created", "invoice.paid"],
)
print("Secret (save it):", sub["secret"])
```

## Errors

```python
from apex_sdk import ApexApiError

try:
    apex.hr.employees.get("no-such-id")
except ApexApiError as e:
    print(e.status_code, e.detail)
```

## Version

`apex_sdk.__version__` returns the current SDK version. API compatibility
is pinned to `/api/v1/`.
