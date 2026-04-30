# FRAPPE FRAMEWORK: DEEP-DIVE ARCHITECTURAL PATTERNS

**Research Date:** 2026-04-30  
**Target Application:** APEX Financial Platform (FastAPI + Flutter Web)  
**Goal:** Extract Frappe/ERPNext patterns applicable to APEX's scalable, extensible SaaS architecture

---

## EXECUTIVE SUMMARY

Frappe is a full-stack web framework built on Python (Flask/Werkzeug) and JavaScript, powering ERPNext (open-source ERP). Its core genius is **metadata-driven architecture**: business logic, permissions, workflows, and UI are defined *as data*, not code. This enables non-technical teams to customize systems without code changes. APEX can adopt 3-4 critical Frappe patterns to become far more extensible and maintainable than today's hard-coded phase architecture.

**Key insight:** Frappe separates *declarations* (metadata) from *behavior* (code). APEX currently conflates them: adding a new field requires Python model changes + TypeScript UI changes + permission logic + workflow adjustments. Frappe moves this to configuration.

---

## 1. DOCTYPE PATTERN — THE CORE ABSTRACTION

### 1.1 What Is a DocType?

A **DocType** is Frappe's answer to "What is an entity in this business?" It's a declarative specification of:
- **Fields** (columns): name, type, validation, visibility, defaults, links
- **Permissions** (roles): who reads/writes/creates/submits/deletes
- **Naming** (auto-increment): `SI-2026-00001`, `INV-001`, `CUST-ABC-001`
- **Workflows** (state machine): Draft → Pending → Approved
- **Lifecycle events** (hooks): before/after save, on submit, on amend
- **UI metadata**: form layout, list view columns, report filters, print formats
- **Relationships**: Link, Table (one-to-many), Many-to-Many

**Example: Invoice DocType (JSON metadata)**
```json
{
  "name": "Invoice",
  "doctype": "DocType",
  "fields": [
    {
      "fieldname": "invoice_number",
      "fieldtype": "Data",
      "label": "Invoice #",
      "unique": 1,
      "reqd": 1
    },
    {
      "fieldname": "customer",
      "fieldtype": "Link",
      "options": "Customer",
      "reqd": 1
    },
    {
      "fieldname": "invoice_date",
      "fieldtype": "Date",
      "reqd": 1
    },
    {
      "fieldname": "items",
      "fieldtype": "Table",
      "options": "Invoice Item"
    },
    {
      "fieldname": "total_amount",
      "fieldtype": "Currency",
      "formula": "sum(items.amount)"
    },
    {
      "fieldname": "status",
      "fieldtype": "Select",
      "options": "Draft\nSubmitted\nCancelled",
      "default": "Draft"
    }
  ],
  "permissions": [
    {
      "role": "Accounts User",
      "read": 1,
      "write": 1,
      "create": 1,
      "submit": 1
    },
    {
      "role": "Manager",
      "read": 1,
      "write": 0,
      "amend": 1
    }
  ]
}
```

The metadata file (usually JSON or Python) is loaded once at startup. The framework auto-generates:
- SQLAlchemy models (or equivalent ORM)
- CRUD API endpoints
- Form UI (via Meta)
- Permission checks
- Validation logic

### 1.2 Field Types in Frappe

| Type | Purpose | Storage | Example |
|------|---------|---------|---------|
| `Data` | String (255 chars) | VARCHAR(255) | Email, phone, name |
| `Long Text` | Text (unlimited) | TEXT | Descriptions, notes |
| `Integer` | Whole numbers | INTEGER | Count, qty |
| `Currency` | Monetary (2 decimals) | DECIMAL(19,2) | Amounts, prices |
| `Date` | YYYY-MM-DD | DATE | Invoice date, due date |
| `Datetime` | Timestamp | TIMESTAMP | Created at, updated at |
| `Link` | Foreign key to another DocType | VARCHAR(255) FK | Customer → Customer.name |
| `Table` | One-to-many (repeating rows) | Separate table + parent_id | Invoice → Invoice Items |
| `Select` | Dropdown (fixed options) | ENUM or VARCHAR with validation | Status (Draft/Active/Closed) |
| `Multiselect` | Multiple select | JSON or separate junction table | Tags, categories |
| `Float` | Decimal numbers | FLOAT | Tax rates, percentages |
| `Checkbox` | Boolean | BOOLEAN | Is active, is system |
| `Attach` | File upload | VARCHAR(255) path | Invoice PDF, attachment |
| `Rating` | Star rating | INTEGER 0-5 | Customer satisfaction |
| `Geolocation` | GPS coordinates | GEOMETRY (PostGIS) | Store location |
| `Color` | Hex color | VARCHAR(7) | Status colors |

### 1.3 Naming Conventions

Frappe supports **naming series** — auto-generated names with patterns:

```
SI-{YYYY}-{MM}-{#####}  → SI-2026-04-00001 (Sales Invoice)
PO-{YYYY}{#####}        → PO-202600023 (Purchase Order)
CUST-{###}              → CUST-001 (Customer)
EMP-{}{YYYY}            → EMP-RAJ2026 (Employee)
```

Each DocType specifies a `naming_series` field (hidden from user) that increments. Alternatively, use `name_field` to set the primary key to a user-entered field (e.g., Customer.customer_name).

**APEX parallel:** Currently, naming is ad-hoc (UUID, integer ID). A naming series would enable consistent, human-readable IDs like `ENG-2026-00042` (Audit Engagement) or `WP-2026-00042-001` (Workpaper).

### 1.4 Metadata-Driven UI: Forms Auto-Generated from DocType

When you load a form in Frappe, the front-end requests the **DocType metadata** and renders it dynamically:

```javascript
// Pseudo-code: Frappe Web Client
frappe.get_route_buttons = function() {
  const doctype_meta = frappe.get_meta('Invoice');
  const form = new frappe.ui.form.Form({
    doctype: 'Invoice',
    name: 'SI-2026-00001',
    meta: doctype_meta
  });
  
  // Render fields dynamically
  doctype_meta.fields.forEach(f => {
    form.add_field(f.fieldname, f.fieldtype, f.options);
  });
  
  // Apply permissions
  doctype_meta.permissions.forEach(p => {
    if (p.role == frappe.session.user_roles) {
      form.set_read_only(!p.write);
    }
  });
};
```

**Why this is powerful:**
- Add a field to Invoice → all users see it without deploying code
- Change permission rules → instant effect, no app redeployment
- Run a script on save → no code deployment needed

### 1.5 Mapping DocType → SQL Table

Frappe's ORM maps DocTypes to tables automatically:

```python
# models/doctype/invoice.py (auto-generated)
class Invoice(Document):
    """Frappe DocType → SQLAlchemy Model"""
    def autoname(self):
        self.name = make_autoname(self.meta.get_field('naming_series').options)
    
    def validate(self):
        # Auto-run field validations from meta.fields
        for field in self.meta.fields:
            if field.fieldtype == 'Link':
                self.validate_link_field(field.fieldname, field.options)
    
    def on_submit(self):
        # Change status to Submitted
        self.db_set('status', 'Submitted')
        self.db_set('submitted_on', now())

# Generated SQL:
# CREATE TABLE invoice (
#   name VARCHAR(255) PRIMARY KEY,
#   customer VARCHAR(255) NOT NULL,
#   invoice_date DATE NOT NULL,
#   total_amount DECIMAL(19,2),
#   status VARCHAR(50),
#   created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
#   modified TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
#   owner VARCHAR(255),
#   ...
# );
```

### 1.6 Why DocType Is Genius for SaaS Extensibility

1. **Rapid customization** — Add a field in UI, no code deploy
2. **Multi-tenant flexibility** — Each tenant can add custom fields / custom DocTypes
3. **Audit trail** — All metadata changes are versioned
4. **Non-technical users** — Finance teams configure workflows without coding
5. **Consistency** — Validation, permissions, naming all centralized
6. **AI integration** — Copilot can read DocType metadata to understand schema

**Downside:** Performance overhead (metadata loaded every request) and complexity for developers.

### 1.7 How APEX Should Adopt DocType

**Current APEX approach:**
```python
# app/phase1/models/audit_engagement.py
class AuditEngagement(Base):
    __tablename__ = "audit_engagement"
    id: int = Column(Integer, primary_key=True)
    engagement_number: str = Column(String(50), unique=True)
    client_id: int = Column(Integer, ForeignKey("client.id"))
    status: str = Column(String(20), default="draft")
    # ... 20 more fields hardcoded

# app/phase1/routes/audit_engagement_routes.py
@router.post("/audit-engagements/")
def create_engagement(data: AuditEngagementCreate):
    # Manual validation
    if not data.client_id:
        raise ValueError("client_id required")
    # Manual permission check
    if user.role not in ['Engagement Manager', 'Admin']:
        raise HTTPException(status_code=403)
    # Manual workflow
    eng = AuditEngagement(status='draft', ...)
    db.add(eng)
    db.commit()
    return {"success": True, "data": eng}
```

