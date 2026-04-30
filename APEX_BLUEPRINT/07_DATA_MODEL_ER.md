# 07 — Data Model ER Diagrams / مخططات نموذج البيانات

> Reference: continues from `06_PERMISSIONS_AND_PLANS_MATRIX.md`. Next: `08_GLOBAL_BENCHMARKS.md`.
> **Source of truth:** SQLAlchemy models in `app/phase{1-11}/models/` and `app/sprint{1-6}/models/`.

---

## 1. Phase 1 — Auth, Plans, Legal / التحقق والخطط والقانوني

```mermaid
erDiagram
    User ||--o{ UserProfile : has
    User ||--o{ UserSession : owns
    User ||--o{ UserRole : has
    User ||--o{ UserSubscription : has
    User ||--o{ PolicyAcceptanceLog : signed
    User ||--o{ Notification : receives
    User ||--o{ AccountClosureRequest : submits
    User ||--o{ UserSecurityEvent : generates
    User ||--o{ PasswordReset : requests

    User {
        UUID id PK
        string username UK
        string email UK
        string password_hash
        boolean is_deleted
        timestamp created_at
        timestamp updated_at
    }
    UserProfile {
        UUID user_id FK
        string first_name
        string last_name
        string phone
        string avatar_url
    }
    UserSession {
        UUID id PK
        UUID user_id FK
        string token_hash
        string ip_address
        string user_agent
        timestamp created_at
        timestamp expires_at
    }

    Role ||--o{ RolePermission : has
    Permission ||--o{ RolePermission : in
    Role ||--o{ UserRole : assigned_to
    UserRole }o--|| User : assigns

    Role {
        UUID id PK
        string code UK
        string name
    }
    Permission {
        UUID id PK
        string resource
        string action
        string description
    }

    Plan ||--o{ PlanFeature : has
    Plan ||--o{ UserSubscription : on
    UserSubscription ||--o{ SubscriptionEntitlement : grants

    Plan {
        UUID id PK
        string code UK
        string name_ar
        decimal price_monthly_sar
        int max_users
        int max_clients
    }
    PlanFeature {
        UUID plan_id FK
        string feature_code
        int limit_value
        string feature_name_ar
    }
    UserSubscription {
        UUID id PK
        UUID user_id FK
        UUID plan_id FK
        string status
        string stripe_subscription_id
        timestamp started_at
        timestamp ends_at
    }
    SubscriptionEntitlement {
        UUID subscription_id FK
        string feature_code
        int limit_value
        int used_count
    }

    PolicyDocument ||--o{ PolicyAcceptanceLog : accepted_in
    PolicyDocument {
        UUID id PK
        string type
        string version
        text content
        date effective_date
        boolean is_active
    }
    PolicyAcceptanceLog {
        UUID id PK
        UUID user_id FK
        UUID policy_id FK
        timestamp accepted_at
        string ip_address
    }

    Notification {
        UUID id PK
        UUID user_id FK
        string type
        string title
        text body
        timestamp read_at
        timestamp created_at
    }
    AccountClosureRequest {
        UUID id PK
        UUID user_id FK
        string reason
        timestamp requested_at
        timestamp scheduled_at
    }
```

---

## 2. Phase 2 — Clients, COA, Audit Cases / العملاء ودليل الحسابات والمراجعة

