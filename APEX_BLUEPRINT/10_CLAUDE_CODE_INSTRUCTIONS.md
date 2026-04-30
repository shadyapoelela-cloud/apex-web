# 10 — Claude Code Executable Playbook / دليل تنفيذي لـ Claude Code

> Reference: continues from `09_GAPS_AND_REWORK_PLAN.md`. Next: `11_INTEGRATION_GUIDE.md`.
> **Audience:** Claude Code (the CLI agent) and senior engineers.
> **Purpose:** Exact, copy-pasteable rules for adding new features without re-inventing structure.

---

## 0. Verify-First Protocol / بروتوكول التحقق أولاً  *(added by G-DOCS-1, Sprint 8)*

> **🟥 Read this before everything else in this file.**
>
> **Code is truth; the blueprint may lag.**
> Sprint 7 found **9 places** where blueprint claims contradicted current code
> reality (gap **G-DOCS-1** § 11 in `09_GAPS_AND_REWORK_PLAN.md` lists them).
> Acting on a stale claim has already caused near-misses including a planned
> `lifespan` swap that would have shipped production with **173 missing
> database tables**, plans to "implement" OAuth and SMS that were already in
> tree (Wave 1 + Wave SMS), and an `.env.example` overwrite that would have
> left every fresh deploy with no env-var template.

### When this protocol applies

For **every** task — feature, refactor, bug-fix, or "just a docs update" —
before you draft a plan, edit a single file, or open a PR.

### The 5-step protocol

1. **Read the gap entry / blueprint section that says the work is needed.**
   Quote the bullet you're about to act on. If a number is cited
   (line count, table count, test count, route count), assume it is stale
   until you verify it.

2. **Grep the cited file paths in the actual repo.** Do not trust
   summaries — open the file. The blueprint will sometimes:
   - claim a feature is "stub" / "missing" when a Wave PR already shipped it
     (see G-B1 Wave 1, G-B2 Wave SMS, G-Z1 Wave 11, G-E1 Wave 13);
   - cite line counts from before a refactor (see G-A1: blueprint had 3500,
     reality was 2146, post-split is 21);
   - cite table counts from before a phase landed (see G-A3: blueprint had
     108, reality is 198 distinct `__tablename__` declarations);
   - reference deleted files (see G-T1.2: `test_flutter_files` still asserts
     `client_onboarding_wizard.dart` which no longer exists).

3. **Run a measurement command** to either confirm or refute the claim:

   | Claim type | Verification command |
   | --- | --- |
   | Line count | `wc -l <path>` (Bash) — or read the file with `Read` |
   | Test count | `pytest tests/ --collect-only -q \| tail -3` |
   | Tables in code | `grep -rE "__tablename__\s*=" app/ \| awk -F\\\" '{print $2}' \| sort -u \| wc -l` |
   | Tables in alembic | `grep -rE "op\.create_table" alembic/versions/ \| wc -l` |
   | Route registered? | `grep -rn "include_router" app/main.py` for the import |
   | File exists? | `ls <path>` or `Glob` the directory |
   | Tests passing? | run that test file directly, do not trust the summary |

4. **Write the verdict next to the original claim**, in the form
   `accurate` / `stale` / `done-but-undocumented`. If `stale` or
   `done-but-undocumented`, fix the doc **in the same PR** that does the
   code work. Do not split a "code fix" PR from its "doc fix" PR — they
   drift again immediately.

5. **If verification reveals a change of scope** (e.g. blueprint asked you
   to "build feature X" and you find feature X already shipped in Wave Y),
   stop, mark the gap as `done-but-undocumented`, and produce a
   doc-only PR closing it. Do **not** "implement" a duplicate.

### Red flags that should trigger this protocol mid-task

- A planned step says *"replace `create_all()` with `alembic upgrade head`"*
  → **stop**, run the table-count check above. If alembic covers <90% of
  declared tables, escalate (see G-A3.1 — DBA review required).
- A planned step says *"the user model needs an `auth_provider` column"*
  → **stop**, grep the model. The column may already exist
  (see `tests/test_core.py::test_user_fields`).
- A planned step says *"add SMS verification"*, *"add Google Sign-In"*,
  *"encrypt ZATCA cert"*, *"add bank feed plumbing"* → **stop**, those are
  in Waves 1 / SMS / 11 / 13 respectively; check first.