**Frappe approach (APEX should adopt):**
```python
# app/metadata/doctypes/audit_engagement.json
{
  "name": "Audit Engagement",
  "doctype": "DocType",
  "fields": [
    {"fieldname": "engagement_number", "fieldtype": "Data", "unique": 1, "reqd": 1},
    {"fieldname": "client", "fieldtype": "Link", "options": "Client", "reqd": 1},
    {"fieldname": "partner_in_charge", "fieldtype": "Link", "options": "User"},
    {"fieldname": "engagement_status", "fieldtype": "Select", "options": "Draft\nProposed\nActive\nClosed", "default": "Draft"},
    {"fieldname": "fee_amount", "fieldtype": "Currency"},
    {"fieldname": "scope_of_work", "fieldtype": "Long Text"},
    {"fieldname": "workpapers", "fieldtype": "Table", "options": "Audit Workpaper"}
  ],
  "permissions": [
    {"role": "Engagement Manager", "read": 1, "write": 1, "submit": 1},
    {"role": "Senior Manager", "read": 1, "write": 0, "amend": 1},
    {"role": "Client", "read": 1, "write": 0}
  ],
  "naming_series": "ENG-{YYYY}-{#####}"
}

# Auto-generated SQLAlchemy model at startup
# Auto-generated REST endpoints at startup
# Auto-generated form metadata at startup
```

**Implementation steps for APEX:**
1. Create `app/core/doctype_registry.py` — loads all DocType JSONs at startup
2. Extend `app/core/base_model.py` — SQLAlchemy models inherit from `DocTypeModel`
3. Auto-generate routes via `app/core/auto_routes.py` — CRUD endpoints created per DocType
4. Frontend `core/meta_service.dart` — requests DocType metadata, renders forms dynamically
5. Tenant customization via `custom_fields` table — store JSON of added fields per tenant

---

## 2. PERMISSION MODEL — FRAPPE'S RBAC

### 2.1 Role-Based Access Control (RBAC) per DocType

Frappe's permission system has **7 permission levels per DocType per role:**

| Level | Meaning | Use Case |
|-------|---------|----------|
| `read` | Can view record | Viewer role |
| `write` | Can edit fields (not submit) | Preparer role |
| `create` | Can create new records | Data entry |
| `submit` | Can move to submitted state | Manager approval |
| `amend` | Can modify submitted records | Corrections post-approval |
| `cancel` | Can cancel submitted records | Reversals |
| `delete` | Can permanently delete | Admin cleanup |

**Example: Invoice permissions**
```json
{
  "permissions": [
    {
      "role": "Accountant",
      "read": 1,
      "write": 1,
      "create": 1,
      "submit": 0,
      "amend": 0,
      "cancel": 0,
      "delete": 0
    },
    {
      "role": "Manager",
      "read": 1,
      "write": 0,
      "create": 0,
      "submit": 1,
      "amend": 1,
      "cancel": 1,
      "delete": 0
    }
  ]
}
```

### 2.2 User Permissions (Record-Level Filtering)

Beyond DocType-level RBAC, Frappe supports **record-level permissions** via `User Permission`:

```json
{
  "doctype": "User Permission",
  "user": "john@company.com",
  "allow": "Customer",
  "for_value": "ABC Corp"
}
```

This means John can only see/edit records linked to Customer="ABC Corp". Queries are auto-filtered:
```sql
SELECT * FROM invoice WHERE customer = 'ABC Corp'  -- John's view
SELECT * FROM invoice                              -- Manager's view
```

**Use case in APEX:**
```json
{
  "doctype": "User Permission",
  "user": "audit_partner@client.com",
  "allow": "Audit Engagement",
  "for_value": "ENG-2026-00042"
}
```

Partner can only see ENG-2026-00042's workpapers.

### 2.3 Permission-as-Data (Configurable, Not Coded)

**Frappe's genius:** Permissions live in the database, not code.

```python
# Frappe core (simplified)
def has_permission(user, doctype, action, doc=None):
    """
    Returns True if user has permission to perform action on doctype/doc.
    Checks:
    1. DocType-level permission (roles)
    2. User permissions (record filters)
    3. Field-level permissions (read-only for some roles)
    """
    # Step 1: Get user's roles
    roles = frappe.get_roles(user)
    
    # Step 2: Query permission table
    perms = frappe.db.get_all(
        'DocType Permission',
        filters={'doctype': doctype, 'role': roles},
        fields=[action]  # 'read', 'write', 'submit', etc.
    )
    
    if not perms or not perms[0][action]:
        return False
    
    # Step 3: Check user permissions (record-level)
    if doc and action != 'create':
        user_perms = frappe.db.get_all(
            'User Permission',
            filters={'user': user, 'allow': doctype, 'for_value': doc.name},
        )
        if not user_perms:
            return False
    
    return True

# Usage in routes
@frappe.route('/api/invoice/<name>', methods=['GET'])
def get_invoice(name):
    if not has_permission(frappe.session.user, 'Invoice', 'read', name):
        raise frappe.PermissionError()
    invoice = frappe.get_doc('Invoice', name)
    return invoice.as_dict()
```

### 2.4 Field-Level Permissions

Individual fields can be restricted per role:

```json
{
  "fieldname": "internal_notes",
  "fieldtype": "Long Text",
  "read_only_except": ["Manager", "Admin"]  // Only these roles can edit
}
```

### 2.5 How APEX Should Adopt This Permission Model

**Current APEX approach:**
```python
# app/core/auth_utils.py
def require_role(*roles):
    def decorator(func):
        def wrapper(*args, **kwargs):
            if current_user.role not in roles:
                raise HTTPException(status_code=403)
            return func(*args, **kwargs)
        return wrapper
    return decorator

# Usage
@router.get("/audit-engagements/{engagement_id}")
@require_role("Engagement Manager", "Admin")
def get_engagement(engagement_id: int):
    eng = db.query(AuditEngagement).get(engagement_id)
    return eng
```

**Frappe-inspired APEX approach:**
```python
# app/core/permission_model.py
class Permission(Base):
    """DocType-level permissions"""
    __tablename__ = "permissions"
    id: int = Column(Integer, primary_key=True)
    doctype: str = Column(String(100))
    role: str = Column(String(100))
    read: bool = Column(Boolean, default=False)
    write: bool = Column(Boolean, default=False)
    create: bool = Column(Boolean, default=False)
    submit: bool = Column(Boolean, default=False)
    amend: bool = Column(Boolean, default=False)
    delete: bool = Column(Boolean, default=False)

class UserPermission(Base):
    """Record-level permissions"""
    __tablename__ = "user_permissions"
    id: int = Column(Integer, primary_key=True)
    user_id: int = Column(Integer, ForeignKey("user.id"))
    doctype: str = Column(String(100))
    record_name: str = Column(String(255))

# app/core/permission_engine.py
def has_permission(user: User, doctype: str, action: str, doc_name: str = None) -> bool:
    """Check DocType and record-level permissions"""
    # Step 1: Check DocType-level permission
    doctype_perm = db.query(Permission).filter(
        Permission.doctype == doctype,
        Permission.role.in_(user.roles)
    ).first()
    
    if not doctype_perm or not getattr(doctype_perm, action):
        return False
    
    # Step 2: Check record-level permission
    if doc_name:
        record_perm = db.query(UserPermission).filter(
            UserPermission.user_id == user.id,
            UserPermission.doctype == doctype,
            UserPermission.record_name == doc_name
        ).first()
        
        if not record_perm:
            return False
    
    return True

# Usage in routes
@router.get("/api/audit-engagement/{engagement_id}")
async def get_engagement(engagement_id: str, current_user: User = Depends(get_current_user)):
    if not has_permission(current_user, "Audit Engagement", "read", engagement_id):
        raise HTTPException(status_code=403, detail="Permission denied")
    
    engagement = db.query(AuditEngagement).filter(
        AuditEngagement.engagement_number == engagement_id
    ).first()
    return engagement

# Frontend applies permissions
@router.get("/api/meta/Audit Engagement")
async def get_doctype_meta(current_user: User):
    """Return metadata only for fields user can access"""
    meta = db.query(DocTypeMeta).filter(...).first()
    
    # Filter fields based on role
    allowed_fields = []
    for field in meta.fields:
        if has_permission(current_user, "Audit Engagement", "read", field.name):
            allowed_fields.append(field)
    
    meta.fields = allowed_fields
    return meta
```

### 2.6 Benefits for APEX

1. **Centralized permission logic** — not scattered across routes
2. **Tenant-specific customization** — clients can assign permissions without code changes
3. **Audit trail** — permission changes logged
4. **Field masking** — sensitive data (partner margin %) hidden from junior users
5. **Multi-tenant isolation** — record-level permissions enforce data boundaries

---

## 3. WORKFLOW ENGINE — DOCUMENT STATE MACHINES

