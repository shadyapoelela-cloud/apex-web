# Deep-Dive: Odoo 17 Accounting Architecture & Conventions

**Research Date:** April 30, 2026  
**Target:** Extract APEX-competitive accounting model, screen flows, and conventions from Odoo 17  
**Deliverable:** Structured markdown covering 14 core accounting domains

**Source Base:** Odoo 17.0 official documentation + forum discussions

---

## 1. THE ACCOUNTING CHEAT SHEET

### Asset, Liability, Equity, Income, Expense Definitions

Per Odoo 17 terminology:

- **Assets**: The company's wealth and the goods it owns. 
  - **Fixed Assets** (long-term): Buildings, offices, equipment.
  - **Current Assets** (short-term): Bank accounts, cash, receivables, inventory.

- **Liabilities**: Obligations from past events that the company will have to pay in the future.
  - Utility bills, debts, unpaid suppliers (accounts payable).
  - Short-term (current) or long-term obligations.

- **Equity**: The amount of funds contributed by owners (founders, shareholders) plus previously retained earnings (or losses).
  - Also called "Owner's Equity" or "Shareholders' Equity."
  - Includes contributed capital + accumulated profit/loss.

- **Income (Revenue)**: Money received from the sale of goods/services or other business activities.
  - Posted to P&L statement (income statement accounts).

- **Expenses**: Costs incurred in running the business (salaries, rent, utilities, cost of goods sold).
  - Posted to P&L statement (expense accounts).

### Debit and Credit Sign Convention

Per Odoo 17 documentation:

- Every transaction is recorded by **debiting and crediting multiple accounts** in a journal entry.
- **For a journal entry to be balanced:** Sum of all debits = Sum of all credits.

**Account Type Direction:**
- **Assets**: Debit increases, Credit decreases.
- **Liabilities**: Credit increases, Debit decreases.
- **Equity**: Credit increases, Debit decreases.
- **Income/Revenue**: Credit increases (positive entry), Debit decreases.
- **Expenses**: Debit increases, Credit decreases.

### Trial Balance Structure

The trial balance lists all general ledger accounts and their balances. It ensures that:
- Total debits = Total credits (fundamental accounting equation verification).
- All accounts are correctly balanced.
- No posting errors exist.

Odoo generates a **Trial Balance report** showing all GL accounts with their debit/credit balances and provides drill-down capability to view underlying transactions.

### Profit & Loss and Balance Sheet Equations

**Balance Sheet Equation (Fundamental):**
```
Assets = Liabilities + Equity
```

**Profit & Loss Equation:**
```
Net Income = Revenue - Expenses
```

**Updated Equity After Period:**
```
Ending Equity = Beginning Equity + Net Income (or Loss) - Dividends
```

In Odoo, the Balance Sheet accounts (Assets, Liabilities, Equity) remain on the books year after year. Income and Expense accounts are closed at year-end to equity via "Current Year's Earnings."

### Fiscal Year Mechanics

- **Fiscal Year Definition**: A defined period (typically 12 months) for which financial statements are prepared and taxes are filed.
- **Default Account for Year-End**: Odoo creates a special account type called **"Current Year's Earnings"** (default: account 999999, named "Undistributed Profits/Losses") that accumulates the difference between income and expenses.
- **Only One Per COA**: The chart of accounts can contain only **one account of the "Current Year's Earnings" type**.
- **Year-End Procedure**: Create a miscellaneous journal entry to allocate current year earnings to an equity account (retained earnings), then set an "All Users Lock Date" to the last day of the fiscal year.
- **No Mandatory Closing Entry**: Odoo does NOT require a specific year-end closing entry. Reports are generated in real-time, so P&L corresponds directly with the year-end date specified.

---

## 2. CHART OF ACCOUNTS (COA)

### Account Types vs. Account Groups

**Account Types** (System-defined categories):
- Hierarchical: Up to 2 levels by default; can be extended to 4 levels with customization.
- Examples: Asset, Liability, Equity, Revenue, Expense, Bank, Receivable, Payable, Current Year's Earnings.
- Controls account behavior in reports and posting logic.

**Account Groups** (User-defined consolidations):
- Consolidate multiple accounts into a larger reportable group.
- Examples: "Total Current Assets," "Total Liabilities," "Cost of Goods Sold."
- Useful for Trial Balance and financial statement presentation.
- Configuration: Accounting ‣ Configuration ‣ Account Groups.
- Required fields: Name, Code (prefix), From/To prefix range, Company.

### Account Hierarchy

Odoo COA is a **flat structure by default** with account codes (e.g., 1100 for Cash, 1200 for Accounts Receivable). Hierarchy is provided via:
- **Parent Account relationships** (via app like `account_parent` in Odoo Apps Store).
- **Account Group assignment** for reporting consolidation.
- **Account Type classification** for statement structure.

Typical hierarchy:
```
1xxx - Assets
  1100 - Cash and Cash Equivalents
  1200 - Accounts Receivable
  1500 - Inventory
  1800 - Fixed Assets
2xxx - Liabilities
  2100 - Accounts Payable
  2200 - Salaries Payable
  2500 - Long-term Debt
3xxx - Equity
  3100 - Common Stock
  3200 - Retained Earnings
4xxx - Revenue
  4100 - Sales Revenue
  4200 - Service Revenue
5xxx - Expenses
  5100 - Cost of Goods Sold
  5200 - Salaries Expense
```

### Multi-Company COA