- A test list / "critical files" list ships unchanged across multiple PRs
  → **stop**, run a directory walk and compare. `test_flutter_files`
  taught us that.

### Conventional-commit hint

When a PR contains both code and doc fixes from this protocol, the body
should call out the verification done. Example:

```
fix(auth): tighten JWT cookie samesite (#G-S2)

Verify-first findings:
- Blueprint G-S2 claimed cookies were not used → false; CSRF middleware
  is wired but disabled by default (CSRF_ENABLED=false).
- Updated 09 § 5 G-S2 with current state and reduced estimate to 2 days.
```

This makes the PR review trivial: reviewers can replay the verification
without guessing what you saw.

---

## 1. The Golden Rules / القواعد الذهبية

These rules apply to EVERY task. If you violate one, stop and reconsider:

1. **NEVER add classes to `lib/main.dart`.** Create new screens in `lib/screens/{service}/{name}_screen.dart`.
2. **NEVER hardcode the API base URL.** Always import from `lib/core/api_config.dart`.
3. **NEVER call HTTP directly from a screen.** Add a method to `lib/api_service.dart` (or new module file).
4. **NEVER use `import 'module' as *;`** — always explicit imports.
5. **NEVER hardcode `JWT_SECRET`** — use `app/core/auth_utils.py`.
6. **NEVER skip tests.** Every new endpoint gets at least one test in `tests/`.
7. **NEVER leak tracebacks** — use `logging.error()` and return generic `HTTPException`.
8. **NEVER bypass `TenantContextMiddleware`** — every tenant-scoped query must filter by `tenant_id`.
9. **NEVER invent a new auth pattern.** Use `Depends(get_current_user)` or `Depends(require_role(...))`.
10. **NEVER skip the blueprint update.** If you change behavior, update the relevant blueprint file.

---

## 2. Where to Put Things / مكان وضع الأشياء

### Backend / الخلفية

```
app/
├── main.py                          # FastAPI app + lifespan + CORS + middleware (READ-ONLY for new features)
├── core/                            # Cross-cutting: auth, audit log, middleware, db
│   ├── auth_utils.py                # JWT_SECRET, get_current_user, require_role
│   ├── audit_log.py                 # Audit event emission
│   ├── db.py                        # SQLAlchemy session factory
│   └── middleware/
├── phase1/                          # Auth, users, plans, legal — DON'T add new features here
├── phase2/                          # Clients, COA, audit cases
├── phase{N}/
│   ├── models/
│   │   └── {domain}_models.py       # SQLAlchemy models (one file per domain area)
│   ├── routes/
│   │   └── {domain}_routes.py       # FastAPI routers
│   ├── services/
│   │   └── {domain}_service.py      # Business logic
│   └── repositories/
│       └── {domain}_repository.py   # DB access (filter by tenant_id!)
├── pilot/                           # ERP daily ops
├── zatca/                           # ZATCA e-invoicing
├── copilot/                         # AI Copilot orchestration
└── sprint{N}_*/                     # Sprint-based vertical slices
```

### Frontend / الواجهة

```
lib/
├── main.dart                        # ONLY app setup (target < 200 lines after rework)
├── api_service.dart                 # All HTTP calls (will be split per gap G-F8)
├── core/
│   ├── api_config.dart              # Base URL — IMPORT FROM HERE
│   ├── api_retry.dart               # Retry with backoff
│   ├── router.dart                  # All GoRouter routes — REGISTER NEW ROUTES HERE
│   ├── session.dart                 # S singleton
│   ├── theme.dart                   # AC singleton
│   ├── company_store.dart           # Active entity state
│   ├── v5/                          # V5 dynamic shell
│   └── v4/                          # DEPRECATED — don't add to
├── screens/                         # NEW SCREENS GO HERE
│   ├── {service}/                   # Group by service: sales, purchase, etc.
│   │   └── {name}_screen.dart
│   └── widgets/                     # Reusable per-screen widgets
├── widgets/                         # GLOBAL reusable widgets (HybridSidebar, BottomNav, etc.)
│   └── {name}.dart
├── providers/
│   └── app_providers.dart           # Riverpod providers
└── l10n/                            # FUTURE — localization ARB files
```

---

## 3. Adding a New Feature: Step-by-Step / إضافة ميزة جديدة

### Scenario: Add "Customer Statement of Account" feature

**User story:** Client admin clicks button on Customer 360 page → backend generates PDF → user downloads.