```mermaid
erDiagram
    User ||--o{ Client : owns
    Client ||--o{ ClientMember : has
    Client ||--o{ ClientDocument : stores
    Client ||--o{ CoaUpload : uploads
    Client ||--o{ AuditCase : commissions
    Client ||--o{ ServiceCase : opens
    Client ||--o{ OnboardingDraft : has

    Client {
        UUID id PK
        UUID owner_id FK
        UUID tenant_id
        string name
        string name_ar
        string email
        string phone
        string cr_number
        string vat_number
        string address
        string legal_entity_type
        string main_sector
        string sub_sector
        timestamp created_at
    }
    ClientMember {
        UUID id PK
        UUID client_id FK
        UUID user_id FK
        string role
        timestamp invited_at
        timestamp accepted_at
    }
    ClientDocument {
        UUID id PK
        UUID client_id FK
        string filename
        string mime
        string storage_url
        string category
    }

    CoaUpload ||--o{ CoaAccount : contains
    CoaUpload {
        UUID id PK
        UUID client_id FK
        string filename
        string state
        json column_mapping
        decimal quality_score
        timestamp uploaded_at
    }
    CoaAccount {
        UUID id PK
        UUID upload_id FK
        string code
        string name
        string name_ar
        string parent_code
        string ifrs_classification
        decimal confidence
        boolean approved
    }

    AuditCase ||--o{ AuditSample : has
    AuditCase ||--o{ AuditWorkpaper : contains
    AuditCase ||--o{ AuditFinding : raises
    AuditCase {
        UUID id PK
        UUID client_id FK
        string year
        string scope
        string status
        UUID partner_id FK
        timestamp created_at
    }
    AuditSample {
        UUID id PK
        UUID case_id FK
        string population
        string method
        int sample_size
        json criteria
    }
    AuditWorkpaper {
        UUID id PK
        UUID case_id FK
        string title
        string preparer
        string reviewer
        string status
        text content
        json attachments
    }
    AuditFinding {
        UUID id PK
        UUID case_id FK
        string severity
        string description
        string mgmt_response
        string status
    }

    ServiceCase {
        UUID id PK
        UUID client_id FK
        string service_code
        string status
        UUID provider_id
        timestamp created_at
    }

    OnboardingDraft {
        UUID id PK
        UUID user_id FK
        string step
        json data
        timestamp updated_at
    }
```

---

## 3. Sprint 1-3 — COA Pipeline / خط أنابيب دليل الحسابات

```mermaid
erDiagram
    CoaUpload ||--o{ CoaAccount : "1:N"
    CoaUpload ||--o{ CoaAssessment : "1:N"
    CoaUpload ||--o{ CoaApprovalEvent : tracks
    CoaAccount ||--o{ CoaClassificationResult : has
    CoaAccount ||--o{ CoaRule : matches
    Client ||--o{ CoaRule : owns

    CoaAssessment {
        UUID id PK
        UUID upload_id FK
        decimal score
        json issues
        timestamp assessed_at
    }
    CoaApprovalEvent {
        UUID id PK
        UUID upload_id FK
        UUID user_id FK
        string action
        timestamp at
    }
    CoaClassificationResult {
        UUID id PK
        UUID account_id FK
        string suggested_category
        decimal confidence
        string source
    }
    CoaRule {
        UUID id PK
        UUID client_id FK
        string pattern
        string target_category
        boolean active
    }
```

---

## 4. Sprint 4 TB / Sprint 5 Analysis — Trial Balance & Reports
## ميزان المراجعة والتحليل

```mermaid
erDiagram
    Client ||--o{ TbUpload : has
    TbUpload ||--o{ TbAccount : contains
    TbUpload ||--|| TbBinding : bound_via
    CoaUpload ||--o{ TbBinding : "matches"
    TbBinding ||--o{ TbBindingRow : "has"

    TbUpload {
        UUID id PK
        UUID client_id FK
        string filename
        string state
        timestamp uploaded_at
    }
    TbAccount {
        UUID id PK
        UUID upload_id FK
        string code
        string name
        decimal debit
        decimal credit
        decimal balance
    }
    TbBinding {
        UUID id PK
        UUID tb_upload_id FK
        UUID coa_upload_id FK
        string state
        decimal match_score
    }
    TbBindingRow {
        UUID id PK
        UUID binding_id FK
        UUID tb_account_id FK
        UUID coa_account_id FK
        decimal confidence
    }

    Client ||--o{ AnalysisRun : produces
    AnalysisRun ||--|| TbBinding : uses
    AnalysisRun ||--o{ AnalysisResult : generates

    AnalysisRun {
        UUID id PK
        UUID client_id FK
        UUID tb_upload_id FK
        string state
        timestamp started_at
        timestamp finished_at
    }
    AnalysisResult {
        UUID id PK
        UUID run_id FK
        string statement_type
        json payload
    }
```

---

## 5. Sprint 4 Knowledge — Concept Graph / خريطة المفاهيم