Each **Company** (in the Odoo Companies menu) can have:
- **Its own Chart of Accounts** (separate GL).
- **Separate accounting journals** per company.
- **Consolidated reporting** across companies via configurable consolidation rules.

When creating a new account, you specify the **Company** in the account form. Reports can be filtered by company or consolidated if needed.

### Default COAs Per Country

Odoo provides **pre-built, localized COAs** via "Fiscal Localization Packages" installed at company creation:
- **Saudi Arabia** (`l10n_sa`): 15% VAT structure, ZATCA e-invoicing support, pre-configured expense/asset accounts.
- **UAE** (`l10n_ae`): 5% VAT structure, pre-configured accounts for UAE businesses.
- **Egypt** (`l10n_eg`): VAT and withholding tax accounts pre-configured.
- **USA** (`l10n_us`): GAAP-compliant COA structure.
- **Europe** (UK, FR, DE, etc.): Localized COAs per country.

**Note:** The Saudi Arabia and UAE COAs include predefined fiscal positions for automatic tax adjustment and account mapping based on customer/supplier VAT status.

---

## 3. JOURNAL ENTRIES & JOURNALS

### Journal Types and Automatic Posting

**Built-in Journal Types:**

1. **Sales Journal** (type: `sale`)
   - Posts customer invoices automatically upon validation.
   - Debits Accounts Receivable (or Bank), Credits Revenue.
   - Can have a separate sequence for credit notes (adds "R" prefix).
   - Can have a separate sequence for debit notes (adds "D" prefix).

2. **Purchase Journal** (type: `purchase`)
   - Posts vendor bills automatically upon validation.
   - Debits Expense/Asset accounts, Credits Accounts Payable (or Bank if paid immediately).
   - Auto-posting can be enabled per vendor: Accounting ‣ Vendors ‣ [Vendor] ‣ Accounting tab ‣ "Auto-post bills" field.

3. **Bank Journal** (type: `bank`)
   - Records bank statement lines and payments.
   - Imported statements create unreconciled entries that match against invoices/payments.
   - Supports statement import formats: CSV, QIF, OFX, CAMT, CODA, XLS, XLSX.
   - Used for bank reconciliation workflow.

4. **Cash Journal** (type: `cash`)
   - Records daily cash transactions and petty cash.
   - Similar to bank journal but for non-bank accounts.

5. **Miscellaneous Journal** (type: `general`)
   - Manual entries: accruals, depreciation, adjustments, year-end closing.
   - Example: Allocating current year's earnings to retained earnings.
   - Accessible from Accounting ‣ Accounting ‣ Journal Entries or Accounting ‣ Miscellaneous ‣ Journal Entries.

### Numbering & Sequences

Each journal has:
- **Unique Code** (1-5 characters): Used as entry prefix. Example: `INV` for sales invoices, `BILL` for purchases.
- **Sequence** (auto-numbering rule):
  - Each journal typically has its own sequence (e.g., `/MONTH/` auto-resets monthly, `/YEAR/` per year).
  - Multiple journals **can share a sequence** if legislation allows.
  - Format: Prefix + Number. Example: `INV/2026/001`, `BILL/2026/001`.
  - When a document (invoice, bill, entry) is validated, Odoo auto-assigns the next number from the sequence.

**Sequence Prefix Note:** The "Sequence Prefix" field is a display hint; the **true numbering is controlled by the assigned Sequence object**, which can include prefixes like `/`, month placeholders, year placeholders, and padding.

### Reversal Entries

- **Reversing Entry** (also called "Reversal"): A journal entry that negates a previous entry by debiting and crediting the opposite accounts in opposite amounts.
- **Use Case**: Correcting an erroneous entry, reversing accruals at period-end.
- **In Odoo**: When viewing a journal entry, click a "Reverse" or "Reversal" button to create a dated reversal entry (typically dated the first day of the next period).
- **Not automatic**: Odoo does not automatically create reversals; the accountant must explicitly create them.

### Lock Dates

**Purpose**: Prevent posting of entries into periods that are already audited or finalized.

**Two Types of Locks:**

1. **Soft Lock** (All Users Lock Date):
   - Applies to all users except account managers with override permission.
   - Prevents creation/modification of entries with an accounting date on or before the lock date.
   - Set at: Accounting ‣ Accounting ‣ Lock Dates.

2. **Hard Lock** (Tax Lock Date, if installed):
   - Applies even to administrators (in some localizations).
   - Set for specific periods when taxes are filed.

**Audit Trail**: When viewing exceptions in lock dates, Odoo shows only changes made during the exception period, logged in the audit trail.

---

## 4. CUSTOMER & VENDOR INVOICING FLOW

### Invoice States and Lifecycle

**Customer Invoice (Sales) Workflow:**

```
Draft → Validate → Posted → In Payment → Paid → Cancelled (or Credit Note issued)
```

**Detailed State Definitions:**

1. **Draft**:
   - Invoice is created but not yet validated.
   - **No accounting impact**: No GL entries are created; invoice is not included in reports.
   - Can be freely edited: Line items, amounts, customer, payment terms, taxes.
   - Status button: "Validate" to confirm.

2. **Validate / Posted**:
   - Accountant clicks "Validate."
   - Odoo **auto-assigns a unique invoice number** from the sales journal's sequence.
   - **GL entries are posted immediately** (or per auto-posting config):
     - Debit: Accounts Receivable (or Bank if immediate payment).
     - Credit: Revenue (or Deferred Revenue if payment terms apply).
     - Credit/Debit: Tax accounts (if sales tax applies).
   - Invoice now appears in financial reports.
   - Status button: "Register Payment" to record customer payment.