#### Step 1: Find existing infrastructure to reuse
Read these blueprint sections:
- `04_SCREENS_AND_BUTTONS_CATALOG.md` § G1 (Customer 360) — confirm screen exists
- `05_API_ENDPOINTS_MASTER.md` — search for "statement" — none → must create new endpoint
- `06_PERMISSIONS_AND_PLANS_MATRIX.md` § 3.4 — Customer 360 = Pro+ feature

#### Step 2: Backend
**Add endpoint:** `app/pilot/routes/customer_routes.py` (already exists for customers)

```python
from fastapi import APIRouter, Depends, Response
from app.core.auth_utils import get_current_user, require_entitlement
from app.pilot.services.statement_service import StatementService

router = APIRouter(prefix="/api/v1/pilot")

@router.get("/customers/{customer_id}/statement")
async def get_customer_statement(
    customer_id: int,
    period_from: str,
    period_to: str,
    format: str = "pdf",
    user = Depends(require_entitlement("customer_statement")),
    svc: StatementService = Depends(),
):
    blob = svc.generate(customer_id, period_from, period_to, format)
    return Response(blob, media_type=f"application/{format}")
```

**Add service:** `app/pilot/services/statement_service.py`

```python
class StatementService:
    def __init__(self, db: Session = Depends(get_db)):
        self.db = db

    def generate(self, customer_id: int, dt_from: str, dt_to: str, fmt: str):
        # 1. Fetch customer (filter by tenant_id - CRITICAL)
        customer = self.db.query(Customer).filter(
            Customer.id == customer_id,
            Customer.tenant_id == get_current_tenant_id(),
        ).first()
        if not customer:
            raise HTTPException(404)

        # 2. Get transactions
        invoices = ...
        payments = ...

        # 3. Render (pdf via reportlab, xlsx via openpyxl)
        ...
```

**Add test:** `tests/test_pilot_statement.py`

```python
def test_customer_statement_pro_user(client_pro, auth_headers):
    resp = client_pro.get("/api/v1/pilot/customers/1/statement?period_from=2026-01-01&period_to=2026-04-30",
                          headers=auth_headers)
    assert resp.status_code == 200
    assert resp.headers["content-type"] == "application/pdf"

def test_customer_statement_free_blocked(client_free, auth_headers):
    resp = client_free.get("/api/v1/pilot/customers/1/statement?...", headers=auth_headers)
    assert resp.status_code == 402
```

**Add entitlement:** `app/phase8/services/entitlement_seeder.py` — add `customer_statement` to Pro+ plans.

#### Step 3: Frontend

**Add API method:** `lib/api_service.dart` — APPEND, don't refactor:

```dart
static Future<Uint8List> getCustomerStatement(
  int customerId, {
  required String from,
  required String to,
  String format = 'pdf',
}) async {
  final url = '${ApiConfig.base}/api/v1/pilot/customers/$customerId/statement?period_from=$from&period_to=$to&format=$format';
  final resp = await _client.get(Uri.parse(url), headers: _authHeaders());
  if (resp.statusCode != 200) throw ApiException(resp.statusCode, resp.body);
  return resp.bodyBytes;
}
```

**Wire button on Customer 360:** `lib/screens/operations/customer_360_screen.dart`

Find the AppBar actions:
```dart
AppBar(
  title: Text('عرض العميل ${customer.name}'),
  actions: [
    FeatureGate(  // From lib/widgets/feature_gate.dart
      feature: 'customer_statement',
      child: IconButton(
        icon: const Icon(Icons.description),
        tooltip: 'كشف حساب',
        onPressed: () => _downloadStatement(),
      ),
    ),
    // ... existing buttons
  ],
),

Future<void> _downloadStatement() async {
  final from = await showDateRangePicker(...);
  if (from == null) return;
  try {
    final bytes = await ApiService.getCustomerStatement(
      widget.customerId, from: from.start.toIso(), to: from.end.toIso(),
    );
    await downloadBytesAsFile(bytes, 'statement-${customer.name}.pdf');
    SnackBar(content: Text('تم تنزيل كشف الحساب بنجاح')).show(context);
  } catch (e) {
    SnackBar(content: Text('فشل التنزيل: $e'), bg: AC.error).show(context);
  }
}
```

#### Step 4: Update Blueprint

