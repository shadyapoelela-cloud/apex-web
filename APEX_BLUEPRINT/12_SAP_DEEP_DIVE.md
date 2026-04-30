# SAP S/4HANA Cloud 2602.500 Deep-Dive: Technical Architecture & Module Design

**Purpose**: Extract architectural patterns from SAP S/4HANA Cloud to inform Arabic SaaS ERP (APEX) design.  
**Research Date**: 2026-04-30  
**Target Version**: SAP S/4HANA Cloud 2602.500  

---

## 1. TOP-LEVEL MODULE MAP (Line of Business Architecture)

SAP S/4HANA Cloud organizes functionality into **discrete, plug-and-play module families**, each with sub-modules:

### 1.1 Financial Management (FM)
- **General Ledger (GL/FI-GL)**: Universal journal (ACDOCA), profit center accounting, cost center accounting
- **Accounts Payable (AP/FI-AP)**: Invoice entry, matching (3-way), payment processing, cash management
- **Accounts Receivable (AR/FI-AR)**: Sales invoice, dunning, collections, credit management
- **Fixed Assets (FI-AA)**: Asset master, depreciation, retirement, revaluation
- **Travel Expense (FI-TV)**: Employee claims, reimbursement, compliance
- **Banking (FI-CA)**: Check/wire processing, bank reconciliation, liquidity forecasting
- **Payroll (HR-PAY)**: Salary calculation, tax deduction, statutory reporting

### 1.2 Procurement & Sourcing (PS)
- **Purchase Requisition**: Demand creation, release workflow
- **Purchase Order (PO)**: PO entry, supplier management, release strategies
- **Purchasing (MM-PUR)**: Bidding, contracting, vendor evaluation
- **Inventory Management (MM-IM)**: Stock transfer, receipt, bin management, material valuation
- **Supplier Collaboration**: Digital procurement, catalogs, order status visibility
- **Invoice Receipt & Matching**: Three-way match (PO→Receipt→Invoice), exception management
- **Sourcing & Contracts (CLM)**: Contract lifecycle, terms negotiation

### 1.3 Sales & Service (SS)
- **Sales Order (SO/SD-SO)**: Inquiry → Quote → Order → Delivery
- **Billing (SD-BIL)**: Invoicing, contract billing, subscription management
- **Customer Management (CRM)**: Account master, contact history, opportunity pipeline
- **Sales Planning**: Demand forecast, allocation, reserve management
- **Service Order (CS)**: Service request, technician dispatch, warranty tracking
- **Professional Services Automation (PSA)**: Project resourcing, time entry, billing
- **Revenue Recognition (FI-REC)**: Performance obligations, milestone tracking (ASC 606/IFRS 15)

### 1.4 Manufacturing & Operations (MO)
- **Production Planning (PP)**: Master scheduling, demand forecasting, capacity planning
- **Manufacturing Orders (PP-SFC)**: Work order creation, material staging, routing
- **Shop Floor Control (SFC)**: In-process inventory, yield tracking, rework
- **Quality Management (QM)**: Inspection lots, defect notification, test results
- **Maintenance (PM)**: Preventive/corrective maintenance, asset breakdown structure
- **Equipment & Maintenance**: Spare parts, work order scheduling
- **Process Industries**: Batch management, recipe variants, co-product handling

### 1.5 Supply Chain & Logistics (SC)
- **Demand Planning**: Forecasting, consensus, seasonality
- **Supply Planning**: MRP runs, procurement recommendations, exception handling
- **Warehouse Management (WM)**: Putaway, pick/pack, shipping, cycle counting
- **Transportation**: Route planning, TMS integration, carrier management
- **Global Trade Services (GTS)**: Import/export compliance, customs, tariff classification
- **Sustainability**: Carbon tracking, ESG reporting, supply chain transparency

### 1.6 Asset Management (AM)
- **Asset Lifecycle**: Acquisition, maintenance, retirement
- **Preventive Maintenance**: PM scheduling, spare parts optimization
- **Corrective Maintenance**: Breakdown response, work order prioritization
- **Equipment Catalog**: Asset master, genealogy, serial tracking

### 1.7 Human Resources & Payroll (HR)
- **Employee Central**: Master data, org structure, competencies
- **Recruiting**: Job posting, applicant tracking, onboarding
- **Learning**: Training catalog, competency development, certification
- **Compensation**: Salary review, bonus calculation, equity management
- **Benefits**: Enrollment, coverage tracking, reconciliation
- **Time Management**: Absence, shift scheduling, approvals
- **Payroll**: Salary calculation, tax deduction, statutory reporting by country

### 1.8 Research & Development (R&D)
- **Product Lifecycle Management (PLM)**: Bill of material (BOM), engineering change order (ECO), versions
- **Engineering**: Design collaboration, specification management
- **Innovation Management**: Idea submission, evaluation, portfolio tracking

### 1.9 Enterprise Risk & Compliance (ERC)
- **Audit Management (CAM)**: Risk assessment, control testing, finding tracking
- **Compliance**: Policy management, certification, evidence collection
- **Data Privacy (GDPR/CCPA)**: Consent management, data subject requests
- **Environmental Health & Safety (EHS)**: Incident management, regulatory reporting
- **Business Continuity**: Disaster recovery planning, testing

### 1.10 Business Analytics & Planning (BAP)
- **Financial Planning & Analysis (FP&A)**: Budget/forecast modeling, variance analysis, driver-based planning
- **Profitability Analysis (CO-PA)**: Segment reporting, contribution margin analysis
- **Corporate Planning**: Strategic planning, scenario modeling
- **Predictive Analytics**: Demand forecasting, churn prediction, anomaly detection
- **Embedded Analytics**: Real-time KPI dashboards, embedded reports in transactional apps

---

## 2. UNIVERSAL JOURNAL (ACDOCA) - THE ONE TABLE TO RULE THEM ALL

### 2.1 The Design Philosophy

Traditional ERPs (SAP ECC, Oracle Financials) split accounting data across **20+ tables**:
- FI_GL_ENTRIES (GL posting)
- FA_ASSET_TRANS (Fixed asset transactions)
- MM_INV_ENTRIES (Inventory)
- CO_PA_DETAIL (Cost object allocation)
- Etc.

**S/4HANA's revolutionary simplification**: All these transactions converge into **ONE universal table: ACDOCA** ("Accounting Document - Actual").

### 2.2 ACDOCA Table Structure

```
ACDOCA (Universal Journal)
├── Header Fields
│   ├── MANDT (Mandant/Client)
│   ├── RBUKRS (Company Code)
│   ├── RLDNR (Ledger Group, e.g., "00" Main, "01" CO-PA)
│   ├── FISCYEAR (Fiscal Year)
│   ├── POPER (Posting Period)
│   ├── DOCNR (Journal Entry Number)
│   └── ITEMNO (Line Item)
│
├── Transaction Keys
│   ├── DOCTYPE (Document type: "SA" Invoice, "DA" Debit Note, etc.)
│   ├── TCODE (Transaction code: "FB01" Manual entry, "MIRO" Invoice receipt, etc.)
│   ├── PSTNG_DATE (Posting date)
│   ├── ENTRY_DATE (Entry date)
│   └── POSTING_ID (identifies batch posting job)
│
├── Dimension Hierarchy
│   ├── RACCT (G/L Account)
│   ├── RCNTR (Cost Center)
│   ├── RCOMP (Company code)
│   ├── RVERSN (Version: "00" Actual, "01" Budget, "02" Forecast)
│   ├── RLDNR (Ledger: "00" Main GL, "01" CO-PA, "02" Balance Sheet variant)
│   └── RPRC (Profit Center)
│
├── Dimensional Attributes (extensible)
│   ├── SEGMENT (IFRS segment)
│   ├── DLOGG (Business Area)
│   ├── KOSTL (Cost Center)
│   ├── AUFNR (Order/Project)
│   └── CUSTOM fields (customer-defined)
│
├── Valuation
│   ├── HKONT (G/L account, balance sheet vs. P&L)
│   ├── DMBTR (Document currency amount)
│   ├── WGBTR (Company code currency amount)
│   ├── RVALUE (Reporting currency amount — for multi-GAAP)
│   └── CURCY (Currency)
│
├── Source & Audit Trail
│   ├── REFERENCE (Invoice/PO/SO #)
│   ├── BSEG_DOCTYPE (Originating doc: "SA" AP Invoice, "KR" Sales Invoice, etc.)
│   ├── BSEG_DOCNR (Originating document number)
│   ├── BSEG_ITEMNO (Originating line item)
│   ├── SOURCE_ID (Posting module: "FI", "AP", "AR", "MM", "CO", "HR", etc.)
│   ├── MODIF_DATE (Last modified)
│   └── MODIF_USER (Modified by)
│
└── Extended Attributes
    ├── TEXT (Line item text/description)
    ├── SUPPITEM (Subledger item number for drill-down)
    └── Flexfields (customer-defined)
```

### 2.3 What Lives in ACDOCA vs. Separate Tables

**IN ACDOCA (Always)**:
- GL posting (all accounting entries, credit/debit, with dimensions)
- AP posting (vendor invoices, payments)
- AR posting (customer invoices, cash collections)
- Fixed asset depreciation (automatic or manual)
- Payroll posting (salary, tax, benefit accruals)
- Manufacturing posting (WIP, COGS)
- CO-PA (cost object) posting (if CO-PA ledger active)
- Multi-GAAP reporting entries (IFRS, GAAP, local)

**IN SEPARATE TABLES** (but linked to ACDOCA):
- **EKKO/EKPO** (Purchase Order master + lines) — linked via DOCNR/ITEMNO to ACDOCA
- **VBAK/VBAP** (Sales Order master + lines) — linked via DOCNR/ITEMNO
- **MARA/MARC** (Material master, plant-specific data) — referenced by RACCT if inventory-related
- **LFA1/LFB1** (Vendor master + company-specific) — referenced for reconciliation
- **KNA1/KNB1** (Customer master + company-specific) — referenced for reconciliation
- **ANLA/ANLB** (Fixed asset master + book values) — referenced for asset transactions
- **BSEG** (Line item history table for analytics/archive) — denormalized from ACDOCA for old transaction retrieval
- **FAGLFLEXI** (Flexible G/L variant, if active) — denormalized for fast reporting

### 2.4 Why ACDOCA Beats Traditional Multi-Table Design

| Aspect | Traditional ERP (ECC) | S/4HANA (ACDOCA) |
|--------|----------------------|------------------|
| **Schema Complexity** | 20+ posting tables (FI, MM, HR, CO) | 1 universal table |
| **Dimension Changes** | Add new cost center → migrate 5 tables | Add new dimension → extend ACDOCA |
| **Report Performance** | Slow (join 4-6 tables; full table scan) | Fast (1 table; indexed on dimensions) |
| **Variance Analysis** | FI vs. CO-PA split; reconciliation nightmare | Single source of truth; trivial reconciliation |
| **Period Close** | Run CO-PA closing separately; month-end reconciliation | No separate closing; real-time P&L |
| **Multi-GAAP** | Duplicate ledger posting; sync nightmare | RLDNR column; post once, report 3 ways |
| **Auditing** | Drill from report back to 4+ tables | Drill directly to ACDOCA line item |
| **Migration to Cloud** | Legacy baggage; refactor required | Cloud-native; no legacy burden |

### 2.5 Drill-Down & Document Flow

**User clicks "Variance of $50K in Q4 Cost of Goods Sold":**

1. **Smart Business KPI Tile** (Embedded Analytics) → Launches "Actual vs. Budget" story
2. **Narrative Layer** → Drill to ACDOCA filtered by:
   - `RLDNR = '00'` (Main ledger)
   - `HKONT = '500000'` (COGS account)
   - `POPER = '12'` (December)
   - `WGBTR < 0` (Expense entries)

3. **ACDOCA Query Result**:
   ```
   DOCNR    SOURCE_ID  HKONT    WGBTR      TEXT
   -----    ---------  -----    -----      ----
   1000456  MM         500000   -45,000    WIP to COGS (Batch MB1B)
   1000457  CO         500000   -5,000     Labor allocation (Order CO-PA)
   ```

4. **Click "1000456"** → Drill to source document in **MM (Materials Management)**:
   - **Table**: MKPF (Material Document header)
   - **Fields**: Doc date, posting date, material, plant, movement type
   - **Linked back**: MKPF.MBLNR = ACDOCA.DOCNR