3. **In Payment** (Partial or Full):
   - A payment has been registered but not yet fully reconciled against a bank statement.
   - Outstanding Payments account holds the unmatched amount.
   - The invoice awaits bank reconciliation to be marked "Paid."

4. **Paid**:
   - Payment has been reconciled against a bank statement line.
   - Invoice is fully matched and closed.
   - No further action needed (unless credit memo issued later).

5. **Cancelled** (or Credit Note Issued):
   - Invoice marked as void or replaced by a credit note.
   - GL entries may be reversed or replaced by credit note entries.

### Vendor Bill (Purchase) Workflow

**Similar to customer invoices but with opposite DR/CR:**

```
Draft → Confirm → Posted → In Payment → Paid
```

1. **Draft**: Bill created, no GL impact, fully editable.

2. **Confirm**:
   - Bill number auto-assigned from purchase journal sequence.
   - GL entries posted:
     - Debit: Expense account (or Asset, e.g., Inventory) or Fixed Asset.
     - Credit: Accounts Payable (or Bank if immediate payment).
     - Credit/Debit: Tax accounts (if recoverable input VAT).

3. **In Payment**: Payment recorded but not yet matched to bank.

4. **Paid**: Payment reconciled against bank statement.

### Payment Workflow and Matching

**From Invoice to Payment Collection (Customer):**

1. **Register Payment** button on validated invoice opens a payment form.
   - Select payment journal (Bank or Cash).
   - Select payment date and amount.
   - Choose payment method (check, bank transfer, credit card, etc.).

2. **Create Payment**:
   - Odoo creates a payment entry in the selected journal.
   - If journal has an "Outstanding Receipts" account configured:
     - Debit: Outstanding Receipts (temporary holding).
     - Credit: Bank (or reverse if payment direction is inbound).
   - Invoice remains "In Payment" status.

3. **Bank Reconciliation** (matching payment to bank statement):
   - Import or manually create bank statement line.
   - Use "Reconciliation" widget (or legacy Bank Reconciliation screen).
   - Match bank statement line to payment entry.
   - Once matched, payment is cleared from Outstanding Receipts.
   - Invoice marked "Paid."

### Payment Terms and Discounts

- **Payment Terms** (on invoice): Define due date relative to invoice date (e.g., Net 30, 2/10 Net 30).
  - Odoo calculates due date automatically.
  - Visible on invoice report and in accounts receivable aging reports.

- **Early Payment Discount**:
  - Configured on payment terms (e.g., 2% discount if paid within 10 days).
  - Applied manually when customer pays early or via a discount account if configured.

- **Late Payment**: No automatic penalty; invoice remains due; optional dunning letters via Accounting Reports.

### Credit Notes and Partial Refunds

**Credit Note (Debit Note for overpayment reversal):**

- **Legal method** to cancel, refund, or modify a validated invoice.
- Created from: Accounting ‣ Customers ‣ Invoices ‣ [Invoice] ‣ "Credit Note" button.
- **Reverse (Full Credit)**: Opens draft credit note with exact copy of invoice details; click Confirm.
- **Partial Credit**: Reverse, then manually adjust Quantity or Amount fields, then Confirm.
- GL entries for credit note:
  - Debit: Revenue (or Deferred Revenue reversal).
  - Debit: Tax accounts (reversal of input VAT, if applicable).
  - Credit: Accounts Receivable (reduces amount owed).

**Refund Processing**:
- Register payment of the credit note after confirmation (if money is being refunded).
- Return of goods: Register the product return separately (if applicable).

---

## 5. BANK RECONCILIATION

### Bank Statement Import and Processing

**Import Formats Supported:**
- CSV (comma/tab-separated)
- QIF (Quicken Interchange Format)
- OFX (Open Financial Exchange)
- CAMT.053 (ISO 20022 format)
- CODA (Belgian standard)
- XLS / XLSX

**Import Process:**
1. Go to Accounting ‣ Bank ‣ Bank Statements ‣ Create or Upload.
2. Select journal (Bank).
3. Upload file or manually enter statement lines.
4. Odoo parses transactions and creates unreconciled statement lines.
5. Transactions appear in the bank reconciliation widget, ready for matching.

### Reconciliation Widget and Auto-Matching

**Manual Reconciliation (Classic Widget):**

1. **Left Side**: Bank statement lines (sorted by date, amount).
2. **Right Side (Bottom)**: Existing invoices, bills, and payments (filtered by partner if bank line has partner info).
3. **Matching Logic**:
   - Click on a bank statement line.
   - Odoo auto-suggests matching entries (invoices/payments) based on:
     - **If no partner**: Compares bank line description against invoice Number, Customer Reference, Bill Reference, Payment Reference.
     - **If partner identified**: Matches by Amount + Partner + Type (invoice, payment, bill).
   - User confirms match or manually selects an entry.

4. **Reconcile Button**: Mark as matched; removes from outstanding accounts.

**Auto-Suggestions (Reconciliation Models):**

Odoo uses predefined **Reconciliation Models** to automatically match transactions:

### Reconciliation Models

**Two Types:**

1. **Rule to Suggest Counterpart Entry**:
   - Matches a bank transaction to a **new GL entry** created on-the-fly.
   - Use case: Recurring transactions (e.g., monthly subscription, fixed salary transfer).
   - Conditions: Match on amount, description, partner (if present), regex.
   - If matched, Odoo suggests creating a matching GL entry; user clicks "Apply" or "Confirm."