- `04_SCREENS_AND_BUTTONS_CATALOG.md` § G1 — add "Statement of Account" button row
- `05_API_ENDPOINTS_MASTER.md` § Pilot ERP — add `GET /api/v1/pilot/customers/{id}/statement`
- `06_PERMISSIONS_AND_PLANS_MATRIX.md` § 3.4 — add `customer_statement` row

#### Step 5: Test

```bash
cd /sessions/inspiring-cool-archimedes/mnt/apex_app
pytest tests/test_pilot_statement.py -v
```

#### Step 6: Commit

```bash
git add app/pilot/services/statement_service.py
git add app/pilot/routes/customer_routes.py
git add lib/screens/operations/customer_360_screen.dart
git add lib/api_service.dart
git add tests/test_pilot_statement.py
git add APEX_BLUEPRINT/04_SCREENS_AND_BUTTONS_CATALOG.md
git add APEX_BLUEPRINT/05_API_ENDPOINTS_MASTER.md
git add APEX_BLUEPRINT/06_PERMISSIONS_AND_PLANS_MATRIX.md
git commit -m "feat: customer statement of account (#sprint8)

- New endpoint GET /api/v1/pilot/customers/{id}/statement
- PDF generation via reportlab
- Pro+ entitlement gate
- Customer 360 button with FeatureGate

Refs: APEX_BLUEPRINT/06 § 3.4"
```

---

## 4. Adding a New Route / إضافة مسار جديد

### Where to register
**File:** `lib/core/router.dart`

### Pattern
```dart
GoRoute(
  path: '/{service}/{feature}',  // NOT /app/* — use direct path for service routes
  pageBuilder: (ctx, state) => _apexPage(
    ctx, state,
    const MyNewScreen(),
  ),
),
```

### Auth/role guards
Default: route is JWT-protected via global redirect logic. To add role check:

```dart
GoRoute(
  path: '/admin/something',
  pageBuilder: (ctx, state) => _apexPage(
    ctx, state,
    const RoleGate(
      roles: ['admin', 'super_admin'],
      child: MyAdminScreen(),
    ),
  ),
),
```

### Plan check
```dart
GoRoute(
  path: '/feature',
  pageBuilder: (ctx, state) => _apexPage(
    ctx, state,
    const FeatureGate(
      feature: 'feature_code',
      child: MyFeatureScreen(),
      fallback: UpgradePromptScreen(featureName: 'My Feature'),
    ),
  ),
),
```

### Update blueprint
- `03_NAVIGATION_MAP.md` — add row in appropriate section
- `04_SCREENS_AND_BUTTONS_CATALOG.md` — add screen entry

---

## 5. Adding a New API Endpoint / إضافة نقطة API

