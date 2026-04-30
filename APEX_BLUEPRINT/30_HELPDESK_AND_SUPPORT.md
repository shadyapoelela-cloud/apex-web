# APEX Helpdesk & Customer Support Module
## Comprehensive Blueprint for Multi-Tenant SaaS

**Version:** 1.0  
**Date:** 2026-04-30  
**Status:** Research & Design Phase  
**Target Release:** Phase 9 (Weeks 1-12)

---

## Executive Summary

APEX's helpdesk module addresses a critical gap in the financial SaaS landscape: a native, Arabic-first, ERP-aware support platform that serves **two distinct audiences simultaneously**:

1. **Internal (Aurora Staff):** Managing tenant support tickets (Tier 1)
2. **Tenant-Facing (White-Label):** Tenants supporting their own end customers (Tier 2)

This dual-sided approach differentiates APEX from generic helpdesk platforms (Zendesk, Freshdesk) while remaining lightweight enough for rapid iteration. The module leverages Anthropic Claude API for AI-powered categorization, reply suggestions, and sentiment analysis—all with native Arabic RTL support and ERP awareness (linking tickets to invoices, journal entries, customers, and audit engagements).

---

## Part 1: Why APEX Needs a Helpdesk Module

### 1.1 Market Context

APEX serves Arabian Peninsula financial teams (Saudi Arabia, UAE, Egypt). Current solutions fall into two categories:

- **Enterprise platforms** (Zendesk, Salesforce Service Cloud): Feature-rich but expensive, culturally generic, and lack ERP integration
- **Lightweight tools** (Plain, Linear-style): Fast and modern but lack the contextual awareness needed for financial workflows

**APEX's opportunity:** A purpose-built, Arabic-native helpdesk that understands financial concepts (invoice disputes, journal entry corrections, GL reconciliations, audit adjustments) while remaining simple and fast.

### 1.2 Internal Use Case: Aurora Support Team

**Scenario:** A tenant's account manager calls Aurora support with a question about a bank reconciliation discrepancy.

**Current workflow:** Manual email or Slack → untracked → likely gets lost or duplicated.

**With APEX helpdesk:**
1. Ticket auto-created from email or Slack
2. Automatically tagged as "GL/Reconciliation" and assigned to the reconciliation specialist
3. Agent can view the tenant's GL, recent reconciliation attempts, and related tickets in context
4. Claude AI suggests similar past issues and relevant KB articles
5. Once resolved, ticket feeds a reporting dashboard showing "Top 10 Questions This Week"

**Benefits:**
- Transparency and audit trail
- Faster resolution (context reduces back-and-forth)
- Pattern detection (e.g., "Every Monday we get reconciliation questions → need better training")
- Data for continuous improvement

### 1.3 Tenant-Facing Use Case: White-Label Portal

**Scenario:** A tenant's CFO needs to support their accounting team and external auditors.

**Current solution:** Tenant hires Zendesk or HubSpot ($50–$200/month per seat), integrates with own systems, trains staff.

**With APEX helpdesk:**
1. Tenant's admin logs into APEX, enables "Help Center" module
2. Helpdesk automatically white-labeled with tenant branding
3. Tenant's accounting staff can create/assign tickets via web UI
4. Tenants' customers (auditors, outsourced accountants) can submit tickets via public form or email
5. AI-powered suggestions help junior staff resolve common issues (e.g., "Document not uploading? Try these steps...")
6. Tenant gets analytics: "Auditors ask about these 5 topics → create KB articles → reduce incoming tickets"