2. **Rule to Match Invoices/Bills**:
   - Matches a bank transaction to an **existing invoice, bill, or payment**.
   - Use case: Customer payment matches open invoice.
   - Conditions: Match on amount, partner, description, or custom regex.
   - If matched, Odoo suggests reconciliation; user confirms.

**Regex Matching:**

- Set **Transaction Type** to "Match Regex."
- Add a regular expression to identify transaction types.
- Odoo automatically retrieves transactions matching the regex and applies the model conditions.

### Reconciliation Algorithm

**Auto-Matching Order:**

1. **Exact Amount Match**: If bank line amount = open invoice/payment amount, suggest match.
2. **Partner Matching**: If bank line partner = invoice partner, increase confidence.
3. **Description Matching**: Compare bank line description against invoice reference fields using substring or regex.
4. **Manual Override**: User can ignore suggestions and manually select the correct match.

**Key Accounts:**

- **Outstanding Receipts Account** (bank journal config): Temporary holding for unreconciled payments; cleared upon reconciliation.
- **Gain/Loss Account**: For currency exchange differences (multi-currency).

---

## 6. TAXES

### Tax Types: Price-Included vs. Price-Excluded

**Price-Excluded Tax:**
- Listed separately in invoice: Subtotal + Tax = Total.
- Customer sees tax amount explicitly.
- Odoo GL: Revenue account records the pre-tax amount; tax account records the tax amount separately.
- Example: $100 + 15% = $115 invoice total.

**Price-Included Tax:**
- Tax is embedded in the listed price; total price includes tax.
- Customer sees one price; tax amount must be calculated (implied).
- Odoo GL: Revenue account records the gross amount; tax account records the tax portion (gross × tax% ÷ (1 + tax%)).
- Example: $115 total (includes 15% VAT); actual VAT = $15.

### Fixed vs. Percentage Tax

- **Percentage Tax**: Amount = Base × Rate%. Example: 15% of invoice total.
- **Fixed Tax**: Amount = Fixed amount per unit or per invoice. Example: $5 per line item.

Odoo supports both; configuration is per tax definition.

### Saudi VAT (15%) and UAE VAT (5%)

**Saudi Arabia (15% VAT):**
- Pre-configured in the `l10n_sa` localization package.
- Standard 15% VAT on most goods/services.
- Zero-rated and Exempt categories available for eligible transactions.
- Supplier charges Output VAT on sales (15% on the sales amount).
- Supplier deducts Input VAT on business purchases.
- Net VAT (Output - Input) is due to the Saudi tax authority monthly/quarterly.

**UAE (5% VAT):**
- Pre-configured in the `l10n_ae` localization package.
- Standard 5% VAT on most goods/services.
- Zero-rated and Exempt categories for eligible goods (food, medicines, etc.).
- Similar input/output VAT mechanism.

### Tax Grids and Reporting

- **Tax Grid**: A matrix showing all tax lines by category (Output VAT, Input VAT, Reverse Charge, etc.) for reporting to authorities.
- **VAT Return**: Odoo can generate a Tax Report (VAT Summary or detailed grid) showing:
  - Total Output VAT (sales).
  - Total Input VAT (purchases).
  - Net VAT payable or refundable.
  - Detailed breakdown by tax type.

**Accessing Reports:**
- Accounting ‣ Reporting ‣ Tax Reports ‣ [Country] VAT Summary.

### Tax Cash Basis vs. Invoice Basis

**Invoice Basis (Accrual):**
- Tax is recorded when the invoice is validated (regardless of payment status).
- GL entries: VAT Payable/Receivable accounts are updated immediately.

**Cash Basis:**
- Tax is recorded only when cash is received/paid.
- GL entries: VAT accounts updated when payment is reconciled.
- Used in countries/situations where tax filing is cash-based.

Odoo supports both; configured per company or per tax definition.

### Withholding Tax

**Definition**: A percentage (e.g., 5-15%) of payment withheld by the payer on behalf of the tax authority (often for contractors, consultants).

**In Odoo:**
- Configured as a separate tax line on invoice or payment.
- GL: Withheld Tax Payable account holds the amount until remitted to authority.
- Vendor receives net amount; withheld amount is reported separately.

---

## 7. FISCAL POSITIONS

### Definition and Automatic Tax & Account Mapping

**Fiscal Position** (also "Fiscal Regime"):
- A rule set that **automatically adapts taxes and GL accounts** based on the customer/supplier characteristics (location, VAT status, etc.).

**Use Cases:**
- **Export Sales (Zero-Rated)**: When invoicing a customer in a different country, apply 0% VAT instead of standard rate, and map revenue account to "Export Sales" instead of "Domestic Sales."
- **Reverse Charge**: When purchasing from a foreign supplier, the customer is responsible for VAT (not the supplier). Fiscal position automatically:
  - Removes the supplier's VAT from the bill.
  - Adds a "Reverse Charge VAT" line.
  - Maps the expense account to a reverse-charge account for tracking.
- **Supplier-Specific Adjustments**: Map a supplier's standard tax to a different tax (e.g., supplier charges 20% but you're entitled to a preferential 10%).

### Configuration

**Fiscal Position Form:**
- Name: Display name.
- Country: Applicable to. (Optional; if blank, applies globally.)
- Tax Mapping:
  - From (Original Tax): Tax on the product/invoice.
  - To (Tax to Apply): Tax to apply instead (or None to remove).