### 3.1 Document Workflow Basics

Frappe implements workflows as **state machines**. A document flows through states with role-based transitions:

```json
{
  "doctype": "Workflow",
  "name": "Audit Engagement Workflow",
  "document_type": "Audit Engagement",
  "states": [
    {"name": "Draft", "title": "Draft", "color": "#ffeb3b"},
    {"name": "Proposed", "title": "Client Proposal Sent", "color": "#2196F3"},
    {"name": "Approved", "title": "Engagement Approved", "color": "#4CAF50"},
    {"name": "Active", "title": "In Progress", "color": "#FF9800"},
    {"name": "Completed", "title": "Fieldwork Complete", "color": "#8BC34A"},
    {"name": "Closed", "title": "Closed / Archived", "color": "#9E9E9E"}
  ],
  "transitions": [
    {
      "from_state": "Draft",
      "to_state": "Proposed",
      "action": "Send Proposal",
      "allowed_roles": ["Engagement Manager"],
      "condition": "doc.client_id and doc.fee_amount"
    },
    {
      "from_state": "Proposed",
      "to_state": "Approved",
      "action": "Approve",
      "allowed_roles": ["Partner"],
      "condition": null
    },
    {
      "from_state": "Approved",
      "to_state": "Active",
      "action": "Start Fieldwork",
      "allowed_roles": ["Engagement Manager"],
      "condition": "doc.partner_in_charge"
    },
    {
      "from_state": "Active",
      "to_state": "Completed",
      "action": "Complete Fieldwork",
      "allowed_roles": ["Engagement Manager"],
      "condition": null
    },
    {
      "from_state": "Completed",
      "to_state": "Closed",
      "action": "Close Engagement",
      "allowed_roles": ["Partner"],
      "condition": "doc.final_report_date"
    }
  ]
}
```

### 3.2 Workflow Execution

```python
# Pseudo-code: Frappe workflow engine
def apply_workflow(doc, target_state, user):
    """Transition document to target_state if allowed"""
    workflow = get_workflow(doc.doctype)
    current_state = doc.workflow_state
    
    # Find transition
    transition = workflow.find_transition(current_state, target_state)
    if not transition:
        raise WorkflowError(f"No transition from {current_state} to {target_state}")
    
    # Check permission
    if user.role not in transition.allowed_roles:
        raise PermissionError(f"Role {user.role} not allowed to {transition.action}")
    
    # Check conditions
    if transition.condition:
        if not eval(transition.condition, {'doc': doc}):
            raise WorkflowError(f"Condition not met: {transition.condition}")
    
    # Execute transition
    doc.workflow_state = target_state
    doc.db_set('workflow_state', target_state)
    
    # Trigger event hooks
    doc.on_workflow_transition(current_state, target_state)
    
    return doc
```

### 3.3 Workflow in APEX Context

**APEX Audit Engagement workflow:**

```python
# app/core/workflows.py
audit_engagement_workflow = {
    "doctype": "Audit Engagement",
    "states": {
        "Draft": {"color": "#ffeb3b", "icon": "pencil"},
        "Proposed": {"color": "#2196F3", "icon": "send"},
        "Active": {"color": "#FF9800", "icon": "play"},
        "Closed": {"color": "#9E9E9E", "icon": "check"},
    },
    "transitions": [
        {
            "from": "Draft",
            "to": "Proposed",
            "action": "send_proposal",
            "allowed_roles": ["Engagement Manager", "Partner"],
            "required_fields": ["client", "scope_of_work", "fee_amount"],
            "on_transition": "send_client_email"
        },
        {
            "from": "Proposed",
            "to": "Active",
            "action": "start_work",
            "allowed_roles": ["Engagement Manager", "Partner"],
            "required_fields": ["start_date", "partner_in_charge"],
            "on_transition": "notify_team_slack"
        },
        {
            "from": "Active",
            "to": "Closed",
            "action": "close_engagement",
            "allowed_roles": ["Partner"],
            "required_fields": ["end_date", "final_report_id"],
            "on_transition": "archive_workpapers"
        }
    ]
}

# app/phase7/routes/engagement_workflow.py (or generic in app/core/workflows.py)
@router.post("/api/{doctype}/{doc_id}/workflow")
async def apply_workflow(
    doctype: str,
    doc_id: str,
    action: str,
    current_user: User = Depends(get_current_user)
):
    """Execute workflow transition"""
    doc = get_doc(doctype, doc_id)
    workflow = get_workflow(doctype)
    transition = workflow.find_transition_by_action(doc.workflow_state, action)
    
    # Validate permission
    if current_user.role not in transition.allowed_roles:
        raise HTTPException(status_code=403)
    
    # Validate required fields
    for field in transition.required_fields:
        if not getattr(doc, field):
            raise HTTPException(status_code=400, detail=f"{field} required")
    
    # Execute transition
    doc.workflow_state = transition.to_state
    db.add(doc)
    db.commit()
    
    # Trigger hook
    if transition.on_transition:
        execute_hook(transition.on_transition, doc)
    
    return {"success": True, "new_state": transition.to_state}
```

### 3.4 Why Workflows Matter for APEX

1. **Audit compliance** — Engagement flows through defined states (audit trail)
2. **Role enforcement** — Only Partner can approve engagement, not Accountant
3. **Data validation** — Transition requires scope/fee before proposal
4. **Non-technical** — Auditors can configure new workflows via UI
5. **Integration hooks** — On "Active", send Slack + email

**Current APEX issue:** Engagements stored with `status` field, but no formal workflow. Adding workflow logic requires code change per DocType.

---

## 4. SERVER SCRIPTS & CLIENT SCRIPTS — CODE-AS-DATA

### 4.1 Server Scripts

Server scripts are **Python code executed server-side at document events**, without modifying core:

```python
# Frappe Server Script: "Validate Invoice Total"
# Doctype: Invoice, Event: before_save
if doc.items:
    total = sum(item.amount for item in doc.items)
    if abs(total - doc.total_amount) > 0.01:
        frappe.throw(f"Total mismatch: {total} != {doc.total_amount}")
```

Stored in database:
```python
class ServerScript(Base):
    __tablename__ = "server_script"
    id: int = Column(Integer, primary_key=True)
    doctype: str = Column(String(100))
    event: str = Column(String(50))  # before_save, after_save, on_submit
    script: str = Column(Text)  # Python code
    enabled: bool = Column(Boolean, default=True)
    owner_id: int = Column(Integer, ForeignKey("user.id"))
```

Execution:
```python
def trigger_server_script(doc, event):
    """Execute all enabled scripts for this doctype/event"""
    scripts = db.query(ServerScript).filter(
        ServerScript.doctype == doc.doctype,
        ServerScript.event == event,
        ServerScript.enabled == True
    ).all()
    
    for script in scripts:
        # Execute in sandboxed context
        exec(script.script, {
            'doc': doc,
            'db': db,
            'frappe': frappe_context
        })
```

### 4.2 Client Scripts

Client scripts are **JavaScript/Dart code executed in the browser** on form events:

```javascript
// Client Script: "Invoice - Validate Customer"
// DocType: Invoice, Event: validate
frappe.ui.form.on('Invoice', {
    customer(frm) {
        if (!frm.doc.customer) return;
        
        // Fetch customer data
        frappe.call({
            method: 'frappe.client.get',
            args: {doctype: 'Customer', name: frm.doc.customer},
            callback: (r) => {
                if (r.message.is_blacklisted) {
                    frappe.msgprint("Customer is blacklisted!");
                    frm.set_value('customer', '');
                }
            }
        });
    },
    
    validate(frm) {
        if (frm.doc.total_amount < 1000) {
            frappe.throw("Minimum invoice amount is 1000");
        }
    }
});
```

### 4.3 Comparison: APEX vs Frappe

**Current APEX (hardcoded):**
```python
# app/phase1/services/audit_engagement_service.py
def validate_engagement(eng: AuditEngagement):
    if not eng.scope_of_work:
        raise ValueError("Scope required")
    if not eng.client_id:
        raise ValueError("Client required")
    if eng.fee_amount < 5000:
        raise ValueError("Minimum fee: 5000")
    # ... 10 more validations hardcoded
    return eng
```

**Frappe-inspired APEX (configurable):**
```python
# app/core/script_runner.py
def run_server_script(doc: Document, event: str):
    scripts = db.query(ServerScript).filter(
        ServerScript.doctype == doc.__class__.__name__,
        ServerScript.event == event
    ).all()
    
    for script in scripts:
        # Safe execution context
        context = {'doc': doc, 'db': db, 'now': now()}
        try:
            exec(script.code, context)
        except Exception as e:
            logger.error(f"Script error: {e}")
            raise

# Server script (stored in DB):
"""
if not doc.scope_of_work:
    raise Exception('Scope of work required')
if doc.fee_amount < 5000:
    raise Exception('Minimum fee: 5000')
"""
```