**Benefits:**
- Tenant retention (can't easily move to another platform without disrupting support)
- APEX earns recurring helpdesk SaaS fees (optional add-on)
- Reduces tenant support burden → higher product happiness
- Data pool (anonymized tenant issues → APEX's own KB improvements)

---

## Part 2: Two-Sided Helpdesk Concept

### 2.1 Tier 1: Tenant → APEX Support

```
┌─────────────────────────────────────────────────────────┐
│  TENANT (customer of APEX)                              │
│  - Account Manager / Finance Team                       │
│  - Can submit tickets via: email, Slack, web form       │
└────────────────┬────────────────────────────────────────┘
                 │
                 │ Ticket Creation (Auto-routing)
                 ▼
┌─────────────────────────────────────────────────────────┐
│  APEX HELPDESK (Internal)                               │
│  - Aurora Staff (support agents, specialists)           │
│  - Multi-queue model: Onboarding, GL, Integrations,     │
│    Audit, Billing, Data Quality, etc.                   │
│  - SLA: 1h (critical), 4h (high), 24h (normal)         │
└────────────────┬────────────────────────────────────────┘
                 │
                 │ Ticket Resolution
                 ▼
┌─────────────────────────────────────────────────────────┐
│  TENANT NOTIFIED (email, Slack, in-app)                │
│  - Status updates, resolution, KB articles              │
└─────────────────────────────────────────────────────────┘
```

**Key entities:**
- **Ticket:** unique ID, tenant-id, customer-id, priority, SLA policy
- **Conversation:** messages within ticket, supports mentions and internal notes
- **Team:** Aurora support team members (agents, supervisors, specialists)
- **Queue:** Onboarding, GL/Reconciliation, Integrations, Audit, Billing
- **Channel:** Email, Slack, web form

---

### 2.2 Tier 2: Tenant's Customer → Tenant's Support Portal

```
┌─────────────────────────────────────────────────────────┐
│  TENANT'S CUSTOMER (e.g., auditor, outsourced AP/AR)   │
│  - Can submit tickets via: email, public form,          │
│    in-app chat widget (white-labeled)                   │
└────────────────┬────────────────────────────────────────┘
                 │
                 │ Ticket Creation
                 ▼
┌─────────────────────────────────────────────────────────┐
│  TENANT'S HELPDESK (within APEX)                       │
│  - Tenant's staff (accounting, operations)              │
│  - Tenant controls: queues, SLAs, KB, branding          │
│  - SLA: configurable per tenant                         │
└────────────────┬────────────────────────────────────────┘
                 │
                 │ Ticket Resolution
                 ▼
┌─────────────────────────────────────────────────────────┐
│  TENANT'S CUSTOMER NOTIFIED (email, portal)             │
│  - Status updates, KB articles, file uploads            │
└─────────────────────────────────────────────────────────┘
```

**Key difference:**
- **Isolation:** Each tenant's helpdesk data is entirely isolated (multi-tenant database design)
- **Branding:** Logo, colors, email templates, help center URL (`help.tenant.com` via DNS CNAME)
- **Customization:** Tenant configures status workflow, SLA policies, auto-reply templates
- **Permissions:** Tenant admin vs. agent vs. customer roles

---

## Part 3: Core Entities & Data Model

### 3.1 Entity Diagram

```
Ticket
├── id (PK)
├── tenant_id (FK) ← Multi-tenancy
├── channel (enum: email, slack, chat, form, api, whatsapp)
├── status (enum: new, open, pending_customer, pending_internal, resolved, closed, reopen)
├── priority (enum: critical, high, normal, low)
├── title
├── description
├── customer_id (FK to Customer)
├── assigned_to_agent_id (FK to Agent)
├── team_id (FK to Team)
├── sla_policy_id (FK to SLAPolicy)
├── category (string: GL, Integrations, Audit, etc.)
├── tags (array)
├── external_ref (optional: invoice_id, customer_id, audit_engagement_id)
├── created_at
├── updated_at
├── first_response_at
├── resolved_at
├── sla_breach (boolean)
├── sentiment_score (float: -1.0 to 1.0)
└── pinned (boolean)

Conversation
├── id (PK)
├── ticket_id (FK)
├── author_id (FK to User: agent or customer)
├── author_role (enum: agent, customer, system)
├── message_text
├── attachments (array: [file_id, file_name, file_size])
├── is_internal_note (boolean) ← Visible only to agents
├── mentions (array: [user_id]) ← @mentions for collaboration
├── ai_generated (boolean) ← Was this suggested by Claude?
├── created_at
└── updated_at

Customer (multi-purpose)
├── id (PK)
├── tenant_id (FK)
├── email
├── name
├── phone (optional)
├── company_name (optional)
├── customer_type (enum: internal_account_manager, external_customer, auditor, contractor)
├── metadata (JSON: custom fields per tenant)
├── last_ticket_at
└── created_at

Agent
├── id (PK)
├── user_id (FK to User)
├── tenant_id (FK)
├── team_id (FK to Team)
├── role (enum: agent, supervisor, specialist, admin)
├── specialization (array: ['GL', 'Integrations', 'Audit'] )
├── max_concurrent_tickets (int: 5, 10, 15)
├── is_available (boolean)
├── working_hours_tz (string: 'Asia/Riyadh')
└── created_at

Team
├── id (PK)
├── tenant_id (FK)
├── name (string: "Aurora Onboarding" or tenant's team)
├── description
├── members (array: [agent_id])
├── queue_name (enum for APEX internal: onboarding, gl, integrations, audit, billing, quality)
├── sla_policy_id (FK to SLAPolicy)
├── parent_team_id (optional, for hierarchies)
└── created_at

SLAPolicy
├── id (PK)
├── tenant_id (FK)
├── name (string: "Premium SLA" or "Standard")
├── priority_level (enum)
├── first_response_minutes (int: 60, 240, 1440)
├── resolution_minutes (int: 1440, 4320, 10080)
├── business_hours_only (boolean)
├── timezone (string: 'Asia/Riyadh' or 'Asia/Dubai')
├── escalation_rule_id (FK to EscalationRule, optional)
└── created_at

Channel
├── id (PK)
├── tenant_id (FK)
├── type (enum: email, slack, chat_widget, form, api, whatsapp)
├── display_name (string: "Support Email" or "Slack #support")
├── config (JSON: email_address, slack_channel_id, webhook_url, etc.)
├── enabled (boolean)
└── created_at

KnowledgeBaseArticle
├── id (PK)
├── tenant_id (FK)
├── title_ar (string)
├── title_en (string)
├── content_ar (rich text)
├── content_en (rich text)
├── category (string: "GL", "Audit", "Data Quality")
├── tags (array)
├── version (int)
├── visibility (enum: public, internal, draft)
├── created_by_agent_id (FK)
├── helpful_count (int) ← "Did this help?" feedback
├── search_rank (float)
├── created_at
├── updated_at
└── last_reviewed_at

Macro (canned response)
├── id (PK)
├── tenant_id (FK)
├── team_id (FK, optional)
├── title (string: "Invoice Matching Steps")
├── content_template (string with {{variables}})
├── tags (array)
├── usage_count (int)
└── created_at

Tag / Category
├── id (PK)
├── tenant_id (FK)
├── name (string)
├── color (hex)
├── usage_count (int)
└── created_at
```

---

## Part 4: Ticket State Machine & Workflows

### 4.1 Status Lifecycle

**Standard flow:**

```
NEW (auto-assigned on creation)
  ↓
OPEN (when agent picks up or auto-assigns)
  ↓
[PENDING_CUSTOMER (agent waiting for more info) ← SLA paused]
  ↓
[PENDING_INTERNAL (internal review, waiting for colleague) ← SLA paused]
  ↓
RESOLVED (issue fixed, awaiting customer confirmation)
  ↓
CLOSED (resolved + confirmed OR auto-close after 3 days)
```

**Additional transitions:**
- **REOPEN:** Customer replies to closed ticket → auto-reopen
- **ESCALATE:** Low → High priority if SLA in jeopardy
- **ESCALATE:** Specialist escalates to supervisor if unable to resolve

### 4.2 Conditional Logic

| Condition | Action |
|-----------|--------|
| First message in 4 hours | SLA: first response NOT met → escalate to supervisor |
| No customer reply for 5 days | Auto-resolve with "unresponsive" tag |
| Agent assigns ticket to self | Status → OPEN |
| Customer replies to CLOSED | Auto-reopen, reset PENDING flag |
| Ticket moved to RESOLVED | Send auto-response: "We're here if you need more" + KB suggestions |
| Sentiment score < -0.7 ("angry") | Flag for supervisor review + auto-escalate priority |

### 4.3 Reopen Logic

**Customer replies to closed ticket:**
- Check timestamp: if > 30 days, create new ticket instead
- If < 30 days: reopen, notify assigned agent via Slack/email

**Agent reopens manually:**
- Reason required (dropdown: "Customer not satisfied", "Incomplete fix", "New issue found")
- Reset SLA on reopened ticket

---

## Part 5: SLA Management

### 5.1 SLA Definition & Policies

**Sample SLA Matrix (APEX Tier 1):**

| Priority | First Response | Resolution | Breach Escalation |
|----------|---|---|---|
| Critical | 1h | 4h | VP Engineering |
| High | 4h | 24h | Tech Lead |
| Normal | 8h | 48h | Team Lead |
| Low | 24h | 5 days | None |

**Business hours:** 8 AM – 8 PM Saudi Arabia time (Asia/Riyadh), 5 days/week (Mon–Fri)

**Timezone handling:** Customers in UAE (Asia/Dubai) treated as +1 hour; display SLA times in their local TZ.

### 5.2 SLA Pause Rules

SLA is **paused** (time doesn't count toward breach) when:
- Status = PENDING_CUSTOMER (waiting for customer input)
- Status = PENDING_INTERNAL (waiting for specialist)
- Ticket is not assigned to any agent
- Business hours ended (if SLA is business-hours-only)

SLA **resumes** when:
- Status changes back to OPEN
- Ticket is assigned
- Business hours resume

### 5.3 SLA Breach Detection & Alerts

**Real-time monitoring:**
- Every 5 minutes: check all open tickets against SLA deadline
- **Imminent breach** (< 30 min remaining): notify assigned agent + team lead via Slack/email
- **Breached**: flag ticket as `sla_breach = true`, mark red in UI, auto-escalate

**Escalation on breach:**
```
If first_response SLA breached:
  → assign to supervisor
  → send email to VP Engineering with ticket link
  → log escalation event

If resolution SLA breached:
  → flag ticket red in all queues
  → notify team lead + VP
  → require weekly recovery plan in ticket notes
```

### 5.4 Pause SLA on Customer Wait

**Example workflow:**

```
Agent: "We need your GL export to debug this."
  ↓ System: Auto-set status to PENDING_CUSTOMER
  ↓ SLA paused (no longer counting toward breach)
  ↓ Ticket moved to "Awaiting Customer" queue

Customer replies 2 days later with GL export:
  ↓ Agent notified
  ↓ Status auto-set to OPEN
  ↓ SLA resumes countdown
```

---

## Part 6: AI Agents for Support

### 6.1 Claude-Powered Capabilities

APEX will leverage Anthropic Claude API for:

#### 6.1.1 Auto-Categorization

**Trigger:** On ticket creation (email, form, chat, API)

**Process:**
```
Message: "I uploaded a bank reconciliation file but it keeps saying format error..."

Claude analysis:
  Category: "Data Quality / Import Error"
  Priority: "Normal" (not blocking invoice posting)
  Team: "Data Quality Specialists"
  Suggested KB: "KB-847: Reconciliation File Format Requirements"
  
System action: Auto-assign to Data Quality queue, notify team
```

**Accuracy target:** > 90% for known categories, human override easy.

#### 6.1.2 Auto-Response to FAQ

**Trigger:** After categorization, if high-confidence match to KB article

**Process:**
```
Incoming message: "How do I connect my bank feeds in APEX?"

Claude search:
  → Found KB-234: "Bank Feed Integration Guide (Arabic + English)"
  → Confidence: 98%
  → Customer language detected: Arabic
  
System action:
  → Compose auto-response in Arabic with KB link
  → Agent sees: "Claude suggests auto-respond with KB-234 [APPROVE / EDIT / SEND]"
  → Agent can add personal touch ("Hi Fatima, here's the guide...")
  → Auto-response queued; if no agent edit in 30 min, send automatically
```

**Opt-out:** Tenant/agent can disable auto-response for specific categories or customers.

#### 6.1.3 Agent Reply Suggestions

**Trigger:** Agent opens a ticket, reads message, clicks "AI suggest reply"

**Process:**
```
Customer message: "We reconciled last month against your bank balance file, 
but today it's different. We're missing 5 transactions."

Claude analysis:
  → Detects: GL reconciliation issue
  → Suggests reply structure:
    1. Ask for reconciliation date and currency
    2. Suggest checking: timestamp of export, transaction filtering rules
    3. Link to KB-567: "Why Transaction Counts Change"
    4. Offer: "Let me schedule a 15-min screen share to debug together"

Agent sees:
  [DRAFT SUGGESTION]
  Hi, thanks for reporting this. A few questions:
  1) Which month's reconciliation are we looking at?
  2) What currency? (might affect filtering if multi-currency enabled)
  
  This often happens if you exported before all transactions posted.
  See our guide: [KB link]
  
  Want to hop on a quick call? I can screen-share and debug.
  
  [EDIT / USE / DISMISS]
```

**Benefit:** New agents onboard faster; junior staff get mentoring-in-a-box.

#### 6.1.4 Thread Summarization

**Trigger:** Manual (agent clicks "Summarize") or auto-on 5+ messages

**Process:**
```
Ticket has 12 messages over 3 days, with tangents and back-and-forth.

Claude generates:

[AI SUMMARY]
Customer Issue: Bank reconciliation shows $5K variance since May 1st update.
Root Cause (found): Duplicate transaction import due to timezone mismatch 
                    in bank feed API (API returns UTC, system expects local).
Resolution: Filtered duplicate via reconciliation rules; advised customer 
            to upgrade to UTC-aware integration.
Status: Customer testing fix, will confirm tomorrow.
Next Step: Await customer confirmation; if OK, close.
```

**Usage:** Easier handoff between agents, faster context for supervisors reviewing SLA breaches.

#### 6.1.5 Sentiment Analysis

**Trigger:** On each customer message

**Process:**
```
Message: "This is really frustrating! We've asked 3 times for this fix and 
nothing's happening. We're going to have to switch platforms if this doesn't 
get resolved this week."

Claude sentiment analysis:
  Sentiment Score: -0.85 (very negative)
  Emotion: Frustration, urgency, churn risk
  Key phrases: "frustrating", "3 times", "switch platforms"
  
System action:
  → Flag ticket with ⚠️ "ANGRY CUSTOMER"
  → Auto-increase priority: Low → Normal
  → Notify supervisor: "Churn-risk customer flagged"
  → Suggest macro: "Apology + 1:1 next steps"
```

**Benefit:** Prevent customer churn by catching angry escalations early.

#### 6.1.6 Translation (Arabic ↔ English)

**Trigger:** Auto-detect message language

**Process:**
```
Customer message in Arabic:
  "الرجاء المساعدة، لدينا مشكلة في مطابقة البنك..."

System action:
  1. Detect: Arabic
  2. Translate to English for internal agents
  3. Auto-tag customer: "Primary Language: Arabic"
  4. When agent replies: Translate English → Arabic
  5. Customer sees: Native Arabic response

Agent view shows both:
  [CUSTOMER MESSAGE - ARABIC]
  الرجاء المساعدة، لدينا مشكلة في مطابقة البنك...
  
  [TRANSLATION]
  Please help, we have a problem with bank matching...
```

**Benefit:** Breaking language barriers; APEX becomes truly bilingual.

#### 6.1.7 Auto-Escalate on Angry Customer

**Trigger:** Sentiment score < -0.7 + priority = low/normal

**Process:**
```
Message: "This is unacceptable. You're wasting our time."

System action:
  1. Sentiment: -0.80 (very angry)
  2. Priority escalated: Normal → Critical
  3. Auto-reassign to supervisor
  4. Slack notified: "@supervisor Angry customer escalation: Ticket #XYZ"
  5. Follow-up email to customer: "Escalating to our team lead for immediate attention"
```

---

### 6.2 Tool Use Pattern (Per Anthropic Docs)

Claude can be given tools to:
- **Lookup customer data:** Retrieve invoice, GL account, reconciliation status
- **Suggest JE adjustment:** "This mismatch is $5K. Suggest JE: Dr. Cash 5000, Cr. Bank Fee 5000"
- **Link ticket to records:** Attach to invoice ID, customer master, audit engagement
- **Search KB:** Find relevant articles and rank by relevance
- **Check system status:** Is ZATCA integration up? Are bank feeds delayed?

**Example:**
```
Claude to Agent Tool Use:

Customer: "Why is invoice XYZ stuck in draft?"

Claude calls tools:
  tool_lookup_invoice(invoice_id="XYZ")
    → Returns: {status: "draft", created_at: "2026-03-15", total: 50000, customer: "ABC Corp"}
  
  tool_search_kb("invoice draft status")
    → Returns: [KB-102: "Why Invoices Stay in Draft", confidence: 0.95]
  
  Claude response:
    "Invoice XYZ has been in draft since March 15 and is for 50,000 SAR to ABC Corp.
     This typically means it's awaiting customer approval or ZATCA registration.
     See our guide: [KB-102]. Want me to check if ABC Corp's approval is pending?"
```

---

## Part 7: Multi-Channel Inbox

### 7.1 Supported Channels

| Channel | Direction | Workflow |
|---------|-----------|----------|
| **Email** | Bidirectional | Customer email → parsed → ticket created. Agent replies in APEX UI → forwarded to customer email. |
| **Chat Widget** | Bidirectional | In-app chat widget (JavaScript) → messages stored as conversation → agent replies via APEX UI → push notification to customer. |
| **Slack** | Bidirectional | /create_ticket command → Slack thread becomes APEX ticket. Agent reply in APEX → Slack thread updated. |
| **WhatsApp Business** | Bidirectional | WhatsApp msg → parsed, ticket created. Agent reply → WhatsApp msg sent back. |
| **Public Form** | Inbound | Tenant/customer submits form → ticket auto-created. |
| **API** | Bidirectional | Partner system calls APEX API → ticket creation, status updates, message posting. |

### 7.2 Email-to-Ticket Automation

**Email forwarding rule:**

```
support@apex-tenant.com  → APEX mailbox
↓ (Inbound handler every 2 minutes)
Parse email (From, To, Subject, Body, Attachments)
↓
Create Ticket:
  - title: subject
  - description: body
  - customer: lookup by email, create if new
  - channel: email
  - auto_tag: "from_email"
  - attachments: fetch and store
↓
Assign (auto-routing rules):
  - If subject contains "GL": assign to GL team
  - If attachment is .pdf reconciliation: tag "reconciliation", assign to Data Quality
  - If sender is @auditfirm.com: escalate to Audit team
↓
SLA policy applied
↓
Agent notified (Slack: "New ticket assigned to you: #123")
```

**Reverse (Ticket → Email):**

```
Agent clicks "Reply" in APEX UI
↓
Compose message (supports rich text, mentions, attachments)
↓
System generates email from support@apex-tenant.com
↓
Email headers include:
  In-Reply-To: <original_email_message_id>
  References: <thread_id>
↓
Customer receives as email thread (not a new email)
↓ (If customer replies)
Email routed back → conversation continued in ticket
```

### 7.3 Slack Integration

**Inbound (Slack → Ticket):**

```
/create_ticket in #support channel
↓ Slack modal:
  Subject: [_______________]
  Priority: [Critical / High / Normal / Low]
  Category: [GL / Integrations / Audit / ...]
↓
Creates APEX ticket + linked Slack thread
↓
Agent replies in APEX UI
↓
Message also posted to Slack thread (with @mention if needed)
```

**Bidirectional notifications:**

```
Ticket created in APEX
  → Slack: "New ticket #456: Invoice matching error [Assign to me]"
  
Agent assigned
  → Slack: "@Ahmed, you've been assigned ticket #456"
  
SLA breach imminent
  → Slack: "🚨 SLA alert: Ticket #456 breaches in 15 minutes"
  
Ticket resolved
  → Slack: "Ticket #456 marked resolved"
```

### 7.4 Chat Widget (In-App)

**Frontend component** (Flutter Web):

```dart
// Simplified Flutter chat widget
ChatWidget(
  tenantId: "tenant_xyz",
  visitorEmail: "customer@email.com",
  onMessage: (message, attachments) {
    // POST /api/tickets/{tenant_id}/chat
    // Stores as conversation; if new, creates ticket
  },
  showKBSuggestions: true, // Auto-suggest KB articles as user types
);
```

**Backend API:**

```
POST /api/v1/{tenant_id}/chat/messages
Body: {
  "message": "I need help...",
  "ticket_id": 123, // optional; if not provided, create new
  "attachments": [file_id1, file_id2]
}

Response:
{
  "success": true,
  "data": {
    "ticket_id": 123,
    "conversation_id": 456,
    "agent_available": true,
    "kb_suggestions": [
      { "id": "kb-101", "title": "...", "relevance": 0.95 }
    ]
  }
}
```

### 7.5 WhatsApp Business API Integration

**Prerequisites:**
- Tenant registers with Meta for WhatsApp Business API
- APEX stores WhatsApp Business Account ID, Phone Number ID, Access Token

**Workflow:**

```
Customer sends WhatsApp message to Tenant's business number
  ↓ (WhatsApp webhook → APEX)
Parse message (text, media, location, etc.)
  ↓
Create/update ticket:
  - channel: whatsapp
  - customer: lookup by phone or create
  - auto_tag: "whatsapp"
  ↓
Agent replies in APEX UI (composes message)
  ↓
System calls WhatsApp API to send message back to customer
  ↓
Conversation continues via WhatsApp & synchronized in APEX ticket
```

**Sample config:**

```yaml
whatsapp_integration:
  enabled: true
  phone_number: "+966501234567"
  business_account_id: "123456789"
  access_token: "EAB***" # encrypted in DB
  webhook_url: "https://api.apex.com/webhooks/whatsapp"
  auto_response_enabled: true
  auto_response_template: "Thanks for reaching out! Our team will respond within 1h."
```

---

## Part 8: Knowledge Base & Help Center

### 8.1 Architecture

**Multi-tenant, multi-language KB:**

```
KnowledgeBase (per tenant)
  ├── Article
  │   ├── title_ar, content_ar (RTL)
  │   ├── title_en, content_en (LTR)
  │   ├── category (GL, Audit, Data Quality, ...)
  │   ├── visibility (public, internal, draft)
  │   ├── version (auto-increment on edit)
  │   ├── helpful_count (from "Did this help?" feedback)
  │   └── tags
  │
  ├── Category (GL, Integrations, Audit, Billing, Data Quality)
  │
  ├── Search Index (full-text, Arabic-aware)
  │   ├── Arabic: n-gram tokenizer for Arabic morphology
  │   ├── English: standard analyzer
  │   └── Ranking: TF-IDF + helpful_count
  │
  └── Public Help Center
      ├── URL: help.{tenant}.apex.com (via DNS CNAME)
      ├── Logo, colors, favicon (tenant branding)
      ├── Search bar (Arabic-enabled)
      ├── Categories (auto-generate from articles)
      └── Feedback (5-star rating + "Helpful?" widget)
```

### 8.2 Article Lifecycle

**Draft → Published → Versioned:**

```
KB Editor creates article:
  Title (AR + EN)
  Content (rich text, images, links)
  Category, tags
  Visibility: Draft
  ↓
Preview in both Arabic and English
  ↓
Publish (visibility: public)
  ↓
Indexed for search
  ↓
Auto-linked in related tickets (Claude finds similar topics)
  ↓
Track metrics: views, helpful_count, unhelpful_count
  ↓
After 3 months: auto-suggest review ("Last reviewed: Jan 2026, due for refresh")
  ↓
Editor updates, increments version_id
  ↓
Changelog visible to agents (who modified what, when)
```

### 8.3 Auto-Suggest in Chat & Tickets

**Real-time KB suggestion:**

```
Customer typing in chat widget:
  "How do I connect my bank account..."
  
Frontend calls:
  GET /api/{tenant_id}/kb/search?q=connect+bank+account
  
Backend:
  1. Parse query (tokenize, remove stopwords)
  2. Search KnowledgeBaseArticle for matches
  3. Rank by relevance + helpful_count
  4. Return top 3 with snippet
  
Frontend displays:
  [Did you know?]
  - "Bank Feed Setup Guide" (98% match)
  - "Supported Banks & Formats" (92% match)
  - "Troubleshoot Connection Errors" (88% match)
  
Customer clicks → navigates to article
```

### 8.4 Feedback & Analytics

**"Did this help?" widget:**

```
At bottom of every public KB article:
  [👍 Helpful]  [👎 Not Helpful]
  
If "Not Helpful":
  Optional feedback: "What's missing? [____]"
  
Admin dashboard:
  KB Article Performance
  ├── Views (this month)
  ├── Helpful ratio (helpful_count / total_votes)
  ├── Unhelpful feedback (themes)
  └── Search terms that led here
  
Auto-flag for review: Articles with < 60% helpful ratio
```

---

## Part 9: Public Status Page

### 9.1 Components & Incident Management

**APEX infrastructure components:**

```
StatusPage
├── Components
│   ├── API (backend)
│   ├── Frontend
│   ├── Database (PostgreSQL)
│   ├── Bank Feed Service (integrations)
│   ├── ZATCA Integration (KSA tax authority)
│   ├── Email Service
│   ├── WhatsApp Gateway
│   └── PDF Generation
│
├── Statuses
│   ├── Operational (green)
│   ├── Degraded (yellow)
│   ├── Partial Outage (orange)
│   ├── Major Outage (red)
│   └── Maintenance (blue)
│
└── Incidents
    ├── Title, description, start time
    ├── Affected components
    ├── Severity (minor, major, critical)
    ├── Updates (timeline of changes)
    ├── Resolution time, root cause
    └── Automatic resolution OR manual close
```

### 9.2 Workflow: Incident Detection → Resolution

```
Monitoring (Sentry, DataDog, custom)
  ↓ Detects: API error rate > 5%
  ↓
Auto-create incident:
  Title: "API Experiencing Elevated Error Rate"
  Status: Investigating
  Components: [API, Frontend]
  Publish to status page
  ↓
Email subscribers:
  "🚨 APEX API experiencing issues. We're investigating."
  
Engineering team investigates
  ↓
Post update:
  "🔧 Investigating database connection pool exhaustion.
   Current impact: 3-5 min response time on invoicing endpoints."
  
Subscribers notified via email/SMS/Slack webhook
  ↓
Issue resolved
  ↓
Post update:
  "✅ Resolved: Scaled DB connection pool. Services normal.
   Total downtime: 12 minutes."
  
Auto-close incident
  ↓
Post mortem scheduled (internal: root cause analysis, prevention)
```

### 9.3 Public Page Features

**Tenants & customers can:**

```
- View current status of all APEX components
- See incident history (past 90 days)
- Hover over component → see uptime SLA (99.5% target)
- Subscribe to updates: Email, SMS, RSS, Slack webhook
- Filter incidents by component or date range
- Read planned maintenance announcements (24h–7d advance notice)
```

---

## Part 10: Reports & Analytics

### 10.1 APEX (Internal) Dashboard

**Aurora support team dashboard:**

```
Metrics
├── Ticket Volume
│   ├── New (today, this week, this month)
│   ├── By priority (critical, high, normal, low)
│   ├── By category (GL, Integrations, Audit, ...)
│   └── Trend (MoM growth)
│
├── SLA Performance
│   ├── % first response met (by team, by agent)
│   ├── % resolution met
│   ├── Breach count & severity
│   └── Avg resolution time (by category)
│
├── Agent Performance
│   ├── Tickets handled (daily, weekly)
│   ├── Avg CSAT score (customer satisfaction rating)
│   ├── Avg first response time
│   ├── Avg resolution time
│   ├── Escalation rate
│   └── Specialization impact (GL agents resolve GL tickets 2x faster)
│
├── Top Issues This Week
│   ├── "Bank feed delays" (8 tickets)
│   ├── "Invoice matching rules not applying" (6 tickets)
│   ├── "ZATCA API timeout errors" (5 tickets)
│   └── → Linked to KB articles (auto-suggest new articles)
│
└── Customer Satisfaction
    ├── CSAT rating (1-5 scale, post-resolution)
    ├── NPS by tenant segment (large, mid-market, startup)
    ├── Churn risk (angry sentiment flagged = potential at-risk)
    └── Feature requests from support feedback
```

**Sample query:**

```sql
SELECT
  DATE(t.created_at) as date,
  t.priority,
  COUNT(*) as ticket_count,
  AVG(EXTRACT(EPOCH FROM (t.resolved_at - t.created_at)) / 3600) as avg_resolution_hours
FROM tickets t
WHERE t.tenant_id = 'apex_internal' AND t.created_at >= NOW() - INTERVAL '30 days'
GROUP BY 1, 2
ORDER BY 1 DESC, 2;
```

### 10.2 Tenant (White-Label) Dashboard

**Tenant's support manager view:**

```
My Helpdesk
├── Queue Overview
│   ├── New (unassigned)
│   ├── Open (assigned)
│   ├── Pending (awaiting customer response)
│   ├── Resolved (ready to close)
│   └── Closed
│
├── Top Issues (last 30 days)
│   ├── Recurring problems → Create KB article
│   ├── Time-to-resolve trends
│   └── Customer satisfaction by category
│
├── Team Performance
│   ├── Tickets per agent
│   ├── Avg resolution time (agent comparison)
│   ├── CSAT rating per agent
│   └── Workload balance
│
├── KB Article Performance
│   ├── Most viewed articles
│   ├── Helpful ratio
│   ├── Unhelpful feedback themes
│   └── Suggested articles for new creation
│
└── Custom Reports
    ├── Export to CSV
    ├── Date range filter
    ├── Breakdown by category, agent, priority
```

### 10.3 APEX Knowledge Base Health Report

**Generated monthly (Anthropic Claude analyzes ticket corpus):**

```
"This month we received 342 support tickets across 45 tenants.
Common themes:

1. Bank Feed Integration Issues (12% of tickets)
   Root cause: Users not aware that feeds run nightly at 2 AM UTC+3.
   Recommendation: Update KB-104 "Bank Feed Timing" with clearer wording.
   Current article helpful ratio: 62% → Refresh this week.

2. Invoice Matching Rules (10% of tickets)
   Root cause: New matching rules added in v2.4 but KB hasn't been updated.
   Recommendation: Create new KB: "Matching Rules v2.4 - What's Changed"
   Estimated ticket deflection: -20 tickets/month if created.

3. ZATCA (Tax) Integration (8% of tickets)
   Root cause: ZATCA API documentation updated in March; our docs outdated.
   Recommendation: Sync with Integration team on API v2.0 changes.
   Escalation: Schedule sync call with Integration team by end of week.
"
```

---

## Part 11: APEX-Specific Features (ERP Awareness)

### 11.1 Link Ticket to Financial Records

**When creating/viewing a ticket:**

```
Ticket context panel:
  
  Customer: "Invoice #INV-2026-001 is stuck in draft"
  
  [Link to Record] dropdown:
    
    ← [INVOICE: INV-2026-001]
       Amount: 50,000 SAR
       Customer: ABC Corp
       Status: DRAFT
       Created: 2026-03-15
       [View Invoice] [Link to Purchase Order]
    
    ← [CUSTOMER: ABC Corp]
       Phone: +966-12-3456789
       Industry: Manufacturing
       Open Tickets: 3 (including this one)
       Last Transaction: 2026-04-20
    
    ← [AUDIT ENGAGEMENT: AUD-2026-001-ABCCORP]
       Status: In Progress
       Engagement Manager: @Ahmed
       Related Tickets: 2
```

**Use case:**
- Auditor calls: "We see invoice INV-2026-001 missing from the trial balance."
- Agent searches APEX: finds ticket + links to invoice
- Agent can see: invoice is draft → never posted → explains missing TB balance
- Agent resolves: post invoice, ticket closed

### 11.2 Create JE Adjustment from Ticket

**Agent can propose a correction journal entry:**

```
Ticket: "We reconciled but found a $5K discrepancy."

Agent view:
  [Propose JE Adjustment]
  
  ┌──────────────────────────────┐
  │ Journal Entry Draft           │
  ├──────────────────────────────┤
  │ Debit:   Cash        5,000 SAR│
  │ Credit:  Bank Fee    5,000 SAR│
  │                              │
  │ Memo: "Reconciling [Ticket   │
  │       #123] - Bank fee not   │
  │       recorded"              │
  │                              │
  │ [Create + Submit to GL Team] │
  └──────────────────────────────┘
```

**Workflow:**
1. Agent proposes JE
2. GL Team notified: "Review proposed JE from support: [link]"
3. GL Specialist reviews, approves, posts
4. Ticket auto-updated: "JE-2026-0456 posted"
5. Ticket closed

**Benefit:** Fixes data issues faster; auditable trail (ticket → JE mapping).

### 11.3 Tenant Self-Service Portal

**Tenant's end-customer can:**

```
Customer Portal
├── Submit Ticket
│   ├── Subject
│   ├── Category (GL, Audit, Data, ...)
│   ├── Upload file(s)
│   └── Tenant pre-fills email/company from session
│
├── View My Tickets
│   ├── Status
│   ├── Last update (date & agent note preview)
│   ├── SLA remaining (countdown to resolution deadline)
│   ├── Conversation thread (can reply inline)
│   └── Attachments (download/upload)
│
├── Knowledge Base
│   ├── Search articles (Arabic-aware)
│   ├── Browse by category
│   ├── "Did this help?" feedback
│   └── Linked suggestions ("Related articles")
│
└── Account
    ├── Ticket history (all time)
    ├── CSAT survey result
    └── Download support export
```

**White-label:** Portal URL customized per tenant:
- `support.tenant.apex.com`
- Logo, colors, email templates customized

### 11.4 Bilingual Default (Arabic UI, English Internal)

**Customer-facing (Arabic):**

```
خط الدعم — المركز الرئيسي
┌──────────────────────┐
│ تقديم تذكرة جديدة     │
│ عرض تذاكري            │
│ قاعدة المعرفة         │
└──────────────────────┘
```

**Agent internal view (English):**

```
Support Tickets
┌─────────────────────────────────────────────────┐
│ Ticket #456 | GL Reconciliation Issue            │
│ Customer: ABC Corp (Arabic-speaking)             │
│ [Customer Message - ARABIC]                      │
│ الرجاء المساعدة، لدينا مشكلة في مطابقة البنك... │
│ [TRANSLATION]                                    │
│ Please help, we have a problem with bank match..│
│ [Agent can reply in English; auto-translate]   │
└─────────────────────────────────────────────────┘
```

---

## Part 12: Build vs. Integrate Analysis

### 12.1 Competitive Comparison

| Feature | Zendesk | Freshdesk | HubSpot | Intercom | APEX Native |
|---------|---------|-----------|---------|----------|------------|
| **Arabic RTL** | ✅ Yes | ✅ Yes | ✅ Limited | ❌ No | ✅ Native |
| **Multi-tenant white-label** | ❌ No | ✅ Yes | ❌ No | ❌ No | ✅ Native |
| **ERP integration** | ⚠️ API | ⚠️ API | ⚠️ API | ⚠️ API | ✅ Native |
| **Claude AI copilot** | ❌ Uses GPT-4 | ❌ Uses Freddy | ❌ No | ✅ Yes | ✅ Anthropic |
| **Link to invoice/GL** | ❌ No | ❌ No | ❌ No | ❌ No | ✅ Native |
| **Create JE from ticket** | ❌ No | ❌ No | ❌ No | ❌ No | ✅ Native |
| **Custom status workflow** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |
| **SLA + escalation** | ✅ Advanced | ✅ Advanced | ✅ Good | ✅ Good | ✅ Good |
| **WhatsApp + Slack** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Planned |
| **Knowledge base** | ✅ Zendesk Help Center | ✅ Freshdesk Help Portal | ✅ Knowledge Base | ✅ Articles | ✅ Native |
| **Pricing (per agent/month)** | $49–$179 | $19–$99 | $50–$150 | $39–$99 | $0 (included) |
| **Setup time** | 2–4 weeks | 1–2 weeks | 2–3 weeks | 1–2 weeks | 3–4 weeks |

### 12.2 Recommendation: BUILD NATIVE for v1

**Rationale:**

1. **Differentiation:** Arabic RTL + ERP awareness are strategic moats unavailable in competitors
2. **Pricing:** White-label helpdesk becomes a revenue stream (APEX tenants pay $5–$20/month per user)
3. **Integration:** Direct database access allows seamless linking to invoices, GL, audit engagements
4. **Brand:** Customers experience unified platform (no third-party branding/costs)
5. **Data:** Support data feeds APEX product roadmap (what customers struggle with)
6. **Vendor lock-in:** Tenants switching requires moving helpdesk + tickets → reduces churn

**Migration path (future):**
- If APEX grows beyond 500 tenants, evaluate licensing Zendesk/Freshdesk
- But native remains differentiator; can hybrid (APEX helpdesk for SMBs, Zendesk for Enterprise)

---

## Part 13: Implementation Roadmap (Phase 9, Weeks 1–12)

### 13.1 Phase 9 Sprint Breakdown

**Sprint 1 (Week 1–3): Foundation & Ticket CRUD**

```
Backend:
  ✓ Create models: Ticket, Conversation, Customer, Agent, Team, Channel
  ✓ Implement database migrations (PostgreSQL)
  ✓ Build REST API: POST/GET/PATCH tickets
  ✓ Email-to-ticket inbound handler (parse + create ticket)
  ✓ Auto-assignment rules (simple: by category → team)
  ✓ Ticket search (full-text by title, description)
  ✓ Webhooks for Slack notifications

Frontend (Flutter Web):
  ✓ New "Support" tab in main.dart
  ✓ Ticket list view (status, priority, age)
  ✓ Ticket detail view (description, conversation thread, attachments)
  ✓ Create ticket form (title, category, priority, attachments)
  ✓ Agent assignment UI (drag-drop to queue)
  ✓ Basic search (text input)

Testing:
  ✓ 30 tests: Ticket CRUD, email parsing, auto-assign, search
  ✓ E2E: Create ticket via email → appears in queue

Deliverable: Tickets created, viewed, assigned via UI or email.
```

**Sprint 2 (Week 4–5): SLA + Workflow + Status Machine**

```
Backend:
  ✓ SLA policies (CRUD, assign to teams)
  ✓ Status machine (New → Open → Pending → Resolved → Closed)
  ✓ SLA breach detection (cron job every 5 min)
  ✓ Escalation rules (priority escalation, supervisor escalation)
  ✓ Status transition rules (validate: can only go Closed → Reopened if < 30 days)
  ✓ Slack alerts (imminent breach, escalation, status change)
  ✓ Pause SLA logic (PENDING_CUSTOMER doesn't count)

Frontend:
  ✓ Status dropdown with validation
  ✓ SLA countdown timer (visible in ticket detail)
  ✓ Red alert on SLA breach
  ✓ Escalation button (escalate priority, escalate to supervisor)
  ✓ Reopen form (select reason)

Testing:
  ✓ 25 tests: SLA calculation, breach detection, escalation, status transitions
  ✓ E2E: Create ticket → assign → hit SLA breach → auto-escalate

Deliverable: Tickets flow through statuses with SLA enforcement.
```

**Sprint 3 (Week 6–7): Knowledge Base + Chat Widget**

```
Backend:
  ✓ Models: KnowledgeBaseArticle, Category, ArticleVersion
  ✓ Article CRUD (create, edit, publish, version)
  ✓ Full-text search (Arabic-aware tokenizer, rank by TF-IDF + helpful_count)
  ✓ Public help center API (GET articles, search, suggest)
  ✓ Feedback API (POST helpful/unhelpful + comment)
  ✓ Chat API (POST message, GET history, suggest KB articles)
  ✓ Chat-to-ticket converter (if no ticket_id, auto-create)

Frontend:
  ✓ KB editor (rich text, title_ar/title_en, category, tags, visibility)
  ✓ Public help center (search, browse, feedback widget)
  ✓ Chat widget (standalone JS component, embeddable on tenant site)
  ✓ Chat thread in ticket detail (merged with email/Slack conversation)
  ✓ KB suggestion panel (in ticket detail, during agent reply)

Testing:
  ✓ 20 tests: Article CRUD, search ranking, feedback tracking, chat creation
  ✓ E2E: Tenant publishes KB article → customer searches → finds answer → doesn't create ticket

Deliverable: KB and chat widget functional; tickets auto-link to relevant articles.
```

**Sprint 4 (Week 8–9): AI Auto-Categorize + Reply Suggestions**

```
Backend:
  ✓ Claude API integration (see Anthropic docs)
  ✓ Auto-categorize service (on ticket creation, call Claude with ticket text)
  ✓ Reply suggestion service (agent clicks button, Claude suggests response)
  ✓ Sentiment analysis (on each conversation message, score -1 to +1)
  ✓ Escalation on angry customer (sentiment < -0.7 → priority escalate)
  ✓ Thread summarization (on demand, Claude summarizes ticket history)
  ✓ Error handling (if Claude API fails, graceful degradation, no suggestion)

Frontend:
  ✓ Auto-assign pill in ticket detail ("Claude suggests: GL Team")
  ✓ "AI Suggest Reply" button (generates draft, agent can edit/send)
  ✓ Sentiment icon (😊 happy, 😐 neutral, 😢 angry)
  ✓ Summarize button (expands to Claude summary)
  ✓ Macro dropdown (canned responses, agent can use as template)

Testing:
  ✓ 25 tests: Categorization accuracy, reply generation, sentiment scoring
  ✓ E2E: Angry customer message → auto-escalate priority + notify supervisor

Deliverable: AI assists agents; auto-escalation on churn risk.
```

**Sprint 5 (Week 10–12): WhatsApp + Status Page + Reporting**

```
Backend:
  ✓ WhatsApp Business API integration (webhook handler for incoming msgs)
  ✓ WhatsApp message send (call WhatsApp API from agent reply)
  ✓ Status page model (Component, Incident, Incident Update)
  ✓ Status page API (GET components, incidents, subscribe for updates)
  ✓ Email notification service (subscribers get incident updates)
  ✓ Analytics service (query ticket counts, SLA metrics, agent performance)
  ✓ Report generation (APEX internal dashboard, tenant dashboard)

Frontend:
  ✓ Public status page (component health, incident log, subscribe button)
  ✓ Analytics dashboard (APEX internal: volume, SLA, agent perf, top issues)
  ✓ Analytics dashboard (Tenant: queue overview, team perf, KB performance)
  ✓ Custom report export (CSV, date range filter)
  ✓ Incident creation UI (internal admin only)

Testing:
  ✓ 15 tests: WhatsApp webhook parsing, status page queries, analytics calculations
  ✓ E2E: Tenant submits ticket via WhatsApp → agent replies → message sent back

Deliverable: Multi-channel support + visibility into APEX health + analytics.
```

### 13.2 Database Schema (Initial)

```sql
-- Tenants & Users already exist; reuse

CREATE TABLE helpdesk_ticket (
  id UUID PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenant(id),
  channel VARCHAR(20) NOT NULL DEFAULT 'email',
  status VARCHAR(50) NOT NULL DEFAULT 'new',
  priority VARCHAR(20) NOT NULL DEFAULT 'normal',
  title VARCHAR(255) NOT NULL,
  description TEXT,
  customer_id UUID REFERENCES helpdesk_customer(id),
  assigned_to_agent_id UUID REFERENCES user(id),
  team_id UUID REFERENCES helpdesk_team(id),
  sla_policy_id UUID REFERENCES helpdesk_sla_policy(id),
  category VARCHAR(50),
  tags TEXT[],
  external_ref JSONB, -- {invoice_id, customer_id, audit_engagement_id}
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  first_response_at TIMESTAMPTZ,
  resolved_at TIMESTAMPTZ,
  sla_breach BOOLEAN DEFAULT FALSE,
  sentiment_score FLOAT,
  pinned BOOLEAN DEFAULT FALSE,
  UNIQUE(tenant_id, id)
);

CREATE TABLE helpdesk_conversation (
  id UUID PRIMARY KEY,
  ticket_id UUID NOT NULL REFERENCES helpdesk_ticket(id) ON DELETE CASCADE,
  author_id UUID REFERENCES user(id),
  author_role VARCHAR(20) NOT NULL, -- 'agent', 'customer', 'system'
  message_text TEXT NOT NULL,
  attachments JSONB[], -- [{file_id, file_name, file_size}]
  is_internal_note BOOLEAN DEFAULT FALSE,
  mentions TEXT[], -- user_ids
  ai_generated BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE helpdesk_customer (
  id UUID PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenant(id),
  email VARCHAR(255) NOT NULL,
  name VARCHAR(255),
  phone VARCHAR(20),
  company_name VARCHAR(255),
  customer_type VARCHAR(50), -- 'internal_account_manager', 'external', 'auditor'
  metadata JSONB,
  last_ticket_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tenant_id, email)
);

CREATE TABLE helpdesk_agent (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES user(id),
  tenant_id UUID NOT NULL REFERENCES tenant(id),
  team_id UUID REFERENCES helpdesk_team(id),
  role VARCHAR(50) NOT NULL DEFAULT 'agent',
  specialization TEXT[],
  max_concurrent_tickets INT DEFAULT 5,
  is_available BOOLEAN DEFAULT TRUE,
  working_hours_tz VARCHAR(50) DEFAULT 'Asia/Riyadh',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE helpdesk_team (
  id UUID PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenant(id),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  members UUID[] REFERENCES helpdesk_agent(id),
  queue_name VARCHAR(50), -- 'onboarding', 'gl', 'audit', etc.
  sla_policy_id UUID REFERENCES helpdesk_sla_policy(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tenant_id, name)
);

CREATE TABLE helpdesk_sla_policy (
  id UUID PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenant(id),
  name VARCHAR(255) NOT NULL,
  priority_level VARCHAR(20), -- 'critical', 'high', 'normal', 'low'
  first_response_minutes INT,
  resolution_minutes INT,
  business_hours_only BOOLEAN DEFAULT TRUE,
  timezone VARCHAR(50) DEFAULT 'Asia/Riyadh',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE helpdesk_knowledge_base_article (
  id UUID PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenant(id),
  title_ar VARCHAR(255) NOT NULL,
  title_en VARCHAR(255) NOT NULL,
  content_ar TEXT NOT NULL,
  content_en TEXT NOT NULL,
  category VARCHAR(50),
  tags TEXT[],
  version INT DEFAULT 1,
  visibility VARCHAR(20) DEFAULT 'draft', -- 'public', 'internal', 'draft'
  created_by_agent_id UUID REFERENCES user(id),
  helpful_count INT DEFAULT 0,
  unhelpful_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  last_reviewed_at TIMESTAMPTZ
);

-- Indexes for performance
CREATE INDEX idx_ticket_tenant_status ON helpdesk_ticket(tenant_id, status);
CREATE INDEX idx_ticket_assigned_agent ON helpdesk_ticket(assigned_to_agent_id);
CREATE INDEX idx_ticket_created_at ON helpdesk_ticket(created_at DESC);
CREATE INDEX idx_conversation_ticket ON helpdesk_conversation(ticket_id);
CREATE INDEX idx_kb_article_tenant_visibility ON helpdesk_knowledge_base_article(tenant_id, visibility);
```

### 13.3 Estimated Effort

| Component | Est. Hours | Person |
|-----------|-----------|--------|
| **Sprint 1: Ticket CRUD + Email** | 120h | Backend (2 devs), Frontend (1) |
| **Sprint 2: SLA + Workflow** | 100h | Backend (2), Frontend (1) |
| **Sprint 3: KB + Chat** | 90h | Backend (2), Frontend (1) |
| **Sprint 4: Claude AI** | 80h | Backend (1 AI-focused), Frontend (1) |
| **Sprint 5: WhatsApp + Status + Reports** | 100h | Backend (2), Frontend (1) |
| **Testing (all sprints)** | 60h | QA (1) |
| **Documentation & Deployment** | 40h | Tech Lead (1) |
| **TOTAL** | **590h ≈ 15 weeks (1 team of 3–4)** | |

---

## Part 14: Deployment & Configuration

### 14.1 Environment Variables

```yaml
# .env

APEX_HELPDESK_ENABLED=true
HELPDESK_ADMIN_ONLY=false # Allow tenants to use helpdesk module

# Email-to-Ticket
HELPDESK_IMAP_HOST=imap.gmail.com
HELPDESK_IMAP_USER=support@apex.com
HELPDESK_IMAP_PASSWORD=xxxxx

# Slack
SLACK_BOT_TOKEN=xoxb-xxxxx
SLACK_SIGNING_SECRET=xxxxx

# WhatsApp Business
WHATSAPP_BUSINESS_ACCOUNT_ID=xxxxx
WHATSAPP_PHONE_NUMBER_ID=xxxxx
WHATSAPP_ACCESS_TOKEN=xxxxx
WHATSAPP_VERIFY_TOKEN=xxxxx

# Claude AI
ANTHROPIC_API_KEY=sk-ant-xxxxx
HELPDESK_ENABLE_AI=true

# Status Page
STATUS_PAGE_ENABLED=true
STATUS_PAGE_URL=https://status.apex.com

# Notifications
NOTIFICATION_EMAIL_FROM=support@apex.com
NOTIFICATION_SLACK_WEBHOOK=https://hooks.slack.com/xxxxx
```

### 14.2 Feature Flags

```python
# app/core/flags.py

HELPDESK_ENABLED = os.getenv("APEX_HELPDESK_ENABLED", "false").lower() == "true"
HELPDESK_AI_ENABLED = os.getenv("HELPDESK_ENABLE_AI", "true").lower() == "true"
HELPDESK_WHATSAPP_ENABLED = os.getenv("HELPDESK_WHATSAPP_ENABLED", "false").lower() == "true"
HELPDESK_STATUS_PAGE_ENABLED = os.getenv("STATUS_PAGE_ENABLED", "false").lower() == "true"
```

---

## Part 15: Future Enhancements (Phases 10–11)

- **Video call integration** (Zoom/Google Meet for screen-share debugging)
- **Ticket merging** (combine duplicate tickets)
- **Satisfaction survey** (automated CSAT email post-resolution)
- **Internal knowledge sharing** (Aurora team creates private KB for cross-training)
- **Advanced routing** (round-robin, skill-based, availability-based)
- **Mobile app** (Flutter native mobile for on-the-go agent support)
- **Custom fields** (tenant-specific metadata on tickets)
- **Business rules engine** (no-code automation, not just simple workflows)
- **AI training** (fine-tune Claude on tenant's domain-specific language)

---

## Part 16: Success Metrics

| KPI | Target | Measurement |
|-----|--------|-------------|
| **Mean Time to First Response** | < 2 hours | Ticket creation → first agent message |
| **Mean Time to Resolution** | < 24 hours | Ticket creation → resolved |
| **SLA Compliance** | > 95% | Tickets meeting SLA targets |
| **Customer Satisfaction (CSAT)** | > 4.2/5 | Post-resolution survey |
| **Ticket Deflection via KB** | > 20% | (Unique search → article view) / total tickets |
| **Agent Efficiency** | > 5 tickets/day | Tickets resolved per agent per day |
| **Churn Prevention** | TBD | Angry customers flagged early; escalation response time |
| **Tenant Adoption** | > 50% of tenants | White-label helpdesk activated by paid tenants |

---

## Sources & References

- [Zendesk Ticket Lifecycle](https://support.zendesk.com/hc/en-us/articles/8263915942938-About-the-ticket-lifecycle-and-ticket-statuses)
- [Zendesk 2025 Updates](https://support.zendesk.com/hc/en-us/articles/10140103140122-2025-recap-What-s-new-in-Zendesk)
- [Freshdesk Automation & Ticketing](https://www.freshworks.com/freshdesk/ticketing/)
- [Freshdesk Automation Rules](https://support.freshdesk.com/support/solutions/articles/99047-automation-rules-that-run-on-ticket-updates)
- [Intercom Helpdesk & AI Agent](https://www.intercom.com/)
- [Intercom Features Overview](https://www.intercom.com/help/en/articles/591233-intercom-features-explained)
- [Help Scout Helpdesk & KB](https://www.helpscout.com/)
- [Help Scout Knowledge Base](https://www.helpscout.com/knowledge-base/)
- [Front Email Helpdesk](https://front.com/)
- [Front Multi-Channel Communication](https://front.com/solutions/multi-channel-communication)
- [HubSpot Service Hub Ticketing](https://www.hubspot.com/products/service/ticketing-system)
- [HubSpot Ticket Routing](https://knowledge.hubspot.com/help-desk/route-tickets-in-help-desk)
- [HubSpot SLA Management](https://knowledge.hubspot.com/help-desk/sla-management)
- [SLA Management Guide](https://www.manageengine.com/products/service-desk/automation/what-is-service-level-agreement-sla.html)
- [SLA Breach Alerts & Best Practices](https://clearfeed.ai/blogs/sla-breach-in-customer-support)
- [AI Ticket Categorization & Automation](https://www.zendesk.com/blog/ai-powered-ticketing/)
- [AI Ticket Routing Tools](https://www.kustomer.com/resources/blog/ai-ticket-triage-tools/)
- [Anthropic Claude API Customer Support](https://platform.claude.com/docs/en/about-claude/use-case-guides/customer-support-chat)
- [Anthropic Tool Use for Agents](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)
- [Claude Customer Service Agent Cookbook](https://github.com/anthropics/anthropic-cookbook/blob/main/tool_use/customer_service_agent.ipynb)
- [Email-to-Ticket Automation](https://help-desk-migration.com/automating-ticket-creation-from-email/)
- [Email Ticketing Systems Guide](https://blog.invgate.com/email-ticketing-system)
- [WhatsApp Business API Helpdesk Integration](https://www.chatarchitect.com/news/integrate-whatsapp-business-api-with-help-desk-systems-for-faster-customer-support)
- [WhatsApp API Customer Support](https://www.callbell.eu/en/whatsapp-api-for-customer-support/index.html)
- [Arabic RTL Helpdesk Systems](https://www.uvdesk.com/en/blog/best-arabic-rtl-helpdesk-system-uvdesk/)
- [Desk365 RTL Language Support](https://help.desk365.io/en/articles/rtl-language-support-in-desk365/)
- [Knowledge Base Software & Help Centers](https://www.knowledgebase.com/)
- [Knowledge Base Analytics & Self-Service](https://bloomfire.com/resources/what-is-customer-support-knowledge-base/)
- [HubSpot Knowledge Base Software](https://www.hubspot.com/products/service/knowledge-base)
- [Help Center Software 2026](https://www.zendesk.com/service/help-center/)
- [Status Pages & Incident Management](https://statuscast.com/)
- [Atlassian Statuspage Incident Communication](https://www.atlassian.com/incident-management/tutorials/incident-communication)

---

**End of Blueprint**

**Last Updated:** 2026-04-30  
**Next Review:** Week 8 of Phase 9 implementation