- Account Mapping:
  - From (Original Account): GL account on the product line.
  - To (Account to Use Instead): GL account to use instead.

**Application (Assignment):**
1. **Manual**: Assigned directly on customer/vendor form (Fiscal Position field).
2. **Automatic**: Via Fiscal Position Rules based on partner country, address, VAT status. Odoo applies the fiscal position automatically if rules match.

### Multi-Country Tax Mapping Example

**Scenario**: UK company invoicing a customer in Saudi Arabia.

**Without Fiscal Position**:
- Invoice applies UK VAT (20%).
- Revenue account is "Sales - UK."

**With Fiscal Position** (Export to Saudi Arabia):
- Tax mapping: Remove 20% UK VAT → Apply 0% (export).
- Account mapping: "Sales - UK" → "Sales - Export - Saudi Arabia."
- Result: Invoice shows $100, no VAT, revenue is recorded in export-specific account for tracking.

---

## 8. MULTI-CURRENCY

### Exchange Rate Management

**Exchange Rate Sources:**
- Manual entry (user-defined).
- Automatic update from web services (European Central Bank, Open Exchange Rates, etc.).

**Configuration:**
- Accounting ‣ Configuration ‣ Settings ‣ Currencies.
- Set update interval: Manually, Daily, Weekly, Monthly.
- Select web service (if automatic).

**Rate Updates:**
- Odoo fetches latest rates at scheduled intervals.
- Rates are stored in an historical table; old rates are retained for revaluation calculations.

### Automatic Exchange Difference Recording

**How It Works:**

When a multi-currency payment is received/made months after invoice:
- Invoice is in Currency A (e.g., EUR) issued at rate 1 EUR = 1.10 USD.
- Payment is received in Currency A at rate 1 EUR = 1.15 USD (rate has changed).
- Odoo calculates the exchange difference: (1.15 - 1.10) × invoice amount = FX gain/loss.

**Automatic GL Entry:**
- Created in a dedicated journal (e.g., "Exchange Difference Journal").
- Debit: FX Gain/Loss account (or Unrealized Gain/Loss).
- Credit: Accounts Receivable/Payable (adjustment).

**Configuration:**
- Accounting ‣ Configuration ‣ Settings ‣ Default Accounts.
- Specify:
  - **Exchange Difference Journal**: Journal for FX entries.
  - **Gain Account**: GL account for gains (e.g., "Foreign Exchange Gains").
  - **Loss Account**: GL account for losses (e.g., "Foreign Exchange Losses").

### Unrealized Gain/Loss Report

**Purpose**: Summary of unrealized currency positions on open invoices/payables.

**Access:**
- Reporting ‣ Management: Unrealized Currency Gains/Losses.

**Functionality:**
- Lists open invoices/bills in foreign currencies.
- Shows original amount, current exchange rate, unrealized gain/loss.
- **Adjustment Entry Button**: Generates a journal entry to record unrealized gains/losses.
- User selects Journal, Income Account (for gains), Expense Account (for losses); Odoo calculates and posts the entry.

**Reconciliation:**
- When payment is reconciled, unrealized becomes realized.
- Realized gains/losses appear in P&L for the period when payment matched.

---

## 9. ANALYTIC ACCOUNTING

### Analytic Accounts vs. Cost Centers

**Analytic Account:**
- An **alternative dimension** to the GL chart of accounts.
- Used to track **costs and revenues** by project, department, cost center, or customer.
- Not a GL account (no debits/credits in traditional sense), but each journal entry line can be tagged with an analytic account.

**Cost Center:**
- A type of analytic account, typically representing an organizational unit (Sales Dept, R&D, Manufacturing).
- Collects all costs incurred for that cost center across multiple GL accounts.

**Example**:
- GL account: 5200 - Salaries.
- Analytic account (Cost Center): Engineering Department.
- Journal entry: "Debit 5200 (Salaries) $100, Analytic: Engineering Dept."
- Reports: GL shows total salaries; Analytic shows salaries attributed to Engineering (useful for departmental profit).

### Analytic Plans and Distribution

**Analytic Plan** (Odoo 17):
- A collection of related analytic accounts organized into a plan (e.g., "By Department," "By Project," "By Customer").
- Each plan can have multiple analytic accounts.
- Multiple plans can be active simultaneously (e.g., distribute cost to both Department AND Project).

**Distribution of Costs:**

When creating a journal entry or invoice line with multiple analytic dimensions:
1. Select the primary analytic account (or leave blank).
2. In the **Analytic** section, specify distribution across multiple analytic accounts:
   - Each plan is a column.
   - Assign analytic accounts from each plan.
   - Set **percentage** or amount for distribution.
   - Example: 60% to Project A, 40% to Project B.

**Entry GL:**
- Single GL debit/credit.
- Analytic attribution split per the percentages.
- Reports can aggregate by analytic dimension.

### Analytic Distribution Models (Automatic Assignment)

**Purpose**: Auto-assign analytic accounts based on triggers (account prefix, partner, product, company).

**Trigger Types:**

1. **Accounts Prefix**: If GL account begins with "61" (e.g., cost of goods sold), assign to Cost Center "Manufacturing."
2. **Partner**: All invoices from Partner "Supplier A" → Cost Center "Procurement."
3. **Product**: All sales of Product "Widget X" → Project "Widget Launch 2026."
4. **Company**: All entries in Company "Saudi Operations" → Department "Saudi Sales."

**Distribution Rules:**
- Model can split indirect costs across departments using predefined percentages.
- Example: Monthly telecom expense of $1,000 split 40% Sales, 30% Operations, 30% R&D.