```mermaid
erDiagram
    Concept ||--o{ ConceptAlias : has
    Concept ||--o{ Rule : referenced_by
    Concept ||--o{ ConceptRelation : from
    Concept ||--o{ ConceptRelation : to

    Concept {
        UUID id PK
        string code UK
        string name
        string name_ar
        string category
        json metadata
    }
    ConceptAlias {
        UUID id PK
        UUID concept_id FK
        string alias
        string source_system
        boolean approved
    }
    ConceptRelation {
        UUID id PK
        UUID from_id FK
        UUID to_id FK
        string relation_type
    }

    Rule ||--o{ RuleCandidate : drafted_as
    Rule {
        UUID id PK
        string name
        text condition
        text action
        boolean active
        UUID promoted_from FK
    }
    RuleCandidate {
        UUID id PK
        UUID submitter_id FK
        text condition
        text action
        string status
        timestamp submitted_at
    }

    SourceSystem {
        UUID id PK
        string name
        string version
        json config
    }
```

---

## 6. Sprint 6 — Reference Registry / سجل المراجع

```mermaid
erDiagram
    Authority ||--o{ Document : issues
    Authority ||--o{ Update : posts
    Authority {
        UUID id PK
        string name
        string country
        string url
    }
    Document {
        UUID id PK
        UUID authority_id FK
        string title
        string doc_type
        string url
        date effective_date
    }
    Update {
        UUID id PK
        UUID authority_id FK
        text content
        date posted_at
        boolean reviewed
    }

    FundingProgram {
        UUID id PK
        string name
        string country
        decimal max_amount
        json criteria
    }
    SupportProgram {
        UUID id PK
        string name
        string country
        json criteria
    }
    LicenseProgram {
        UUID id PK
        string name
        string country
        json requirements
    }

    Client ||--o{ EligibilityAssessment : scored_in
    EligibilityAssessment {
        UUID id PK
        UUID client_id FK
        string program_type
        UUID program_id
        boolean eligible
        json gaps
        timestamp assessed_at
    }
```

---

## 7. Phase 4-5 — Marketplace & Providers / السوق ومقدمو الخدمات

```mermaid
erDiagram
    User ||--o| ServiceProvider : becomes
    ServiceProvider ||--o{ ProviderDocument : uploads
    ServiceProvider ||--o{ ProviderVerification : reviewed_via
    ServiceProvider ||--o{ ServiceRequest : assigned_to
    ServiceProvider ||--o{ ProviderRating : receives
    ServiceProvider ||--o{ Suspension : may_have

    ServiceProvider {
        UUID id PK
        UUID user_id FK
        string display_name
        string professional_id
        json categories
        boolean verified
        decimal rating_avg
        int rating_count
    }
    ProviderDocument {
        UUID id PK
        UUID provider_id FK
        string doc_type
        string storage_url
        boolean verified
    }
    ProviderVerification {
        UUID id PK
        UUID provider_id FK
        UUID admin_id FK
        string action
        text notes
        timestamp at
    }

    Client ||--o{ ServiceRequest : posts
    ServiceRequest ||--o{ RequestMessage : has
    ServiceRequest ||--o| ProviderRating : ends_with

    ServiceRequest {
        UUID id PK
        UUID client_id FK
        UUID provider_id FK
        string title
        text description
        decimal budget
        string status
        timestamp created_at
    }
    RequestMessage {
        UUID id PK
        UUID request_id FK
        UUID sender_id FK
        text body
        timestamp at
    }
    ProviderRating {
        UUID id PK
        UUID request_id FK
        int stars
        text comment
    }

    Suspension {
        UUID id PK
        UUID provider_id FK
        UUID admin_id FK
        string reason
        timestamp from
        timestamp to
        boolean lifted
    }
```

---

## 8. Phase 10 — Notifications V2 / الإشعارات

```mermaid
erDiagram
    User ||--o{ NotificationV2 : receives
    User ||--o| NotificationPreference : has
    NotificationV2 {
        UUID id PK
        UUID user_id FK
        string type
        string title
        text body
        json metadata
        timestamp read_at
        timestamp created_at
    }
    NotificationPreference {
        UUID user_id FK
        json prefs
    }
```

