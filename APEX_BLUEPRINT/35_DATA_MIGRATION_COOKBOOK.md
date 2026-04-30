# APEX Data Migration & Onboarding Cookbook

**Status:** Framework & Requirements Definition
**Version:** 1.0  
**Date:** April 30, 2026  
**Audience:** APEX product, engineering, and customer success teams

---

## Executive Summary

Data migration is the #1 friction point for SaaS accounting software adoption, especially in MENA. Most customers today migrate via manual Excel re-entry—painful, error-prone, and time-consuming. Modern SaaS platforms (Xero, Odoo, NetSuite, Stripe) all provide structured data import tooling to reduce friction.

**APEX should build a dedicated "Migration & Data Onboarding" module (v1) that supports:**
- CSV imports with column mapping
- Pre-built importers for QuickBooks, Daftra, Qoyod, and Excel templates
- Real-time validation with line-by-line error reporting
- Dry-run preview before commit
- Idempotent, resumable imports
- Progress tracking for long-running jobs

**Expected Impact:** Reduce customer onboarding time from weeks to days, improve data quality, and enable self-service migration without white-glove support.

---

## 1. The Migration Problem in MENA

### Current State: Manual Spreadsheet Hell

Most MENA businesses (especially Saudi Arabia, UAE, Egypt) still migrate accounting data manually:

1. **Export from legacy system** (QuickBooks, Daftra, Qoyod, Excel, or paper) → unstructured CSV/XLS
2. **Manual re-entry** into new system → customer manually types data, line by line
3. **Spreadsheet errors** → typos, formula breaks, inconsistent formats
4. **Data integrity issues** → duplicate customers, misaligned COA, missing opening balances
5. **Weeks of setup** before going live