**Configuration:**
- Accounting ‣ Configuration ‣ Analytic Distribution Models.
- Create model, set trigger, define GL distribution rules, activate.

**Activation:**
- Accounting ‣ Configuration ‣ Settings ‣ Analytics section ‣ Enable "Analytic Accounting."
- Select "Analytic Plans" or "Analytic Accounts" mode.

---

## 10. ACCOUNTING REPORTS

### Standard Reports

**General Ledger (GL):**
- Lists all transactions in each GL account for a date range.
- Columns: Account, Date, Reference (journal entry #), Description, Debit, Credit, Balance.
- Drill-down: Click on line to view underlying journal entry.
- Filter: By account, date, department (analytic).

**Trial Balance:**
- Lists all GL accounts with their period-end debit and credit balances.
- Verification: Total Debits = Total Credits (should always balance).
- Drill-down: Click on balance to view GL transactions.

**Partner Ledger (Accounts Receivable / Payable):**
- Lists all transactions per customer or vendor.
- Columns: Partner, Date, Reference, Description, Debit (for receivables) / Credit (for payables), Balance.
- Shows open and paid invoices/bills.
- Useful for customer statements, vendor verification.

**Aged Receivables / Payables:**
- Breakdown of open invoices by age: Current (0-30 days), 30-60, 60-90, 90+ days.
- Columns: Partner, Total Outstanding, Current, 30-60, 60-90, 90+.
- Used for credit risk assessment (receivables) and cash flow planning (payables).

**Profit and Loss (Income Statement):**
- Shows Revenue - Expenses = Net Income for a period.
- Columns: Account, Current Period, Prior Period (for comparison), YTD.
- Grouped: Revenue section, Cost of Goods Sold, Gross Profit, Operating Expenses, Operating Income, Other Income/Expense, Net Income.
- Multi-period comparison highlights growth/decline.

**Balance Sheet:**
- Snapshot of Assets, Liabilities, Equity at a point in time.
- Structure:
  - **Assets**: Current (cash, receivables, inventory) + Non-current (fixed assets).
  - **Liabilities**: Current (payables, short-term debt) + Non-current (long-term debt).
  - **Equity**: Contributed capital + Retained Earnings + Current Year's Earnings.
- Verification: Assets = Liabilities + Equity (should always balance).

**Cash Flow Statement (Optional):**
- Shows cash movements by activity: Operating, Investing, Financing.
- Reconciles net income to actual cash change.
- Not automatically generated in all localizations; may require additional configuration.

### Report Customization (Odoo Enterprise)

- **PDF/Excel Export**: All reports available in PDF and XLS formats.
- **Drill-Down**: Click on amounts to view underlying transactions (GL entries, invoices, payments).
- **Filters**: By date, period, account, partner, department, company.
- **Template Design**: Reports can be customized via report designer (Enterprise only) or via custom Python templates.

---

## 11. LOCKING AND AUDIT

### Lock Dates: Soft Lock and Hard Lock

**Soft Lock (All Users Lock Date):**
- Applied to all users except account managers with override permission.
- Location: Accounting ‣ Accounting ‣ Lock Dates ‣ All Users Lock Date.
- Effect: Prevents creation/modification of entries with Accounting Date on or before the lock date.
- Override: User with "Account Manager" role can still edit locked entries if the lock is not hard-locked.
- Use: Month-end close, period-end verification.

**Hard Lock (Tax Lock Date, if available):**
- Cannot be overridden by anyone (even admins in some localizations).
- Location: Accounting ‣ Accounting ‣ Lock Dates ‣ Tax Lock Date (if enabled).
- Effect: Permanently prevents modification of entries in that period.
- Use: After tax filing, regulatory compliance.

### Audit Trail

**Purpose**: Log all changes to financial data for compliance and dispute resolution.

**What's Tracked:**
- Creation, modification, deletion of invoices, bills, journal entries.
- Changes to amounts, accounts, partners, tax, dates.
- Who made the change, when, from which IP address.

**Accessing Audit Trail:**
- Click "Audit" button on an entry or document.
- Shows: Timestamp, User, Action (create, write, unlink), Field Changed, Old Value, New Value.
- **Exception Periods**: When viewing audit for lock date exceptions, Odoo shows only changes made during the exception period (user-approved override).

### Data Inalterability (SHA-256 Hashing)

**Purpose** (Required in France, Belgium, Italy, others):
- Prove that posted accounting entries cannot be altered retroactively.
- Implement an immutable ledger using cryptographic hashing.

**How It Works:**
- **SHA-256 Hash**: Odoo creates a unique fingerprint of each posted GL entry by:
  1. Taking the entry's essential data: Date, Account, Amount, Description, Reference.
  2. Combining with the **previous entry's hash** (chain).
  3. Running through SHA-256 function → produces unique 64-character hash.
- **Deterministic**: Same input always produces same output; any modification changes the hash completely.
- **Chain Integrity**: Each entry's hash depends on the previous entry, so altering an old entry invalidates all subsequent hashes.

**Compliance Report:**
- Download: Accounting ‣ Configuration ‣ Settings ‣ Reporting ‣ "Download the Data Inalterability Check Report."
- Report shows: All GL entries with their hash values.
- Verification: Recompute hashes to confirm no entries were altered (third-party auditors often do this).

**Override Exception**:
- If an override to a locked date is needed (rare), a special exception entry is logged with a new hash chain starting from the override point.

---

## 12. YEAR-END CLOSE PROCEDURE

### Step-by-Step Close Process

**Phase 1: Pre-Close Verification** (Before generating closing entries)

1. **Bank Reconciliation**: Reconcile all bank accounts up to year-end; confirm book balance = bank statement balance.
2. **Accounts Receivable**: Ensure all customer invoices have been entered and approved; collect outstanding customer confirmations.
3. **Accounts Payable**: Ensure all vendor bills have been entered and agreed; verify outstanding bills match vendor statements.
4. **Inventory Verification**: If applicable, perform physical count and reconcile to GL.
5. **Journal Entry Review**: Scan for large, unusual, or incomplete entries that need correction before close.

**Phase 2: Period Adjustments** (Manual entries)

1. **Accruals**:
   - Accrue unpaid salaries, bonuses, commissions for the period.
   - Accrue utility bills, rent, subscriptions.
   - Accrue revenue (if service delivered but invoice not sent).
   - Journal entry: Debit Expense, Credit Payable/Revenue Liability.

2. **Depreciation**:
   - Record monthly/annual depreciation of fixed assets.
   - Journal entry: Debit Depreciation Expense, Credit Accumulated Depreciation.

3. **Bad Debt Reserve**:
   - Estimate uncollectible receivables and adjust allowance.
   - Journal entry: Debit Bad Debt Expense, Credit Allowance for Doubtful Accounts.

4. **Prepaid Adjustments**:
   - Amortize prepaid insurance, subscriptions, rent for the period.
   - Journal entry: Debit Expense, Credit Prepaid Asset.

5. **Currency Revaluation** (Multi-currency):
   - Run Unrealized Currency Gains/Losses report.
   - Generate adjustment entry for unrealized gains/losses.

6. **Intercompany Transactions** (Multi-company):
   - Verify intercompany invoices and payments are matched.
   - Eliminate intercompany revenue/expense if consolidated reporting.

**Phase 3: Generate Reports**

1. **Trial Balance**: Verify total debits = total credits.
2. **Profit & Loss**: Review for reasonableness (compare to prior year, budget).
3. **Balance Sheet**: Verify assets = liabilities + equity.
4. **Cash Flow Statement**: Reconcile net income to actual cash change.

**Phase 4: Allocate Current Year's Earnings**

In Odoo, the **Current Year's Earnings account** (e.g., "Undistributed Profits/Losses," account 999999) automatically accumulates the net income/loss for the period.

- **Example**: If P&L shows Net Income = $100,000, the Current Year's Earnings account will show a credit balance of $100,000.
- **To Close**: Create a miscellaneous journal entry to move current year's earnings to a permanent equity account (e.g., "Retained Earnings"):
  - Debit: Current Year's Earnings ($100,000).
  - Credit: Retained Earnings ($100,000).
- **Verification**: After this entry, Current Year's Earnings balance should be zero (or close to zero if trailing small items remain).

**Phase 5: Set Lock Dates**

1. Go to Accounting ‣ Accounting ‣ Lock Dates.
2. Set **All Users Lock Date** to the last day of the fiscal year.
   - Example: For fiscal year ending December 31, 2025, set lock date to 2025-12-31.
3. Optional: Set **Tax Lock Date** if supported by localization.
4. Effect: All users (except account managers) cannot create/modify entries dated on or before the lock date.

**Phase 6: Finalize and Retain Records**

1. **Archive invoices/bills** (optional, for performance): Move old documents to archive.
2. **Back up GL data**: Export GL entries or bank reconciliation data for external audit.
3. **Sign off**: Finance manager confirms close is complete; document approval.

### Key Odoo Mechanics

- **No Mandatory Closing Entry**: Unlike traditional accounting, Odoo does NOT require separate closing entries for P&L accounts. The "Current Year's Earnings" account serves as a placeholder; actual P&L is generated real-time by the reporting engine based on the date range queried.
- **Real-Time Reports**: P&L reports correspond directly to the date range you specify; no need to "close out" accounts manually.
- **Fiscal Year Configuration**: Odoo recognizes "Fiscal Years" (defined by date range). You can have multiple fiscal years open and switch between them; reports automatically filter by the year in question.

---

## 13. E-INVOICING MODULES & LEGAL COMPLIANCE

### Saudi Arabia ZATCA (Phase 2 Integration)

**Overview**:
- ZATCA (Zakat, Tax and Customs Authority) e-invoice system for Saudi businesses.
- Phases: Phase 1 (initial filing), Phase 2 (integration/real-time submission).

**Odoo Support**:
- Module: `l10n_sa_e_invoice` (available in Odoo 17).
- Functionality:
  - Automatic invoice submission to ZATCA Fatoora portal.
  - Serial number configuration per sales journal (ZATCA tab).
  - Submission to simulation portal for testing.
  - Transition from simulation to production (one-way, irreversible).
  - Compliance: Automatic VAT 15% on invoices (or override per fiscal position).

**Configuration**:
- Accounting ‣ Journals ‣ [Sales Journal] ‣ ZATCA tab.
- Enter Serial Number (issued by ZATCA).
- Select Simulation or Production mode.
- Confirm invoice → Odoo auto-submits to Fatoora portal, displays response.

### Other Countries

**Italy (SDI - Sistema di Interscambio):**
- Not explicitly documented in Odoo 17 search results; likely available via enterprise module or partner.
- Purpose: Mandatory e-invoice exchange system for Italian businesses.

**France (Chorus Portail):**
- Not explicitly documented in Odoo 17 search results.
- Purpose: Public sector e-invoicing in France.

**USA, UK, Others:**
- Odoo does not provide direct e-invoicing integration in most cases; businesses typically export invoices in compliance format and submit via third-party portals.
- Format support: PDF, XML, standard invoices with compliance fields.

---

## 14. MULTI-COMPANY ACCOUNTING

### Separate Chart of Accounts Per Company

Each Odoo **Company** (defined in Odoo ‣ Settings ‣ Companies) has:
- **Separate GL** (chart of accounts is company-specific).
- **Separate journals** (sales, purchase, bank journals are per-company).
- **Separate bank accounts and payment methods**.
- **Separate fiscal localization** (e.g., one company in Saudi Arabia with SAR currency, another in UAE with AED).

**Cross-Company Restriction**:
- Invoices, bills, and GL entries belong to a single company.
- You **cannot** directly invoice from Company A to Company B (use intercompany transfers or separate processes).

### Consolidated Reporting (Multi-Company Rollup)

Odoo supports consolidated reports that aggregate GL balances across multiple companies:
- **Configuration**: Reporting ‣ Settings ‣ Consolidation (requires Enterprise).
- **Consolidation Rules**: Define which companies to include, account mapping between companies, currency conversion, elimination rules.
- **Consolidated P&L / Balance Sheet**: Generated from multiple GL instances, with intercompany transactions eliminated.

---

## APPENDIX: Odoo 17 Accounting Screen / Menu Structure

**Primary Navigation:**

- **Accounting Dashboard** (primary entry point):
  - Quick stats: Revenue, Expenses, Open Invoices, Receivable/Payable.
  - Jump to: Invoices, Bills, Reconciliation, Reports.

- **Accounting Module** (Accounting app):
  - **Accounting** (main submenu):
    - Invoices (Customers ‣ Invoices).
    - Bills (Vendors ‣ Bills).
    - Journal Entries (Accounting ‣ Journal Entries).
    - Lock Dates (Accounting ‣ Lock Dates).

  - **Customers**:
    - Invoices (list, create).
    - Credit Notes (reverse invoices).
    - Customers (master data).

  - **Vendors**:
    - Bills (list, create).
    - Debit Notes.
    - Vendors (master data).

  - **Bank**:
    - Statements (import/upload).
    - Reconciliation (matching widget).
    - Bank Accounts (master data).

  - **Configuration**:
    - Chart of Accounts (Accounting ‣ Configuration ‣ Chart of Accounts).
    - Journals (Accounting ‣ Configuration ‣ Journals).
    - Account Groups (Accounting ‣ Configuration ‣ Account Groups).
    - Fiscal Positions (Accounting ‣ Configuration ‣ Fiscal Positions).
    - Tax (Accounting ‣ Configuration ‣ Taxes).
    - Settings (Accounting ‣ Configuration ‣ Settings) — Currencies, Default Accounts, Analytic, Email templates.

  - **Reporting**:
    - Trial Balance.
    - General Ledger.
    - Partner Ledger (Customers / Vendors).
    - Aged Receivable / Payable.
    - Profit and Loss.
    - Balance Sheet.
    - Cash Flow.
    - Tax Reports (VAT Summary, etc.).
    - Unrealized Currency Gains/Losses.
    - Data Inalterability Check Report.

---

## Key Sources

1. [Odoo 17 Accounting Cheat Sheet](https://www.odoo.com/documentation/17.0/applications/finance/accounting/get_started/cheat_sheet.html)
2. [Odoo 17 Chart of Accounts](https://www.odoo.com/documentation/17.0/applications/finance/accounting/get_started/chart_of_accounts.html)
3. [Odoo 17 Customer Invoices](https://www.odoo.com/documentation/17.0/applications/finance/accounting/customer_invoices.html)
4. [Odoo 17 Vendor Bills](https://www.odoo.com/documentation/17.0/applications/finance/accounting/vendor_bills.html)
5. [Odoo 17 Bank Reconciliation](https://www.odoo.com/documentation/17.0/applications/finance/accounting/bank/reconciliation.html)
6. [Odoo 17 Reconciliation Models](https://www.odoo.com/documentation/17.0/applications/finance/accounting/bank/reconciliation_models.html)
7. [Odoo 17 Fiscal Positions](https://www.odoo.com/documentation/17.0/applications/finance/accounting/taxes/fiscal_positions.html)
8. [Odoo 17 Multi-Currency System](https://www.odoo.com/documentation/17.0/applications/finance/accounting/get_started/multi_currency.html)
9. [Odoo 17 Analytic Accounting](https://www.odoo.com/documentation/17.0/applications/finance/accounting/reporting/analytic_accounting.html)
10. [Odoo 17 Year-End Closing](https://www.odoo.com/documentation/17.0/applications/finance/accounting/reporting/year_end.html)
11. [Odoo 17 Data Inalterability](https://www.odoo.com/documentation/17.0/applications/finance/accounting/reporting/data_inalterability.html)
12. [Odoo 17 Saudi Arabia Localization](https://www.odoo.com/documentation/17.0/applications/finance/fiscal_localizations/saudi_arabia.html)
13. [Odoo 17 Credit Notes and Refunds](https://www.odoo.com/documentation/17.0/applications/finance/accounting/customer_invoices/credit_notes.html)

---

**Document End**  
**Word Count:** ~6,850 words  
**Generated:** April 30, 2026  
**Intended Use:** APEX Financial Platform architecture reference; matching/exceeding Odoo 17 functionality for Arabic SaaS.

