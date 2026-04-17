---
id: getting-started
title: البدء مع APEX
sidebar_position: 1
---

# البدء مع APEX

مرحباً بك في منصة APEX المالية. في 5 دقائق ستصبح جاهزاً لاستدعاء الـ API.

## 1. الحصول على مفتاح API

من لوحة APEX: `الإعدادات → المطورون → إنشاء مفتاح`. خزّن المفتاح في
متغير بيئة — لا تضعه في الكود:

```bash
export APEX_API_KEY="apex_live_xxxxxxxxxxxx"
export APEX_TENANT_ID="t_xxxxxx"
```

## 2. الاتصال الأول

### Python

```python
from apex_sdk import ApexClient

apex = ApexClient(
    base_url="https://api.apex-app.com",
    api_key=os.environ["APEX_API_KEY"],
    tenant_id=os.environ["APEX_TENANT_ID"],
)

for emp in apex.paginate("/hr/employees", limit=50):
    print(emp["name_ar"])
```

### Node.js

```javascript
import { ApexClient } from "@apex/sdk";

const apex = new ApexClient({
  baseUrl: "https://api.apex-app.com",
  apiKey: process.env.APEX_API_KEY,
  tenantId: process.env.APEX_TENANT_ID,
});

for await (const emp of apex.paginate("/hr/employees", { limit: 50 })) {
  console.log(emp.employee_number, emp.name_ar);
}
```

### PHP

```php
use Apex\Sdk\ApexClient;

$apex = new ApexClient([
    'base_url'  => 'https://api.apex-app.com',
    'api_key'   => getenv('APEX_API_KEY'),
    'tenant_id' => getenv('APEX_TENANT_ID'),
]);

foreach ($apex->paginate('/hr/employees', ['limit' => 50]) as $emp) {
    echo $emp['employee_number'] . "\n";
}
```

### curl

```bash
curl https://api.apex-app.com/hr/employees?limit=25 \
  -H "Authorization: Bearer $APEX_API_KEY" \
  -H "X-Tenant-Id: $APEX_TENANT_ID"
```

## 3. الخطوات التالية

- [استعراض كامل API](./api/overview) — كل الـ endpoints.
- [الـ Webhooks](./webhooks) — اشترك في أحداث الفواتير والدفعات.
- [ZATCA Phase 2](./compliance/zatca) — الفوترة الإلكترونية السعودية.
- [UAE FTA](./compliance/uae-fta) — ضريبة الشركات + Peppol.

## الدعم

- تذكرة دعم: [apex-app.com/support](https://apex-app.com/support)
- Discord للمطورين: [discord.gg/apex](https://discord.gg/apex)
- GitHub: [github.com/apex/apex-web](https://github.com/apex/apex-web)