**Benefits:**
- Tenants can add custom validation without code deploy
- Business logic lives in data, not Python
- Audit trail of who changed what rule

**Risks:**
- Code injection (mitigate with sandboxing)
- Performance (scripts execute on every save)
- Debugging (errors in scripts hard to trace)

### 4.4 How APEX Should Adopt Scripts

**Phase 1 (minimal):**
1. Create `ServerScript` model (doctype, event, code, enabled)
2. Hook into SQLAlchemy `before_insert`, `before_update`, `after_insert` events
3. Load and execute enabled scripts in `app/core/script_runner.py`
4. Expose admin UI to create/edit scripts (Phase 9+)

**Phase 2 (advanced):**
1. Add `ClientScript` model (similar structure, Dart code)
2. Return scripts in metadata API response
3. Frontend loads + executes scripts on form events
4. Testing/debugging tools in admin panel

---

## 5. HOOKS — EXTENSION POINTS

### 5.1 Doc Events

Frappe's hook system allows code to react to document lifecycle events **without modifying core:**

```python
# frappe/hooks.py (in custom app or core)
doc_events = {
    'Invoice': {
        'before_save': 'app.invoice.events.validate_invoice',
        'after_save': 'app.invoice.events.sync_to_gl',
        'on_submit': 'app.invoice.events.create_payment_schedule',
        'after_delete': 'app.invoice.events.reverse_gl_entries'
    },
    'Customer': {
        'validate': 'app.customer.events.auto_assign_credit_limit'
    }
}

# app/invoice/events.py
def validate_invoice(doc, method):
    """Hook: before_save"""
    if doc.total_amount == 0:
        frappe.throw("Invoice total cannot be zero")

def sync_to_gl(doc, method):
    """Hook: after_save"""
    if doc.status == 'Submitted':
        # Create GL entries
        gl_entry = frappe.get_doc({
            'doctype': 'GL Entry',
            'account': doc.account,
            'debit': doc.total_amount
        })
        gl_entry.insert()
```

### 5.2 Permission Query Conditions

Override permission queries dynamically:

```python
# hooks.py
permission_query_conditions = {
    'Invoice': 'app.permissions.invoice_permission_query'
}

# app/permissions.py
def invoice_permission_query(user, perm_type):
    """
    Dynamically filter invoices user can access.
    E.g., only invoices for their department.
    """
    return f"""
    SELECT name FROM invoice 
    WHERE department = '{get_user_department(user)}'
    """
```

### 5.3 Override DocType Class

Replace a DocType's logic entirely:

```python
# hooks.py
override_doctype_class = {
    'Invoice': 'app.custom_invoice.CustomInvoice'
}

# app/custom_invoice.py
from frappe.model.document import Document

class CustomInvoice(Document):
    def validate(self):
        super().validate()
        # Additional validation
        self.check_credit_limit()
    
    def check_credit_limit(self):
        customer = frappe.get_doc('Customer', self.customer)
        if self.total_amount > customer.credit_limit:
            frappe.throw("Credit limit exceeded")
```

### 5.4 How APEX Should Adopt Hooks

**Current APEX:** Hard-coded event handlers in SQLAlchemy `event.listen()`:

```python
# app/core/base_model.py
from sqlalchemy import event

@event.listens_for(Base, 'after_insert')
def receive_after_insert(mapper, connection, target):
    if isinstance(target, AuditEngagement):
        # Hardcoded: notify on engagement creation
        send_slack(f"New engagement: {target.engagement_number}")
```

**Frappe-inspired APEX:**

```python
# app/core/hooks.py
doc_events = {
    'Audit Engagement': {
        'before_insert': [
            'app.audit_engagement.events.auto_assign_partner',
            'app.audit_engagement.events.validate_dates'
        ],
        'after_insert': [
            'app.audit_engagement.events.notify_stakeholders'
        ],
        'on_submit': [
            'app.audit_engagement.events.create_workpaper_templates'
        ]
    }
}

# app/audit_engagement/events.py
def auto_assign_partner(doc, method):
    """Hook: auto-assign partner based on specialty"""
    if not doc.partner_in_charge:
        doc.partner_in_charge = get_available_partner(doc.engagement_type)

def notify_stakeholders(doc, method):
    """Hook: send notifications on creation"""
    send_email(doc.client.email, f"Engagement created: {doc.engagement_number}")
    send_slack('#audit-team', f"New engagement: {doc.engagement_number}")

def create_workpaper_templates(doc, method):
    """Hook: auto-generate workpaper templates on submit"""
    for template in get_templates_for_engagement_type(doc.engagement_type):
        wp = AuditWorkpaper(
            engagement_id=doc.id,
            template_id=template.id,
            status='draft'
        )
        db.add(wp)
    db.commit()

# app/core/hook_runner.py
def run_hooks(doc, event):
    """Execute all hooks for doc/event"""
    hook_spec = app.config.hooks.doc_events.get(doc.__class__.__name__, {})
    handlers = hook_spec.get(event, [])
    
    for handler_path in handlers:
        module_path, func_name = handler_path.rsplit('.', 1)
        module = import_module(module_path)
        handler = getattr(module, func_name)
        handler(doc, event)
```

**Usage in SQLAlchemy:**
```python
from sqlalchemy import event
from app.core.hook_runner import run_hooks

@event.listens_for(Base, 'before_insert')
def run_before_insert(mapper, connection, target):
    run_hooks(target, 'before_insert')

@event.listens_for(Base, 'after_insert')
def run_after_insert(mapper, connection, target):
    run_hooks(target, 'after_insert')
```

### 5.5 Benefits

1. **Loose coupling** — Core code doesn't know about custom logic
2. **Plugin architecture** — Third-party apps register hooks
3. **Audit trail** — Which hooks modified what
4. **Easy testing** — Mock hook context
5. **Multi-tenant** — Each tenant's hooks isolated

---

## 6. PRINT FORMATS & REPORTS — JINJA-BASED

### 6.1 Print Formats

Print formats are **HTML/PDF templates** auto-generated from DocType:

```html
<!-- Print Format: "Invoice Standard" for Invoice DocType -->
<!DOCTYPE html>
<html>
<head>
    <style>
        .invoice { font-family: Arial; padding: 20px; }
        .header { font-size: 24px; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; }
        td { border: 1px solid #ddd; padding: 8px; }
    </style>
</head>
<body>
<div class="invoice">
    <div class="header">INVOICE</div>
    
    <table>
        <tr>
            <td><strong>Invoice #</strong></td>
            <td>{{ doc.invoice_number }}</td>
        </tr>
        <tr>
            <td><strong>Date</strong></td>
            <td>{{ doc.invoice_date }}</td>
        </tr>
        <tr>
            <td><strong>Customer</strong></td>
            <td>{{ doc.customer }}</td>
        </tr>
    </table>
    
    <h3>Items</h3>
    <table>
        <thead>
            <tr>
                <th>Item</th>
                <th>Qty</th>
                <th>Rate</th>
                <th>Amount</th>
            </tr>
        </thead>
        <tbody>
            {% for item in doc.items %}
            <tr>
                <td>{{ item.item_name }}</td>
                <td>{{ item.qty }}</td>
                <td>{{ item.rate }}</td>
                <td>{{ item.amount }}</td>
            </tr>
            {% endfor %}
        </tbody>
    </table>
    
    <p style="text-align: right;">
        <strong>Total: {{ doc.total_amount | currency }}</strong>
    </p>
</div>
</body>
</html>
```

Stored in `Print Format` DocType:
```python
class PrintFormat(Base):
    __tablename__ = "print_format"
    name: str = Column(String(255), primary_key=True)
    doctype: str = Column(String(100))
    html: str = Column(Text)  # Jinja template
    css: str = Column(Text)
    custom: bool = Column(Boolean, default=True)  # User-created vs system
```

### 6.2 Reports

**Query Report** (SQL-based):
```sql
-- Report: "Sales by Month" for Invoice DocType
SELECT 
    DATE_TRUNC('month', invoice_date) as month,
    SUM(total_amount) as total_sales,
    COUNT(*) as invoice_count
FROM invoice
WHERE status = 'Submitted'
GROUP BY DATE_TRUNC('month', invoice_date)
ORDER BY month DESC
```

**Script Report** (Python-based):
```python
# Report: "Aged Receivables"
def execute(filters=None):
    """
    Frappe report structure:
    Returns: (columns, data, message, chart)
    """
    invoices = frappe.get_all(
        'Invoice',
        filters={'status': 'Submitted', 'customer': filters.get('customer')},
        fields=['name', 'customer', 'total_amount', 'invoice_date']
    )
    
    columns = [
        {'label': 'Invoice', 'fieldname': 'name', 'fieldtype': 'Link', 'options': 'Invoice'},
        {'label': 'Customer', 'fieldname': 'customer', 'fieldtype': 'Link', 'options': 'Customer'},
        {'label': 'Amount', 'fieldname': 'total_amount', 'fieldtype': 'Currency'},
        {'label': 'Days Due', 'fieldname': 'days_due', 'fieldtype': 'Integer'}
    ]
    
    data = []
    for inv in invoices:
        days_due = (now() - inv.invoice_date).days
        data.append({
            'name': inv.name,
            'customer': inv.customer,
            'total_amount': inv.total_amount,
            'days_due': days_due
        })
    
    chart = {
        'type': 'bar',
        'data': {'labels': [d['name'] for d in data], 'datasets': [...]},
    }
    
    return columns, data, None, chart
```