**Pain Points (Research-Backed):**
- Data corruption, incomplete details, mismatched formats ([Numeric.io](https://numeric.io/blog/accounting-data-migration))
- Resistance from teams comfortable with Excel
- Temporary productivity decreases during adjustment periods ([Penieltech](https://www.penieltech.com/blog/top-10-accounting-software-in-dubai/))
- Manual reconciliation required post-migration
- Multiple currencies and VAT compliance complexity ([Wafeq Migration Checklist](https://www.wafeq.com/en-business-hub/for-business/accounting-system-migration-checklist:-complete-guide-for-uae-businesses))

### Why MENA is Unique

1. **VAT Compliance Complexity**: UAE (5%), Saudi Arabia (15%), Egypt (14%) → must validate VAT codes during import
2. **Multi-Currency**: USD, AED, SAR, EGP coexist → no single "home currency" assumption
3. **Paper-Based Legacies**: Many SMEs still use handwritten ledgers → no digital export option
4. **Regulatory**: FTA (UAE), Zakat (Saudi), CSR (Egypt) add compliance overhead
5. **Localization**: Account names, report templates, document formats must be Arabic-first
6. **Daftra/Qoyod Lock-In**: Switching costs are high because extraction is manual ([Daftra](https://www.daftra.com/en/), [Qoyod](https://www.qoyod.com/en))

---

## 2. Data Migration Maturity Levels

Industry-standard 5-level framework (based on research from Xero, Odoo, NetSuite, Stripe):

### Level 1: Manual CSV Upload + Column Mapping
**Effort:** Low | **Cost:** $0 | **Time:** 30 mins per file  
**Example:** Stripe's data migrations API, Daftra export

**Features:**
- User uploads CSV file (drag-drop or file picker)
- System auto-detects headers
- User maps columns to APEX fields via UI
- Preview shows first 5 rows
- Import runs, errors flagged at end

**Limitations:** No validation, no deduplication, errors discovered post-import

---

### Level 2: Pre-Built Importers Per Source System
**Effort:** Medium | **Cost:** Engineering effort per source | **Time:** 10 mins per file

**Example:** Xero's QuickBooks migration tool, Odoo's CSV templates

**Features:**
- Dedicated importers for QuickBooks Online, Daftra, Qoyod, Excel
- Pre-mapped column order (user just uploads without mapping step)
- Template download with correct column headers
- Data transformation rules baked in (e.g., QB "Account" → APEX "Account Name")
- Field-level validation (VAT codes, CR numbers, dates)

**Limitations:** Rigid schema, doesn't handle custom fields or data outside template

---

### Level 3: Direct API Integration (Read from Source)
**Effort:** High | **Cost:** OAuth + API client | **Time:** Automated (minutes)

**Example:** Stripe's payment data imports, Xero's QuickBooks API sync, Odoo's external system connectors

**Features:**
- User authenticates source system (OAuth)
- APEX reads data directly from QuickBooks API, Daftra API, etc.
- Field mapping runs server-side
- Delta sync (only new/changed records)
- No manual export/import step

**Limitations:** Requires source system to have robust API, OAuth complexity, rate limits

---

### Level 4: White-Glove Migration Service
**Effort:** Very High | **Cost:** $2K–$10K+ | **Time:** 1–4 weeks

**Example:** NetSuite Migration Services, Xero's professional migration partners

**Features:**
- Dedicated migration consultant assigned
- Data audit & cleansing
- Custom mapping for unique COA structures
- Hands-on validation and verification
- Parallel run (data in both systems, compare before cutover)
- Post-go-live reconciliation

**Limitations:** Not scalable, suitable for enterprise customers only

---

### Level 5: Real-Time Sync (Parallel Run)
**Effort:** Very High | **Cost:** Engineering + ongoing maintenance | **Time:** 0 (continuous)

**Example:** Stripe's parallel processing, cloud ERP dual-system sync

**Features:**
- Both source and APEX run simultaneously for 2–4 weeks
- Every transaction posted to both systems
- Reconciliation dashboard highlights deltas
- Cutover triggered when data matches 100%
- Zero downtime, full rollback if issues

**Limitations:** Extremely complex, requires bidirectional sync, suitable for large migrations only

---

## 3. APEX Migration Module v1: What Must Be Supported

### 3.1 Scope: Level 1 + Level 2

APEX should launch with **Levels 1 & 2** in Phase 2 or as a dedicated Sprint:

**Must Support:**
- CSV import with column mapping wizard (Level 1)
- Pre-built importers for 5 source systems (Level 2)
- Real-time validation + dry-run preview
- Idempotent, resumable imports
- Background job processing (async)
- Audit trail of all imports

**Out of Scope (v1):**
- API integrations (Level 3) — defer to v2
- White-glove services (Level 4) — CSM responsibility
- Real-time sync (Level 5) — future

---

### 3.2 Data Types to Support

#### A. Chart of Accounts (COA)
```
Required Fields:
- account_code (string, 10 chars, unique)
- account_name (string, required)
- account_type (enum: ASSET, LIABILITY, EQUITY, REVENUE, EXPENSE)
- parent_account_code (optional, for hierarchies)
- is_detail_account (boolean, default: true)
- vat_code (string, optional, e.g., "SR5", "Z", "E")
- is_active (boolean, default: true)

Special Rules:
- Parent accounts must exist before child accounts can be created
- Cannot create child of detail account
- COA cannot be modified if journal entries posted to it
```

**Import Validation:**
- Check for duplicate account codes
- Validate parent → child hierarchy (no circular references)
- Warn if account code overlaps with system defaults
- Validate VAT codes against Sage/Oracle VAT lookup (MENA compliance)

**Example:**
```csv
account_code,account_name,account_type,parent_account_code,vat_code,is_active
1000,Current Assets,ASSET,,SR5,true
1100,Cash,ASSET,1000,Z,true
1110,Cash at Bank,ASSET,1100,,true
2000,Current Liabilities,LIABILITY,,SR5,true
```

---

#### B. Customers (Accounts Receivable Subledger)
```
Required Fields:
- customer_code (string, unique)
- customer_name (string)
- contact_name (string, optional)
- email (string, optional)
- phone (string, optional)
- country (string, 2-letter ISO code)
- city (string)
- currency (string, 3-letter ISO code, default: AED/SAR/USD)
- credit_limit (decimal, default: 0)
- tax_id (string, VAT number, required in MENA)
- is_active (boolean)

Opening Balance:
- opening_balance (decimal, as of opening_balance_date)
- opening_balance_date (date)
```

**Import Validation:**
- Check for duplicate customer codes
- Validate email format
- Validate VAT/CR number format per region (UAE 100001234567890, KSA 1010049609)
- Check for special characters in customer_name (potential SQL injection)
- Validate country codes against ISO 3166-1

**Example:**
```csv
customer_code,customer_name,contact_name,email,phone,tax_id,currency,credit_limit,is_active,opening_balance,opening_balance_date
C001,Acme Corp LLC,John Smith,john@acme.com,+971501234567,100001234567890,AED,50000,true,25000,2026-01-01
C002,Global Trade Ltd,Sarah Johnson,sarah@globaltrade.ae,+971501234568,100001234567891,AED,0,true,0,2026-01-01
```

---

#### C. Vendors (Accounts Payable Subledger)
```
Required Fields:
- vendor_code (string, unique)
- vendor_name (string)
- contact_name (string, optional)
- email (string, optional)
- phone (string, optional)
- payment_terms (enum: NET_30, NET_60, COD, etc.)
- currency (string, 3-letter ISO code)
- tax_id (string, VAT number, optional but recommended)
- is_active (boolean)

Opening Balance:
- opening_balance (decimal)
- opening_balance_date (date)
```

**Import Validation:**
- Duplicate vendor code check
- VAT/tax ID validation (if provided)
- Email format validation
- Payment terms enum validation

---

#### D. Products / Services
```
Required Fields:
- product_code (string, unique, SKU)
- product_name (string)
- product_type (enum: INVENTORY, SERVICE, DIGITAL)
- uom (enum: UNIT, KG, LITER, METER, etc., default: UNIT)
- default_sales_price (decimal)
- default_cost (decimal, optional)
- default_revenue_account (account_code, must exist)
- default_expense_account (account_code, optional)
- vat_code (string, required)
- is_active (boolean)
```

**Import Validation:**
- Duplicate product code check
- Revenue account must be REVENUE type
- VAT code must be valid per region
- Sales price must be positive
- Cost must be non-negative

**Example:**
```csv
product_code,product_name,product_type,uom,default_sales_price,vat_code,default_revenue_account,is_active
SKU001,Widget A,INVENTORY,UNIT,100,SR5,4100,true
SKU002,Consulting Services,SERVICE,HOUR,150,SR5,4200,true
```

---

#### E. Opening Balances (Trial Balance)
```
Required Fields:
- account_code (string, must exist in COA)
- debit_amount (decimal, >= 0)
- credit_amount (decimal, >= 0)
- opening_balance_date (date)

Constraints:
- Only one of debit_amount OR credit_amount can be non-zero
- Total debits must equal total credits (balanced TB)
```

**Import Validation:**
- Account code must exist
- Debit + Credit totals must match exactly
- Date must be within valid fiscal year
- Flag accounts with unusual balances (e.g., revenue account with debit balance)

**Example:**
```csv
account_code,debit_amount,credit_amount,opening_balance_date
1100,150000,0,2026-01-01
1110,50000,0,2026-01-01
4100,0,200000,2026-01-01
2100,0,100000,2026-01-01
```

---

#### F. Historical Transactions (Journal Entries)
```
Required Fields:
- document_date (date, must be in open period)
- document_type (enum: INV, BILL, JE, PT, CT)
- document_number (string, unique per type per month)
- line_sequence (int, 1+ for ordering)
- account_code (string, must exist in COA)
- debit_amount (decimal, >= 0)
- credit_amount (decimal, >= 0)
- description (string)
- reference (string, optional, e.g., invoice #)

Optional (linked to subledgers):
- customer_code (if AR-related)
- vendor_code (if AP-related)
```

**Import Validation:**
- Account code must exist
- Document date must be in open period
- Debit + Credit must balance per document
- Each document must have at least 2 lines (double-entry rule)
- Cannot post to EQUITY accounts (except via specific journal entries)

---

#### G. Bank Accounts
```
Required Fields:
- bank_account_code (string, unique)
- bank_name (string)
- account_number (string)
- iban (string, optional but recommended)
- currency (string, 3-letter ISO)
- opening_balance (decimal, as of opening_balance_date)
- opening_balance_date (date)
- is_active (boolean)
```

**Import Validation:**
- IBAN format validation (per country)
- Duplicate account number check (within same currency)
- Opening balance must be present

---

#### H. Employees (HR Integration)
```
Required Fields:
- employee_id (string, unique)
- first_name (string)
- last_name (string)
- email (string)
- phone (string)
- department (string)
- job_title (string)
- hire_date (date)
- salary (decimal, if payroll system imports)
- is_active (boolean)
```

**Import Validation:**
- Email uniqueness check
- Hire date must be before today
- Department must match org structure
- Salary must be positive

---

### 3.3 Supported File Formats (v1)

1. **CSV** (comma-separated, UTF-8)
2. **XLSX** (Excel 2007+, parsed to CSV internally)
3. **TSV** (tab-separated, for Daftra exports)

**Not Supported (v1):**
- JSON (defer to v2 API)
- XML (defer to v2 API)
- PDF (requires OCR, out of scope)
- Proprietary formats (QB Desktop .QBW, etc.)

---

### 3.4 Supported Source Systems (v1)

#### 1. QuickBooks Online
**Template Name:** `QB_Online_Export_Template.xlsx`

**Key Mapping:**
- QB "Account" → APEX "account_code"
- QB "Account Name" → APEX "account_name"
- QB "Account Type" → APEX "account_type" (with lookup table)
- QB "Opening Balance" → APEX trial balance import

**Special Handling:**
- QB uses hierarchical account names (e.g., "Current Assets:Cash:Cash at Bank") → parse hierarchy, create parents
- QB doesn't have VAT codes → user must add during mapping step or via UI post-import
- QB COA can have thousands of accounts → warn user, suggest archiving unused

**Export Steps (Customer Docs):**
1. QB Online → Accounting → Chart of Accounts
2. Click "Download" → CSV export
3. Upload to APEX

---

#### 2. Daftra (Arabic ERP)
**Template Name:** `Daftra_Export_Template.xlsx`

**Key Mapping:**
- Daftra "رقم الحساب" → APEX "account_code"
- Daftra "اسم الحساب" → APEX "account_name"
- Daftra "نوع الحساب" → APEX "account_type"

**Special Handling:**
- Daftra uses right-to-left (RTL) Arabic text → validate UTF-8 BOM
- Multi-currency support (AED/SAR/USD/EGP) → user specifies home currency
- VAT codes are Daftra-specific → map to APEX VAT codeset or use as custom field

**Export Steps (Customer Docs):**
1. Daftra → الإعدادات (Settings) → الحسابات (Chart of Accounts)
2. تصدير (Export) → CSV/Excel
3. Upload to APEX

---

#### 3. Qoyod (KSA-Focused)
**Template Name:** `Qoyod_Export_Template.xlsx`

**Key Mapping:**
- Qoyod "رمز الحساب" → APEX "account_code"
- Qoyod "اسم الحساب" → APEX "account_name"

**Special Handling:**
- Qoyod is optimized for Saudi Arabia (15% VAT, Zakat compliance)
- Customer/Vendor lists include CR (Commercial Registration) numbers
- Bank reconciliation data available via API (not CSV export)

---

#### 4. Generic Excel Template
**Template Name:** `APEX_Generic_Import_Template.xlsx`

**Sheet 1: Chart of Accounts**
Columns: account_code, account_name, account_type, parent_account_code, vat_code, is_active

**Sheet 2: Customers**
Columns: customer_code, customer_name, email, phone, tax_id, currency, credit_limit, opening_balance

**Sheet 3: Vendors**
Columns: vendor_code, vendor_name, payment_terms, tax_id, opening_balance

**Sheet 4: Products**
Columns: product_code, product_name, product_type, uom, default_sales_price, vat_code

**Sheet 5: Opening Balances**
Columns: account_code, debit_amount, credit_amount, opening_balance_date

**Sheet 6: Transactions (Optional)**
Columns: document_date, document_type, document_number, account_code, debit_amount, credit_amount, description

---

## 4. Data Quality Issues & Handling

| Issue | Root Cause | Detection | Resolution |
|-------|-----------|-----------|-----------|
| **Duplicates** | Merged companies, multiple ledger systems | Hash(code + name), fuzzy matching | Flag & consolidate, or reject |
| **Missing Required Fields** | Manual data entry, incomplete exports | Schema validation | Mark row as error, skip with user review |
| **Invalid VAT Codes** | Typos, regional variance (SR5 vs S5) | Lookup against VAT codeset | Suggest correction, allow override |
| **Date Format Mismatch** | Locale-specific (DD/MM/YYYY vs MM/DD/YYYY) | Try multiple parsers, show examples | Ask user to clarify, reparse |
| **Currency Mismatch** | Assumed home currency vs actual | Check ISO 4217 codes | Validate against org default, warn |
| **Circular COA Hierarchy** | Accidental parent→child→parent loop | Graph traversal, DFS cycle detection | Reject import, show cycle path |
| **Unbalanced Trial Balance** | Arithmetic error, missing accounts | Sum debit vs sum credit | Show delta, reject until fixed |
| **Account Code Conflicts** | Code in use or reserved by system | Lookup in existing COA | Suggest renumbering or merge |
| **Negative Opening Balances** | Manual entry error, liability in debit | Schema validation (debit OR credit, not both) | Flag for review, allow if intentional |
| **Special Characters** | Encoding issues, copy/paste from Word | Regex validation, ASCII/UTF-8 checks | Sanitize or reject with examples |

---

## 5. APEX Migration Module Architecture

### 5.1 Module Structure

```
app/migration/
├── __init__.py
├── models/
│   ├── __init__.py
│   ├── import_job.py         # ImportJob, ImportLog, MappingConfig
│   ├── import_templates.py   # SourceSystemTemplate, ColumnMapping
│   └── import_errors.py      # ImportError, ValidationError
├── routes/
│   ├── __init__.py
│   ├── upload.py             # POST /migration/upload
│   ├── mapping.py            # POST /migration/map-columns
│   ├── preview.py            # POST /migration/preview
│   ├── validate.py           # POST /migration/validate
│   └── execute.py            # POST /migration/execute, GET /migration/jobs/{id}
├── services/
│   ├── __init__.py
│   ├── importers/
│   │   ├── base_importer.py  # Abstract importer class (ETL pattern)
│   │   ├── csv_importer.py   # CSV-specific logic
│   │   ├── qb_importer.py    # QuickBooks-specific mapping
│   │   ├── daftra_importer.py
│   │   ├── qoyod_importer.py
│   │   └── excel_importer.py
│   ├── mappers/
│   │   ├── column_mapper.py   # Maps CSV columns → APEX fields
│   │   ├── vat_mapper.py      # VAT code lookup & validation
│   │   └── coa_mapper.py      # COA hierarchy reconstruction
│   ├── validators/
│   │   ├── schema_validator.py # Type & format validation
│   │   ├── business_validator.py # COA hierarchy, balances, duplicates
│   │   └── compliance_validator.py # VAT, CR numbers, regional rules
│   ├── loaders/
│   │   ├── coa_loader.py     # Transactional COA insert
│   │   ├── customer_loader.py
│   │   ├── vendor_loader.py
│   │   ├── transaction_loader.py
│   │   └── batch_loader.py   # Bulk insert with rollback
│   └── workers/
│       ├── import_worker.py  # Celery task: extract → map → validate → load
│       └── job_monitor.py    # Job status updates, error logging
└── templates/
    ├── QB_Online_Export_Template.xlsx
    ├── Daftra_Export_Template.xlsx
    ├── Qoyod_Export_Template.xlsx
    ├── APEX_Generic_Import_Template.xlsx
    └── README_Import_Templates.md
```

---

### 5.2 Data Flow (ETL Pattern)

```
USER SUBMITS FILE
      ↓
[1] EXTRACT
      ├─ File upload (S3 or local)
      ├─ Auto-detect format (CSV, XLSX, TSV)
      ├─ Parse headers & sample 100 rows
      └─ Store raw_data in ImportJob
      ↓
[2] MAP
      ├─ User maps CSV columns → APEX field names
      ├─ System suggests mappings (fuzzy match on headers)
      ├─ User confirms or edits
      └─ Store mapping_config in ImportJob
      ↓
[3] VALIDATE (DRY RUN)
      ├─ Iterate over all rows
      ├─ Schema validation (type, format, required)
      ├─ Business validation (duplicates, COA hierarchy, balance)
      ├─ Compliance validation (VAT codes, CR numbers)
      ├─ Collect errors (row number, field, error message, suggestion)
      └─ Return error report without modifying database
      ↓
[4] PREVIEW
      ├─ Show first 10 valid rows
      ├─ Show error summary (5 errors, 100 valid rows)
      ├─ Ask user to confirm or fix
      └─ Store preview result
      ↓
[5] LOAD (ASYNC JOB)
      ├─ Transaction scope
      ├─ Iterate over valid rows
      ├─ Insert/upsert records
      ├─ Log audit trail (who, what, when)
      ├─ On error: rollback entire import
      └─ Update job status → COMPLETED / FAILED
      ↓
JOB COMPLETE
      └─ Send user notification (email, in-app)
```

---

### 5.3 Database Schema (Simplified)

```sql
-- Migration import jobs
CREATE TABLE migration.import_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    source_system VARCHAR(50) NOT NULL, -- 'QB_ONLINE', 'DAFTRA', 'GENERIC', etc.
    import_type VARCHAR(50) NOT NULL, -- 'COA', 'CUSTOMERS', 'VENDORS', 'TRANSACTIONS'
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING', -- PENDING, MAPPING, PREVIEW, RUNNING, COMPLETED, FAILED
    file_url VARCHAR(500), -- S3 URL or local path
    file_size_bytes BIGINT,
    raw_row_count INT,
    valid_row_count INT DEFAULT 0,
    error_row_count INT DEFAULT 0,
    mapping_config JSONB, -- { "csv_columns": [...], "apex_fields": [...], "column_map": {...} }
    validation_errors JSONB, -- [ { "row": 2, "field": "vat_code", "error": "...", "suggestion": "..." }, ... ]
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    created_by VARCHAR(500) -- user email
);

-- Import audit trail
CREATE TABLE migration.import_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    import_job_id UUID NOT NULL REFERENCES migration.import_jobs(id) ON DELETE CASCADE,
    action VARCHAR(50), -- 'UPLOADED', 'MAPPED', 'VALIDATED', 'LOADED_ROW', 'ERROR'
    row_number INT,
    field_name VARCHAR(100),
    old_value TEXT,
    new_value TEXT,
    error_message TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Mapping templates (for re-use)
CREATE TABLE migration.mapping_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    template_name VARCHAR(200) NOT NULL,
    source_system VARCHAR(50) NOT NULL,
    import_type VARCHAR(50) NOT NULL,
    mapping_config JSONB NOT NULL,
    is_public BOOLEAN DEFAULT FALSE, -- share with org
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, template_name)
);
```

---

### 5.4 Async Job Processing (Celery)

```python
# app/migration/workers/import_worker.py

from celery import shared_task
from app.migration.services.importers.base_importer import ImporterFactory
from app.migration.services.validators import SchemaValidator, BusinessValidator
from app.migration.services.loaders import BatchLoader
import logging

logger = logging.getLogger(__name__)

@shared_task(bind=True, max_retries=3)
def run_import_job(self, import_job_id: str):
    """
    Async task: extract → map → validate → load
    Retryable with exponential backoff
    """
    import_job = ImportJob.get(import_job_id)
    
    try:
        # Extract
        importer = ImporterFactory.create(import_job.source_system)
        raw_data = importer.extract(import_job.file_url)
        
        # Map
        mapped_data = importer.map_columns(raw_data, import_job.mapping_config)
        
        # Validate (skip if already validated)
        if import_job.status != 'PREVIEW':
            validator = SchemaValidator()
            errors = validator.validate_bulk(mapped_data, import_job.import_type)
            if errors:
                import_job.status = 'VALIDATION_FAILED'
                import_job.validation_errors = errors
                import_job.save()
                return
        
        # Load (transactional)
        loader = BatchLoader(import_job.company_id)
        loader.load(mapped_data, import_job.import_type)
        
        import_job.status = 'COMPLETED'
        import_job.completed_at = datetime.now()
        import_job.save()
        
        # Notify user
        send_import_complete_email(import_job.user_id, import_job)
        
    except Exception as exc:
        logger.error(f"Import job {import_job_id} failed: {exc}")
        import_job.status = 'FAILED'
        import_job.error_message = str(exc)
        import_job.save()
        
        # Retry with exponential backoff
        raise self.retry(exc=exc, countdown=2 ** self.request.retries)
```

---

### 5.5 API Endpoints (REST)

#### POST /migration/upload
**Upload file and detect format**

Request:
```json
{
  "source_system": "QB_ONLINE",
  "import_type": "COA",
  "file": <multipart file>
}
```

Response:
```json
{
  "success": true,
  "data": {
    "import_job_id": "550e8400-e29b-41d4-a716-446655440000",
    "file_size_bytes": 102400,
    "detected_format": "XLSX",
    "raw_row_count": 150,
    "headers": ["account_code", "account_name", "account_type", "parent_account_code"],
    "sample_rows": [
      {"account_code": "1000", "account_name": "Assets", "account_type": "ASSET"},
      {"account_code": "1100", "account_name": "Cash", "account_type": "ASSET"}
    ]
  }
}
```

---

#### POST /migration/map-columns
**User maps CSV columns to APEX fields**

Request:
```json
{
  "import_job_id": "550e8400-e29b-41d4-a716-446655440000",
  "mapping": {
    "CSV Column 0": "account_code",
    "CSV Column 1": "account_name",
    "CSV Column 2": "account_type",
    "CSV Column 3": "parent_account_code"
  }
}
```

Response:
```json
{
  "success": true,
  "data": {
    "mapping_saved": true,
    "status": "MAPPED"
  }
}
```

---

#### POST /migration/preview
**Validate and show dry-run preview**

Request:
```json
{
  "import_job_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

Response:
```json
{
  "success": true,
  "data": {
    "valid_row_count": 145,
    "error_row_count": 5,
    "preview_rows": [
      {"row": 1, "account_code": "1000", "account_name": "Assets", "status": "OK"},
      {"row": 2, "account_code": "1100", "account_name": "Cash", "status": "OK"}
    ],
    "errors": [
      {
        "row": 10,
        "field": "vat_code",
        "error": "Invalid VAT code 'XX'",
        "suggestion": "Valid codes: SR5, Z, E, V5, A4"
      },
      {
        "row": 15,
        "field": "parent_account_code",
        "error": "Parent account '5000' does not exist",
        "suggestion": "Create parent account 5000 first, or remove parent reference"
      }
    ],
    "status": "PREVIEW"
  }
}
```

---

#### POST /migration/execute
**Start async import job**

Request:
```json
{
  "import_job_id": "550e8400-e29b-41d4-a716-446655440000",
  "dry_run": false
}
```

Response:
```json
{
  "success": true,
  "data": {
    "import_job_id": "550e8400-e29b-41d4-a716-446655440000",
    "status": "RUNNING",
    "message": "Import job started. Check progress at /migration/jobs/{id}"
  }
}
```

---

#### GET /migration/jobs/{import_job_id}
**Poll job status (SSE or WebSocket alternative)**

Response:
```json
{
  "success": true,
  "data": {
    "import_job_id": "550e8400-e29b-41d4-a716-446655440000",
    "status": "RUNNING",
    "progress_percent": 65,
    "processed_rows": 97,
    "total_rows": 145,
    "errors_so_far": 3,
    "estimated_completion": "2026-04-30T14:30:00Z"
  }
}
```

---

#### GET /migration/jobs/{import_job_id}/results
**Get final results and error report**

Response:
```json
{
  "success": true,
  "data": {
    "import_job_id": "550e8400-e29b-41d4-a716-446655440000",
    "status": "COMPLETED",
    "created_count": 142,
    "updated_count": 3,
    "error_count": 0,
    "completed_at": "2026-04-30T14:25:00Z",
    "results_url": "https://s3.amazonaws.com/apex-imports/550e8400-e29b-41d4-a716-446655440000-results.csv",
    "audit_log": [
      {"action": "LOADED_ROW", "row": 1, "entity_id": "acc_123", "created_at": "..."},
      {"action": "LOADED_ROW", "row": 2, "entity_id": "acc_124", "created_at": "..."}
    ]
  }
}
```

---

## 6. Migration UX Wireframe

### Step 1: Pick Source & File Upload

```
┌─────────────────────────────────────────────────────┐
│ MIGRATE YOUR DATA TO APEX                           │
├─────────────────────────────────────────────────────┤
│                                                       │
│ Step 1 of 6: Select Your Source                      │
│                                                       │
│ Choose where your data is coming from:              │
│                                                       │
│  ○ QuickBooks Online                                │
│  ○ Daftra (Arabic ERP)                             │
│  ○ Qoyod (KSA Accounting)                          │
│  ○ Excel or CSV (Generic)                          │
│  ○ Other (contact support)                         │
│                                                       │
│ Selected: [QuickBooks Online]                       │
│                                                       │
│ ┌─────────────────────────────────────────────────┐ │
│ │ 📁 Drag & drop your file here                   │ │
│ │ or click to browse                              │ │
│ │                                                 │ │
│ │ Supported: CSV, XLSX                            │ │
│ │ Max size: 100 MB                                │ │
│ └─────────────────────────────────────────────────┘ │
│                                                       │
│ Download template: [QB_Online_Export_Template.xlsx] │
│                                                       │
│                          [Cancel] [Next: Map Data] → │
└─────────────────────────────────────────────────────┘
```

---

### Step 2: Map Columns

```
┌─────────────────────────────────────────────────────┐
│ MIGRATE YOUR DATA TO APEX                           │
├─────────────────────────────────────────────────────┤
│                                                       │
│ Step 2 of 6: Map Your Columns                       │
│                                                       │
│ We found 150 rows with these columns:              │
│                                                       │
│ CSV Column          →  APEX Field          Status   │
│ ──────────────────────────────────────────────────  │
│ Account Code        →  [account_code]       ✓       │
│ Account Name        →  [account_name]       ✓       │
│ Account Type        →  [account_type]       ✓       │
│ (unused)            →  [skip]               ○       │
│ Parent Account      →  [parent_account]     ✓       │
│                                                       │
│ Need help mapping? [Show Examples] [Auto-Fill]     │
│                                                       │
│                  [← Back] [Next: Preview] →         │
└─────────────────────────────────────────────────────┘
```

---

### Step 3: Preview & Validate

```
┌─────────────────────────────────────────────────────┐
│ MIGRATE YOUR DATA TO APEX                           │
├─────────────────────────────────────────────────────┤
│                                                       │
│ Step 3 of 6: Preview & Validate                     │
│                                                       │
│ ✓ 145 rows valid                                    │
│ ⚠ 5 rows have errors (see below)                   │
│ ⏭ 0 rows skipped                                    │
│                                                       │
│ Sample Valid Rows:                                 │
│ ┌─────────────────────────────────────────────────┐ │
│ │ account_code │ account_name │ account_type │ ... │ │
│ ├─────────────────────────────────────────────────┤ │
│ │ 1000         │ Assets       │ ASSET        │ ... │ │
│ │ 1100         │ Cash         │ ASSET        │ ... │ │
│ │ 1200         │ Accounts Rec │ ASSET        │ ... │ │
│ └─────────────────────────────────────────────────┘ │
│                                                       │
│ Errors to Fix (5 rows):                             │
│ ┌─────────────────────────────────────────────────┐ │
│ │ Row 10: Field vat_code = "XX"                   │ │
│ │ Error: Invalid VAT code                         │ │
│ │ Suggestion: Use one of [SR5, Z, E, V5, A4]     │ │
│ │ [Fix] [Ignore] [Delete Row]                     │ │
│ │                                                 │ │
│ │ Row 15: Field parent_account_code = "5000"      │ │
│ │ Error: Parent account does not exist            │ │
│ │ Suggestion: Create account 5000 or remove link  │ │
│ │ [Fix] [Ignore] [Delete Row]                     │ │
│ └─────────────────────────────────────────────────┘ │
│                                                       │
│                  [← Back] [Next: Import] →          │
└─────────────────────────────────────────────────────┘
```

---

### Step 4: Confirm & Run

```
┌─────────────────────────────────────────────────────┐
│ MIGRATE YOUR DATA TO APEX                           │
├─────────────────────────────────────────────────────┤
│                                                       │
│ Step 4 of 6: Ready to Import                        │
│                                                       │
│ Summary:                                             │
│ ─────────────────────────────────────────────────  │
│ Data Type:           Chart of Accounts              │
│ Source:              QuickBooks Online              │
│ Rows to Import:      145                            │
│ Estimated Time:      ~2 minutes                     │
│                                                       │
│ ⚠️ IMPORTANT:                                        │
│  - Existing COA will NOT be overwritten             │
│  - Duplicates will be skipped (see audit log)       │
│  - You can import multiple batches                  │
│  - Once complete, you cannot undo this import       │
│                                                       │
│ □ I understand and want to proceed                 │
│                                                       │
│              [← Back] [Import Now] →                │
└─────────────────────────────────────────────────────┘
```

---

### Step 5: Progress Tracking

```
┌─────────────────────────────────────────────────────┐
│ MIGRATE YOUR DATA TO APEX                           │
├─────────────────────────────────────────────────────┤
│                                                       │
│ Step 5 of 6: Importing...                           │
│                                                       │
│ ▓▓▓▓▓▓▓▓▓░░░░░░░░░░  65%                           │
│                                                       │
│ Processed: 97 / 145 rows                            │
│ Time elapsed: 1 min 23 sec                          │
│ Estimated time left: 45 sec                         │
│                                                       │
│ Current row (97):                                   │
│ account_code=5200, account_name=Depreciation       │
│                                                       │
│ Status: ✓ Loading accounts...                       │
│                                                       │
│ You can close this window and come back later.      │
│ We'll email you when the import is complete.        │
│                                                       │
│                                [Close Window]        │
└─────────────────────────────────────────────────────┘
```

---

### Step 6: Results & Completion

```
┌─────────────────────────────────────────────────────┐
│ MIGRATE YOUR DATA TO APEX                           │
├─────────────────────────────────────────────────────┤
│                                                       │
│ Step 6 of 6: Import Complete ✓                      │
│                                                       │
│ Success! 145 Chart of Accounts imported             │
│                                                       │
│ Summary:                                             │
│ ─────────────────────────────────────────────────  │
│ ✓ Created:   142 new accounts                       │
│ ○ Updated:     3 existing accounts                  │
│ ⚠ Skipped:     0 rows (no errors)                   │
│ ⏱ Duration:   2 minutes 15 seconds                 │
│                                                       │
│ Next Steps:                                          │
│  1. Import Customers & Vendors                      │
│  2. Review & adjust opening balances                │
│  3. Reconcile trial balance                         │
│  4. Go live!                                        │
│                                                       │
│ [View Audit Log] [Download Report] [Start Over]    │
│                                                       │
│                   [Done] [Next: Customers] →        │
└─────────────────────────────────────────────────────┘
```

---

## 7. Migration Cookbook: Top 5 Source Systems

### 7.1 QuickBooks Online → APEX

**What Can Be Migrated:**
- Chart of Accounts
- Customers (with opening balances)
- Vendors (with opening balances)
- Products/Services
- Trial Balance (opening)
- Last 12 months of transactions

**What Cannot Be Migrated:**
- Complex custom fields (QB has flexible fields; APEX has fixed schema)
- Memorized transactions or recurring invoices
- QB-specific reports or dashboards
- Attachments or notes

**Step-by-Step:**

1. **Export from QB Online:**
   ```
   QB Online → Accounting → Chart of Accounts → Download
   QB Online → Sales → Customers → Export
   QB Online → Expenses → Vendors → Export
   QB Online → Reports → Balance Sheet (as of your cutover date)
   ```

2. **Download APEX Template:**
   ```
   APEX Migration → Templates → Download QB_Online_Export_Template.xlsx
   ```

3. **Upload & Map:**
   - Map QB "Account Type" to APEX account_type (e.g., QB "Bank" → APEX "ASSET")
   - Map QB customer names to APEX customer_code (auto-generated if blank)
   - Handle VAT: QB doesn't have regional VAT → user must add via UI or CSV

4. **Validate & Import:**
   - Check for circular COA hierarchy (rare but possible in QB)
   - Verify opening balances match QB balance sheet
   - Import in this order: COA → Customers → Vendors → Opening Balances → Transactions

5. **Reconciliation:**
   - Compare APEX trial balance vs QB trial balance
   - Flag differences > $1 for review
   - Test a few customer invoices end-to-end

---

### 7.2 Daftra → APEX

**What Can Be Migrated:**
- Chart of Accounts (hierarchical)
- Customers & Vendors (with CR numbers)
- Products & Services
- Opening balances
- Invoice data (12 months)
- Multi-currency transactions

**Daftra-Specific Considerations:**
- RTL (Arabic) text → validate UTF-8 encoding
- Daftra uses hierarchical account names (e.g., "الأصول / النقد" = Assets / Cash)
- Multi-currency → user specifies home currency for APEX
- VAT codes are Daftra-specific → map to APEX VAT codeset

**Step-by-Step:**

1. **Export from Daftra:**
   ```
   Daftra → الإعدادات (Settings) → الحسابات (Chart of Accounts) → تصدير (Export) → CSV
   Daftra → العملاء (Customers) → تصدير (Export)
   Daftra → الموردين (Vendors) → تصدير (Export)
   Daftra → الميزانية (Trial Balance) → تصدير
   ```

2. **Download & Prepare:**
   - Download APEX_Generic_Import_Template.xlsx
   - Open Daftra export in Excel, copy/paste to APEX template
   - Preserve Arabic text (do NOT convert to English)
   - Validate currency consistency

3. **Map & Validate:**
   - Daftra "اسم الحساب" (Account Name) → APEX "account_name"
   - Daftra hierarchy (parent/child) → APEX "parent_account_code"
   - VAT codes → cross-check against APEX VAT codeset

4. **Handle Multi-Currency:**
   ```
   APEX Setting: Home Currency = AED (or user's choice)
   Opening Balances: Convert to home currency (at historical rates)
   Transactions: Keep original currency, track conversion rates
   ```

5. **Import & Verify:**
   - Import in order: COA (parents before children) → Customers → Vendors → Balances
   - Verify Arabic text displays correctly
   - Test reports in both Arabic & English

---

### 7.3 Qoyod → APEX

**What Can Be Migrated:**
- Chart of Accounts
- Customers (including CR numbers)
- Vendors
- Products
- Opening balances
- Transactions

**Qoyod-Specific Considerations:**
- Optimized for Saudi Arabia (15% VAT, Zakat compliance)
- CR (Commercial Registration) number validation
- Payment terms are Qoyod-specific

**Step-by-Step:**

1. **Export from Qoyod:**
   ```
   Qoyod → الإعدادات (Settings) → الحسابات (Chart of Accounts) → تصدير
   Qoyod → العملاء (Customers) → تصدير
   (Note: Qoyod exports are Arabic-named, ensure UTF-8 BOM)
   ```

2. **Validate CR Numbers:**
   ```python
   # Saudi CR format: 1234567890 (10 digits)
   import re
   cr_pattern = r'^\d{10}$'
   if not re.match(cr_pattern, customer['cr_number']):
       raise ValueError(f"Invalid CR: {customer['cr_number']}")
   ```

3. **Map Qoyod → APEX:**
   - Qoyod "رمز الحساب" → account_code
   - Qoyod "اسم الحساب" → account_name
   - Qoyod VAT (15%) → APEX "S15" (Saudi 15%)

4. **Import & Compliance Check:**
   - Verify all customers/vendors have CR numbers
   - Check Zakat-related accounts exist (if required by business)
   - Validate 15% VAT is applied to taxable accounts only

---

### 7.4 Excel (Free Format) → APEX

**What Can Be Migrated:**
- Any structured data (COA, Customers, Vendors, Products, Balances)

**Considerations:**
- User responsible for data quality
- No vendor-specific mapping
- Requires manual column mapping

**Step-by-Step:**

1. **User Prepares Excel:**
   - Open any accounting export or manual spreadsheet
   - Ensure one data type per sheet (COA, Customers, etc.)
   - Add headers: account_code, account_name, account_type, ...
   - Save as .xlsx or .csv

2. **Upload to APEX:**
   ```
   Migration → Upload → Select "Excel or CSV (Generic)"
   ```

3. **Auto-Detect & Map:**
   - APEX fuzzy-matches headers to APEX fields
   - Example: "Account #" → "account_code", "Cust Name" → "customer_name"
   - User confirms or manually corrects mapping

4. **Validate & Import:**
   - Standard validation (required fields, formats, duplicates)
   - User fixes errors or ignores (with acknowledgment)
   - Import runs

---

### 7.5 SAP B1 → APEX (Complex, Enterprise)

**Scope:** Not recommended for v1 (too complex). Defer to v2 or white-glove services.

**Why SAP → APEX Migration is Painful:**

1. **SAP B1 Complexity:**
   - Thousands of tables (OACT, OCRD, OVTG, OJDT, etc.)
   - Custom user-defined fields (UDF)
   - Complex hierarchies (cost centers, profit centers, dimensions)
   - Legacy data quality issues

2. **Options:**

   **Option A: Manual Export via SAP Query**
   ```sql
   -- SAP Query (SQ03) to extract COA
   SELECT T.AcctCode, T.AcctName, T.AcctType
   FROM OACT T
   WHERE T.Frozen = 'N'
   ORDER BY T.AcctCode
   ```

   **Option B: Use SAP BI/BW**
   - Extract via BAPI_GL_GET_ACCOUNT or similar
   - Transform using SAP DataServices or custom ETL
   - Load to APEX

   **Option C: Third-Party SAP Integration Tool**
   - Talend, Boomi, Trifacta
   - Cost: $5K–$50K+
   - Timeline: 4–12 weeks

3. **APEX Recommendation for v1:**
   - Flag SAP migrations as "Enterprise Only"
   - Refer to certified SAP → Modern Cloud ERP partners
   - Offer Level 4 white-glove service (if customer requests)

---

## 8. Implementation Timeline & Effort

### Phase 2 Sprint 3: Migration Module v1

**Duration:** 3–4 weeks (18–20 story points)

**Breakdown:**

| Task | Effort | Owner | Deliverable |
|------|--------|-------|-------------|
| Database schema (ImportJob, logs) | 1 day | Backend | migration/models |
| CSV parser + column detection | 2 days | Backend | csv_importer.py |
| Schema validator | 2 days | Backend | validators/ |
| COA hierarchical loader | 2 days | Backend | loaders/coa_loader.py |
| Celery worker + async jobs | 1 day | Backend | workers/import_worker.py |
| REST API endpoints (upload, map, preview, execute) | 2 days | Backend | migration/routes/ |
| QuickBooks importer | 1 day | Backend | qb_importer.py |
| Daftra importer (RTL support) | 1 day | Backend | daftra_importer.py |
| Qoyod importer | 0.5 day | Backend | qoyod_importer.py |
| Excel template library | 0.5 day | Backend | migration/templates/ |
| Flutter UI: 6-step wizard | 3 days | Frontend | migration_screen.dart |
| Integration tests (204 existing → +50 migration tests) | 2 days | QA | test_migration.py |
| Customer docs & video walkthrough | 1 day | DevEx | 35_DATA_MIGRATION_COOKBOOK.md |
| **Total** | **~20 days** | | **v1.0 ready** |

---

## 9. Recommendation: Create Separate Documentation

**YES.** This cookbook should be a standalone document: `35_DATA_MIGRATION_COOKBOOK.md`

**Why:**
1. **Size:** Migration is a complex feature requiring 3000+ words of detail
2. **Audience:** PMs, engineers, CSMs, and customers need this reference
3. **Lifecycle:** Evolves separately from main architecture docs
4. **SEO:** Customers Google "how to migrate to APEX accounting software" → lands on migration cookbook
5. **Updateability:** As migration patterns change (v2, API integrations), this doc updates independently

**Companion Docs to Create:**
- `MIGRATION_TEMPLATES/QB_Online_Export_Template.xlsx`
- `MIGRATION_TEMPLATES/Daftra_Export_Template.xlsx`
- `MIGRATION_TEMPLATES/Qoyod_Export_Template.xlsx`
- `MIGRATION_TEMPLATES/APEX_Generic_Import_Template.xlsx`
- `MIGRATION_API_REFERENCE.md` (detailed endpoint docs)
- `MIGRATION_TROUBLESHOOTING.md` (common errors & fixes)

---

## 10. Data Quality & Idempotency

### Idempotent Import Design

**Key Principle:** Importing the same file twice should not create duplicates or corrupt data.

**Implementation:**

```python
# Use external ID (dedup key) pattern
class ImportBatch:
    batch_id = str(UUID4())  # Unique ID for this import run
    import_timestamp = datetime.now()
    
    def load_customer(self, customer_data):
        # Dedup key: (company_id, source_system, customer_code)
        dedup_key = hash((self.company_id, "QB_ONLINE", customer_data['code']))
        
        # Upsert: if exists, update; if not, insert
        customer = Customer.query.filter_by(
            company_id=self.company_id,
            source_system="QB_ONLINE",
            external_id=dedup_key
        ).first()
        
        if customer:
            # Update existing record
            customer.update(customer_data)
            return "UPDATED"
        else:
            # Insert new record
            customer = Customer.create(customer_data)
            customer.external_id = dedup_key
            return "CREATED"
```

---

### Duplicate Detection

**Before Import:**
```python
class DuplicateDetector:
    def find_duplicates(self, import_rows, import_type):
        """Find duplicates within import batch and vs. existing data."""
        
        if import_type == 'COA':
            # Check for duplicate account codes
            codes = [row['account_code'] for row in import_rows]
            duplicates = [code for code in codes if codes.count(code) > 1]
            
            # Check existing COA for conflicts
            existing = Account.query.filter(
                Account.account_code.in_(codes)
            ).all()
            
            return {
                'within_batch': duplicates,
                'conflicts_with_existing': [a.account_code for a in existing]
            }
        
        # Similar logic for customers, vendors, products
```

---

### Rollback Strategy

**Transaction-Based Rollback:**
```python
from sqlalchemy import event, exc

@shared_task
def run_import_job(import_job_id):
    import_job = ImportJob.get(import_job_id)
    
    # Open a single transaction for the entire import
    with db.session.begin_nested():
        try:
            loader = BatchLoader(import_job.company_id)
            loader.load(import_job.mapped_data, import_job.import_type)
            
            # If we reach here, commit
            import_job.status = 'COMPLETED'
            db.session.commit()
            
        except Exception as exc:
            # Automatic rollback on any error
            db.session.rollback()
            import_job.status = 'FAILED'
            import_job.error_message = str(exc)
            db.session.commit()
            raise
```

---

## 11. Validation Error Taxonomy

**Real Examples:**

| Category | Error | Code | Suggested Fix |
|----------|-------|------|-------|
| **Required Field** | account_code is required | VAL_001 | Add account_code or use template |
| **Format** | account_code must be 10 chars max | VAL_002 | Truncate or rename account code |
| **Duplicate** | account_code "1000" already exists | VAL_003 | Use different code or skip row |
| **Reference** | parent_account_code "9999" not found | VAL_004 | Import parent account first |
| **Enum** | account_type "XYZ" invalid | VAL_005 | Use ASSET, LIABILITY, EQUITY, REVENUE, EXPENSE |
| **Regex** | tax_id "ABC" invalid format | VAL_006 | Use 10-digit Saudi CR or 15-digit UAE VAT |
| **Range** | credit_limit -500 not allowed | VAL_007 | Use positive number or zero |
| **Logic** | debit + credit both > 0 | VAL_008 | Use either debit OR credit, not both |
| **Balance** | Trial balance debit (100) ≠ credit (150) | VAL_009 | Add missing accounts or fix amounts |

---

## 12. Key Metrics & Success Criteria

### Success Metrics (v1 Launch)

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Migration Time** | < 10 mins for 500 rows | Average import duration (end-to-end) |
| **Accuracy** | > 99% (< 1 error per 100 rows) | Error rate during validation |
| **User Adoption** | > 80% of new customers use import wizard | % skipping manual entry |
| **Support Tickets** | < 5% migration-related | post-migration support volume |
| **Onboarding Speed** | 2 days vs 2 weeks | Time from signup to "go live" |

---

## 13. Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|-----------|
| **Data corruption during import** | Entire COA unusable | Low | Use transactions, rollback, dry-run preview |
| **Encoding issues (RTL/Arabic text)** | Customer names garbled | Medium | Validate UTF-8 BOM, test Arabic importers |
| **Circular COA hierarchy** | Import fails silently | Medium | Graph traversal to detect cycles |
| **Unbalanced trial balance** | TB never imports | High | Reject TB until balanced (educate users) |
| **API rate limits (QB/Daftra)** | Import timeout | Medium | Implement exponential backoff, queue retries |
| **Large file uploads (> 100 MB)** | Memory overflow, server crash | Low | Chunked uploads, stream processing |
| **Duplicate entries on retry** | COA explodes with duplicates | Medium | Use idempotent keys, dedup on re-import |

---

## 14. Future Roadmap (v2–v5)

### v2: API Integrations (3 months)
- OAuth to QuickBooks Online API (real-time sync)
- Daftra API connector
- Qoyod API connector
- Stripe payment data import

### v3: Advanced Validation (2 months)
- Fuzzy matching for duplicates ("Acme Inc" vs "Acme Inc.")
- Regex patterns for domain-specific formats (CR, VAT numbers per country)
- Machine learning classification (e.g., auto-assign GL accounts)

### v4: White-Glove Services (6 months)
- CSM-facing dashboard for managing migration projects
- Parallel run (data in both systems, reconciliation dashboard)
- Rollback & re-do capability
- Post-migration audit & certification

### v5: Real-Time Sync (12+ months)
- Continuous sync with source system during 2-week parallel period
- Auto-reconciliation dashboard
- Zero-downtime cutover

---

## 15. Conclusion

**APEX Migration Module v1** is essential for reducing customer onboarding friction in MENA and globally. By supporting CSV imports, pre-built importers for top 5 source systems, and real-time validation, APEX can:

1. **Reduce onboarding time** from 2 weeks to 2 days
2. **Improve data quality** with automated validation
3. **Enable self-service** migration without white-glove support
4. **Differentiate from competitors** (Daftra, Qoyod) who lack modern import tooling
5. **Scale customer acquisition** without proportional CSM headcount

**Recommendation:** Allocate 1 sprint (3 weeks) in Phase 2 or Phase 3 to build v1, then iterate based on customer feedback.

---

## Sources

- [Xero QuickBooks Migration Guide](https://www.xero.com/us/accounting-software/convert-from-quickbooks/)
- [Xero Conversion Methods](https://www.xero.com/us/resources/conversion-methods-smb/)
- [Move My Ledger QuickBooks to Xero 2025](https://www.movemyledger.com/migrate-from-quickbooks-to-xero-2025-guide/)
- [CSVBox: Build a CSV Importer for Your SaaS](https://blog.csvbox.io/csv-importer-saas/)
- [SaaS UI Patterns: Import & Export](https://www.saasframe.io/categories/import-export)
- [Smart Interface Design: Bulk Import UX](https://smart-interface-design-patterns.com/articles/bulk-ux/)
- [Smashing Magazine: Designing Data Importers](https://www.smashingmagazine.com/2020/12/designing-attractive-usable-data-importer-app/)
- [SAP Data Migration Checklist 2026](https://blog.syniti.com/the-ultimate-sap-data-migration-checklist-for-2026/)
- [SAP to Cloud Migration Trends 2026](https://www.snpgroup.com/en/resources/blog/the-key-trends-shaping-sap-transformations-in-2026/)
- [Daftra Cloud ERP](https://www.daftra.com/en/)
- [Qoyod Accounting](https://www.qoyod.com/en)
- [Portable: Daftra & Qoyod Integration](https://portable.io/connectors/daftra/qoyod)
- [Odoo Data Migration Tool](https://apps.odoo.com/apps/modules/18.0/st_odoo_data_migration)
- [SDLC Corp: Odoo Data Migration Best Practices](https://sdlccorp.com/post/data-migration-best-practices-for-odoo-implementation/)
- [NetSuite Data Migration Planning](https://www.houseblend.io/articles/netsuite-data-migration-best-practices/)
- [NetSuite SuiteCloud 2026.1 Batch APIs](https://www.netsuite.com/portal/resource/articles/cloud-saas/suitecloud-platform-delivers-ai-native-development-expanded-rest-apis-and-next-generation-extensibility-in-netsuite-2026-1.shtml)
- [Stripe Data Migrations Overview](https://docs.stripe.com/get-started/data-migrations/overview)
- [Stripe Payment Data Import](https://docs.stripe.com/get-started/data-migrations/payment-method-imports)
- [FileFeed: Data Validation Best Practices 2026](https://www.filefeed.io/blog/data-validation-best-practices)
- [Numerous.ai: Data Validation Best Practices](https://numerous.ai/blog/data-validation-best-practices/)
- [Endgrate: Error Handling Best Practices for SaaS](https://endgrate.com/blog/error-handling-best-practices-for-saas-integrations/)
- [Quinnox: Data Migration Validation Best Practices](https://www.quinnox.com/blogs/data-migration-validation-best-practices/)
- [Oracle Fusion: Chart of Accounts Mapping](https://docs.oracle.com/en/cloud/saas/financials/25c/faiac/segment-rules-and-account-rules-for-chart-of-accounts-mapping.html)
- [Wafeq UAE Accounting System Migration Checklist](https://www.wafeq.com/en-business-hub/for-business/accounting-system-migration-checklist:-complete-guide-for-uae-businesses)
- [Wafeq: Setting Up Opening Balances](https://www.wafeq.com/en/wafeq-help/getting-started/setting-up-opening-balances-for-your-accounts)
- [The Munim: Migrate Data from Excel to Accounting Software](https://themunim.com/how-to-migrate-data-from-excel-to-accounting-software/)
- [Excel vs Accounting Software: Madras Accountancy](https://madrasaccountancy.com/blog-posts/excel-vs-accounting-software-why-small-businesses-should-upgrade)
- [Celery: Background Tasks in Python](https://medium.com/@hitorunajp/celery-and-background-tasks-aebb234cae5d)
- [Toptal: Orchestrating Celery Background Jobs](https://www.toptal.com/python/orchestrating-celery-python-background-jobs)
- [AppSignal: Scheduling Background Tasks with Celery](https://blog.appsignal.com/2025/08/27/scheduling-background-tasks-in-python-with-celery-and-rabbitmq.html)
- [PatriotSoftware: How to Import Trial Balances](https://www.patriotsoftware.com/accounting/training/help/how-to-import-trial-balances/)
- [SaaSAnt: Import Trial Balance into QuickBooks Online](https://support.saasant.com/support/solutions/articles/import-trial-balance-quickbooks-online-us/)
- [FirstBit: VAT Compliance & Tax Software UAE](https://firstbit.ae/features/taxes/)
- [Penieltech: Best Accounting Software for VAT UAE 2025](https://www.penieltech.com/blog/top-10-accounting-software-in-dubai/)

---

**Document Version:** 1.0  
**Last Updated:** April 30, 2026  
**Next Review:** Q3 2026 (post-v1 launch)
