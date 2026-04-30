# 11 — Integration Guide: How to Use Existing Infrastructure
# دليل التكامل: كيفية استخدام البنية الموجودة

> Reference: continues from `10_CLAUDE_CODE_INSTRUCTIONS.md`. **Final document in the blueprint package.**
> **Purpose:** Concrete examples of wiring new features into the **already-built** APEX infrastructure so we don't reinvent.

---

## 1. Mental Model / النموذج الذهني

APEX has accumulated 11 phases + 6 sprints of infrastructure. Most "new" features can be assembled from EXISTING parts:

```mermaid
graph TB
    NEW[New Feature Idea]
    NEW -->|"Does it need auth?"| AUTH_INF[Phase 1 Auth<br/>get_current_user, JWT]
    NEW -->|"Does it touch tenant data?"| TENANT_INF[TenantContextMiddleware<br/>auto tenant_id filter]
    NEW -->|"Does it need plan check?"| PLAN_INF[Phase 8 Entitlements<br/>require_entitlement]
    NEW -->|"Does it need to be audited?"| AUDIT_INF[Audit Log<br/>audit_log() helper]
    NEW -->|"Should it notify user?"| NOTIF_INF[Phase 10 Notifications<br/>NotificationService.emit]
    NEW -->|"Need AI?"| AI_INF[Copilot Service<br/>Anthropic Claude wrapper]
    NEW -->|"Need to store file?"| STORAGE_INF[Storage Backend<br/>local/S3 abstraction]
    NEW -->|"Send email?"| EMAIL_INF[Email Backend<br/>console/SMTP/SendGrid]
    NEW -->|"Charge money?"| PAYMENT_INF[Payment Backend<br/>mock/Stripe]
    NEW -->|"Show in UI?"| ROUTER_INF[GoRouter<br/>register in router.dart]
    NEW -->|"Save user pref?"| SESSION_INF[S Singleton<br/>localStorage]
```

---

## 2. Auth Integration / التكامل مع التحقق

### Backend: protect endpoint
```python
from app.core.auth_utils import get_current_user

@router.get("/my-resource")
async def list_resources(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return db.query(Resource).filter(Resource.user_id == user.id).all()
```

### Backend: require role
```python
from app.core.auth_utils import require_role

@router.post("/my-resource")
async def create(
    user = Depends(require_role("client_admin", "provider_user")),
):
    ...
```

### Backend: require entitlement (plan check)
```python
from app.core.auth_utils import require_entitlement

@router.post("/heavy-feature")
async def heavy(
    user = Depends(require_entitlement("heavy_feature_code")),
):
    ...
```

### Frontend: read user
```dart
import 'package:apex_finance/core/session.dart';

if (S.token == null) {
  context.go('/login');
  return;
}
final username = S.uname ?? S.uid ?? '';
final isProUser = ['pro', 'business', 'expert', 'enterprise'].contains(S.plan);
```

---

## 3. Tenant Isolation / عزل المستأجرين

### Backend: every query MUST filter
```python
def get_my_things(db: Session, user: User):
    return db.query(Thing).filter(Thing.tenant_id == user.tenant_id).all()
```

**Anti-pattern** (DO NOT):
```python
def get_my_things(db: Session):
    return db.query(Thing).all()  # leaks ALL tenants!
```

### Frontend: scope by entity
```dart
final entityId = S.entityId;
if (entityId == null) {
  // route to /onboarding/wizard
  return;
}
final invoices = await ApiService.pilotListSalesInvoices(entityId);
```

---

## 4. Audit Log Integration / سجل التدقيق

### Backend: emit event
```python
from app.core.audit_log import audit_log

@router.post("/my-resource")
async def create(payload: ResourceIn, user = Depends(get_current_user), db = Depends(get_db)):
    obj = Resource(**payload.dict(), tenant_id=user.tenant_id)
    db.add(obj)
    db.commit()

    audit_log(
        db,
        user=user,
        event_type="resource.created",
        resource=f"resource/{obj.id}",
        after_state=ResourceOut.from_orm(obj).dict(),
    )

    return obj
```

The audit_log helper takes care of:
- Adding to `audit_events` table
- Computing hash chain (`prev_hash`, `this_hash`)
- Capturing IP, user agent
- Adding tenant_id

### What to audit
- Login/logout events ✓ (already done in Phase 1)
- All POST/PUT/DELETE on tenant-scoped resources
- Permission denials (401, 403)
- Subscription changes
- Plan upgrades / downgrades
- ZATCA submissions
- Audit engagement state transitions
- Workpaper sign-offs

---

## 5. Notifications Integration / الإشعارات