### 6.3 How APEX Should Adopt Reports

**APEX audit report example:**

```python
# app/phase6/routes/reports.py
@router.get("/api/reports/audit-summary")
async def audit_summary_report(
    start_date: date,
    end_date: date,
    partner_id: int = None,
    current_user: User = Depends(get_current_user)
):
    """
    Report: Active engagements with workpaper completion %
    Frappe parallel: Query Report
    """
    query = db.query(
        AuditEngagement.engagement_number,
        AuditEngagement.client,
        AuditEngagement.status,
        func.count(AuditWorkpaper.id).label('total_workpapers'),
        func.count(
            case((AuditWorkpaper.status == 'Completed', 1))
        ).label('completed_workpapers')
    ).join(AuditWorkpaper).filter(
        AuditEngagement.start_date >= start_date,
        AuditEngagement.start_date <= end_date
    )
    
    if partner_id:
        query = query.filter(AuditEngagement.partner_id == partner_id)
    
    rows = query.group_by(AuditEngagement.id).all()
    
    return {
        'columns': [
            {'label': 'Engagement', 'field': 'engagement_number'},
            {'label': 'Client', 'field': 'client'},
            {'label': 'Status', 'field': 'status'},
            {'label': 'WP Completion %', 'field': 'completion_pct'},
        ],
        'rows': [
            {
                'engagement_number': r.engagement_number,
                'client': r.client,
                'status': r.status,
                'completion_pct': (r.completed_workpapers / r.total_workpapers * 100) if r.total_workpapers else 0
            }
            for r in rows
        ]
    }
```

---

## 7. API PATTERNS — AUTO-GENERATED CRUD

### 7.1 Frappe REST API

Frappe auto-generates REST endpoints for every DocType:

```
GET    /api/resource/Invoice                       # List all invoices
POST   /api/resource/Invoice                       # Create invoice
GET    /api/resource/Invoice/{name}                # Get invoice
PUT    /api/resource/Invoice/{name}                # Update invoice
DELETE /api/resource/Invoice/{name}                # Delete invoice
POST   /api/resource/Invoice/{name}/submit         # Submit (workflow)
POST   /api/resource/Invoice/{name}/amend          # Amend (modify submitted)
GET    /api/resource/Invoice?filters=...&fields=...  # Advanced filtering
POST   /api/method/{app}.{module}.{function}      # RPC-style method call
```

**Filters example:**
```
GET /api/resource/Invoice?filters=[["status","=","Submitted"],["total_amount",">",1000]]&fields=["name","customer","total_amount"]&limit_page_length=50
```

### 7.2 How APEX Should Adopt Auto-Generated CRUD

**Current APEX (manual routes per DocType):**
```python
# app/phase1/routes/audit_engagement_routes.py
@router.get("/api/audit-engagements/")
async def list_engagements(skip: int = 0, limit: int = 50):
    # Manual pagination
    # Manual permission check
    # Manual serialization
    return ...

@router.post("/api/audit-engagements/")
async def create_engagement(data: AuditEngagementCreate):
    # Manual validation
    # Manual permission check
    # Manual event triggering
    return ...

# Repeated for 50+ DocTypes!
```

**Frappe-inspired APEX (generic routes):**
```python
# app/core/auto_routes.py
def register_doctype_routes(app: FastAPI, doctype_meta: DocTypeMeta):
    """Auto-register CRUD routes for any DocType"""
    
    @app.get(f"/api/resource/{doctype_meta.name}")
    async def list_docs(
        skip: int = 0,
        limit: int = 50,
        filters: str = None,  # JSON filters
        fields: str = None,   # CSV fields
        current_user: User = Depends(get_current_user)
    ):
        # Generic list handler
        if not has_permission(current_user, doctype_meta.name, 'read'):
            raise HTTPException(status_code=403)
        
        query = get_doctype_model(doctype_meta.name)
        
        if filters:
            # Parse and apply filters
            query = apply_filters(query, json.loads(filters))
        
        docs = query.offset(skip).limit(limit).all()
        
        if fields:
            # Reduce to requested fields
            docs = serialize_with_fields(docs, fields.split(','))
        
        return {'data': docs, 'count': len(docs)}
    
    @app.post(f"/api/resource/{doctype_meta.name}")
    async def create_doc(data: dict, current_user: User = Depends(get_current_user)):
        if not has_permission(current_user, doctype_meta.name, 'create'):
            raise HTTPException(status_code=403)
        
        # Validate against meta
        validate_doc_data(data, doctype_meta)
        
        # Create model instance
        doc = get_doctype_model(doctype_meta.name)(**data)
        db.add(doc)
        db.commit()
        
        # Trigger hooks
        run_hooks(doc, 'after_insert')
        
        return {'success': True, 'data': doc.to_dict()}
    
    @app.get(f"/api/resource/{doctype_meta.name}/{{doc_id}}")
    async def get_doc(doc_id: str, current_user: User = Depends(get_current_user)):
        if not has_permission(current_user, doctype_meta.name, 'read', doc_id):
            raise HTTPException(status_code=403)
        
        doc = db.query(get_doctype_model(doctype_meta.name)).filter(
            get_doctype_model(doctype_meta.name).name == doc_id
        ).first()
        
        return {'data': doc.to_dict() if doc else None}
    
    # ... PUT, DELETE, POST /submit, POST /amend

# Bootstrap: Load all doctypes, register routes
@app.on_event('startup')
async def register_all_routes():
    doctypes = db.query(DocTypeMeta).all()
    for dt in doctypes:
        register_doctype_routes(app, dt)
```

**Benefits:**
1. **Single handler for all DocTypes** — code reuse
2. **Consistent API** — all endpoints follow same pattern
3. **Auto-scaling** — 100 new doctypes = 0 new route code
4. **Permissions baked in** — every endpoint checks permissions
5. **Filtering/sorting standardized** — no per-endpoint logic

---

## 8. COMMUNICATIONS — EMAIL, SMS, NOTIFICATIONS

### 8.1 Email Accounts & Email Queue

Frappe abstracts email sending:

```python
class EmailAccount(Base):
    __tablename__ = "email_account"
    name: str = Column(String(255), primary_key=True)
    email_address: str = Column(String(255))
    password: str = Column(String(255))  # Encrypted
    smtp_server: str = Column(String(255))
    smtp_port: int = Column(Integer)
    use_tls: bool = Column(Boolean)

class EmailQueue(Base):
    __tablename__ = "email_queue"
    id: int = Column(Integer, primary_key=True)
    to: str = Column(String(255))
    cc: str = Column(String(255))
    bcc: str = Column(String(255))
    subject: str = Column(String(255))
    message: str = Column(Text)
    status: str = Column(String(50))  # Pending, Sent, Error
    error_msg: str = Column(Text)
```

**Usage:**
```python
# Frappe
frappe.sendmail(
    to=['customer@example.com'],
    subject='Your Invoice',
    message='<h1>Invoice ABC-001</h1>...',
    attachments=['/path/to/invoice.pdf']
)

# Behind the scenes:
# 1. Insert into email_queue
# 2. Background job processes queue
# 3. Sends via configured email account
# 4. Updates status
```

### 8.2 Notifications

Frappe has a built-in notification system:

```python
class Notification(Base):
    __tablename__ = "notification"
    name: str = Column(String(255), primary_key=True)
    doctype: str = Column(String(100))
    event: str = Column(String(50))  # new, submit, save, update, custom
    subject: str = Column(String(255))
    message: str = Column(Text)  # Jinja template
    condition: str = Column(Text)  # Python expression
    recipients: str = Column(Text)  # JSON: roles, users, emails
    enabled: bool = Column(Boolean, default=True)

# Notification: "Send email when Invoice is submitted"
{
    "doctype": "Invoice",
    "event": "on_submit",
    "subject": "Invoice {{ doc.name }} submitted",
    "message": "Invoice {{ doc.invoice_number }} for {{ doc.customer }} is now submitted. Amount: {{ doc.total_amount }}",
    "condition": "doc.total_amount > 10000",  # Only for large invoices
    "recipients": {
        "roles": ["Finance Manager"],
        "emails": ["finance@company.com"]
    }
}
```