5. **Click "1000457"** → Drill to source in **CO (Cost Accounting)**:
   - **Table**: COBK (CO Document header)
   - **Click through**: To COEP (CO line items), showing cost object allocation

**Why this matters**: Every financial report is instantly auditable. No hidden data. No separate ledgers. One click → source.

### 2.6 Performance Characteristics

**ACDOCA Indexing** (SAP best practice):
```
Primary Key:  (MANDT, RBUKRS, RLDNR, FISCYEAR, POPER, DOCNR, ITEMNO)
Secondary:    (MANDT, FISCYEAR, RACCT, RCNTR, PSTNG_DATE)  ← G/L Query
Tertiary:     (MANDT, RBUKRS, HKONT, POPER, RVERSN)         ← Balance query
Full-Text:    REFERENCE, TEXT (optional, for drill-down)
```

**Volume Patterns** (annual, medium-sized company):
- GL entries only: ~2M rows/year
- Full transactional: ~50M rows/year (with AP, AR, MM, HR posting)
- Multi-year rolling forecast: ~250M rows (if history kept)

**Query Response Time**:
- "GL balance for cost center X, account Y, this month" → <100ms (indexed lookup)
- "Variance report, 12 cost centers, 100 accounts, 12 months" → <2s (in-memory aggregation)
- "Drill-down to source doc for transaction Z" → <500ms (1-table lookup + 1 join to subledger)

**Columnstore (SAP HANA) Advantage**:
- ACDOCA often stored in SAP HANA's **column-oriented format** (not row-oriented)
- Compress similar values (e.g., 50K rows with same RCNTR) → 10:1 compression
- Aggregation on compressed columns → 100x faster than row-store

---

## 3. FIORI APP CATALOG - FINANCE + AUDIT + PROCUREMENT + SALES (50+ Apps)

Fiori is SAP's modern UI framework. Each Fiori app is a **single, purposeful task** (not a monolithic screen).

### 3.1 General Ledger & Financial Accounting (GL)

| App Name | Role | Function Group | Key Actions |
|----------|------|-----------------|-------------|
| **Manage Journal Entries** | GL Accountant | FI-GL | Create manual JE, post, reverse, copy template |
| **Monitor GL Balances** | Controller/CFO | FI-GL | View account balance, variance to budget, drill-down |
| **Financial Close Cockpit** | Close Manager | FI-GL | Track period close tasks, sign-off, dependencies |
| **Reconciliation Workbench** | GL Accountant | FI-GL | Match GL to subledger, flag exceptions, approve |
| **Cash Position Report** | Treasurer | FI-GL | View liquidity forecast, cash flow, currency exposure |
| **Chart of Accounts Browser** | Accountant/Admin | FI-GL | Manage COA, define GL accounts, hierarchy, mappings |
| **G/L Account History** | Auditor | FI-GL | View all changes to account master, who changed, when |
| **Period Closing Monitor** | Close Manager | FI-GL | Real-time close progress, pending tasks, bottlenecks |

### 3.2 Accounts Payable (AP)

| App Name | Role | Function Group | Key Actions |
|----------|------|-----------------|-------------|
| **Manage Invoices** | AP Clerk | FI-AP | Enter invoice, 3-way match (PO/Rcpt), approve, hold |
| **Monitor Payables** | AP Manager | FI-AP | Aging analysis, payment due, vendor risk score |
| **Process Payments** | Treasurer | FI-AP | Select invoices for payment, assign bank account, submit |
| **Approve Invoices** | Approver/Cost Owner | FI-AP | Review invoice, cost center charge, approval workflow |
| **Vendor Master Data** | Procurement Admin | FI-AP | Create vendor, tax ID, banking details, payment terms |
| **Invoice Approval Monitor** | Approver | FI-AP | Pending approvals, overdue, escalation |
| **Duplicate Invoice Check** | AP Controller | FI-AP | Identify duplicate invoices by amount/date/vendor |
| **Accruals & Payables** | GL Accountant | FI-AP | Record goods received not invoiced, debit entries |
| **Procurement Card Reconciliation** | Card Manager | FI-AP | Reconcile corporate card charges to GL |

### 3.3 Accounts Receivable (AR)

| App Name | Role | Function Group | Key Actions |
|----------|------|-----------------|-------------|
| **Manage Invoices** | AR Clerk | FI-AR | Create invoices, post, email to customer, track status |
| **Monitor Receivables** | AR Manager | FI-AR | Aging analysis, days sales outstanding (DSO), credit limits |
| **Process Collections** | Collections Agent | FI-AR | Dunning letters, payment reminders, settlement |
| **Customer Master Data** | AR Admin | FI-AR | Create customer, credit limit, payment terms, billing contact |
| **Cash Application** | AR Clerk | FI-AR | Receive payment, match to invoices, apply overpayment |
| **Credit Management** | Credit Manager | FI-AR | Set credit limits, review order-to-credit, approvals |
| **Revenue Recognition** | Revenue Accountant | FI-AR | Track performance obligations, milestone completion, posting |
| **Customer Profitability** | Finance Manager | FI-AR | Gross margin by customer, profitability trend, contract value |

### 3.4 Fixed Assets

| App Name | Role | Function Group | Key Actions |
|----------|------|-----------------|-------------|
| **Manage Fixed Assets** | FA Accountant | FI-AA | Acquire asset, depreciate, retire, revalue, transfer |
| **Asset Disposals** | FA Manager | FI-AA | Retire asset, calculate gain/loss, post, update register |
| **Depreciation Posting** | GL Accountant | FI-AA | Run monthly depreciation, post to GL, review exceptions |
| **Asset Register Report** | Auditor | FI-AA | Asset listing, gross/net book value, by location/cost center |

### 3.5 Payroll

| App Name | Role | Function Group | Key Actions |
|----------|------|-----------------|-------------|
| **Manage Payroll Run** | Payroll Manager | HR-PAY | Create payroll run, configure parameters, approve/post |
| **Employee Tax Audit** | Payroll Accountant | HR-PAY | Validate tax withholding, quarterly/annual reconciliation |
| **Payroll Posting Review** | GL Accountant | HR-PAY | Review salary, benefit, tax, deduction entries pre-posting |

### 3.6 Accounts Payable & Financial Close (Combined)

| App Name | Role | Function Group | Key Actions |
|----------|------|-----------------|-------------|
| **Accrual Workbench** | GL Accountant | FI-GL/AP | Automated accrual: goods rcvd not invoiced, monthly expenses |
| **Supplier Balance Confirmation** | Controller | FI-AP | Send balance letter to vendor, track confirmations, exceptions |

### 3.7 Procurement

| App Name | Role | Function Group | Key Actions |
|----------|------|-----------------|-------------|
| **Manage Requisitions** | Employee | MM-PUR | Create PR, route for approval, monitor status |
| **Approve Requisitions** | Manager | MM-PUR | Review PR, approve/reject, set cost center |
| **Manage Purchase Orders** | Procurement Officer | MM-PUR | Create PO, send to vendor, track receipt, monitor budget |
| **Manage Goods Receipt** | Warehouse | MM-IM | Receipt of goods, stock transfer, quality check, putaway |
| **Process Invoice (AP)** | AP Clerk | MM-PUR + FI-AP | Match 3-way (PO, Rcpt, Invoice), post if matched |
| **Manage Suppliers** | Procurement Manager | MM-PUR | Vendor evaluation, performance score, contract terms |
| **Procurement Analytics** | Procurement Manager | MM-PUR | Spend by vendor, category, contract compliance, savings |
| **Catalog Management** | Catalog Owner | MM-PUR | Maintain internal catalogs, supplier product lists |

### 3.8 Sales & Billing

| App Name | Role | Function Group | Key Actions |
|----------|------|-----------------|-------------|
| **Manage Sales Orders** | Sales Order Processor | SD-SO | Create SO, monitor fulfillment, ship, invoice |
| **Manage Customers** | Sales Manager | SD-SO | Customer master, credit limit, contact, order history |
| **Monitor Sales Performance** | Sales VP | SD-SO | Revenue forecast, pipeline, win rate, quota attainment |
| **Manage Deliveries** | Warehouse/Logistics | SD-SO | Create delivery, pick/pack, ship, post goods issue |
| **Manage Billing** | Billing Clerk | SD-BIL | Create billing document, post invoice, email to customer |
| **Monitor Sales Invoices** | AR Manager | SD-BIL | Outstanding invoices, aging, collections status |
| **Manage Service Orders** | Service Manager | CS-SO | Create service order, dispatch technician, time entry, billing |
| **Customer Service Management** | Service Agent | CS-SO | Service request, ticket tracking, escalation, resolution |

### 3.9 Analytics & Reporting

| App Name | Role | Function Group | Key Actions |
|----------|------|-----------------|-------------|
| **Financial Report (Profit & Loss)** | CFO/Controller | FI-GL + CO | P&L by segment, variance, trend, drill-down to GL |
| **Financial Report (Balance Sheet)** | CFO/Controller | FI-GL + AR/AP | Balance sheet, asset/liability/equity breakdown, ratios |
| **Cash Flow Report** | Treasurer | FI-GL + CA | Indirect/direct cash flow, liquidity analysis |
| **Variance Analysis Report** | Controller | CO-PA | Actual vs. budget by cost object, variance drivers |
| **Management Dashboards** | CFO/VP Finance | Multi-module | KPI tiles, trend, alert-driven |
| **Cost Object Profitability** | Cost Accountant | CO-PA | Segment P&L, by product/customer/order, contribution margin |

### 3.10 Audit & Compliance

| App Name | Role | Function Group | Key Actions |
|----------|------|-----------------|-------------|
| **Manage Audit Issues** | Internal Auditor | CAM | Track audit findings, remediation, follow-up testing |
| **Control Testing Workbench** | Internal Auditor | CAM | Design test, select sample, document evidence, assess |
| **Segregation of Duties Monitor** | SOX Coordinator | CAM | Identify conflicting user roles, flag risky combinations |
| **Journal Entry Audit Trail** | Auditor | FI-GL | All changes to JE (user, time, change), suspense entries |
| **Compliance Calendar** | Compliance Manager | CAM | Regulatory due dates, status tracking, evidence attachment |

---

## 4. ROLES & AUTHORIZATIONS (30+ Standard Business Roles)

SAP S/4HANA ships with **role-based access control (RBAC)** via **predefined business roles** (Packaged Roles).

### 4.1 Core Financial Roles

| Role Code | Role Name | Key Permissions |
|-----------|-----------|-----------------|
| **SAP_BR_GL_ACCOUNTANT** | General Ledger Accountant | Post manual JE; review GL balance; reconcile; period close tasks |
| **SAP_BR_AP_ACCOUNTANT** | Accounts Payable Accountant | Enter invoice; 3-way match; hold invoices; process debit entries |
| **SAP_BR_AR_ACCOUNTANT** | Accounts Receivable Accountant | Create invoice; post; cash application; credit management |
| **SAP_BR_AP_SPECIALIST** | AP Specialist | Vendor master; payment processing; accrual entry |
| **SAP_BR_AR_SPECIALIST** | AR Specialist | Customer master; dunning; collections workflow |
| **SAP_BR_FA_SPECIALIST** | Fixed Asset Specialist | Asset acquisition; depreciation run; disposal; revaluation |
| **SAP_BR_PAYROLL_PROCESSOR** | Payroll Processor | Create payroll run; validate taxes; post payroll entries |
| **SAP_BR_CLOSE_MANAGER** | Period Close Manager | Execute close checklist; sign-off tasks; period lockdown; variance review |
| **SAP_BR_CONTROLLER** | Financial Controller | All GL/AP/AR/FA; variance analysis; consolidation prep; internal reporting |
| **SAP_BR_FINANCE_MANAGER** | Finance Manager | Planning, budgeting, forecasting, reporting, variance analysis |
| **SAP_BR_ACCOUNTANT_SUPERVISOR** | Accounting Supervisor | Approve invoices, JEs, payroll; override holds; reconciliation review |

### 4.2 Procurement Roles