---

## 9. Cross-Cutting — Audit Log / سجل التدقيق العام

```mermaid
erDiagram
    User ||--o{ AuditEvent : generates
    AuditEvent {
        UUID id PK
        UUID user_id FK
        UUID tenant_id
        string event_type
        string resource
        json before_state
        json after_state
        string ip_address
        string user_agent
        string prev_hash
        string this_hash
        timestamp at
    }
```

The hash chain (`prev_hash`, `this_hash`) makes the log tamper-evident.

---

## 10. ERP Pilot Schema (Sprint 5+) / مخطط ERP

The Pilot ERP module (`/api/v1/pilot/*`) implements full bookkeeping:

```mermaid
erDiagram
    Tenant ||--o{ Entity : owns
    Entity ||--o{ Branch : has
    Entity ||--o{ Customer : has
    Entity ||--o{ Vendor : has
    Entity ||--o{ Product : has
    Entity ||--o{ JournalEntry : posts
    Entity ||--o{ FiscalPeriod : has

    Customer ||--o{ SalesInvoice : raised_to
    SalesInvoice ||--o{ SalesInvoiceLine : has
    SalesInvoice ||--o{ CustomerPayment : paid_via
    SalesInvoice ||--o| ZatcaInvoice : cleared_as

    Vendor ||--o{ PurchaseOrder : on
    Vendor ||--o{ PurchaseInvoice : received_from
    PurchaseOrder ||--o{ GoodsReceipt : received_via
    PurchaseInvoice ||--o{ VendorPayment : paid_via

    Branch ||--o{ PosSession : runs
    PosSession ||--o{ PosTicket : sells

    JournalEntry ||--o{ JournalLine : balances

    SalesInvoice ||--o{ JournalEntry : "creates GL entry"
    PurchaseInvoice ||--o{ JournalEntry : "creates GL entry"
    CustomerPayment ||--o{ JournalEntry : "creates GL entry"
    VendorPayment ||--o{ JournalEntry : "creates GL entry"
    PosSession ||--o{ JournalEntry : "creates GL entry"

    Entity {
        UUID id PK
        UUID tenant_id FK
        string name
        string vat_number
        string fiscal_year_start
        string base_currency
    }

    JournalEntry {
        UUID id PK
        UUID entity_id FK
        string reference
        date entry_date
        text description
        string status
        string source_type
        UUID source_id
    }
    JournalLine {
        UUID id PK
        UUID je_id FK
        string account_code
        decimal debit
        decimal credit
        text description
    }
    SalesInvoice {
        UUID id PK
        UUID entity_id FK
        UUID customer_id FK
        string invoice_number UK
        date issue_date
        decimal subtotal
        decimal vat_amount
        decimal total
        string status
        string currency
        decimal fx_rate
    }
    SalesInvoiceLine {
        UUID id PK
        UUID invoice_id FK
        UUID product_id FK
        decimal qty
        decimal unit_price
        decimal vat_rate
        decimal line_total
    }
```

---

## 11. ZATCA / E-Invoicing Schema

```mermaid
erDiagram
    Entity ||--o{ ZatcaDevice : registers
    ZatcaDevice ||--o{ ZatcaCsid : has
    SalesInvoice ||--|| ZatcaInvoice : maps_to
    ZatcaInvoice ||--o{ ZatcaQueueItem : queued_in

    ZatcaDevice {
        UUID id PK
        UUID entity_id FK
        string device_id
        string serial_number
        timestamp registered_at
    }
    ZatcaCsid {
        UUID id PK
        UUID device_id FK
        string csid_type
        text certificate
        text private_key
        timestamp issued_at
        timestamp expires_at
    }
    ZatcaInvoice {
        UUID id PK
        UUID sales_invoice_id FK
        UUID device_id FK
        string uuid
        text ubl_xml
        text qr_tlv
        string clearance_status
        json zatca_response
        timestamp cleared_at
    }
    ZatcaQueueItem {
        UUID id PK
        UUID invoice_id FK
        string state
        int retry_count
        text last_error
        timestamp scheduled_at
    }
```