### Backend: send notification
```python
from app.phase10.services.notification_service import NotificationService

ns = NotificationService(db)
ns.emit(
    user_id=client.owner_id,
    type="invoice_issued",
    title="فاتورة جديدة",
    body=f"تم إصدار الفاتورة #{invoice.invoice_number} للعميل {customer.name}",
    metadata={"invoice_id": str(invoice.id), "amount": str(invoice.total)},
)
```

This will:
- Create `Notification` row
- Push via WebSocket to in-app channel (if user online)
- Send email if user opted in for this type
- Send SMS if user opted in for critical types

### Frontend: read notifications
Already wired to bell icon in launchpad. Just emit events backend-side.

### Notification preferences
- Per-user via `/notifications/prefs`
- Per-type: `in_app`, `email`, `sms` toggles
- Default: critical events all-channel, info events in-app only

---

## 6. AI / Copilot Integration / المساعد

### Backend: simple completion
```python
from app.copilot.services.copilot_service import CopilotService

cs = CopilotService()
response = cs.simple_complete(
    system="You are a financial expert. Translate the following GL account name to IFRS category.",
    user_message=account_name,
    max_tokens=100,
)
```

### Backend: with tool use
```python
response = cs.complete_with_tools(
    system="...",
    user_message=question,
    tools=[
        {"name": "lookup_balance", "description": "...", "input_schema": {...}},
        {"name": "compute_ratio", "description": "...", "input_schema": {...}},
    ],
    tool_handler=lambda name, input: {...},
)
```

### Backend: chat session
```python
session = cs.get_or_create_session(user.id, client_id=client.id)
reply = cs.send_message(session_id=session.id, message=user_message)
```

### Fallback when API key missing
```python
if not settings.ANTHROPIC_API_KEY:
    return {"reply": "AI Copilot غير متاح حالياً. يرجى المحاولة لاحقاً.", "fallback": True}
```

### Frontend: open Copilot panel
```dart
// In any screen
import 'package:apex_finance/apex_ask_panel.dart';

ApexAskPanel.show(
  context,
  preset: 'ما هو رصيد العميل ${customer.name}؟',
  contextEntityId: S.entityId,
);
```

---

## 7. ZATCA Integration / تكامل ZATCA

### Auto-clear after invoice issue
**Existing hook:** `app/pilot/services/sales_invoice_service.py::issue()` already calls ZATCA service.

If you add a NEW invoice type (e.g., credit note), wire it the same way:

```python
def issue_credit_note(self, cn_id: UUID, user: User):
    cn = self.db.query(CreditNote).filter(CreditNote.id == cn_id).first()
    cn.status = "issued"

    if user.tenant.zatca_phase2_enabled:
        from app.zatca.services.zatca_service import ZatcaService
        ZatcaService(self.db).enqueue_or_clear(cn, doc_type="credit_note")

    self.db.commit()
```

### Reading ZATCA state
```python
from app.zatca.services.zatca_service import ZatcaService

state = ZatcaService(db).get_invoice_state(invoice_id)
# → {"status": "cleared", "uuid": "...", "qr": "...", "pdf_url": "..."}
```

### Frontend: ZATCA invoice viewer
Already implemented at `/compliance/zatca-invoice/:id`. Just navigate to it after invoice issue:
```dart
context.go('/compliance/zatca-invoice/${invoice.id}');
```

---

## 8. Storage Integration / التخزين

### Save a file
```python
from app.core.storage import get_storage

storage = get_storage()  # returns LocalStorage or S3Storage based on STORAGE_BACKEND env
url = storage.put(
    content=file_bytes,
    key=f"client-docs/{client.id}/{filename}",
    content_type="application/pdf",
)
# → url is a public URL or signed URL
```

### Retrieve a file
```python
content = storage.get(key=f"client-docs/{client.id}/{filename}")
```

### Frontend: upload via multipart
```dart
final result = await FilePicker.platform.pickFiles();
if (result == null) return;
final file = result.files.single;
final url = await ApiService.uploadFile(file, category: 'invoice');
```

---

## 9. Email Integration / البريد الإلكتروني

### Send email
```python
from app.core.email import get_email_backend

email = get_email_backend()  # console/SMTP/SendGrid based on EMAIL_BACKEND
email.send(
    to="customer@example.com",
    subject="فاتورة جديدة",
    html=render_template("invoice.html", invoice=inv),
    attachments=[("invoice.pdf", pdf_bytes, "application/pdf")],
)
```

### Templates
- `app/templates/email/`
- Bilingual (Arabic + English)
- Use Jinja2