| Role Code | Role Name | Key Permissions |
|-----------|-----------|-----------------|
| **SAP_BR_REQUESTER** | Purchase Requester | Create PR; monitor status |
| **SAP_BR_REQUISITION_APPROVER** | Requisition Approver | Approve/reject PR; set cost center |
| **SAP_BR_PROCUREMENT_OFFICER** | Procurement Officer | Create PO; negotiate with vendor; contract terms |
| **SAP_BR_PROCUREMENT_MANAGER** | Procurement Manager | Vendor evaluation; performance monitoring; spend analysis; budgeting |
| **SAP_BR_SUPPLIER_MASTER_MANAGER** | Supplier Management | Create vendor; manage master data; tax ID; banking; contracts |
| **SAP_BR_GOODS_RECEIPT_CLERK** | Goods Receipt Clerk | Receive goods; quality check; confirm receipt; post to stock |
| **SAP_BR_INVOICE_VERIFICATION_CLERK** | Invoice Verification Clerk | 3-way match; hold discrepancies; post matched invoices |

### 4.3 Sales Roles

| Role Code | Role Name | Key Permissions |
|-----------|-----------|-----------------|
| **SAP_BR_SALES_ORDER_PROCESSOR** | Sales Order Processor | Create SO; monitor fulfillment; confirm shipment |
| **SAP_BR_SALES_MANAGER** | Sales Manager | Customer master; credit limit; order approval; performance dashboard |
| **SAP_BR_BILLING_CLERK** | Billing Clerk | Create billing document; post invoice; generate email |
| **SAP_BR_DELIVERY_PROCESSOR** | Delivery Processor | Create delivery; pick/pack; post goods issue; confirm receipt |
| **SAP_BR_REVENUE_ACCOUNTANT** | Revenue Accountant | Revenue recognition; milestone tracking; contract analysis; posting |

### 4.4 Manufacturing Roles

| Role Code | Role Name | Key Permissions |
|-----------|-----------|-----------------|
| **SAP_BR_PRODUCTION_PLANNER** | Production Planner | MRP run; capacity planning; order scheduling |
| **SAP_BR_MANUFACTURING_SUPERVISOR** | Manufacturing Supervisor | Create work order; issue materials; confirm completion; yield report |
| **SAP_BR_QUALITY_INSPECTOR** | Quality Inspector | Create inspection lot; record test results; approve/reject |
| **SAP_BR_SHOP_FLOOR_OPERATOR** | Shop Floor Operator | Clock in/out; record work progress; report defects |

### 4.5 Warehouse & Logistics Roles

| Role Code | Role Name | Key Permissions |
|-----------|-----------|-----------------|
| **SAP_BR_WAREHOUSE_OPERATOR** | Warehouse Operator | Receipt; putaway; picking; packing; shipping |
| **SAP_BR_WAREHOUSE_MANAGER** | Warehouse Manager | Bin management; stock transfers; cycle count; inventory adjustment |
| **SAP_BR_LOGISTICS_MANAGER** | Logistics Manager | Route planning; shipment tracking; carrier mgmt; KPI monitoring |

### 4.6 Analytics & Planning Roles

| Role Code | Role Name | Key Permissions |
|-----------|-----------|-----------------|
| **SAP_BR_FINANCIAL_ANALYST** | Financial Analyst | Budget/forecast modeling; variance analysis; ad-hoc reporting; data access to GL/AP/AR/CO-PA |
| **SAP_BR_PLANNING_MANAGER** | Planning Manager | Strategic planning; scenario modeling; consolidation |

### 4.7 Audit & Compliance Roles

| Role Code | Role Name | Key Permissions |
|-----------|-----------|-----------------|
| **SAP_BR_INTERNAL_AUDITOR** | Internal Auditor | Audit trail query; risk assessment; testing; journal entry review |
| **SAP_BR_COMPLIANCE_OFFICER** | Compliance Officer | Policy mgmt; cert tracking; evidence collection; control testing |
| **SAP_BR_SOX_COORDINATOR** | SOX Compliance Coordinator | SoD monitoring; user access review; control documentation; testing |

### 4.8 System Administration Roles

| Role Code | Role Name | Key Permissions |
|-----------|-----------|-----------------|
| **SAP_BR_SYSTEM_ADMINISTRATOR** | System Administrator | User mgmt; role assignment; backup/recovery; patch mgmt |
| **SAP_BR_SECURITY_ADMIN** | Security Administrator | Authorization mgmt; audit log review; compliance configuration |

### 4.9 How Roles Work (Authorization Model)

**Role = Bundle of Transactions + Authorization Objects**

Example: `SAP_BR_GL_ACCOUNTANT` includes:
- Transaction FB01 (Post GL entry): `Authorization Object F_BKPF_BK` (Document type: SA, DA, etc.)
- Transaction FS00 (Display GL master): `Authorization Object F_GLAC_AC` (Account range, company code)
- Transaction OB05 (Period lock): `Authorization Object F_BLCK_A` (Period, ledger, company)

**Segregation of Duties (SoD) Enforced**:
- User cannot have both `SAP_BR_AP_ACCOUNTANT` (Enter invoice) AND `SAP_BR_REQUISITION_APPROVER` + `SAP_BR_PROCUREMENT_OFFICER` (Approve PR + Create PO)
- User cannot have both `SAP_BR_GL_ACCOUNTANT` (Post JE) AND `SAP_BR_PAYMENT_PROCESSOR` (Process payment from same account)

**Role Assignment (via Identity & Access)**:
- Admin → **PFCG transaction** (Role profile generation)
- OR → **Identity & Access Governance (IAG)** app in Fiori (request-based workflow)

---

## 5. COUNTRY LOCALIZATION (Saudi Arabia - SA)

SAP S/4HANA Cloud includes **pre-built Saudi Arabia localization** (`Localization for KSA`).

### 5.1 Saudi Arabia Localization Package Contents

**VAT/Zakat Configuration:**
- **VAT Rate**: 15% (standard rate; reduced rates for food, medicine available)
- **VAT Registration Number (RN)**: Managed in tax master (transaction `TAXNR`); validated against ZATCA
- **VAT Account Master**: Separate GL accounts for VAT payable/receivable; calculation rules

**ZATCA Integration (Phase 2 - E-Invoicing):**
- **ZATCA (Zakat, Tax & Customs Authority) E-Invoice**: Fiori app **"Manage E-Invoice"**
- **Phase 1** (complete; 2020-2021): Tax registration, monthly filing
- **Phase 2** (2023+, mandatory since Oct 2023): Real-time e-invoicing to ZATCA
  - Invoice transmitted to ZATCA on issue
  - ZATCA returns Unique Invoice Reference (UIR)
  - Integration: S/4HANA → API → ZATCA Hub → Buyer's system
  - Approval status: "Approved", "Rejected", "Cleared", "Reported"
  - All documents logged; audit trail mandatory

**E-Invoicing Configuration in S/4HANA**:
```
FI (Finance) → E-Invoicing (ZATCA)
├── Outbound Interface (S/4HANA → ZATCA)
│   ├── API Endpoint: https://api.zatca.gov.sa/einvoicing/phase2
│   ├── Authentication: OAuth 2.0 (ZATCA issues credentials)
│   ├── Payload: JSON (Invoice, seller RN, buyer tax ID)
│   └── Signature: PKCS#7 (digital signature; certificate from Saudi CERT authority)
│
├── Inbound Interface (ZATCA → S/4HANA)
│   ├── Response: UIR, timestamp, clearance status
│   └── Stored in: ACDOCA (extra field for UIR), VBAK/VBAP (for SO links)
│
└── Compliance Rules
    ├── All invoices (sales, purchase) → ZATCA
    ├── No retroactive amendments (once cleared, frozen)
    └── Monthly summary (Tax period closing)
```

**Hijri Calendar Support:**
- **Field**: Company date in Islamic calendar (AH — Anno Hegirae)
- **Display Format** (Fiori apps): Show Gregorian + Hijri dates side-by-side
- **GL Reporting**: Option to close periods by Islamic calendar (12-month Hijri year ≠ Gregorian)
- **Payroll**: Hajj allowance, Eid bonuses, prayer times (custom in HR module)

**Arabic Language & RTL Support:**
- **Primary UI Language**: Arabic (Fiori apps localized)
- **Content Localization**:
  - GL account names in Arabic (ACDOCA.TXTSH field)
  - Document text (invoice, PO) in Arabic
  - Email notifications to customers in Arabic
- **RTL Layout**: Fiori framework handles right-to-left text flow (no custom CSS needed)
- **Reporting**: Bilingual reports (English + Arabic side-by-side or Arabic-only option)

**Withholding Tax (Zakat on Payments):**
- **Company Zakat Obligation**: 2.5% of net profit (annual, on zakat base)
- **Vendor Withholding** (optional): Withheld tax on large supplier payments
  - Field: Vendor master → Withholding tax code (percentage, GL account for payable)
  - Posting: When payment posted, automatic debit to liability account
- **Monthly Reporting**: Tax return includes withholding tax paid