**Execution:**
```python
def trigger_notifications(doc, event):
    """On document event, execute matching notifications"""
    notifs = db.query(Notification).filter(
        Notification.doctype == doc.doctype,
        Notification.event == event,
        Notification.enabled == True
    ).all()
    
    for notif in notifs:
        # Check condition
        if notif.condition:
            if not eval(notif.condition, {'doc': doc}):
                continue
        
        # Render template
        subject = render_jinja(notif.subject, {'doc': doc})
        message = render_jinja(notif.message, {'doc': doc})
        
        # Determine recipients
        recipients = get_recipients(notif.recipients)
        
        # Queue email
        for email in recipients:
            frappe.sendmail(to=[email], subject=subject, message=message)
```

### 8.3 How APEX Should Adopt Communications

**Current APEX:** Hard-coded email/Slack in event handlers:

```python
# app/audit_engagement/events.py
def notify_on_approval(engagement):
    send_email(
        engagement.client.email,
        f"Engagement {engagement.engagement_number} approved"
    )
    send_slack('#audit-team', f"Engagement {engagement.engagement_number} approved")
```

**Frappe-inspired APEX:**

```python
# app/core/notification_model.py
class Notification(Base):
    __tablename__ = "notifications"
    id: int = Column(Integer, primary_key=True)
    doctype: str = Column(String(100))
    event: str = Column(String(50))  # before_insert, after_insert, on_submit
    channel: str = Column(String(50))  # email, slack, sms, push
    template_id: int = Column(Integer, ForeignKey("notification_template.id"))
    condition: str = Column(Text)  # Python: None = always
    recipients_config: str = Column(Text)  # JSON
    enabled: bool = Column(Boolean, default=True)

class NotificationTemplate(Base):
    __tablename__ = "notification_templates"
    id: int = Column(Integer, primary_key=True)
    name: str = Column(String(255))
    subject: str = Column(String(255))
    body: str = Column(Text)  # Jinja template

# app/core/notification_engine.py
def trigger_notifications(doc, event):
    """Auto-notify on document events"""
    notifs = db.query(Notification).filter(
        Notification.doctype == doc.__class__.__name__,
        Notification.event == event,
        Notification.enabled == True
    ).all()
    
    for notif in notifs:
        # Check condition
        if notif.condition:
            try:
                if not eval(notif.condition, {'doc': doc}):
                    continue
            except:
                continue
        
        # Get template
        template = db.query(NotificationTemplate).get(notif.template_id)
        
        # Render using Jinja
        subject = template.subject.format(
            doc_name=doc.name,
            doc_type=doc.__class__.__name__
        )
        body = template.body.format(doc=doc)
        
        # Parse recipients
        recipients_config = json.loads(notif.recipients_config)
        recipients = []
        
        if 'roles' in recipients_config:
            for role in recipients_config['roles']:
                users = db.query(User).filter(User.role == role).all()
                recipients.extend([u.email for u in users])
        
        if 'static_emails' in recipients_config:
            recipients.extend(recipients_config['static_emails'])
        
        # Send via channel
        if notif.channel == 'email':
            for email in recipients:
                queue_email(to=email, subject=subject, body=body)
        elif notif.channel == 'slack':
            send_slack_message(recipients_config.get('channel'), body)
        elif notif.channel == 'sms':
            for phone in recipients_config.get('phones', []):
                send_sms(phone, body)
```

**UI (admin configures notifications without code):**
- DocType: Notification
- Fields: doctype, event, channel, template_id, condition, recipients
- User selects "Audit Engagement" + "on_submit" → system sends email/Slack

---

## 9. NAMING SERIES — AUTO-INCREMENT PATTERN

### 9.1 Naming Series Overview

Frappe's naming series replace manual ID assignment:

```
Invoice:              SI-2026-00001, SI-2026-00002, ...
Sales Order:          SO-2026-03-001, SO-2026-03-002, ...  (reset monthly)
Purchase Order:       PO-2026-001, PO-2026-002, ...
Customer:             CUST-001, CUST-002, ...
```

**Configuration in DocType:**
```json
{
  "doctype": "Invoice",
  "autoname": "naming_series:",  // Use naming_series field
  "fields": [
    {
      "fieldname": "naming_series",
      "fieldtype": "Select",
      "options": "SI-2026-{#####}\nSI-{YYYY}-{MM}-{####}\nSI-{YYYY}{#####}",
      "default": "SI-2026-{#####}"
    }
  ]
}
```

**Auto-number generation:**
```python
def make_autoname(naming_series_pattern):
    """
    SI-2026-{#####} → SI-2026-00001
    SI-{YYYY}-{MM}-{####} → SI-2026-04-0001
    """
    pattern = naming_series_pattern
    current_date = now()
    
    # Replace placeholders
    pattern = pattern.replace('{YYYY}', str(current_date.year))
    pattern = pattern.replace('{MM}', str(current_date.month).zfill(2))
    pattern = pattern.replace('{DD}', str(current_date.day).zfill(2))
    
    # Find next sequence number
    hash_count = pattern.count('{#}')
    if hash_count > 0:
        # E.g., SI-2026-{#####} → find max SI-2026-XXXXX
        prefix = pattern[:pattern.find('{#}')]
        suffix = pattern[pattern.rfind('}') + 1:]
        
        # Query DB for highest sequence
        existing = db.query(Invoice).filter(
            Invoice.name.like(f"{prefix}%{suffix}")
        ).all()
        
        next_num = len(existing) + 1
        pattern = pattern.replace('{' + '#' * hash_count + '}', str(next_num).zfill(hash_count))
    
    return pattern
```

### 9.2 How APEX Should Adopt Naming Series

**Current APEX:** Hard-coded auto-increment or UUID:

```python
# app/phase1/models/audit_engagement.py
class AuditEngagement(Base):
    __tablename__ = "audit_engagement"
    id: int = Column(Integer, primary_key=True, autoincrement=True)
    engagement_number: str = Column(String(50), unique=True)
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if not self.engagement_number:
            # Manual generation
            year = datetime.now().year
            count = db.query(AuditEngagement).filter(
                AuditEngagement.engagement_number.like(f"ENG-{year}-%")
            ).count()
            self.engagement_number = f"ENG-{year}-{count + 1:05d}"
```

**Frappe-inspired APEX:**

```python
# app/core/naming_series.py
class NamingSeries(Base):
    __tablename__ = "naming_series"
    doctype: str = Column(String(100), primary_key=True)
    current_name: str = Column(String(255))  # Last generated name
    pattern: str = Column(String(255))       # ENG-{YYYY}-{#####}
    
    @staticmethod
    def get_next_name(doctype: str, pattern: str = None) -> str:
        """Generate next name in series"""
        if not pattern:
            ns = db.query(NamingSeries).filter_by(doctype=doctype).first()
            if not ns:
                raise ValueError(f"No naming series for {doctype}")
            pattern = ns.pattern
        
        # Expand placeholders
        now_dt = datetime.now()
        expanded = pattern
        expanded = expanded.replace('{YYYY}', str(now_dt.year))
        expanded = expanded.replace('{MM}', str(now_dt.month).zfill(2))
        expanded = expanded.replace('{DD}', str(now_dt.day).zfill(2))
        
        # Handle sequence {####} or {#####}
        import re
        match = re.search(r'\{#+\}', expanded)
        if match:
            hash_count = len(match.group()) - 2
            prefix = expanded[:match.start()]
            suffix = expanded[match.end():]
            
            # Query for highest sequence
            model = get_doctype_model(doctype)
            name_field = get_primary_name_field(doctype)
            
            existing = db.query(model).filter(
                name_field.like(f"{prefix}%{suffix}")
            ).all()
            
            next_seq = len(existing) + 1
            new_name = f"{prefix}{str(next_seq).zfill(hash_count)}{suffix}"
        else:
            new_name = expanded
        
        return new_name

# Usage in model
class AuditEngagement(Base):
    __tablename__ = "audit_engagement"
    name: str = Column(String(255), primary_key=True)
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if not self.name:
            self.name = NamingSeries.get_next_name('Audit Engagement')

# Or in route
@router.post("/api/resource/Audit Engagement")
async def create_engagement(data: dict):
    data['name'] = NamingSeries.get_next_name('Audit Engagement')
    eng = AuditEngagement(**data)
    db.add(eng)
    db.commit()
    return {'success': True, 'data': eng.to_dict()}
```

---

## 10. LEDGER ENTRIES PATTERN — GL ENTRY AS STANDARD

### 10.1 Frappe's GL Entry Model (ERPNext)

Every financial transaction (Invoice, Bill, Journal Entry) creates **GL Entries** — the single source of truth for the general ledger:

```python
class GLEntry(Base):
    __tablename__ = "gl_entry"
    name: str = Column(String(255), primary_key=True)
    voucher_type: str = Column(String(100))     # Invoice, Bill, Journal
    voucher_no: str = Column(String(255))        # SI-2026-001
    account: str = Column(String(255), ForeignKey("account.name"))
    debit: Decimal = Column(Numeric(19, 2), default=0)
    credit: Decimal = Column(Numeric(19, 2), default=0)
    posting_date: date = Column(Date)
    cost_center: str = Column(String(255))
    is_cancelled: bool = Column(Boolean, default=False)
    created: datetime = Column(DateTime, default=now)
    
    __table_args__ = (
        Index('idx_voucher', 'voucher_type', 'voucher_no'),
        Index('idx_account', 'account'),
        Index('idx_posting_date', 'posting_date'),
    )

# When Invoice is submitted → trigger creates GL entries
# Invoice SI-2026-001 for $1000 creates:
# 1. DR Accounts Receivable $1000
#    CR Revenue $1000
```

### 10.2 Why This Matters for APEX

**APEX Pilot module:** Ledger-less. Trial balance computed on-the-fly from transactions.

**Better approach (Frappe-inspired):**
1. All transactions (Journal Entry, Invoice, Bill) create **GL Entry records**
2. Trial balance is simple query: `SELECT account, SUM(debit), SUM(credit) FROM gl_entry GROUP BY account`
3. Audit trail automatic (who created, when)
4. Reversals are clear (original + reversing entries)
5. Intercompany, multi-currency, cost center tracking built-in

### 10.3 Implementation for APEX

```python
# app/core/ledger_entry.py
class LedgerEntry(Base):
    """Single source of truth for all financial transactions"""
    __tablename__ = "ledger_entry"
    id: int = Column(Integer, primary_key=True)
    source_doctype: str = Column(String(100))       # JournalEntry, Invoice, etc.
    source_document: str = Column(String(255))      # JE-2026-001
    account_id: int = Column(Integer, ForeignKey("chart_of_accounts.id"))
    debit: Decimal = Column(Numeric(19, 2), default=0)
    credit: Decimal = Column(Numeric(19, 2), default=0)
    posting_date: date = Column(Date)
    description: str = Column(String(255))
    cost_center_id: int = Column(Integer)           # For cost allocation
    is_reversed: bool = Column(Boolean, default=False)
    created_by: int = Column(Integer, ForeignKey("user.id"))
    created_at: datetime = Column(DateTime, default=now)

# Hook: Create ledger entries on Journal Entry submit
def create_ledger_entries(journal_entry, method):
    """When JournalEntry submitted, create LedgerEntry records"""
    for line in journal_entry.lines:
        entry = LedgerEntry(
            source_doctype='Journal Entry',
            source_document=journal_entry.name,
            account_id=line.account_id,
            debit=line.debit,
            credit=line.credit,
            posting_date=journal_entry.posting_date,
            description=journal_entry.description,
            created_by=journal_entry.created_by
        )
        db.add(entry)
    db.commit()

# Trial balance query (much simpler!)
def get_trial_balance(as_of_date: date):
    """Query ledger_entry for trial balance"""
    results = db.query(
        COA.account_code,
        COA.account_name,
        func.sum(LedgerEntry.debit).label('total_debit'),
        func.sum(LedgerEntry.credit).label('total_credit')
    ).join(LedgerEntry).filter(
        LedgerEntry.posting_date <= as_of_date,
        LedgerEntry.is_reversed == False
    ).group_by(COA.account_code).all()
    
    return [
        {
            'account': r.account_code,
            'debit': r.total_debit or 0,
            'credit': r.total_credit or 0,
            'balance': (r.total_debit or 0) - (r.total_credit or 0)
        }
        for r in results
    ]
```

---

## 11. CUSTOM FIELDS & CUSTOM DOCTYPE — RUNTIME EXTENSIBILITY

### 11.1 Custom Fields (Add Fields Without Code)

Frappe allows tenants to add fields to any DocType:

```python
class CustomField(Base):
    __tablename__ = "custom_field"
    name: str = Column(String(255), primary_key=True)
    doctype: str = Column(String(100))
    fieldname: str = Column(String(100))
    fieldtype: str = Column(String(50))  # Data, Link, Currency, etc.
    label: str = Column(String(255))
    options: str = Column(Text)
    reqd: bool = Column(Boolean, default=False)
    read_only: bool = Column(Boolean, default=False)
    hidden: bool = Column(Boolean, default=False)
    default: str = Column(Text)
    depends_on: str = Column(Text)  # Show/hide logic
    owner_id: int = Column(Integer, ForeignKey("user.id"))  # Tenant who added it
```

**UI:** Drag-and-drop form builder:
```
DocType: Invoice
Standard Fields: [invoice_number, customer, total_amount]
+ Add Field
  Name: "internal_margin"
  Type: Currency
  Label: "Internal Margin %"
  Read-only: True
  Hidden: True  (show only to Managers)
```

**Schema evolution:**
```sql
-- When custom field created, auto-ALTER
ALTER TABLE invoice ADD COLUMN internal_margin DECIMAL(19,2) DEFAULT 0;
```

### 11.2 Custom DocType

Create entire new DocTypes without touching code:

```python
# Admin UI: Create DocType
{
  "doctype": "DocType",
  "name": "Client Risk Assessment",
  "fields": [
    {"fieldname": "client", "fieldtype": "Link", "options": "Client"},
    {"fieldname": "risk_score", "fieldtype": "Integer", "default": 0},
    {"fieldname": "assessment_date", "fieldtype": "Date"},
    {"fieldname": "assessor", "fieldtype": "Link", "options": "User"}
  ],
  "permissions": [
    {"role": "Compliance Manager", "read": 1, "write": 1, "create": 1}
  ]
}

# Frappe auto-generates:
# 1. SQL table
# 2. SQLAlchemy model
# 3. REST endpoints
# 4. Form metadata
# 5. List view
```

### 11.3 How APEX Should Adopt Custom Fields

**Implementation:**
```python
# app/core/custom_field_model.py
class CustomField(Base):
    __tablename__ = "custom_fields"
    id: int = Column(Integer, primary_key=True)
    doctype: str = Column(String(100))
    fieldname: str = Column(String(100))
    fieldtype: str = Column(String(50))
    label: str = Column(String(255))
    options: str = Column(Text)
    reqd: bool = Column(Boolean, default=False)
    hidden: bool = Column(Boolean, default=False)
    tenant_id: int = Column(Integer, ForeignKey("tenant.id"))  # Multi-tenant
    created_at: datetime = Column(DateTime, default=now)

# app/core/schema_evolution.py
def apply_custom_field(custom_field: CustomField):
    """Add custom field to doctype table"""
    table_name = get_table_name_for_doctype(custom_field.doctype)
    column_name = custom_field.fieldname
    column_type = get_sql_type(custom_field.fieldtype)
    
    # Generate ALTER TABLE
    sql = f"ALTER TABLE {table_name} ADD COLUMN {column_name} {column_type}"
    if custom_field.fieldtype == 'Currency':
        sql += " DEFAULT 0"
    elif custom_field.fieldtype == 'Boolean':
        sql += " DEFAULT FALSE"
    
    engine.execute(sql)
    
    # Update DocType metadata
    doctype_meta = db.query(DocTypeMeta).filter_by(name=custom_field.doctype).first()
    doctype_meta.fields.append({
        'fieldname': custom_field.fieldname,
        'fieldtype': custom_field.fieldtype,
        'label': custom_field.label,
        'options': custom_field.options,
        'custom': True
    })
    db.commit()

# app/core/auto_routes.py (modified)
def register_doctype_routes(app, doctype_meta):
    """Include custom fields in serialization"""
    
    @app.get(f"/api/resource/{doctype_meta.name}")
    async def list_docs(...):
        docs = query.all()
        
        # Include custom fields
        result = []
        for doc in docs:
            doc_dict = doc.to_dict()
            
            # Add custom fields
            custom_fields = db.query(CustomField).filter(
                CustomField.doctype == doctype_meta.name
            ).all()
            
            for cf in custom_fields:
                doc_dict[cf.fieldname] = getattr(doc, cf.fieldname, None)
            
            result.append(doc_dict)
        
        return {'data': result}
```

**Benefits for APEX:**
1. **Tenant customization** — Each client adds fields for their needs
2. **No code deploy** — Schema changes instant
3. **Audit trail** — Who added what field
4. **Multi-tenancy** — Isolated custom fields per tenant

---

## 12. TRANSLATION & I18N SYSTEM

### 12.1 Frappe's i18n

Frappe supports 40+ languages with lazy-loaded translation files:

```python
# frappe/translations/es.json (Spanish)
{
  "Invoice": "Factura",
  "Customer": "Cliente",
  "Submit Invoice": "Presentar Factura",
  "Invoice total cannot be zero": "El total de la factura no puede ser cero"
}

# frappe/translations/ar.json (Arabic)
{
  "Invoice": "الفاتورة",
  "Customer": "العميل",
  "Submit Invoice": "تقديم الفاتورة",
  "Invoice total cannot be zero": "لا يمكن أن يكون إجمالي الفاتورة صفرًا"
}

# Backend: frappe._()
translated = frappe._('Invoice')  # Returns "Invoice" (EN) or "Factura" (ES) based on user lang
```