### Common email triggers
- Invoice issued → email customer
- Payment received → email user
- Period close completed → email accountant
- ZATCA failure → email admin
- Weekly digest → email user (toggleable)

---

## 10. Payment Integration / المدفوعات

### Subscription upgrade flow
**Existing pattern** in `app/phase8/services/subscription_service.py`:
```python
def upgrade(self, user: User, plan_code: str):
    plan = self.db.query(Plan).filter(Plan.code == plan_code).first()

    if settings.PAYMENT_BACKEND == "stripe":
        session = self.stripe.create_checkout_session(
            customer=user.stripe_customer_id,
            line_items=[{"price": plan.stripe_price_id, "quantity": 1}],
            mode="subscription",
            success_url=f"{settings.FRONTEND_URL}/subscription?success=1",
            cancel_url=f"{settings.FRONTEND_URL}/subscription?cancel=1",
        )
        return {"checkout_url": session.url}
    else:  # mock
        # Simulate immediate success
        self._activate_subscription(user, plan)
        return {"checkout_url": None, "mocked": True}
```

### Webhook handler
**Existing:** `app/phase8/routes/stripe_webhook.py` handles:
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.payment_succeeded`
- `invoice.payment_failed`

If adding a new event:
```python
elif event.type == "checkout.session.completed":
    session = event.data.object
    # ... your handling
```

---

## 11. Background Jobs / المهام الخلفية

### APScheduler setup (already in lifespan)
```python
# app/main.py
@asynccontextmanager
async def lifespan(app: FastAPI):
    scheduler = AsyncIOScheduler()
    # Existing jobs:
    scheduler.add_job(zatca_queue_processor, IntervalTrigger(minutes=1))
    scheduler.add_job(ai_guardrails_evaluator, IntervalTrigger(minutes=5))

    # ADD YOUR JOB:
    scheduler.add_job(
        my_daily_job,
        CronTrigger(hour=8, minute=0),
        id="my_daily_job",
        replace_existing=True,
    )

    scheduler.start()
    yield
    scheduler.shutdown()
```

### Job function pattern
```python
async def my_daily_job():
    db = SessionLocal()
    try:
        # Filter by tenant if needed (loop tenants)
        for tenant in db.query(Tenant).filter(Tenant.active == True):
            # Process tenant
            ...
    finally:
        db.close()
```

### Future: move to dedicated worker
If load grows, consider moving APScheduler jobs to a separate Celery/RQ worker process to keep the API responsive.

---

## 12. Frontend State Management / إدارة الحالة في الواجهة

### Riverpod providers (existing)
**File:** `lib/providers/app_providers.dart`

```dart
// READ a provider
class MyScreen extends ConsumerWidget {
  @override
  Widget build(context, ref) {
    final clients = ref.watch(clientsProvider);
    return clients.when(
      data: (list) => ListView(...),
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
    );
  }
}

// INVALIDATE after mutation
await ApiService.createClient(...);
ref.invalidate(clientsProvider);
```

### Adding a new provider
**File:** `lib/providers/app_providers.dart`
```dart
final myDataProvider = FutureProvider.autoDispose<List<MyData>>((ref) async {
  return ApiService.fetchMyData();
});

// With family (parameterized):
final entityResourcesProvider = FutureProvider.autoDispose.family<List<R>, String>((ref, entityId) async {
  return ApiService.listResources(entityId);
});
```

### Session singleton (S)
**File:** `lib/core/session.dart` — read/write user info
```dart
S.token        // current token
S.uid          // user ID
S.uname        // username
S.plan         // 'free'|'pro'|...
S.entityId     // active entity
S.roles        // List<String>
S.save()       // persist
S.clear()      // logout
```

### Theme singleton (AC)
**File:** `lib/core/theme.dart` — read theme
```dart
AC.primary
AC.bg1, AC.bg2, AC.bg3, AC.bg4
AC.textPrimary, AC.textSecondary, AC.textDim
AC.border
AC.success, AC.error, AC.warning, AC.info
AC.isDark   // bool
```

---

## 13. Adding to a Service Hub / الإضافة لمركز خدمة

A "service hub" is a screen at `/{service}` showing tiles for sub-features.

**File pattern:** `lib/core/v5/v5_data.dart` defines hubs.

### To add a tile to existing hub
Find the hub in `v5_data.dart`:
```dart
'sales': ServiceHub(
  id: 'sales',
  title: 'المبيعات',
  tiles: [
    HubTile(id: 'customers', title: 'العملاء', icon: Icons.people, route: '/sales/customers'),
    HubTile(id: 'invoices', title: 'الفواتير', icon: Icons.receipt, route: '/sales/invoices'),
    // ADD YOUR TILE:
    HubTile(
      id: 'statements',
      title: 'كشوف الحساب',
      icon: Icons.description,
      route: '/sales/statements',
      requiredPlan: 'business',
      requiredFeature: 'customer_statement',
    ),
  ],
),
```

The tile auto-renders with lock icon if user's plan doesn't allow.

---

## 14. Useful Code Snippets / مقتطفات مفيدة

### Format SAR currency
```dart
String formatSar(num amount) {
  final formatter = NumberFormat.currency(locale: 'ar_SA', symbol: 'ر.س ', decimalDigits: 2);
  return formatter.format(amount);
}
```

### Format Hijri date alongside Gregorian
```dart
import 'package:hijri/hijri_calendar.dart';