**Customs & Trade Compliance:**
- **Import/Export** (via Global Trade Services module):
  - HS code (tariff), origin, value declaration
  - SARIE (Saudi Arabia's customs system) integration
  - Duty calculation, VAT on imports
- **Excise Tax**: Applied to tobacco, energy drinks, sugary beverages
  - Rates configured in TAX master; auto-calculated on purchase/sales

**Statutory Reporting (Saudi Arabia):**
- **VAT Return** (monthly): `VA01` (VAT return form) → e-file to ZATCA
- **Corporate Tax** (annual): Taxable income, deductions, withholding tax paid
- **Zakat Base**: Calculation per Islamic accounting rules
- **Labor Law Compliance**: Wage protection (30-60 day payment cycle); social insurance deduction (10% employer, 9% employee)

### 5.2 SAP Saudi Arabia Localization Activation Steps

1. **New Implementation**:
   - Select "Kingdom of Saudi Arabia" in `Activate Enterprise Structure` (IMG)
   - System auto-enables: VAT config, ZATCA interface, Hijri calendar, Arabic language

2. **Existing Implementation**:
   - Run IMG config: FI → Tax on Sales/Purchases → Set VAT parameters
   - Activate ZATCA: **IMG → Sales & Distribution → Billing → E-Invoicing**
   - Assign role `SAP_BR_TAX_COMPLIANCE_OFFICER` to user managing ZATCA

3. **Validation**:
   - Fiori app: **"Manage Company Code"** → Check "Country" = "SA"
   - Fiori app: **"Manage VAT"** → Confirm VAT rate 15%, posting rules
   - Test e-invoice submission (sandbox ZATCA environment before go-live)

---

## 6. PERIOD CLOSE COCKPIT / SAPF&CC (Financial Close Cycle)

The **Period Close Cockpit** (aka **SAPF&CC** — SAP Financial Close Center) is a Fiori app that orchestrates the **month-end close process**.

### 6.1 Close Cockpit User Interface

**Main Screen** (Fiori app: "Financial Close Cockpit"):
```
┌─────────────────────────────────────────────────────────────┐
│ Period Close Progress                                       │
│ Fiscal Year: 2026   Period: 03 (March)                      │
└─────────────────────────────────────────────────────────────┘

│ Overall Close Status: 70% Complete (Est. finish: 2026-04-05)│

┌─────────────────────────────────────────────────────────────┐
│ Close Tasks (Checklist)                                     │
├─────────────────────────────────────────────────────────────┤
│ ✓ GL Reconciliation (Completed 2026-03-28)                  │
│ ✓ Revenue Recognition (Completed 2026-03-28)                │
│ ⏳ AP Accruals (In Progress, Assigned: Sarah)                │
│ ⏳ Depreciation Run (Pending, Due: 2026-03-31)               │
│ ⭕ Intercompany Netting (Not Started, Depends on: GL Rec)   │
│ ⭕ Consolidation (Not Started, Blocked until: IC Netting)   │
│ ⭕ Management Reporting (Not Started)                        │
└─────────────────────────────────────────────────────────────┘

│ Bottlenecks:                                                │
│ • AR: Aging > 90 days ($2.5M); followup needed              │
│ • AP: 52 invoices pending 3-way match; hold until matched   │
│ • FX: Open EUR position; revalue before cutoff              │
└─────────────────────────────────────────────────────────────┘
```

### 6.2 Core Close Tasks (Typical Close Cycle)

| Task | Frequency | Owner | Duration | Dependency | Automation |
|------|-----------|-------|----------|-----------|-----------|
| **GL Reconciliation** | Monthly | GL Accountant | 2 days | None | Partial (automated subledger matching) |
| **AP Accruals** (GR/IR) | Monthly | AP Specialist | 1 day | GL Reconciliation | Full (auto-accrual posting) |
| **Revenue Recognition** | Monthly | Revenue Accountant | 2 days | AR posting complete | Partial (milestone tracking; manual judgment) |
| **Depreciation Run** | Monthly | FA Accountant | 0.5 day | None | Full (batch posting; time-based) |
| **Payroll Accrual** | Monthly | Payroll Manager | 1 day | Payroll run posted | Full (auto-calculate unused PTO, bonuses) |
| **Intercompany Netting** | Monthly | GL Accountant | 1 day | GL Reconciliation | Partial (automated matching; manual review) |
| **Currency Revaluation** | Monthly | Treasurer | 0.5 day | GL Reconciliation | Full (batch rate lookup; auto-posting) |
| **Bad Debt Reserve** | Monthly | AR Accountant | 0.5 day | AR aging analysis | Partial (aging-based calculation; manual override) |
| **Consolidation** | Quarterly | Controller | 3 days | All GL close tasks | Partial (data collection; manual elimination entries) |
| **Management Reporting** | Monthly | Finance Manager | 1 day | All close tasks | Full (auto-generated; drill-down available) |

### 6.3 Automated Close Rules (Drools-Based Automation)

**SAP Close Task Framework** allows **Rules Engine (Drools)** configuration for repetitive tasks:

```javascript
// Example: Auto-Accrue Rent Expense on Month-End
Rule "AccrueMonthlyRent"
When:
  - Posting period = current month
  - GL account = 400000 (Rent Expense)
  - Cost center = 01 (HQ)
  - No posting in GL yet for this account/cost center/month

Then:
  1. Calculate: Monthly Rent = $500K / 12 = $41,667
  2. Create JE:
     DR 400000 (Rent Expense) $41,667  [CC: 01]
     CR 200500 (Accrued Rent Payable) $41,667  [CC: 01]
  3. Document Type: "AC" (Accrual)
  4. Approval Rule: Auto-approve (no human review)
  5. Post to ACDOCA
```

**Approval Workflows** (if not auto-approved):
- Task routed to Owner (e.g., GL Accountant)
- Owner reviews Fiori app "Approval Queue"
- Click "Approve" → Task marked complete; dependent tasks unblocked
- Click "Reject" → Task reopened; notification sent; responsible party contacted

### 6.4 Period Lockdown

**Posting Lock** (prevents further entries after close):
```
IMG → Financial Accounting → General Ledger → Period Close
│
├── Define Period Lock (OB04)
│   ├── Variant 0: All locked
│   ├── Variant 1: Locked except GL (manual entries still allowed)
│   ├── Variant 2: Locked except specific GL accounts
│   └── Variant 3: Locked except AP/AR (subledger posting allowed)
│
├── Lock User Groups
│   ├── Group A (Accountants): Variant 1 (only post GL JE)
│   ├── Group B (Managers): Locked completely (read-only)
│   └── Group C (Auditors): Variant 0 (read-only)
│
└── Lock Schedule
    ├── Period 1: Locked from 2026-02-28 to 2026-03-20
    ├── Period 2: Locked from 2026-03-31 to 2026-04-20
    └── Quarterly: Locked from 2026-03-31 to 2026-05-15 (Q1 close)
```

---

## 7. AP/AR CORE FLOWS (Invoice-to-Payment & Order-to-Cash)

### 7.1 Procure-to-Pay (P2P) Flow: AP

**End-to-end invoice receipt, matching, posting, and payment**:

```
Step 1: Create Purchase Requisition (PR)
├─ App: "Manage Requisitions" (MM-PUR)
├─ Actions: Employee enters item, quantity, cost center, GL account
├─ Approval: Manager reviews, approves (authorization limit)
└─ Outcome: PR created in table BANF

Step 2: Create Purchase Order (PO)
├─ App: "Manage Purchase Orders" (MM-PUR)
├─ Actions: Procurement officer creates PO from PR (can consolidate multiple PRs)
├─ System: Checks budget, supplier master, contract terms
├─ Posting: PO created in table EKKO/EKPO; links to ACDOCA (commitment)
└─ Sending: Email + EDI to supplier; supplier confirms receipt

Step 3: Goods Receipt (GR)
├─ App: "Manage Goods Receipt" (MM-IM)
├─ Actions: Warehouse receives shipment; scans barcodes; confirms quantity
├─ Quality Check: QM module checks inspection results (optional)
├─ Posting: 
│  ├─ Table MKPF/MKPO (Material document header/line)
│  ├─ Stock increased (table MARD)
│  └─ Commitment in ACDOCA updated (PO→GR link recorded)
└─ Hold Status: Invoice not yet received; matching cannot proceed yet

Step 4: Invoice Receipt (3-Way Match)
├─ App: "Manage Invoices" (FI-AP)
├─ Actions: AP clerk enters invoice data (invoice #, date, amount, GL account)
├─ System: 
│  ├─ Retrieves PO (EKKO/EKPO) + GR (MKPF/MKPO)
│  ├─ Compares amounts (price variance tolerance defined in MM master)
│  └─ Variance Assessment:
│     ├─ Match on 3-way: Quantity, Price, Amount
│     ├─ Variance < 5%: Auto-approve invoice posting
│     ├─ Variance 5-10%: Flag for review; hold invoice
│     └─ Variance > 10%: Block posting; escalate to manager
│
├─ Posting (if matched):
│  ├─ DR GL Account (e.g., 500000 COGS or 150000 Inventory)
│  ├─ CR AP payable (vendor liability)
│  └─ ACDOCA entry created (SOURCE_ID = "AP"; DOCTYPE = "SA")
│
└─ Hold Status: Invoice ready for payment (if no variance)

Step 5: Payment Processing
├─ App: "Process Payments" (FI-CA Bank/CA)
├─ Actions: Treasurer/Finance selects invoices for payment
├─ System:
│  ├─ Payment terms: Net 30 → due date = invoice date + 30 days
│  ├─ Early pay discount: 2/10 Net 30 → $98 discount if paid within 10 days
│  └─ Selection: Filter overdue invoices; apply discount rule
│
├─ Consolidation: Batch multiple invoices to same vendor into 1 check
├─ Method: Check, wire transfer, ACH, credit card (per vendor master)
├─ Currency: If foreign vendor, FX rate locked at payment time
│
└─ Outcome: 
   ├─ Check/wire instruction created (table PAYR)
   ├─ Bank interface (SWIFT/ACH) triggered
   └─ ACDOCA entry: DR AP Payable, CR Bank account

Step 6: Bank Reconciliation
├─ App: "Bank Reconciliation" (FI-CA)
├─ Actions: Bank statement imported (MT940 format)
├─ System: 
│  ├─ Matches check #/wire ref in bank statement to payment created in Step 5
│  ├─ Clears payment in ACDOCA (match bank statement amount)
│  └─ Flags cleared payments as "Reconciled"
│
└─ Outcome: GL bank account now reflects actual cash outflow

Step 7: Reconciliation & Reporting
├─ App: "Reconciliation Workbench" (FI-GL)
├─ Actions: GL accountant reconciles AP subledger to GL control account (200000 AP Payable)
├─ System:
│  ├─ Subledger: Sum of all vendor balances (from FI-AP posting layer)
│  ├─ GL Control: 200000 balance (from ACDOCA)
│  └─ Match: Subledger ≈ GL control (< $1 variance acceptable)
│
└─ If mismatch → Drill into ACDOCA to find unreconciled item (timing difference or missing posting)
```

### 7.2 Order-to-Cash (O2C) Flow: AR

**End-to-end sales order, invoicing, and cash collection**:

```
Step 1: Create Sales Order (SO)
├─ App: "Manage Sales Orders" (SD-SO)
├─ Actions: Sales order processor creates SO
│  ├─ Customer master lookup (KNA1); credit limit check
│  ├─ Item selection (MARA material master)
│  ├─ Quantity, delivery date, billing info
│  └─ Approval if order exceeds credit limit
│
├─ Posting: SO created in table VBAK/VBAP; commitment to GL (not yet posted to ACDOCA)
└─ Outcome: SO ready for fulfillment

Step 2: Delivery Creation & Goods Issue
├─ App: "Manage Deliveries" (SD-SO)
├─ Actions: Warehouse creates delivery from SO
│  ├─ Pick: Pick list generated; warehouse picks items from stock
│  ├─ Pack: Items packed into shipment units
│  └─ Post Goods Issue: Warehouse confirms goods shipped
│
├─ Posting:
│  ├─ Table: LIKP/LIPS (Delivery header/line)
│  ├─ Stock reduction: MARD (inventory reduced)
│  └─ ACDOCA entry: 
│     ├─ DR COGS (e.g., 500000 Cost of Goods Sold)
│     ├─ CR Inventory (e.g., 150000 Inventory)
│     └─ At standard cost (price at PO receipt time)
│
└─ Outcome: Goods physically handed off; shipment tracked in logistics

Step 3: Invoicing (Billing)
├─ App: "Manage Billing" (SD-BIL)
├─ Actions: Billing clerk creates billing document
│  ├─ Billing from delivery (SO/Delivery → Invoice)
│  ├─ Amount: Item price × qty (from SO master)
│  ├─ Tax calculation: VAT/Sales tax added (per tax master, customer location)
│  └─ Payment terms: Net 30, 2/10 Net 30, COD, etc.
│
├─ Posting: 
│  ├─ Table: VBRK/VBRP (Billing document header/line)
│  └─ ACDOCA entry:
│     ├─ DR AR Receivable (e.g., 100000 Accounts Receivable)
│     ├─ CR Revenue (e.g., 400000 Sales Revenue)
│     ├─ CR Tax Payable (e.g., 210000 Sales Tax Payable)
│     └─ Linked to VBRK/VBRP (drill-down enabled)
│
├─ Email: Invoice PDF sent to customer (email address from KNA1)
└─ Outcome: Revenue recognized (if timing-based; otherwise per contract milestone)

Step 4: Revenue Recognition (If Contract-Based)
├─ App: "Revenue Recognition" (FI-REC)
├─ Actions: Revenue accountant reviews performance obligation completion
│  ├─ For Software/SaaS: Monthly subscription → recognize monthly
│  ├─ For Project: Completion milestone → recognize on completion
│  └─ System: Track % of performance obligation satisfied
│
├─ Posting (if timing-based in step 3 only):
│  └─ No additional entry (already posted in step 3)
│
├─ Posting (if contract-based, deferred revenue):
│  ├─ At invoice: 
│  │  ├─ DR AR (100000) XXX
│  │  └─ CR Deferred Revenue (200500) XXX
│  │
│  └─ Monthly on schedule (5-year contract, recognize 1/60 monthly):
│     ├─ DR Deferred Revenue (200500) ~$X
│     └─ CR Revenue (400000) ~$X
│
└─ Outcome: Revenue posted per ASC 606/IFRS 15 compliance

Step 5: Cash Collection (Cash Application)
├─ App: "Cash Application" (FI-AR)
├─ Actions: AR clerk receives payment from customer
│  ├─ Check/wire receipt recorded
│  ├─ Amount matched to invoice(s)
│  └─ Overpayment allocated or held in suspense
│
├─ Posting:
│  ├─ DR Bank Account (e.g., 100100 Cash)
│  └─ CR AR Receivable (100000) — applies payment to specific invoice
│
├─ Discount (if paid early, 2/10 Net 30):
│  ├─ If paid within 10 days: $980 payment clears $1000 invoice
│  ├─ DR Sales Discount (400500) $20
│  └─ CR AR Receivable (100000) $20
│
└─ Outcome: Receivable cleared from customer account; bad debt risk reduced

Step 6: Dunning & Collections (If Not Paid)
├─ App: "Process Collections" (FI-AR)
├─ Trigger: Invoice overdue > 30 days
│
├─ Actions: Collections agent initiates dunning
│  ├─ Level 1 (30 days overdue): Reminder letter (friendly tone)
│  ├─ Level 2 (45 days overdue): 2nd reminder (firm tone)
│  ├─ Level 3 (60 days overdue): Final notice (legal consequences)
│  └─ Level 4 (90+ days): Escalate to external collection agency
│
├─ System: 
│  ├─ Dunning letter generated (Fiori app) → email to customer
│  ├─ Dunning status tracked in AR master (KNVV field)
│  └─ Follow-up scheduled automatically
│
└─ Outcome: If customer pays → clear as in Step 5; if not paid → bad debt reserve

Step 7: Bad Debt Reserve (Month-End Close)
├─ App: "Bad Debt Reserve" (FI-AR close cockpit task)
├─ Calculation: 
│  ├─ Analyze AR aging: 0-30, 30-60, 60-90, 90+ days overdue
│  ├─ Historical write-off rate: e.g., 2% of 30-60, 5% of 60-90, 10% of 90+
│  └─ Reserve required: (Aging < 30 days × 0%) + (30-60 × 2%) + (60-90 × 5%) + (90+ × 10%)
│
├─ Posting (if reserve increased):
│  ├─ DR Bad Debt Expense (e.g., 410000)
│  └─ CR Bad Debt Reserve (e.g., 100500 — contra-asset)
│
└─ Outcome: AR net of reserve on balance sheet

Step 8: Reconciliation (Month-End Close)
├─ App: "Reconciliation Workbench" (FI-GL)
├─ Actions: AR accountant reconciles subledger to GL
│  ├─ Subledger: Sum of all customer balances (from FI-AR open items)
│  ├─ GL Control: 100000 AR balance (from ACDOCA)
│  └─ Match required: Subledger ≈ GL
│
└─ Outcome: If mismatch → drill to ACDOCA to find timing difference or erroneous entry
```

### 7.3 Key Tables & Transaction Codes

| Module | Table | Content | Tcodes |
|--------|-------|---------|--------|
| **AP** | EKKO/EKPO | Purchase order | ME21N (Create), ME22N (Change) |
| **AP** | MKPF/MKPO | Material document (GR) | MIGO (Goods receipt) |
| **AP** | RSEG | AP line items (subledger) | N/A (view only) |
| **AP** | BSEG | GL line items (append from ACDOCA) | N/A |
| **AP** | LFA1/LFB1 | Vendor master | XK01 (Create), XK02 (Change) |
| **AR** | VBAK/VBAP | Sales order | VA01 (Create), VA02 (Change) |
| **AR** | LIKP/LIPS | Delivery | VL01N (Create) |
| **AR** | VBRK/VBRP | Billing document | VF01 (Create) |
| **AR** | KNA1/KNB1 | Customer master | XD01 (Create), XD02 (Change) |
| **AR** | BSID/BSAD | AR open/archived items | N/A (view only; select from open items) |
| **GL** | ACDOCA | Universal journal | FB01 (Manual entry), FB60 (Change) |

---

## 8. BANK RECONCILIATION

### 8.1 Manual Bank Reconciliation Flow

**Traditional approach**: Bank statement (MT940) imported; line-by-line matching.

```
Step 1: Import Bank Statement
├─ App: "Bank Reconciliation" (FI-CA)
├─ Source: Bank portal download (MT940 file)
├─ Actions: Select company code, bank account, statement date range
├─ System: Parse file; create bank statement line items in table EXTBP
└─ Outcome: ~120 bank statement lines loaded

Step 2: Match Outstanding Checks
├─ System: 
│  ├─ Retrieves GL bank account balance: $500K
│  ├─ Retrieves ERP payments issued (not yet cleared): ~20 checks
│  │  ├─ Check #5001-5020, totaling $80K
│  │  └─ Issued dates 3-10 days ago (not yet on statement)
│  └─ Outstanding checks: $80K (known; reconciling item)
│
└─ Outcome: Temporarily exclude from match

Step 3: Match Deposits
├─ System:
│  ├─ Retrieves AR cash collections (not yet on statement): ~15 deposits
│  ├─ Total: $75K (deposits from 2-5 days ago)
│  └─ Mark as "Outstanding deposit"
│
└─ Outcome: Temporarily exclude from match

Step 4: Auto-Match Check #'s & Amounts
├─ System:
│  ├─ For each payment issued in Step 2 (checks, wires), find match in bank statement
│  ├─ Match rule: Check # matches + amount = $X (within $0.01 tolerance)
│  ├─ For wire transfers: Wire reference matches
│  └─ Result: 18 of 20 checks matched; 2 still outstanding (older checks; stale)
│
└─ Outcome: ~18 items cleared from bank perspective

Step 5: Identify Unmatched Items
├─ Bank statement items with no match:
│  ├─ Bank fee: -$25 (not posted in ERP)
│  ├─ Interest earned: +$150 (not posted in ERP)
│  └─ Wire received from customer: +$50K (cash collection just arrived; no AR entry yet)
│
├─ ERP items with no match:
│  ├─ AP payment to vendor: -$5K (issued but not on statement yet)
│  └─ AR collection from customer: +$75K (sent to bank; not yet cleared)
│
└─ Outcome: ~6 reconciling items identified; need review

Step 6: Book ERP Adjustments
├─ Bank fees:
│  ├─ Manual JE: DR Bank Fee Expense (410000) $25, CR Bank Account (100100) $25
│  └─ Post to ACDOCA; clear from reconciliation
│
├─ Interest:
│  ├─ Manual JE: DR Bank Account (100100) $150, CR Interest Income (440000) $150
│  └─ Post to ACDOCA; clear from reconciliation
│
├─ Received wire (deferred AR matching):
│  ├─ Temporary: DR Bank (100100) $50K, CR Suspense (200800) $50K
│  ├─ Next day: AR clerk matches to customer invoice (Cash Application step)
│  └─ Then: CR Suspense, DR AR Receivable (normal flow)
│
└─ Outcome: ERP now reflects bank statement items

Step 7: Reconciliation Complete
├─ Calculation:
│  ├─ Bank statement balance: $500K
│  ├─ Outstanding checks: -$80K (from Step 2)
│  ├─ Outstanding deposits: +$75K (from Step 3)
│  ├─ Reconciled ERP balance: $500K - $80K + $75K = $495K ✓
│  └─ GL bank account balance: $495K ✓ MATCH
│
└─ Outcome: Reconciliation complete; no variance
```

### 8.2 Automated Bank Reconciliation (EBS - Electronic Bank Statement)

**Modern approach**: Real-time EBS feed; minimal manual intervention.

**Setup**:
- Bank provides **SFTP/API** connection (e.g., bank APIs, ISO 20022 XML)
- S/4HANA connects via **CPI** (Cloud Platform Integration) or **API Hub**
- Statement ingested **daily** (not monthly)

**Automatic Reconciliation Engine**:
```
Input: Bank statement (daily) + ERP payments
│
├─ Matching Rules (in priority order):
│  ├─ Rule 1: Check # exact match (for US checks)
│  ├─ Rule 2: Wire reference (SWIFT field) exact match
│  ├─ Rule 3: Amount + date within 2 days (for ACH transfers)
│  ├─ Rule 4: Fuzzy matching: Vendor name + amount ± $5
│  └─ Rule 5: Manual exception (human review, if unmatched)
│
├─ Unmatched Bank Items:
│  ├─ If amount ≤ $100: Auto-accrue to suspense (GL 200800)
│  └─ If amount > $100: Flag for review; create task in Fiori
│
├─ Unmatched ERP Items:
│  ├─ If payment > 30 days old + not on statement: Flag as "likely lost in transit" → resend or cancel
│  └─ System: Send email to treasurer with list
│
└─ Output: GL bank account ≈ Bank statement balance automatically
```

**Example Fiori App: "Bank Reconciliation Monitor"**:
```
┌─────────────────────────────────────────────────────────┐
│ Bank Reconciliation Monitor                             │
│ Company Code: 1000  Bank Account: 1100  As of: 2026-04-05
├─────────────────────────────────────────────────────────┤
│ Status: 95% Reconciled ($50K variance; auto-analyzed)   │
│                                                         │
│ Reconciling Items (5):                                  │
│ 1. Wire received from customer (pending AR match)       │
│    Amount: $50K | Days pending: 3 | Action: Match      │
│ 2. Bank fee (posted; cleared)                           │
│    Amount: -$25 | Status: ✓ Matched                    │
│ 3. Interest (posted; cleared)                           │
│    Amount: +$150 | Status: ✓ Matched                   │
│ 4. AP payment (issued 15 days ago; not on statement)    │
│    Amount: -$5K | Check #: 5042 | Status: ⚠ Outstanding│
│ 5. AR collection (sent to bank; clearing in 2 days)    │
│    Amount: +$75K | Status: ⚠ In Transit                │
│                                                         │
│ Action: (1) requires manual matching to customer       │
│         (4) mark as stale check (60+ days) + reissue   │
└─────────────────────────────────────────────────────────┘
```

---

## 9. OUTPUT MANAGEMENT & FORMS (Adobe Forms, Smart Forms, Output Channels)

### 9.1 Output Types & Channels

**Traditional SAP Output Management** (still in S/4HANA, backward compat):

| Output Type | Document | Example Form | Channel | Frequency |
|-------------|----------|--------------|---------|-----------|
| **Form** | Invoice | Invoice_Adobe.pdf | Print, Email, Fax | On-demand + schedule |
| **Form** | PO | PO_SmartForm | Print, EDI, Supplier portal | On-demand |
| **Form** | Check | Check_Laser | Print only | On-demand (batch) |
| **Notice** | Dunning letter | Dunning_Adobe | Email, Print | Periodic (weekly) |
| **Notice** | Tax document | Tax_Certificate.pdf | Email, File store | Annual |
| **E-Invoice** | Invoice (digital) | E-Invoice_XML | ZATCA, Customer portal | Real-time |

### 9.2 Adobe Forms (Modern Approach)

**Setup in S/4HANA**:

```
IMG → Cross-Application Components → Output Management → Forms
├── Form Design
│   ├── Tool: Adobe Forms Designer (integrated in SAP)
│   ├── Data binding: Automated from ABAP structure (e.g., invoice header/line)
│   ├── Layout: WYSIWYG designer; supports Arabic RTL, multi-page
│   └── Logic: JavaScript (in-form calculations, field visibility)
│
├── Connection to Document
│   ├── Trigger: Sales invoice posted → Billing app calls output
│   ├── System retrieves: VBRK (invoice header) + VBRP (lines) + KNA1 (customer) data
│   ├── Template data: Merged into Adobe form
│   └── PDF output: Generated in-memory
│
└── Output Channels
    ├── Print: Sent to printer queue (table TBJOB); can batch print
    ├── Email: Merged with email template; attachment to recipient from KNA1
    ├── Portal: Uploaded to customer self-service portal (Fiori Launchpad)
    └── Archive: Stored in Document Management (DMS) table DRAW
```

**Example Adobe Form Template** (Invoice):
```
[COMPANY LOGO]

INVOICE
Invoice #: [VBRK.VBELN]
Date: [VBRK.FKDAT]
Due: [VBRK.FKDAT + VBRK.ZBD1T]

Bill To:
[KNA1.NAME1]
[KNA1.STRAS]
[KNA1.PSTLZ] [KNA1.ORT01]
[KNA1.LAND1]

Items:
┌─────────────────────────────────────┐
│ Description  | Qty | Unit Price | Total │
├─────────────────────────────────────┤
│ [VBRP.VTEXT] | [VBRP.FKIMG] | [VBRP.NETPR] | [VBRP.NETWR] │
│ ...                                 │
├─────────────────────────────────────┤
│ Subtotal:                    [VBRK.SUBTOTAL] │
│ Tax (15% - KSA VAT):         [VBRK.TAXAMT] │
│ TOTAL:                       [VBRK.DOCAMOUNT] │
└─────────────────────────────────────┘

Payment Terms:
Terms: [VBRK.TERMS_TEXT]
Bank: [COMPANY.BANK_DETAILS]
```

### 9.3 Smart Forms (Legacy, Still Supported)

**Smart Forms** are a pre-cursor to Adobe Forms; still widely used:

```
Transaction SE71: Smart Forms Designer
├── Structure:
│   ├── Global data: Define variables, tables
│   ├── Form pages: Multiple pages, templates
│   ├── Windows: Define output regions (header, body, footer)
│   └── Logic: ABAP code for calculations
│
├── Data flow:
│   ├── Input: ABAP structure (EKKO, EKPO for PO)
│   ├── Processing: ABAP subroutines embedded in form
│   └── Output: Print or PDF
│
└── Example: PO Smart Form
    ├── Page 1 (Header): PO header, seller, buyer
    ├── Page 2+ (Detail): PO line items (table loop)
    └── Page N (Footer): Terms, signature line, bank details
```

**When to use**:
- **Adobe Forms**: New forms, customer-facing (invoices, statements)
- **Smart Forms**: Internal forms, processes (PO, picking list), legacy systems

### 9.4 E-Invoice & Structured Output (Saudi Arabia - ZATCA)

**ZATCA E-Invoicing Output**:

```
Trigger: Invoice posted (VBRK.FKDAT = today)
│
├─ System check: 
│  ├─ Buyer tax ID populated (KNA1.STEUERNUMMER)
│  ├─ Company VAT ID populated (BUKRS.TAXNUMBER)
│  └─ Item VAT lines present (VBRP.MWSKZ)
│
├─ Format conversion: VBRK/VBRP → JSON/XML structure
│  ├─ Field mapping:
│  │  ├─ VBRK.VBELN → Invoice ID
│  │  ├─ VBRK.FKDAT → Issue date
│  │  ├─ KNA1.NAME1 → Buyer name
│  │  ├─ KNA1.STEUERNUMMER → Buyer tax ID
│  │  ├─ BUKRS.TAXNUMBER → Seller tax ID
│  │  └─ SUM(VBRP.NETWR) → Invoice amount
│  │
│  └─ Tax breakdown:
│     ├─ Items with VAT 15%: subtotal $X
│     ├─ Items with VAT 0%: subtotal $Y
│     └─ Total VAT payable: $(X × 0.15)
│
├─ Digital signature:
│  ├─ Hash SHA-256(invoice_json)
│  ├─ Sign with PKCS#7 (certificate from Saudi CERT authority)
│  └─ Result: Signed_Encrypted_Invoice
│
├─ Submit to ZATCA API:
│  ├─ Endpoint: https://api.zatca.gov.sa/einvoicing/phase2
│  ├─ Payload: Signed_Encrypted_Invoice + signatures
│  └─ Response: Unique Invoice Reference (UIR) + clearance status
│
└─ Store result:
   ├─ VBRK.UIR (Unique Invoice Reference)
   ├─ VBRK.ZATCA_STATUS ("Approved", "Rejected", "Cleared")
   └─ ACDOCA link: E-Invoice metadata stored in audit trail
```

### 9.5 Output Scheduling

**Periodic Outputs** (batch processing):

```
IMG → Sales & Distribution → Billing → Output → Maintain Output Determination
│
├── Setup:
│   ├── Output type: YDRK (dunning notice)
│   ├── Trigger condition: AR age > 30 days
│   ├── Frequency: Weekly (Mondays 08:00)
│   ├── Distribution list: Send to collection agents
│   └── Form: Dunning_Adobe form
│
└── Execution:
    ├── Job name: "DUNNING_BATCH_WEEKLY"
    ├── Schedule: Mondays 08:00 via SAP background job (SM36)
    ├── Process:
    │   ├── Query BSAD (open AR items) where TAGE > 30
    │   ├── For each customer, generate dunning letter
    │   ├── Group by customer (1 letter per customer, all overdue invoices listed)
    │   └── Send email to collection agent + customer
    │
    └── Report: "Dunning Run Report" lists all notices sent
```

---

## 10. SECURITY MODEL (Authorization, Segregation of Duty, GRC)

### 10.1 Authorization Objects (Fine-Grained Access Control)

**Authorization objects** control which transactions/fields a user can access.

**Key Objects** (Finance):

| Object Code | Object Name | Fields | Example Usage |
|-------------|-------------|--------|---------------|
| **F_BKPF_BK** | Accounting document by posting key | BUKRS, BLART (Doc type), ACTVT (Activity) | User can post doc type SA (AP invoice) in company 1000, but not DA (debit note) |
| **F_GLAC_AC** | G/L account — GL master | BUKRS, SAKNR (GL account), ACTVT | User can view GL 400000-499999 (revenue), but not 500000+ (expense) |
| **F_BLCK_A** | Period lock/open by user | BUKRS, BSTAT (Status), ACTVT | User can post to current period, but cannot post to prior periods |
| **F_BKPF_US** | Accounting document — Vendor/Customer | VEND, CUST, ACTVT | User can view invoices for vendor 1000, but not vendor 1001 |
| **F_LFA1_A** | Vendor master — data access | BUKRS, VEND, ACTVT | User can create vendors, but only for their company code |
| **F_KNA1_A** | Customer master — data access | BUKRS, CUST, ACTVT | User can edit customer payment terms, but only for their cost center |
| **M_BANF_BWA** | Purchase requisition — plant access | WERKS (plant), ACTVT | User can release PRs for plant 1000, not 1001 |
| **M_EBAN_BWA** | Purchase requisition — access | WERKS, ACTVT | User can see PRs for warehouse 1000 |
| **M_EKKO_EKG** | Purchase order — document type | BSART (PO type), ACTVT | User can create purchase orders, not blanket orders |

**Authorization Fields**:
- **ACTVT** (Activity): 01=Create, 02=Change, 03=Display, 06=Delete, 16=Post
- **BUKRS** (Company Code): Which company the user can transact in
- **WERKS** (Plant): Which manufacturing plant
- **EKGRP** (Purchasing group): Which procurement group
- **FKART** (Billing doc type): Which invoice types
- **LIFNR** (Vendor range): Specific vendor restrictions

### 10.2 Segregation of Duties (SoD)

**SAP-provided SoD policies** prevent conflicting roles:

| Conflict | Role A | Role B | Why Prevented |
|----------|--------|--------|---------------|
| **Invoice → Approval → Payment** | AP Clerk (enter) | Approver (approve) + Treasurer (pay) | One person cannot post AP invoice AND approve AND pay |
| **PO Creation → Receipt → Invoice Match** | Procurement (create PO) | Warehouse (receipt) + AP (invoice) | One person cannot create PO, receive, AND match invoice |
| **GL Post → Reconciliation** | GL Accountant (post JE) | GL Accountant (reconcile) | Same person can post JE then reconcile (allowed if subledger matches); escalation to controller if variance |
| **Revenue Recognition → AR Posting** | Revenue Accountant (recognize) | AR Clerk (post invoice) | Preferably different people (AR posts invoice, Revenue Accountant reviews for revenue impact) |
| **User Admin → Approval Authority** | Sys Admin (create user) | Approver role (for same doc type) | System Admin cannot also approve transactions they configure access for |

**SoD Monitoring** (Fiori app):
```
App: "Segregation of Duties Monitor"
│
├─ Report: All users with conflicting roles
├─ Example output:
│  ├─ User JOHN.SMITH:
│  │  ├─ Role: SAP_BR_AP_ACCOUNTANT (post invoices)
│  │  ├─ Role: SAP_BR_PAYMENT_PROCESSOR (process payments)
│  │  └─ CONFLICT: Can post AND pay from same account; requires mitigating control
│  │
│  └─ Recommendation: Assign Payment Processor role to different user (SARAH.JONES)
│
└─ Approval workflow: Risk acceptance by Compliance Officer
```

### 10.3 User Access Provisioning & Governance

**Identity & Access Governance (IAG)** in Fiori:

```
User requests a role (e.g., new employee starts)
│
├─ Request submitted in Fiori app "Identity & Access Governance"
│   ├─ Employee name: JOHN.SMITH
│   ├─ Role needed: SAP_BR_AP_ACCOUNTANT
│   ├─ Justification: "Hired as AP Clerk; process invoices for EMEA region"
│   ├─ Company code: 1000 (EMEA)
│   ├─ Cost center: CC1010 (Accounting)
│   └─ Manager approval: MANAGER.APPROVER confirms
│
├─ System SoD check:
│   ├─ Does JOHN.SMITH have conflicting roles?
│   │  ├─ JOHN has: Nothing yet (new employee)
│   │  └─ JOHN requesting: SAP_BR_AP_ACCOUNTANT
│   └─ SoD clearance: PASS (no conflict)
│
├─ Technical approval:
│   ├─ Access reviewer (ALICE.REVIEWER, Compliance Officer) approves
│   ├─ System auto-generates PFCG role assignment
│   └─ Role provisioned: Sync to identity provider (SAML, OAuth)
│
└─ Audit trail:
   ├─ Who approved: ALICE.REVIEWER on 2026-04-05
   ├─ Justification: Stored in audit log
   └─ Role removal: When employee leaves, manager de-provisions via same workflow
```

### 10.4 Audit Trail & Compliance (GRC)

**Audit Trail** (table CDCLS, real-time logging):

```
Every posting (GL JE, AP invoice, AR cash, etc.) generates audit trail:
│
├─ User: JOHN.SMITH
├─ Action: Posted AP invoice (transaction MIRO)
├─ Document: Invoice #12345 from Vendor 1000
├─ Amount: $50,000 USD
├─ GL Account: 500000 (COGS)
├─ Timestamp: 2026-04-05 14:32:15 CEST
├─ IP Address: 192.168.1.100
├─ Success: Yes
│
└─ Retrieved via Fiori app:
   ├─ App: "Journal Entry Audit Trail"
   ├─ Filter: GL account 500000, last 7 days
   ├─ Result: 47 postings; click any entry to see full audit details
   └─ Export: CSV for external auditor review
```

**Change log** (table CDHDR, historical):

```
If user edits GL account master (transaction FS00):
│
├─ Change: Field "Account name" from "COST OF GOODS SOLD" to "COST OF REVENUE"
├─ Who: ALICE.REVIEWER on 2026-04-05 10:15:00
├─ Old value: "COST OF GOODS SOLD"
├─ New value: "COST OF REVENUE"
│
└─ Retrieved via Fiori app:
   ├─ App: "G/L Account History"
   ├─ View all changes to account 500000 (COGS)
   ├─ Who, when, old/new value
   └─ Critical for compliance: Accounts Payable audit trail ensures no retroactive changes
```

**GRC (Governance, Risk, Compliance):**

SAP GRC module provides:
- **Access Risk Analysis**: Identify conflicting user roles (SoD violations)
- **Fraud Detection**: Unusual posting patterns (e.g., large JE outside business hours)
- **Control Testing**: Auditor samples transactions; tests control effectiveness
- **Remediation Tracking**: Document fix for control failures

---

## 11. INTEGRATION PATTERNS

### 11.1 Cloud Platform Integration (CPI) — Middleware

**CPI** is SAP's cloud iPaaS (integration platform as a service).

**Typical Integration Scenarios**:

```
Scenario 1: Bank Statement Import
│
├─ Bank APIs (MT940, ISO 20022 XML)
├─ Receives daily → CPI endpoint
├─ CPI transformation:
│   ├─ Parse bank statement (MT940)
│   ├─ Map bank fields to S/4HANA EXTBP (bank statement table)
│   └─ Validation: Amount totals, dates, duplicate checks
│
├─ Push to S/4HANA:
│   ├─ REST API call: /sap/opu/odata/sap/BankReconciliationService
│   ├─ Payload: Bank transactions + metadata
│   └─ Response: Success/failure; import log
│
└─ Result: Bank statement loaded; reconciliation engine triggered

Scenario 2: Supplier Price List Updates
│
├─ Supplier portal (supplier.com)
├─ Supplier publishes new catalog XML
├─ CPI receives via SFTP/API
├─ CPI transformation:
│   ├─ Parse supplier catalog (product #, price, UOM, lead time)
│   ├─ Validation: Product exists in MARA (material master); price reasonable
│   └─ Match to S/4HANA RM (request for materials)
│
├─ Push to S/4HANA:
│   ├─ OData API: /sap/opu/odata/sap/InfoRecordListService
│   ├─ Create/update EINA (purchase info record)
│   └─ Price effective date: From catalog date
│
└─ Result: Material prices updated; PO creation uses latest vendor quotes

Scenario 3: Invoice Transmission to Customer (EDI 810)
│
├─ Trigger: Sales invoice posted (VBRK)
├─ CPI retrieves invoice data:
│   ├─ VBRK.VBELN (invoice #), VBRK.NETWR (amount)
│   ├─ KNA1 customer name/address
│   ├─ VBRP line items (qty, price, total)
│   └─ Tax calculation (VAT)
│
├─ CPI transforms to EDI X12 810 (invoice format):
│   ├─ Map S/4HANA fields to EDI 810 segments
│   ├─ Add UK-specific fields (e.g., buyer reference)
│   └─ Digital signature (customer may require)
│
├─ Push to customer:
│   ├─ Via EDI network (SEEBURGER, SPS, Elemica hub)
│   ├─ OR via customer portal (REST API)
│   └─ Delivery confirmation: EDI 997 ACK receipt
│
└─ Result: Customer receives invoice in their ERP; automatic three-way match

Scenario 4: SAP SuccessFactors (HR) to Finance
│
├─ Payroll processed in SuccessFactors (HR cloud)
├─ Trigger: Payroll period closed
├─ SF publishes:
│   ├─ Employee name, ID, amount
│   ├─ Salary, bonus, tax, deduction
│   └─ Cost center (department)
│
├─ CPI receives and transforms:
│   ├─ Map SuccessFactors employee ID to PERNR (S/4HANA)
│   ├─ Map cost center to KOSTL
│   ├─ Aggregate: Total salary expense by cost center
│   └─ Create accounting lines
│
├─ Push to S/4HANA:
│   ├─ Payroll posting via OData: /sap/opu/odata/sap/PayrollPostingService
│   ├─ Creates ACDOCA entries:
│   │  ├─ DR Salary Expense (400200) $XXX [by cost center]
│   │  ├─ CR Salary Payable (200200) $XXX
│   │  ├─ CR Tax Payable (210100) $XXX
│   │  └─ CR Deduction Payable (210300) $XXX (401k, health)
│   │
│   └─ Result: Payroll expense posted to GL automatically
│
└─ Month-end close: Finance reviews posting; GL balanced
```

### 11.2 API Hub & OData Services

**SAP API Hub** (api.sap.com) catalogs all S/4HANA Cloud REST APIs.

**Key OData Services** (used by Fiori apps + external integrations):

| API | Entity | CRUD Operations |
|-----|--------|-----------------|
| **BusinessPartnerService** | Vendor (Supplier) | Create, read, update vendor master (LFA1) |
| **SalesOrderService** | Sales order | Create SO, read, update status (VBAK) |
| **PurchaseOrderService** | Purchase order | Create PO, read, change (EKKO) |
| **InvoiceService** | Billing document | Read invoices (VBRK); no create (via SalesOrder) |
| **JournalEntryService** | GL journal entry | Create manual JE, read, post (ACDOCA) |
| **MaterialDocumentService** | Goods receipt/issue | Create material doc, read (MKPF) |
| **SupplierInvoiceService** | AP invoice | Create invoice, read, match (RSEG) |
| **BankReconciliationService** | Bank statement | Import bank lines, read reconciliation status |
| **CostElementService** | Cost center | Read cost center master (CSKS) |

**Example: Create Purchase Order via OData**:

```json
POST /sap/opu/odata/sap/PurchaseOrderService/PurchaseOrders

{
  "PurchaseOrderNumber": "4500000123",
  "Vendor": "1000",
  "CompanyCode": "1000",
  "PurchaseOrderDate": "2026-04-05",
  "PurchaseOrderType": "NB",  // Standard PO
  "Currency": "USD",
  
  "LineItems": [
    {
      "LineNumber": "10",
      "Material": "WIDGET-X",
      "Quantity": "100",
      "UnitOfMeasure": "EA",
      "NetPrice": "50.00",
      "DeliveryDate": "2026-05-05",
      "GLAccount": "500000",  // COGS (expense account)
      "CostCenter": "CC1010"
    }
  ]
}

Response 201:
{
  "PurchaseOrderNumber": "4500000123",
  "Status": "Draft",
  "TotalAmount": "5000.00",
  "_links": {
    "self": "https://s4hanacloud.company.com/sap/opu/odata/sap/PurchaseOrderService('4500000123')"
  }
}
```

### 11.3 Event Mesh & Real-Time Integration

**Event Mesh** (SAP's publish-subscribe platform):

```
Scenario: Automatic AR Collection Notification

Event Source: S/4HANA (Invoice posting)
│
├─ Event: "SalesInvoicePosted"
│  ├─ Payload: Invoice #, amount, customer, due date
│  ├─ Published to: Topic "sap/finance/invoices/created"
│  └─ Timestamp: Real-time (milliseconds after GL posting)
│
├─ Event Subscriber: Email service
│  ├─ Subscribed to: "sap/finance/invoices/created"
│  ├─ Filter: Amount > $10,000 (only large invoices)
│  └─ Action: Trigger email workflow
│
├─ Event Subscriber: Analytics (SAP Analytics Cloud)
│  ├─ Subscribed to: "sap/finance/invoices/created"
│  └─ Action: Update real-time revenue dashboard
│
└─ Event Subscriber: Collections system (3rd-party)
   ├─ Subscribed to: "sap/finance/invoices/created" + "sap/finance/payments/received"
   ├─ Process: Track customer balance; trigger dunning when overdue
   └─ Action: Integrate with customer's AR platform
```

### 11.4 iDoc (Intermediate Document) — Legacy Integration

**iDocs** are SAP's legacy message format (still supported for backward compat).

```
Outbound iDoc Example: AP Invoice to Vendor Portal

Trigger: AP invoice received (transaction MIRO)
│
├─ System generates iDoc (outbound):
│  ├─ Message type: INVOIC (Invoice)
│  ├─ Direction: Outbound (S/4HANA → external system)
│  ├─ Segments:
│  │  ├─ HDR: Invoice header (vendor, date, amount, terms)
│  │  ├─ ITM: Line items (material, qty, price)
│  │  └─ TAX: Tax breakdown
│  │
│  └─ Status: Ready to send
│
├─ Port configuration (RFC destination, FTP, email):
│  ├─ Where to send: Vendor EDI network or email
│  ├─ Format: IDX (iDoc text format) or XML
│  └─ Encryption: Optional (PGP for sensitive data)
│
└─ Result: Vendor receives EDI/XML invoice; processes in their AR system
```

---

## 12. DATA MIGRATION COCKPIT

### 12.1 Rapid Data Loading (RDL) Tools

**SAP provides XL templates** (Excel-based loaders) for migrating master data.

**Common Migrations:**

| Entity | XL Template | Key Fields | Validation |
|--------|-------------|-----------|-----------|
| **Chart of Accounts** | `COA.xlsb` | Account #, name, type (A/L/E/R), currency | Account # must be unique; account type valid |
| **Vendor Master** | `Vendor.xlsb` | Vendor #, name, address, tax ID, payment terms, bank | Vendor # unique; country valid; bank account IBAN format |
| **Customer Master** | `Customer.xlsb` | Customer #, name, address, credit limit, payment terms, sales area | Customer # unique; country valid; credit limit ≤ company policy |
| **Material Master** | `Material.xlsb` | Material #, description, UOM, plant, standard cost | Material # unique; UOM valid; cost > 0 |
| **GL Balances** (opening) | `GLBalance.xlsb` | Company code, GL account, period, amount | GL account must exist (from CoA); period valid; debit/credit balanced |
| **Vendor Invoices** | `VendorInvoice.xlsb` | Vendor, invoice #, date, PO, amount, line items | Vendor exists; invoice date ≤ today; amount > 0 |
| **Customer Orders** | `CustomerOrder.xlsb` | Customer, order #, item, qty, price, delivery date | Customer exists; item exists; qty > 0 |

### 12.2 Migration Process

```
Step 1: Download XL Template
├─ Fiori app: "Manage Data Loading"
├─ Select entity: e.g., Vendor Master
└─ Download template (e.g., Vendor.xlsb)

Step 2: Populate Template
├─ Open in Excel
├─ Fill columns: Vendor #, Name, Address, Tax ID, Payment Terms
├─ Validation: Formula-based cell checks (color coding for errors)
├─ Example row:
│  ├─ Vendor #: 5000
│  ├─ Name: "ABC Supplies Inc."
│  ├─ Address: "123 Main St, Chicago, IL 60601"
│  ├─ Tax ID: "12-3456789"
│  └─ Payment Terms: "Net 30"
│
└─ Save: vendor_migration_2026.xlsb

Step 3: Upload to S/4HANA
├─ Fiori app: "Manage Data Loading"
├─ Select file: vendor_migration_2026.xlsb
├─ Staging area: File stored in table LSMW (Legacy System Migration Workbench)
├─ Validation:
│  ├─ Check: Vendor # not already exists (duplicate key check)
│  ├─ Check: Country code valid
│  ├─ Check: Tax ID format correct
│  └─ Result: Pass/Fail for each row
│
└─ Errors: Color-coded in Fiori app; must fix and re-upload

Step 4: Review & Approve
├─ Migration Manager (LSMW_ADMIN role) reviews
├─ Checks:
│  ├─ All records passed validation
│  ├─ No duplicates with existing vendors
│  └─ Sample spot-check (e.g., vendor 5000 address correct)
│
└─ Approval: Click "Activate Migration" (irreversible!)

Step 5: Posting to Database
├─ Background job (asynchronous) runs
├─ Inserts into master tables:
│  ├─ LFA1 (vendor header)
│  ├─ LFB1 (vendor company-specific data)
│  └─ LFBK (vendor bank)
│
├─ Audit trail: All rows logged (user, timestamp, status)
└─ Report: "Vendor Migration Report" shows results

Step 6: Post-Migration Validation
├─ Fiori app: "Vendor Master Data Browser"
├─ Spot-check: Search for vendor 5000 → verify name, address, tax ID match uploaded data
├─ Subledger test: Create test PO from vendor 5000 → verify payment terms apply
└─ Reconciliation: Count of vendors in LFA1 matches count uploaded
```

### 12.3 GL Opening Balance Migration

**Critical for go-live**:

```
Scenario: Migrating from legacy ERP (e.g., ECC) to S/4HANA Cloud

Legacy GL balance (as of 2026-03-31, final day before go-live):
│
├─ Assets:
│  ├─ Cash (100100): $1,000,000
│  ├─ AR (100000): $500,000
│  ├─ Inventory (150000): $800,000
│  └─ Fixed Assets (160000): $5,000,000
│
├─ Liabilities:
│  ├─ AP (200000): $700,000
│  ├─ Accrued Expenses (200500): $150,000
│  └─ Long-term Debt (250000): $3,000,000
│
└─ Equity:
   ├─ Paid-in Capital (300000): $2,000,000
   └─ Retained Earnings (310000): $1,450,000

Total Assets = $7,300,000; Total Liabilities + Equity = $7,300,000 ✓ Balanced

Migration Steps:
│
├─ Step 1: Prepare opening balance journal entry (ACDOCA segment)
│  ├─ GL account (RACCT) | Amount
│  ├─ 100100 (Cash)        | $1,000,000
│  ├─ 100000 (AR)          | $500,000
│  ├─ 150000 (Inventory)   | $800,000
│  ├─ 160000 (Fixed Assets)| $5,000,000
│  ├─ 200000 (AP)          | -$700,000
│  ├─ 200500 (Accruals)    | -$150,000
│  ├─ 250000 (LT Debt)     | -$3,000,000
│  ├─ 300000 (Paid Capital)| -$2,000,000
│  └─ 310000 (Ret. Earn.)  | -$1,450,000
│
├─ Step 2: Determine posting method
│  ├─ Option A (Preferred): Post as opening balance adjustment
│  │  └─ Doc type: "OB" (Opening balance); auto-posted by system
│  │
│  └─ Option B: Manual JE (if you have subledger detail)
│     └─ Doc type: "SA" (Accounting document); requires human review
│
├─ Step 3: Post to ACDOCA
│  ├─ Transaction: FB01 (Create JE) or upload via XL template
│  ├─ Document number: System auto-generates (e.g., 1000001)
│  ├─ Posting date: 2026-03-31 (period 03, fiscal year 2026)
│  ├─ All entries hit ACDOCA (no subledger detail; aggregate at GL level)
│  └─ Result: GL balance now matches legacy ERP
│
└─ Step 4: Reconciliation
   ├─ Compare S/4HANA ACDOCA total to legacy ERP total
   ├─ All 9 GL account balances must match exactly
   └─ Verify: No currency rounding errors, all accounts populated
```

---

## 13. ACTIVATE METHODOLOGY (Implementation Roadmap)

**SAP Activate** is the recommended implementation methodology for S/4HANA Cloud deployments.

### 13.1 Phases of Activate

**4 phases + continuous improvement**:

```
Phase 1: EXPLORE (Weeks 1-4)
├─ Goal: Understand requirements; define scope; identify business process gaps
├─ Activities:
│  ├─ Process interviews (Finance, Sales, Procurement leads)
│  ├─ Current-state mapping (legacy system workflows → S/4HANA)
│  ├─ Gap analysis: What S/4HANA does natively vs. custom development needed
│  └─ Business process scope (e.g., "only US + EU; single GL company")
│
├─ Deliverables:
│  ├─ "Business Process Scope Document" (BPSD)
│  ├─ "Gap & Fit Analysis" (top gaps identified + solutions)
│  └─ High-level timeline (target go-live date)
│
└─ Outcome: Executive steering committee approves project scope + budget

Phase 2: REALIZE (Weeks 5-16)
├─ Goal: Design, configure, and build the solution
├─ Activities:
│  ├─ Process design workshops:
│  │  ├─ Finance: GL structure, COA, cost centers, P&L segment
│  │  ├─ AP/AR: Invoice workflow, payment terms, aging
│  │  ├─ Procurement: PO workflow, 3-way match, vendor master
│  │  └─ Sales: Billing, credit limit, revenue recognition
│  │
│  ├─ SAP configuration (IMG):
│  │  ├─ Company code setup
│  │  ├─ GL account master
│  │  ├─ Cost center master + internal order master
│  │  ├─ Vendor/customer master setup
│  │  ├─ AP invoice workflow
│  │  ├─ AR credit management
│  │  ├─ Depreciation posting rules
│  │  ├─ Payroll setup (if in-scope)
│  │  └─ VAT/Tax configuration
│  │
│  ├─ Development (if custom code needed):
│  │  ├─ Fiori apps (custom SAPUI5 apps if not standard)
│  │  ├─ Workflow automation (Fiori Elements + custom logic)
│  │  └─ Integrations (CPI workflows to legacy or 3rd-party systems)
│  │
│  └─ Data migration templates:
│     ├─ Chart of Accounts
│     ├─ Vendor + Customer masters
│     ├─ GL opening balances
│     └─ Material masters (if used)
│
├─ Test cycles:
│  ├─ SIT (System Integration Test): Config tested in isolation
│  ├─ UAT (User Acceptance Test): Business users test workflows end-to-end
│  └─ Performance test: High-volume GL posting (month-end close) tested
│
└─ Outcome: UAT sign-off; system ready for cutover

Phase 3: DEPLOY (Weeks 17-19)
├─ Goal: Go-live; migrate data; switchover from legacy
├─ Activities:
│  ├─ Pre-cutover:
│  │  ├─ Final data extraction from legacy system (night before go-live)
│  │  ├─ Data staging: Load GL opening balance, vendor/customer masters
│  │  ├─ Cutover testing: Dry-run in production-like environment
│  │  └─ Backups: Full legacy system backup (30-day retention for rollback)
│  │
│  ├─ Cutover weekend (Friday 18:00 → Monday 06:00):
│  │  ├─ Legacy system locked (no new transactions)
│  │  ├─ Final GL balance export from legacy
│  │  ├─ GL opening balance JE posted to S/4HANA
│  │  ├─ Vendor/customer/material masters loaded
│  │  ├─ Data validation: Reconcile legacy to S/4HANA
│  │  └─ S/4HANA "go-live" (enabled for transaction processing)
│  │
│  └─ Go-live week:
│     ├─ Day 1 (Monday): First business transactions posted in S/4HANA
│     ├─ Days 2-5: Monitor; troubleshoot issues; execute "hypercare" (24/7 support)
│     └─ Month-end close (first month in S/4HANA): Close cockpit executed
│
└─ Outcome: Legacy system decommissioned; S/4HANA in steady state

Phase 4: RUN (Weeks 20+)
├─ Goal: Optimize; train; transition to BAU (Business as Usual)
├─ Activities:
│  ├─ Post-go-live optimization:
│  │  ├─ Analyze transaction volumes (GL posting, AP invoices, AR collections)
│  │  ├─ Identify bottlenecks (slow reports, period close delays)
│  │  └─ Tune indexes (ACDOCA indexed on critical dimensions)
│  │
│  ├─ Lessons learned:
│  │  ├─ What worked well
│  │  ├─ What took longer than expected
│  │  └─ Improvements for next phase (e.g., add supply chain, manufacturing)
│  │
│  ├─ User training:
│  │  ├─ Finance team: GL posting, period close, variance analysis
│  │  ├─ Procurement: PO creation, invoice matching, vendor management
│  │  ├─ Sales: SO creation, billing, credit management
│  │  └─ HR: Payroll posting review
│  │
│  └─ Governance transition:
│     ├─ SAP support model (Managed Cloud Services, SAP Innovation Services)
│     ├─ Change management (Patch Tuesday monthly updates; SAP manages)
│     └─ Continuous improvement (quarterly release deployments)
│
└─ Outcome: System stable; users trained; BAU achieved; ongoing optimization
```

---

## 14. EMBEDDED ANALYTICS (Smart Business KPI Tiles, Story-Based Reporting, Embedded BW)

### 14.1 Smart Business KPI Tiles

**Embedded in Fiori Launchpad**:

```
User: CFO (role: SAP_BR_CONTROLLER)
├─ Logs into Fiori Launchpad
└─ Sees tiles:

┌──────────────────────────────────────┐
│ "Revenue YTD" (Smart Business Tile)  │
│                                      │
│ $47.3M  (vs. Target $50M; -5.4%)    │
│                                      │
│ [TREND] ↑ +$3.2M vs. prior quarter  │
│                                      │
│ [CLICK] Drill to: Revenue by Segment│
└──────────────────────────────────────┘

┌──────────────────────────────────────┐
│ "Days Sales Outstanding (DSO)"      │
│                                      │
│ 42 days  (vs. Target 35 days; ⚠)    │
│                                      │
│ [ALERT] Customer ABC $5M outstanding│
│         Invoice due 2026-04-10       │
│                                      │
│ [CLICK] Drill to: Collections Mgmt  │
└──────────────────────────────────────┘

┌──────────────────────────────────────┐
│ "AP Aging" (Payables Alert Tile)    │
│                                      │
│ 30-60 days overdue: $3.2M (15 inv.) │
│ 60-90 days overdue: $1.8M (8 inv.)  │
│ 90+ days overdue: $0.5M (2 inv.)    │
│                                      │
│ [CLICK] Drill to: Payment Processing│
└──────────────────────────────────────┘
```

**How it Works** (Fiori Smart Business):

```
Tile Definition (in IMG):
├─ Name: "Revenue YTD"
├─ Query: OData service → /sap/opu/odata/sap/AnalyticsService/Revenue
├─ Filter: Company code = 1000, Period = YTD 2026
├─ Target: $50M (configuration parameter)
├─ Refresh: Real-time (or hourly cache)
│
└─ Threshold logic:
   ├─ Green: Achievement ≥ 95% of target
   ├─ Yellow: Achievement 85-95%
   └─ Red: Achievement < 85%

Visualization:
├─ Actual value: Large font, prominent
├─ % of target: Percentage variance
├─ Trend: Up/down arrow + $ change vs. last period
└─ Status indicator: Color (red/yellow/green)

Drill-down:
├─ Click tile → Launch Fiori app "Revenue Analytics Story"
├─ Shows: Revenue by segment (product, customer, region)
├─ Drill deeper: Segment → Detail transactions
└─ All data sourced from ACDOCA + GL
```

### 14.2 Story-Based Reporting (Embedded BW)

**SAP Analytics Cloud (SAC) Stories** embedded in S/4HANA:

```
Story: "Financial Close Dashboard"
├─ Source: ACDOCA (GL posting data)
├─ Refresh: Real-time (or batch nightly)
│
├─ Page 1 — "Income Statement Summary"
│  ├─ Chart 1: Revenue trend (12 months)
│  ├─ Chart 2: Expense breakdown (COGS, SG&A, R&D)
│  ├─ Chart 3: EBITDA margin trend
│  └─ Drill to any segment → detailed GL account level
│
├─ Page 2 — "Cash Position"
│  ├─ Chart 1: Cash balance by company code + currency
│  ├─ Chart 2: Cash flow forecast (rolling 13 weeks)
│  ├─ Chart 3: Currency exposure (foreign exchange risk)
│  └─ [ACTION] Drill to bank reconciliation detail
│
├─ Page 3 — "Working Capital"
│  ├─ Metric: Cash conversion cycle = DSO + DIO - DPO
│  │  ├─ DSO (Days Sales Outstanding): AR aging
│  │  ├─ DIO (Days Inventory Outstanding): Inventory aging
│  │  └─ DPO (Days Payable Outstanding): AP aging
│  │
│  ├─ Chart: Trend over 24 months
│  ├─ [ALERT] If CCC > target, highlight in red
│  └─ [CLICK] Drill to: Customer aging, inventory aging, AP aging
│
└─ Page 4 — "Close Checklist"
   ├─ Task: "GL Reconciliation" — Status: Complete (2026-03-28)
   ├─ Task: "AP Accruals" — Status: In progress (Assigned: Sarah)
   ├─ Task: "Period Close" — Status: Not started (Depends on GL Recon)
   └─ [CLICK] Task → Launch corresponding Fiori app
```

**Creation** (no coding required):

```
SAP Analytics Cloud (SaaS dashboard tool)
│
├─ Connect to S/4HANA: OData service → /sap/opu/odata/sap/AnalyticsService/GL
├─ Create data source: "GL Balances"
├─ Add visualizations:
│  ├─ Table: GL account, balance, prior period, variance
│  ├─ Chart: Stacked bar (account → amount, by cost center)
│  ├─ KPI: Net income (single number)
│  └─ Combo: Line (trend) + bar (period comparison)
│
├─ Add interactivity:
│  ├─ Filter: Date range, company code, GL account range
│  ├─ Drill-down: GL account detail → ACDOCA line items
│  └─ Input controls: Allow CFO to adjust forecast assumptions
│
└─ Publish to S/4HANA:
   ├─ Embed in Fiori Launchpad tile
   └─ Share link with Finance Manager role
```

### 14.3 Key Performance Indicators (KPIs) by Business Area

**Finance KPIs** (from ACDOCA):

| KPI | Formula | Frequency | Target |
|-----|---------|-----------|--------|
| **Gross Profit Margin** | (Revenue - COGS) / Revenue | Monthly | 40% |
| **Operating Margin** | (Revenue - Operating Expense) / Revenue | Monthly | 15% |
| **Current Ratio** | Current Assets / Current Liabilities | Monthly | 1.5:1 |
| **Quick Ratio** | (Cash + AR) / Current Liabilities | Monthly | 1.0:1 |
| **Cash Conversion Cycle** | DSO + DIO - DPO | Monthly | < 30 days |
| **Days Sales Outstanding** | (AR / Revenue) × Days in period | Monthly | 35 days |
| **Days Inventory Outstanding** | (Inventory / COGS) × Days | Monthly | 60 days |
| **Days Payable Outstanding** | (AP / COGS) × Days | Monthly | 45 days |
| **Debt-to-Equity Ratio** | Total Liabilities / Shareholders' Equity | Quarterly | < 2.0 |
| **Return on Assets (ROA)** | Net Income / Total Assets | Quarterly | 10% |
| **Return on Equity (ROE)** | Net Income / Shareholders' Equity | Quarterly | 20% |

**AP/AR KPIs**:

| KPI | Formula | Frequency | Target |
|-----|---------|-----------|--------|
| **Invoice Processing Time** | Days from receipt to payment | Weekly | 5 days |
| **3-Way Match Success Rate** | Matched invoices / Total invoices | Weekly | 98% |
| **AP Aging** | % invoices overdue > 30 days | Weekly | < 5% |
| **Discount Capture Rate** | Early discounts taken / Available | Monthly | 95% |
| **AR Aging** | % invoices overdue > 30 days | Weekly | < 10% |
| **Bad Debt Reserve Rate** | Reserve / Total AR | Monthly | 2-5% |
| **Collections Effectiveness Index** | Collections / (Starting AR + New AR) | Monthly | > 95% |

---

## CONCLUSION

**S/4HANA Cloud's strength** derives from:

1. **ACDOCA Universal Journal** — One table, no reconciliation nightmare, instant drill-down
2. **Modular Architecture** — Pick & choose functions (you don't need all 14 modules)
3. **Cloud-Native Design** — Automatic patching, disaster recovery, global availability
4. **Fiori UX** — Single-purpose apps, mobile-first, AR/RTL support
5. **Embedded Analytics** — Real-time KPI tiles, no separate BI tool required
6. **Activation Methodology** — Structured go-live path (Explore → Realize → Deploy → Run)
7. **Regulatory Compliance** — Saudi VAT/ZATCA built-in, multi-country support
8. **Integration Patterns** — CPI, OData, Event Mesh for seamless ecosystem

**For APEX (Arabic SaaS ERP)**, emulate:
- **Single universal journal** (not split tables)
- **Modular phase-based architecture** (like SAP's phases 1-11)
- **Fiori-like Riverpod state** (reactive, not imperative UI)
- **ZATCA e-invoice integration** (critical for Saudi market)
- **Role-based access control** (with SoD enforcement)
- **Embedded analytics** (KPI tiles, drill-down from GL)
- **Cloud-native infrastructure** (Render.com, GitHub Pages style)