---

## 12. Knowledge Brain DB (Separate) / دماغ المعرفة (قاعدة منفصلة)

`KB_DATABASE_URL` may point to a separate database. Schema:

```mermaid
erDiagram
    KbConcept ||--o{ KbAlias : has
    KbConcept ||--o{ KbRule : referenced_by
    KbConcept ||--o{ KbRelation : "from/to"

    KbConcept {
        UUID id PK
        string code UK
        string name_en
        string name_ar
        string namespace
        json metadata
    }
    KbAlias {
        UUID id PK
        UUID concept_id FK
        string alias
        string locale
    }
    KbRule {
        UUID id PK
        string name
        json conditions
        json actions
        boolean active
    }
    KbRelation {
        UUID id PK
        UUID from_id FK
        UUID to_id FK
        string type
        decimal weight
    }
```

---

## 13. Total Tables Count / عدد الجداول الإجمالي

| Phase | Tables |
|-------|--------|
| Phase 1 (auth/plans/legal) | 18 |
| Phase 2 (clients/coa/audit) | 12 |
| Phase 3 (knowledge feedback) | 3 |
| Phase 4 (provider verification) | 4 |
| Phase 5 (marketplace) | 6 |
| Phase 6 (admin) | 2 |
| Phase 7 (tasks) | 3 |
| Phase 8 (subscription) | 4 |
| Phase 9 (account center) | 3 |
| Phase 10 (notifications V2) | 2 |
| Phase 11 (legal acceptance) | 3 |
| Sprint 1-3 (COA pipeline) | 5 |
| Sprint 4 (concept graph) | 8 |
| Sprint 4 TB | 4 |
| Sprint 5 (analysis) | 2 |
| Sprint 6 (reference registry) | 7 |
| Pilot ERP | 15 |
| ZATCA | 5 |
| Cross-cutting (audit log, etc.) | 3 |
| **Total** | **~109 tables** |

---

## 14. Schema Migration Strategy / استراتيجية الهجرة

**Current state:** Alembic configured (`alembic.ini` + `alembic/`) but **no migration files**. Schema is created via `Base.metadata.create_all()` at startup.

**Recommendation:**
1. Generate baseline migration: `alembic revision --autogenerate -m "baseline"`
2. Switch startup to run `alembic upgrade head` instead of `create_all`
3. Every model change → new migration
4. CI runs migrations on a fresh DB before tests

Full plan in `09_GAPS_AND_REWORK_PLAN.md` § "Database Migrations".

---

## 15. Indexing Recommendations / توصيات الفهرسة

Critical indexes (some already exist):

```sql
-- User
CREATE UNIQUE INDEX idx_user_email ON users(email);
CREATE INDEX idx_user_tenant ON users(tenant_id);

-- Sessions
CREATE INDEX idx_session_user ON user_sessions(user_id);
CREATE INDEX idx_session_token ON user_sessions(token_hash);

-- Audit
CREATE INDEX idx_audit_user_at ON audit_events(user_id, at DESC);
CREATE INDEX idx_audit_tenant_at ON audit_events(tenant_id, at DESC);

-- ERP
CREATE INDEX idx_je_entity_date ON journal_entries(entity_id, entry_date DESC);
CREATE UNIQUE INDEX idx_invoice_number ON sales_invoices(entity_id, invoice_number);

-- ZATCA
CREATE INDEX idx_zatca_queue_state ON zatca_queue_items(state, scheduled_at);
```

---

## 16. Multi-Tenancy Strategy / استراتيجية تعدد المستأجرين

**Current model:** Discriminator column `tenant_id` on shared tables. Filtered by `TenantContextMiddleware`.

**Trade-offs:**
- Pros: simple ops, single connection pool, easy backups
- Cons: noisy-neighbor risk, hard to do per-tenant retention/region

**Future considerations (Enterprise plan):**
- Per-tenant schema (PostgreSQL `SET search_path`)
- Per-tenant database (separate `DATABASE_URL` per tenant)
- Region pinning for data residency (Saudi data → Saudi region)

---

**Continue → `08_GLOBAL_BENCHMARKS.md`**