String dualDate(DateTime g) {
  final h = HijriCalendar.fromDate(g);
  return '${DateFormat('d MMMM yyyy', 'ar').format(g)} (${h.hDay} ${h.longMonthName} ${h.hYear})';
}
```

### Validate Saudi VAT number (15 digits, starts with 3)
```python
import re
def is_valid_saudi_vat(v: str) -> bool:
    return bool(re.match(r"^3\d{14}$", v))
```

### Validate Saudi CR number (10 digits)
```python
def is_valid_saudi_cr(v: str) -> bool:
    return bool(re.match(r"^\d{10}$", v))
```

### Compute Zakat (basic)
```python
def compute_zakat(zakat_base: Decimal) -> Decimal:
    """Zakat = 2.5% of net zakatable base."""
    return (zakat_base * Decimal("0.025")).quantize(Decimal("0.01"))
```

### Compute VAT (KSA 15%)
```python
def add_vat_ksa(net: Decimal, rate: Decimal = Decimal("0.15")) -> tuple[Decimal, Decimal]:
    """Returns (vat_amount, total_inc_vat)."""
    vat = (net * rate).quantize(Decimal("0.01"))
    return vat, net + vat
```

---

## 15. End-to-End Example: "Send Invoice via WhatsApp"
## مثال شامل: إرسال فاتورة عبر واتساب

### 1. Backend
**File:** `app/integrations/whatsapp_service.py`
```python
import httpx
from app.core.config import settings

class WhatsAppService:
    BASE = "https://graph.facebook.com/v18.0"

    async def send(self, to: str, message: str, attachment_url: str | None = None):
        if not settings.WHATSAPP_TOKEN:
            logger.warning("WhatsApp not configured")
            return {"sent": False, "reason": "not_configured"}

        async with httpx.AsyncClient() as client:
            payload = {
                "messaging_product": "whatsapp",
                "to": to,
                "type": "text",
                "text": {"body": message},
            }
            if attachment_url:
                payload = {
                    "messaging_product": "whatsapp",
                    "to": to,
                    "type": "document",
                    "document": {"link": attachment_url, "caption": message},
                }
            resp = await client.post(
                f"{self.BASE}/{settings.WHATSAPP_PHONE_ID}/messages",
                headers={"Authorization": f"Bearer {settings.WHATSAPP_TOKEN}"},
                json=payload,
            )
        return {"sent": resp.status_code == 200, "response": resp.json()}
```

**File:** `app/pilot/routes/sales_invoice_routes.py`
```python
@router.post("/sales-invoices/{iid}/send-whatsapp")
async def send_via_whatsapp(
    iid: int,
    user = Depends(require_entitlement("whatsapp_send")),
    db: Session = Depends(get_db),
):
    inv = db.query(SalesInvoice).filter(SalesInvoice.id == iid).first()
    if not inv:
        raise HTTPException(404)
    customer = inv.customer
    if not customer.phone:
        raise HTTPException(400, "Customer phone missing")

    # 1. Generate PDF + upload to storage
    pdf = build_invoice_pdf(inv)
    storage = get_storage()
    url = storage.put(pdf, key=f"invoices/{inv.id}.pdf", content_type="application/pdf")

    # 2. Send WhatsApp
    ws = WhatsAppService()
    result = await ws.send(
        to=customer.phone,
        message=f"فاتورتك من {inv.entity.name} رقم {inv.invoice_number}\nالمبلغ: {format_sar(inv.total)}",
        attachment_url=url,
    )

    # 3. Audit log
    audit_log(db, user, "invoice.sent_whatsapp", resource=f"invoice/{inv.id}")

    # 4. Notify user
    NotificationService(db).emit(
        user_id=user.id,
        type="invoice_sent",
        title="تم إرسال الفاتورة",
        body=f"تم إرسال الفاتورة {inv.invoice_number} للعميل عبر واتساب.",
    )

    return {"success": True, "result": result}