### Decide which phase/sprint
- New auth feature? → Phase 1 ⚠️ (be careful, it's foundational)
- New client/COA feature? → Phase 2 or Sprint 1-3
- New analysis feature? → Sprint 5
- New ERP feature? → `app/pilot/`
- New compliance/tax feature? → `app/{module}/` (or new module)
- AI / Copilot feature? → `app/copilot/`

### File pattern
**Routes:** `app/{module}/routes/{domain}_routes.py`
```python
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.auth_utils import get_current_user
from app.core.db import get_db

router = APIRouter(prefix="/api/v1/{module}", tags=["{module}"])

@router.post("/{resource}", response_model=ResourceOut, status_code=201)
async def create_resource(
    payload: ResourceIn,
    user = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # 1. Permission check (if not via Depends)
    if "client_admin" not in user._roles:
        raise HTTPException(403)

    # 2. Validate
    ...

    # 3. Persist
    obj = Resource(**payload.dict(), tenant_id=user.tenant_id)
    db.add(obj)
    db.commit()
    db.refresh(obj)

    # 4. Audit log
    audit_log(db, user, "resource.created", resource_id=obj.id)

    # 5. Return
    return ResourceOut.from_orm(obj)
```

### Register in main.py
**File:** `app/main.py`
Find the phase loading block:
```python
try:
    from app.{module}.routes.{domain}_routes import router as my_router
    app.include_router(my_router)
    HAS_MY_MODULE = True
except ImportError as e:
    logger.warning(f"My module not loaded: {e}")
    HAS_MY_MODULE = False
```

### Add Pydantic schemas
**File:** `app/{module}/schemas/{domain}_schemas.py`
```python
from pydantic import BaseModel, Field
from datetime import datetime

class ResourceIn(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    amount: float

class ResourceOut(BaseModel):
    id: int
    name: str
    amount: float
    created_at: datetime
    class Config:
        from_attributes = True
```

### Add service & repository
- **Service:** business logic, may call multiple repositories
- **Repository:** raw DB access, ALWAYS filter by `tenant_id`

### Test
**File:** `tests/test_{module}_{domain}.py`
```python
def test_create_resource(client, auth_headers):
    resp = client.post("/api/v1/{module}/{resource}",
                      json={"name": "test", "amount": 100.0},
                      headers=auth_headers)
    assert resp.status_code == 201
    data = resp.json()
    assert data["name"] == "test"
    assert "id" in data

def test_create_resource_no_auth(client):
    resp = client.post("/api/v1/{module}/{resource}", json={...})
    assert resp.status_code == 401

def test_create_resource_wrong_role(client, basic_user_headers):
    resp = client.post("/api/v1/{module}/{resource}", json={...},
                      headers=basic_user_headers)
    assert resp.status_code == 403
```

### Update blueprint
- `05_API_ENDPOINTS_MASTER.md` — add row in appropriate phase section

---

## 6. Adding a New Screen / إضافة شاشة جديدة

### Decision tree
1. Where does it belong? → `lib/screens/{service}/{name}_screen.dart`
2. What's the route? → `/service/feature` or `/app/service/feature/sub`
3. What permissions? → role gate / plan gate
4. What API does it call? → confirm endpoint exists in `05_API_ENDPOINTS_MASTER.md`

### Template
**File:** `lib/screens/sales/my_new_screen.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:apex_finance/api_service.dart';
import 'package:apex_finance/core/theme.dart';
import 'package:apex_finance/core/session.dart';

class MyNewScreen extends ConsumerStatefulWidget {
  const MyNewScreen({super.key});
  @override
  ConsumerState<MyNewScreen> createState() => _State();
}

class _State extends ConsumerState<MyNewScreen> {
  bool _loading = false;
  List<MyData> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.fetchMyData();
      setState(() => _items = data);
    } catch (e) {
      _showError('فشل تحميل البيانات: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AC.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.bg1,
        appBar: AppBar(
          title: const Text('عنوان الشاشة'),
          backgroundColor: AC.bg2,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const EmptyState(message: 'لا توجد بيانات بعد')
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (_, i) => MyCard(item: _items[i]),
                  ),
        floatingActionButton: FloatingActionButton(
          onPressed: _onAdd,
          backgroundColor: AC.primary,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _onAdd() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MyAddScreen()));
  }
}
```

### Register route
**File:** `lib/core/router.dart`

### Update blueprint
- `03_NAVIGATION_MAP.md`
- `04_SCREENS_AND_BUTTONS_CATALOG.md`

---

## 7. Adding a New Database Model / إضافة نموذج بيانات

**File:** `app/{module}/models/{domain}_models.py`

```python
from sqlalchemy import Column, String, DateTime, ForeignKey, Numeric, Integer, Boolean
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
from app.core.db import Base

class Resource(Base):
    __tablename__ = "resources"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id = Column(UUID(as_uuid=True), nullable=False, index=True)  # CRITICAL
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    name = Column(String(200), nullable=False)
    amount = Column(Numeric(18, 2), nullable=False, default=0)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)
    is_deleted = Column(Boolean, default=False, index=True)

    user = relationship("User", back_populates="resources")
```

### Migration
After model change:
```bash
cd /sessions/inspiring-cool-archimedes/mnt/apex_app
alembic revision --autogenerate -m "add Resource table"
alembic upgrade head
```

### Update blueprint
- `07_DATA_MODEL_ER.md` — add ER diagram entry

---

## 8. AI / Copilot Integration / تكامل المساعد

### When to use Anthropic Claude
- Free-form text understanding
- Document classification
- Summarization
- Generative responses to user queries

### When NOT to use
- Numeric calculations (use Python directly)
- Deterministic logic (rules engine)
- Where result must be reproducible

### Pattern
**File:** `app/copilot/services/my_ai_service.py`
```python
from anthropic import Anthropic
from app.core.config import settings

class MyAIService:
    def __init__(self):
        self.client = Anthropic(api_key=settings.ANTHROPIC_API_KEY)

    def classify(self, text: str) -> dict:
        if not settings.ANTHROPIC_API_KEY:
            return self._fallback(text)

        try:
            msg = self.client.messages.create(
                model="claude-sonnet-4-6",
                max_tokens=1024,
                system="You are a financial accounting expert. Classify the given account name into IFRS category.",
                messages=[{"role": "user", "content": text}],
            )
            return {"category": msg.content[0].text.strip(), "confidence": 0.9}
        except Exception as e:
            logger.error(f"Claude API error: {e}")
            return self._fallback(text)

    def _fallback(self, text: str) -> dict:
        # Hardcoded heuristic
        ...
```

### Track tokens
Always log to `AICostLog` table for tenant attribution (see Gap G-AI2).

---

## 9. ZATCA Integration / تكامل ZATCA

### When invoice is issued
Hook into the sales invoice issue flow:

**File:** `app/pilot/services/sales_invoice_service.py`
```python
def issue(self, invoice_id: UUID, user: User):
    invoice = self.db.query(SalesInvoice).filter(...).first()
    invoice.status = "issued"

    # ZATCA integration
    if user.tenant.zatca_phase2_enabled:
        from app.zatca.services.zatca_service import ZatcaService
        ZatcaService(self.db).enqueue_or_clear(invoice)

    self.db.commit()
```

### Adding new invoice type to ZATCA
**File:** `app/zatca/services/ubl_builder.py`
- Update `_build_xml()` to handle new invoice type
- Update QR builder if mandatory fields differ
- Test against Fatoora sandbox first

### Production cutover
- Set `ZATCA_BASE_URL=https://gw-fatoora.zatca.gov.sa/...` (NOT sandbox)
- Ensure PCSID is production-issued
- Monitor `/zatca/queue/stats` daily

---

## 10. Testing / الاختبارات

### Run all tests
```bash
cd /sessions/inspiring-cool-archimedes/mnt/apex_app
pytest tests/ -v --cov=app --cov-report=term-missing
```

### Add a new test file
**File:** `tests/test_my_feature.py`
```python
import pytest
from fastapi.testclient import TestClient
from app.main import app

@pytest.fixture
def client():
    return TestClient(app)

@pytest.fixture
def auth_headers(client):
    resp = client.post("/auth/login", json={"username": "shady", "password": "Aa@123456"})
    token = resp.json()["data"]["access_token"]
    return {"Authorization": f"Bearer {token}"}

def test_my_feature(client, auth_headers):
    ...
```

### CI runs on every push
**File:** `.github/workflows/ci.yml` — adds Black, Ruff, Bandit, pytest, coverage.

If your change breaks lint:
```bash
black app/ tests/ --line-length 120
ruff check app/ tests/ --fix
```

---

## 11. Common Patterns / أنماط شائعة

### A. Paginated list endpoint
```python
@router.get("")
async def list_items(
    page: int = 1,
    page_size: int = 50,
    user = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    q = db.query(Item).filter(Item.tenant_id == user.tenant_id)
    total = q.count()
    items = q.offset((page - 1) * page_size).limit(page_size).all()
    return {"items": items, "total": total, "page": page, "page_size": page_size}
```

### B. File upload endpoint
```python
@router.post("/upload")
async def upload_file(
    file: UploadFile = File(...),
    user = Depends(get_current_user),
):
    if not file.filename.endswith((".xlsx", ".xls", ".csv")):
        raise HTTPException(400, "Invalid file type")
    if file.size > 10 * 1024 * 1024:
        raise HTTPException(413, "File too large (max 10MB)")
    content = await file.read()
    # Save to storage backend
    storage = get_storage()
    url = storage.put(content, key=f"uploads/{user.tenant_id}/{file.filename}")
    return {"url": url}
```

### C. Background task (lifespan-managed)
```python
# In app/main.py lifespan:
@asynccontextmanager
async def lifespan(app: FastAPI):
    scheduler = AsyncIOScheduler()
    scheduler.add_job(zatca_queue_processor, IntervalTrigger(minutes=1))
    scheduler.add_job(daily_recurring_invoices, CronTrigger(hour=8))
    scheduler.start()
    yield
    scheduler.shutdown()
```

### D. Stripe webhook
```python
@router.post("/stripe/webhook")
async def stripe_webhook(request: Request, db: Session = Depends(get_db)):
    payload = await request.body()
    sig = request.headers.get("stripe-signature")
    try:
        event = stripe.Webhook.construct_event(
            payload, sig, settings.STRIPE_WEBHOOK_SECRET
        )
    except stripe.error.SignatureVerificationError:
        raise HTTPException(400, "Invalid signature")
    if event.type == "customer.subscription.updated":
        ...
```

---

## 12. Pitfalls to Avoid / أخطاء شائعة

### ❌ Bad: SQL injection
```python
db.execute(f"SELECT * FROM users WHERE email = '{email}'")
```
### ✅ Good
```python
db.query(User).filter(User.email == email).first()
```

### ❌ Bad: Missing tenant filter
```python
return db.query(Customer).all()  # leaks ALL tenants!
```
### ✅ Good
```python
return db.query(Customer).filter(Customer.tenant_id == user.tenant_id).all()
```

### ❌ Bad: Leak traceback to client
```python
try:
    ...
except Exception as e:
    return {"error": str(e), "traceback": traceback.format_exc()}
```
### ✅ Good
```python
try:
    ...
except Exception as e:
    logger.exception("Error in resource creation")
    raise HTTPException(500, "Internal server error")
```

### ❌ Bad: Hardcoded URL
```dart
final url = 'https://apex-api.onrender.com/api/v1/...';
```
### ✅ Good
```dart
final url = '${ApiConfig.base}/api/v1/...';
```

### ❌ Bad: Skipping retry on cold start
```dart
final resp = await http.get(url);
```
### ✅ Good
```dart
final resp = await ApiRetry.run(() => http.get(url));
```

### ❌ Bad: Forgetting `dispose()`
```dart
final ctrl = TextEditingController();  // leaks
```
### ✅ Good
```dart
final ctrl = TextEditingController();
@override
void dispose() {
  ctrl.dispose();
  super.dispose();
}
```

---

## 13. Reading Order for New Engineer / ترتيب القراءة لمهندس جديد

1. `00_MASTER_INDEX.md` (this folder)
2. `01_ARCHITECTURE_OVERVIEW.md` — understand the layers
3. `02_USER_JOURNEYS_FLOWCHART.md` — what users do
4. `03_NAVIGATION_MAP.md` — frontend route structure
5. `06_PERMISSIONS_AND_PLANS_MATRIX.md` — RBAC model
6. `10_CLAUDE_CODE_INSTRUCTIONS.md` — this file
7. Then dive into code: `app/main.py`, `lib/main.dart`, `lib/core/router.dart`

**Allow at least 1 day for reading before writing code.**

---

## 14. Daily Operations / العمليات اليومية

### Run backend locally
```bash
cd /sessions/inspiring-cool-archimedes/mnt/apex_app
pip install -r requirements.txt --break-system-packages
export JWT_SECRET="dev-secret-change-me"
export ADMIN_SECRET="dev-admin"
uvicorn app.main:app --reload --port 8000
```

### Run frontend locally
```bash
cd /sessions/inspiring-cool-archimedes/mnt/apex_app/apex-web  # or wherever
flutter pub get
flutter run -d chrome --dart-define=API_BASE=http://127.0.0.1:8000
```

### Run all tests
```bash
pytest tests/ -v --cov=app --cov-report=term-missing
```

### Lint & format
```bash
black app/ tests/ --line-length 120
ruff check app/ tests/ --fix
bandit -r app/ -ll
```

### Generate Alembic migration (after fix G-A3)
```bash
alembic revision --autogenerate -m "describe change"
alembic upgrade head
```

---

## 15. When in Doubt / عند الشك

**EN:** If you're unsure about anything, follow this priority:
1. Check the relevant blueprint section
2. Look for similar existing pattern in code (`grep` for similar feature)
3. Read existing tests for examples
4. Ask: "Does this fit Pattern 1-12 from `08_GLOBAL_BENCHMARKS.md`?"
5. If still stuck, write a one-line summary in `09_GAPS_AND_REWORK_PLAN.md` § ad-hoc and proceed with best judgment.

**AR:** عند الشك في أي شئ، اتبع هذه الأولويات:
1. راجع قسم المخطط ذو الصلة
2. ابحث عن نمط مشابه في الكود (`grep` للميزة المشابهة)
3. اقرأ الاختبارات الموجودة كأمثلة
4. اسأل: "هل يتناسب هذا مع نمط 1-12 من `08_GLOBAL_BENCHMARKS.md`؟"
5. إذا لا تزال عالقاً، اكتب ملخصاً من سطر في `09_GAPS_AND_REWORK_PLAN.md` § مخصص ثم تابع بأفضل اجتهاد.

---

**Continue → `11_INTEGRATION_GUIDE.md`**