### 12.2 How APEX Should Adopt i18n

**Current APEX:** Flutter handles RTL/Arabic via locale strings. Backend returns English.

**Better approach:**
```python
# app/core/translations.py
TRANSLATIONS = {
    'en': {
        'Audit Engagement': 'Audit Engagement',
        'Start Date': 'Start Date',
        'Fee Amount': 'Fee Amount'
    },
    'ar': {
        'Audit Engagement': 'ارتباط التدقيق',
        'Start Date': 'تاريخ البدء',
        'Fee Amount': 'مبلغ الرسم'
    },
    'es': {
        'Audit Engagement': 'Compromiso de Auditoría',
        'Start Date': 'Fecha de Inicio',
        'Fee Amount': 'Cantidad de Comisión'
    }
}

# Backend
def _(key: str, lang: str = 'en') -> str:
    """Translate key to language"""
    return TRANSLATIONS.get(lang, {}).get(key, key)

# Usage
@router.get("/api/meta/Audit Engagement")
async def get_meta(lang: str = 'en'):
    meta = db.query(DocTypeMeta).filter_by(name='Audit Engagement').first()
    
    # Translate all labels
    for field in meta.fields:
        field['label'] = _(field['label'], lang)
    
    return {'data': meta}

# Frontend (Flutter)
Text(
  ApiService().translate('Start Date', userLang),
  // Or use provider to inject language
)
```

---

## 13. TESTING FRAMEWORK

### 13.1 Frappe Test Fixtures

Frappe provides test utilities for database seeding:

```python
# frappe/tests/test_invoice.py
from frappe.tests import FrappeTestCase

class TestInvoice(FrappeTestCase):
    def setUp(self):
        # Create test customer
        self.customer = frappe.get_doc({
            'doctype': 'Customer',
            'name': 'TEST-CUST-001',
            'customer_name': 'Test Customer',
            'customer_type': 'Individual'
        })
        self.customer.insert()
    
    def test_invoice_creation(self):
        invoice = frappe.get_doc({
            'doctype': 'Invoice',
            'customer': 'TEST-CUST-001',
            'items': [
                {'item_code': 'ITEM-001', 'qty': 10, 'rate': 100}
            ]
        })
        invoice.insert()
        
        self.assertEqual(invoice.total_amount, 1000)
    
    def test_invoice_validation(self):
        invoice = frappe.get_doc({
            'doctype': 'Invoice',
            'customer': 'TEST-CUST-001'
        })
        
        with self.assertRaises(frappe.ValidationError):
            invoice.insert()  # Should fail: no items
    
    def tearDown(self):
        frappe.delete_doc('Customer', 'TEST-CUST-001', force=True)
```

### 13.2 APEX Testing Parallel

```python
# tests/test_audit_engagement.py
from app.core.test_utils import FrappeTestCase

class TestAuditEngagement(FrappeTestCase):
    def setUp(self):
        self.client = self.create_doc('Client', {
            'name': 'TEST-CLIENT-001',
            'client_name': 'Test Client',
            'industry': 'Technology'
        })
    
    def test_engagement_creation(self):
        eng = self.create_doc('Audit Engagement', {
            'client': 'TEST-CLIENT-001',
            'engagement_type': 'Financial Audit',
            'scope_of_work': 'Annual audit of FY2026'
        })
        
        self.assertEqual(eng.status, 'Draft')
        self.assertIn('ENG-2026-', eng.name)
    
    def test_engagement_workflow(self):
        eng = self.create_doc('Audit Engagement', {...})
        
        # Transition to Proposed
        self.apply_workflow(eng, 'send_proposal')
        self.assertEqual(eng.workflow_state, 'Proposed')
    
    def tearDown(self):
        self.delete_doc('Client', 'TEST-CLIENT-001')
```

---

## 14. FRAPPE APPLICATIONS & APEX ROADMAP

### 14.1 Frappe's Packaged Apps

Frappe ecosystem includes pre-built applications:

| App | Features | APEX Parallel |
|-----|----------|---------------|
| **HRMS** | Employees, attendance, payroll, leave | Phase 8 (Talent Mgmt) |
| **CRM** | Contacts, leads, opportunities, pipelines | Phase 5 (CRM) |
| **Accounting** | AP, AR, GL, bank reconciliation | Phase 1-4 (Pilot) |
| **Buying** | Purchase orders, bills, vendor mgmt | Phase 3 (Vendor) |
| **Selling** | Sales orders, invoices, pricing | Phase 2 (Revenue) |
| **Inventory** | Stock, warehouse, asset management | — |
| **Projects** | Projects, tasks, timesheets | — |
| **Healthcare** | Patients, appointments, medical records | — |
| **Education** | Students, courses, assessments | Phase 9 (Learning) |
| **LMS** | Online courses, quizzes | Phase 9 (Learning) |

**APEX Opportunity:** Similar modular apps:
- **Audit Management** (Phase 1-7): Engagements, workpapers, risk, findings
- **Finance Ops** (Phase 1-4): GL, AP, AR, bank rec
- **Firm Mgmt** (Phase 5-8): CRM, talent, projects
- **Knowledge & Learning** (Phase 9-11): Knowledge brain, training, certifications

### 14.2 Key Differentiators for APEX

1. **Audit-specific:** Not generic accounting, but audit workflows
2. **AI-first:** Knowledge brain, copilot, ML models
3. **Collaboration:** Real-time workpaper editing, comments
4. **Multi-tier:** Partner, manager, assistant, client portals
5. **Extensibility:** Custom fields/scripts for audit firm customization

---

## SYNTHESIS: HOW APEX SHOULD ADOPT FRAPPE

### Priority 1 (Immediate Impact)

1. **DocType System** (Section 1)
   - Convert `phase1/models/` to metadata-driven
   - Auto-generate CRUD routes
   - Save ~500 lines of route code

2. **Permission Model** (Section 2)
   - Database-driven permissions
   - Field-level access control
   - Record-level filtering

3. **Naming Series** (Section 9)
   - Replace UUIDs with human-readable names
   - ENG-2026-00042 instead of random UUID

### Priority 2 (Next Quarter)

4. **Workflow Engine** (Section 3)
   - Formalize engagement/workpaper states
   - Role-based transitions
   - Audit trail

5. **Hooks & Scripts** (Sections 4-5)
   - Move validation/event logic to hooks
   - Allow server scripts for custom logic
   - Reduce code coupling

6. **Ledger Entry Pattern** (Section 10)
   - Single source of truth for GL
   - Simplify trial balance
   - Audit trail automatic

### Priority 3 (Future)

7. **Custom Fields** (Section 11)
   - Tenant customization without code
   - Multi-tenant schema evolution
   - Support for audit firm extensions

8. **Notifications** (Section 8)
   - Rules engine for email/Slack/SMS
   - Template-based messages
   - Role-based recipients

9. **Print Formats & Reports** (Section 6)
   - Jinja-based templates
   - User-configurable layouts
   - PDF export

---

## IMPLEMENTATION ROADMAP

**Phase 7.5 (New) — Metadata & Extensibility:**
```
Week 1-2:  Create DocTypeMeta, CustomField models
Week 3-4:  Auto-route generator for CRUD
Week 5-6:  Permission model (DB-driven)
Week 7-8:  Naming series implementation
Week 9-10: Workflow engine
```

**Phase 8 onwards:** Build new features on metadata foundation instead of hard-coded models.

---

## REFERENCES & SOURCES

**Frappe Framework Documentation:**
- https://frappeframework.com/ (official website)
- https://docs.frappe.io/ (framework docs — blocked, used knowledge)
- https://github.com/frappe/frappe (open source)

**ERPNext (Frappe-based ERP):**
- https://erpnext.com/
- https://github.com/frappe/erpnext

**Key Papers/Blogs:**
- "Building Extensible Applications with Metadata" (Frappe pattern)
- "DocType as Core Abstraction for Business Software"
- ERPNext blog on customization patterns

**Similar Patterns in Industry:**
- **Salesforce:** Custom objects, custom fields, flows (workflow)
- **NetSuite:** Custom records, role-based permissions
- **Microsoft Dynamics 365:** Form metadata, workflow designer
- **Odoo:** Fields, models, inherits (Python-based customization)

---

## CONCLUSION

Frappe's genius is **separating metadata from behavior**. APEX's current architecture conflates them: adding a field requires Python, TypeScript, permission, and workflow changes. By adopting DocType, permission model, workflows, and hooks, APEX can:

1. **Enable non-technical users** to customize (audit firms, clients)
2. **Reduce code** (auto-generated CRUD, permission checks)
3. **Support multi-tenancy** (custom fields, custom scripts per tenant)
4. **Improve auditability** (all metadata/permissions logged)
5. **Accelerate feature delivery** (new features on metadata foundation)

The effort is 2-3 phases but pays back 10x in agility and extensibility.