```

### 2. Add entitlement
`app/phase8/services/entitlement_seeder.py` — `whatsapp_send` for Business+ plans.

### 3. Frontend method
`lib/api_service.dart`:
```dart
static Future<bool> sendInvoiceWhatsApp(int invoiceId) async {
  final url = '${ApiConfig.base}/api/v1/pilot/sales-invoices/$invoiceId/send-whatsapp';
  final resp = await _client.post(Uri.parse(url), headers: _authHeaders());
  if (resp.statusCode != 200) throw ApiException(resp.statusCode, resp.body);
  return true;
}
```

### 4. Wire button on invoice screen
```dart
FeatureGate(
  feature: 'whatsapp_send',
  child: IconButton(
    icon: const Icon(Icons.share),
    tooltip: 'إرسال عبر واتساب',
    onPressed: () async {
      try {
        await ApiService.sendInvoiceWhatsApp(invoice.id);
        SnackBar(content: Text('تم الإرسال بنجاح'), bg: AC.success).show(context);
      } catch (e) {
        SnackBar(content: Text('فشل الإرسال: $e'), bg: AC.error).show(context);
      }
    },
  ),
),
```

### 5. Tests
`tests/test_whatsapp_send.py` — mock `WhatsAppService.send`, verify endpoint behavior.

### 6. Update blueprints
- `04_SCREENS_AND_BUTTONS_CATALOG.md` — add row in invoice screen buttons
- `05_API_ENDPOINTS_MASTER.md` — add row in Pilot ERP section
- `06_PERMISSIONS_AND_PLANS_MATRIX.md` — add `whatsapp_send` to Business+ row

---

## 16. Cross-Reference: Where to Find Things / مرجع: أين تجد الأشياء

| Looking for | File / location |
|-------------|-----------------|
| All routes (frontend) | `lib/core/router.dart` |
| All API methods (frontend) | `lib/api_service.dart` |
| Auth check (backend) | `app/core/auth_utils.py::get_current_user` |
| Tenant filter | `app/core/middleware/tenant_context.py` |
| JWT secret | `app/core/auth_utils.py::JWT_SECRET` (env var) |
| Theme colors | `lib/core/theme.dart::AC.*` |
| Session info | `lib/core/session.dart::S.*` |
| API base URL | `lib/core/api_config.dart::ApiConfig.base` |
| HTTP retry | `lib/core/api_retry.dart` |
| Database session | `app/core/db.py::get_db` |
| Audit log helper | `app/core/audit_log.py::audit_log` |
| Notification service | `app/phase10/services/notification_service.py` |
| Copilot service | `app/copilot/services/copilot_service.py` |
| ZATCA service | `app/zatca/services/zatca_service.py` |
| Storage backend | `app/core/storage.py::get_storage` |
| Email backend | `app/core/email.py::get_email_backend` |
| Stripe wrapper | `app/phase8/services/stripe_service.py` |
| Anthropic wrapper | `app/copilot/services/copilot_service.py` |
| Test fixtures | `tests/conftest.py` |
| Existing endpoints catalog | `APEX_BLUEPRINT/05_API_ENDPOINTS_MASTER.md` |
| Existing screens catalog | `APEX_BLUEPRINT/04_SCREENS_AND_BUTTONS_CATALOG.md` |

---

## 17. Final Checklist for Every PR / قائمة التحقق النهائية

Before submitting a PR:

- [ ] All new endpoints listed in `05_API_ENDPOINTS_MASTER.md`
- [ ] All new screens listed in `04_SCREENS_AND_BUTTONS_CATALOG.md`
- [ ] All new routes listed in `03_NAVIGATION_MAP.md`
- [ ] All new permissions listed in `06_PERMISSIONS_AND_PLANS_MATRIX.md`
- [ ] All new tables listed in `07_DATA_MODEL_ER.md`
- [ ] All new TODOs (if any) listed in `09_GAPS_AND_REWORK_PLAN.md`
- [ ] Tests added (`pytest tests/ -v` green)
- [ ] Lint clean (`black`, `ruff`, `bandit`)
- [ ] Tenant isolation verified
- [ ] Plan/role gates applied
- [ ] Audit log emitted for state-changing actions
- [ ] Arabic strings in UI
- [ ] No `import *`
- [ ] No hardcoded URLs
- [ ] No traceback leaks

---

**End of Blueprint Package / نهاية حزمة المخطط**

🎯 **You now have everything Claude Code needs to professionally restructure and complete APEX.**
🎯 **لديك الآن كل ما يحتاجه Claude Code لإعادة هيكلة وإكمال APEX باحتراف.**

Open `index.html` for interactive navigation across all 12 documents.
