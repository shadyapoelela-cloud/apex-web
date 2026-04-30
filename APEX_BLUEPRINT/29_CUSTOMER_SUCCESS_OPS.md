# Customer Success Operations for APEX
**A Comprehensive Blueprint for B2B SaaS Customer Retention, Growth & Renewal Management**

**Document Date:** April 30, 2026  
**Prepared for:** APEX Financial Platform (ERP/Audit for SMBs, audit firms in MENA region)  
**Scope:** CS ops design, health scoring, lifecycle playbooks, automation, and metrics

---

## Executive Summary

APEX currently lacks systematic customer success operations, resulting in silent customer churn, missed renewal opportunities, and no data-driven expansion. This blueprint introduces a production-ready Customer Success framework built on industry best practices from Gainsight, ChurnZero, Vitally, and emerging CS platforms.

**Key Deliverables:**
- Customer Health Score model (0–100 composite) with engagement, adoption, commercial, and risk signals
- 6-stage customer lifecycle (Onboarding → Adoption → Maturity → At-Risk → Churn-Imminent → Churned)
- Concrete playbooks for each stage with automated touchpoints
- Renewal forecasting and expansion pipelines
- CS metrics dashboard aligned to NRR/GRR targets (120% / 90%+)
- Build-vs-buy recommendations for tooling

---

## Part 1: The Customer Success Problem in APEX

### Current State (As-Is)

APEX has **zero visibility** into customer health and churn risk:

- **No health score:** Customers cannot be ranked or triaged
- **No churn prediction:** Risk customers are only discovered at cancellation request
- **No renewal automation:** Renewal emails sent ad hoc; no renewal pipeline forecasting
- **Silent churn:** Users stop logging in; no alerts trigger
- **No playbooks:** CS team reacts to support tickets rather than proactively engaging customers
- **Segment-blind:** Free, Pro, and Enterprise tiers treated identically
- **No expansion tracking:** Usage signals exist in the database but are never analyzed

### Impact

- **Revenue leakage:** 3–5% preventable churn from lack of early intervention
- **Lost expansion:** Customers approaching usage limits are never offered upsells
- **Poor onboarding visibility:** New customers with low engagement in first 30 days are undetected
- **Manual renewal management:** CSMs scramble for contracts 2 weeks before expiry
- **Low NRR:** Estimated 95–100% GRR (no expansion upside)

### Root Causes

1. **No unified customer data model:** Engagement, transactions, support tickets live in separate systems
2. **No scoring engine:** No predictive logic to weight signals
3. **No workflow automation:** All touchpoints are manual email or Slack
4. **No CSM tooling:** Employees managing accounts via spreadsheets
5. **No SaaS metrics mindset:** Company defaults to accounting-focused metrics (MRR, churn%), not CS-focused (NRR, expansion, health score)

---

## Part 2: Customer Health Score Model for APEX

### Philosophy

A customer health score is a **predictive metric** that consolidates multiple signals—engagement, adoption, commercial performance, and risk indicators—into a single 0–100 composite score to identify renewal risk and expansion opportunities.

**Sources:** [Gainsight Health Scoring](https://www.gainsight.com/blog/customer-health-scores/), [ChurnZero Health Score Handbook](https://churnzero.com/guides/the-customer-health-score-handbook/), [Vitally Dynamic Scoring](https://www.vitally.io/features/health-scores)

### Health Score Architecture

#### **Signal Categories & Weights**

| Category | Weight | Signals | Data Source |
|----------|--------|---------|-------------|
| **Engagement** | 25% | Logins per week, screens viewed, API calls | Product analytics (logs, events) |
| **Adoption** | 25% | COA uploaded, TB bound, period closed, audit created, seats invited | Product events, feature flags |
| **Commercial** | 30% | Payment on time, plan utilization %, expansion-ready signals, contract renewal date | Billing system, usage tables |
| **Support Health** | 10% | Support tickets (count, resolved %), login failures, API errors | Support system, error logs |
| **Negative Risk** | 10% | Declining login trend, decreasing transactions, no activity 7d, support sentiment | Product analytics, sentiment API |

#### **Composite Score Calculation**

```
Health Score = (
    (Engagement_Score × 0.25) +
    (Adoption_Score × 0.25) +
    (Commercial_Score × 0.30) +
    (Support_Score × 0.10) +
    (1 - Risk_Score) × 0.10
)
```

Each sub-score is 0–100; final score is 0–100.

#### **Health Score Bands**

| Band | Score | Color | Meaning | Action |
|------|-------|-------|---------|--------|
| **Green** | 80–100 | Green | Healthy, low churn risk, expansion-ready | QBR prep, upsell conversations |
| **Yellow** | 50–79 | Yellow | At-risk, concerning trends, needs attention | CSM outreach, playbook triggers |
| **Red** | 0–49 | Red | High churn risk, immediate intervention | Save offer, executive escalation |

### Engagement Score (0–100)

Tracks **weekly active usage** and **feature breadth**.

| Metric | Good | Fair | Poor | Source |
|--------|------|------|------|--------|
| Logins per week | ≥3 | 1–2 | 0 | Session logs |
| Unique screens used per month | ≥8 | 4–7 | <4 | Page view events |
| Copilot messages per month | ≥5 | 1–4 | 0 | Copilot API logs |
| API calls per day (if integrated) | ≥10 | 1–9 | 0 | API logs |

**Calculation:**
```
Engagement_Score = (
    MIN(logins_per_week / 3, 1) × 0.40 +
    MIN(unique_screens / 8, 1) × 0.30 +
    MIN(copilot_messages / 5, 1) × 0.20 +
    MIN(api_calls / 10, 1) × 0.10
) × 100
```

### Adoption Score (0–100)

Tracks **progress through onboarding & feature adoption milestones**.

| Milestone | Points | Timeline | Source |
|-----------|--------|----------|--------|
| **Profile setup** (company, users, industry) | 15 | Day 0–1 | Account table |
| **COA uploaded** (Chart of Accounts) | 20 | Day 1–7 | Documents table |
| **COA approved** (admin review) | 10 | Day 3–14 | Workflow status |
| **Trial Balance bound** (QB/SAP) | 20 | Day 7–21 | Integrations table |
| **First period close** (month end) | 15 | Day 20–45 | Close tasks |
| **Audit engagement created** | 10 | Day 30–60 | Audit table |
| **Seats invited** (team members ≥2) | 10 | Day 1–30 | User invites table |

**Adoption Score = (Points Earned / 100) × 100**

### Commercial Score (0–100)

Tracks **subscription health, payment reliability, and plan utilization**.

| Metric | Good | Fair | Poor | Source |
|--------|------|------|------|--------|
| Payment status | On-time, all invoices paid | 1–2 late payments | Overdue / failed | Billing system |
| Plan utilization | 70–90% | 40–69% | <40% | Usage table |
| Months to contract renewal | >3 | 1–3 | <1 | Contract table |
| Expansion signal (users or entities approaching limit) | Yes, room to grow | Approaching limit | At limit | Usage stats |

**Calculation:**
```
Commercial_Score = (
    payment_on_time_score × 0.40 +
    MIN(plan_utilization / 70, 1) × 100 × 0.30 +
    renewal_runway_score × 0.20 +
    expansion_signal_score × 0.10
)
```

### Support Health Score (0–100)

Tracks **support interactions and system stability**.

| Metric | Good | Fair | Poor | Source |
|--------|------|------|------|--------|
| Support tickets (per month) | 0–1 | 2–3 | ≥4 | Support system |
| Ticket resolution rate | >95% | 80–95% | <80% | Support system |
| Login failures (per month) | 0 | 1–2 | ≥3 | Auth logs |
| API errors (per month) | <5 | 5–15 | >15 | Error logs |

**Calculation:**
```
Support_Score = 100 - (
    (ticket_count × 15) +
    ((100 - resolution_rate) × 0.20) +
    (login_failures × 10) +
    (api_errors × 2)
)
Capped at 0–100
```

### Risk Score (0–100)

Tracks **negative signals and churn indicators**. Higher = higher risk.

| Risk Signal | Impact | Weight | Source |
|-------------|--------|--------|--------|
| No login in 7 days | High | 0.40 | Session logs |
| No login in 14 days | Critical | 0.60 | Session logs |
| No login in 30 days | Churn-imminent | 1.00 | Session logs |
| Declining login trend (down 50% MoM) | Medium | 0.25 | Analytics |
| Declining transactions (down 50% MoM) | Medium | 0.25 | Usage table |
| Support sentiment negative (auto-detected) | Medium | 0.20 | Ticket AI analysis |
| Failed payment attempts (≥2 in 30d) | High | 0.35 | Billing system |

**Calculation:**
```
Risk_Score = MIN(
    (no_login_7d × 0.40) +
    (no_login_14d × 0.60) +
    (no_login_30d × 1.00) +
    (declining_login × 0.25) +
    (declining_transactions × 0.25) +
    (negative_sentiment × 0.20) +
    (payment_failures × 0.35),
    1.0
) × 100
```

### Score Recalculation Frequency

- **Daily:** Engagement, adoption (partial), risk signals
- **Weekly:** Commercial scores, support aggregates
- **Monthly:** Full recalculation and trend analysis

---

## Part 3: Customer Lifecycle Stages

### Stage Definitions & Duration

#### **Stage 1: Onboarding (Day 0–30)**

**Goal:** First invoice issued + COA uploaded + initial team trained

**Success Criteria:**
- Logins ≥3 per week
- COA uploaded (or imported via API)
- Trial Balance linked to accounting system
- At least 2 team members with active seats
- Time to First Value ≤7 days (first meaningful feature used)

**Typical Path:**
- Day 0: Account created, welcome email, in-app onboarding tour
- Day 1: Setup wizard (company profile, industry, users)
- Day 3: COA upload / import
- Day 7: First period closed OR first audit prep task
- Day 14: CSM check-in call
- Day 30: Onboarding completion review

**Handoff Trigger:** Adoption score ≥50 AND engagement score ≥60 → move to Adoption stage

#### **Stage 2: Adoption (Day 31–90)**

**Goal:** Regular feature use, first period close, first audit prep, expansion readiness

**Success Criteria:**
- Logins ≥2 per week (consistent)
- Unique screens used ≥5 per month
- ≥1 period closed
- ≥1 audit engagement created (if applicable)
- Plan utilization ≥50%

**Typical Path:**
- Week 5: Feature adoption nudges (in-app, email)
- Week 6: "Unlock Copilot" email (if AI Copilot available)
- Week 8: First usage milestone celebration
- Week 10: Adoption check-in call
- Week 13: Readiness assessment for Maturity stage

**Handoff Trigger:** Adoption score ≥70 AND engagement score ≥70 AND support health ≥80 → move to Maturity stage

#### **Stage 3: Maturity (Day 91+)**

**Goal:** Stable usage, expansion/upsell, referral readiness, QBR pipeline

**Success Criteria:**
- Logins consistent (≥1 per week)
- Monthly transactions stable or growing
- Health score ≥75
- Commercial score ≥70 (plan utilization, payment on-time)
- Expansion signals identified (multi-entity interest, team growth)

**Typical Path:**
- Monthly: Health score monitoring, trend analysis
- Q1–Q4: Quarterly Business Reviews (QBRs)
- Quarterly: Upsell/cross-sell assessment
- Annually: Renewal planning (6 months prior)

**Handoff Trigger:** Health score <50 for 14 consecutive days → move to At-Risk stage

#### **Stage 4: At-Risk (Triggered)**

**Goal:** Intervention, root cause analysis, remediation plan

**Triggers:**
- Health score <50 for 14 days (any reason)
- No login for 7 days (engagement drop)
- Payment failed ≥2 times in 30 days
- Negative support sentiment (escalations, complaints)

**Typical Path:**
- Day 1 (trigger): Automated CSM task created, Slack alert
- Day 2: CSM reaches out (email + call)
- Day 3: Root cause analysis (engagement barrier, usability issue, business change)
- Day 5: Remediation plan (training, feature walkthrough, save offer, or upgrade)
- Day 14: Follow-up check-in

**Handoff Triggers:**
- Health score returns to ≥65 → move back to Maturity
- No response to intervention × 3 attempts → move to Churn-Imminent

#### **Stage 5: Churn-Imminent (Triggered)**

**Goal:** Last-ditch retention, executive escalation, save offer

**Triggers:**
- Health score <30 for 14 consecutive days
- No login for 30 days
- Cancellation request received
- Explicit churn intent (customer states it)

**Typical Path:**
- Day 1: Executive escalation (VP of CS or CEO)
- Day 2: Save offer (discount 20–30%, extended trial of premium features, pause contract)
- Day 5: Win-back campaign launch (series of educational emails, ROI recalculation)
- Day 30: Final decision point (renewal, pause, or churn)

**Handoff Trigger:**
- Customer confirms churn intent OR contract expires without renewal → move to Churned

#### **Stage 6: Churned (Post-Exit)**

**Goal:** Exit experience, feedback collection, win-back pipeline

**Triggers:**
- Subscription cancelled or expired
- No renewal payment received

**Typical Path:**
- Day 0: Exit survey (why are you leaving?)
- Day 1: Offboarding checklist (data export, transition support)
- Day 7: Win-back offer (50% discount, 3-month free trial)
- Day 30: "What's new?" email (feature updates, case studies)
- Day 90+: Win-back campaign (quarterly touchpoints for 12 months)

**Handoff Trigger:** Customer re-engages → return to Onboarding stage

### Lifecycle Stage Diagram

```
Onboarding (0–30d)
    ↓
Adoption (31–90d)
    ↓
Maturity (91+d)
    ↓
    ├─→ [Health ≥65] → Maturity (loop)
    └─→ [Health <50 × 14d] → At-Risk
            ↓
            ├─→ [Remediation succeeds] → Maturity
            └─→ [No response × 3] → Churn-Imminent
                    ↓
                    ├─→ [Save offer accepted] → At-Risk
                    └─→ [Churn confirmed] → Churned
                            ↓
                            └─→ [Re-engages] → Onboarding (win-back)
```

---

## Part 4: Playbooks & Automated Workflows

### Playbook Framework

Each playbook defines **trigger conditions, timeline, tasks, and success metrics**. Playbooks are activated by health score changes, lifecycle stage transitions, usage events, or manual CSM actions.

### 4.1 Onboarding Playbook (Day 0–30)

**Trigger:** New subscription created (account.created event)  
**Owner:** Onboarding Specialist or Customer Success Manager  
**Timeline:** 30 days

#### Automated Tasks & Touchpoints

| Day(s) | Task | Channel | Template | Owner | Success Metric |
|--------|------|---------|----------|-------|-----------------|
| **0** | Welcome email + in-app tour | Email + In-App | "Welcome to APEX" | Auto | Email opened >60% |
| **1** | Setup wizard nudge | In-App + Slack | "Complete your profile" | Auto | Profile ≥80% complete |
| **3** | "Upload COA" reminder | Email | "Ready to sync your chart?" | Auto | COA upload <10d |
| **5** | Copilot intro email | Email | "Meet your AI assistant" | Auto | Copilot first use <14d |
| **7** | Check-in call scheduled | Slack + Email | "Let's get you started" | Manual | Call completed |
| **14** | Mid-point review | Email | "Your first week review" | Manual | Adoption score ≥40 |
| **21** | Feature highlights email | Email | "What you can do with APEX" | Auto | Link clicks >40% |
| **30** | Graduation email + survey | Email + In-App | "You're ready for production!" | Manual | Survey completion |

#### Conditional Branches

**If COA not uploaded by Day 10:**
- Day 10: Escalation email (CSM personal touch)
- Day 12: Demo offer (screen share walkthrough)
- Day 15: Data import service offer (APEX team uploads COA)

**If logins drop below 2/week by Day 14:**
- Day 14: Usage alert to CSM → outreach call
- Day 18: Barrier identification email (obstacles?)
- Day 21: Training session offer

#### Success Criteria
- ≥70% of customers reach Adoption stage by Day 30
- TTFV (time to first value) ≤7 days
- COA uploaded ≥80% by Day 30
- TB linked ≥60% by Day 30

---

### 4.2 Adoption Playbook (Day 31–90)

**Trigger:** Move to Adoption stage (adoption_score ≥50 AND engagement_score ≥60)  
**Owner:** Customer Success Manager  
**Timeline:** 60 days

#### Automated Tasks & Touchpoints

| Week | Task | Channel | Trigger | Owner |
|------|------|---------|---------|-------|
| **5** | Adoption check-in call | Zoom | Auto-scheduled | CSM |
| **6** | Feature highlight email | Email | Adoption_score <60 | Auto |
| **7** | "Period close prep" email | Email | No period closed yet | Auto |
| **8** | Success story shared | Email + Slack | Adoption_score ≥60 | Auto |
| **9** | Q&A webinar invitation | Email | If ≥3 attendees from cohort | Auto |
| **10** | Usage analytics report | Email | Weekly dashboard | Auto |
| **11** | Expansion readiness survey | In-App | Adoption_score ≥75 | Manual |
| **12** | Graduation to Maturity | Email | Auto if criteria met | Auto |

#### Success Criteria
- ≥80% reach Maturity stage by Day 90
- ≥1 period closed
- Engagement score ≥70
- Support health ≥80 (few/resolved tickets)

---

### 4.3 Maturity Playbook (Day 91+)

**Trigger:** Move to Maturity stage  
**Owner:** Customer Success Manager  
**Timeline:** Ongoing (monthly/quarterly cadence)

#### Recurring Touchpoints

| Frequency | Task | Channel | Metric Trigger |
|-----------|------|---------|-----------------|
| **Monthly** | Health score review | Dashboard | Auto-updated |
| **Quarterly** | Quarterly Business Review (QBR) | Zoom + Presentation | Calendar reminder |
| **Quarterly** | Upsell/expansion assessment | Email + call | Usage trends |
| **Quarterly** | NPS/CSAT survey | In-App | Pulse survey |
| **Semi-annually** | Account planning session | Zoom | Strategy alignment |
| **Annually** (6m prior) | Renewal planning kickoff | Email | Contract date trigger |

#### Maturity QBR Agenda (1 hour)
1. **Value Summary** (15m): ROI delivered, metrics progress
2. **Challenges & Wins** (15m): What's working, what's not
3. **Roadmap Alignment** (15m): Customer priorities, product direction
4. **Next Quarter Plan** (15m): Goals, expansion opportunities, training

#### Success Criteria
- ≥90% of mature customers renew (GRR ≥90%)
- ≥40% of mature customers expand (upsell/cross-sell acceptance)
- Health score distribution: ≥80% Green, <10% Red
- NRR ≥120%

---

### 4.4 At-Risk Playbook (Triggered)

**Trigger:** Health score <50 for 14 days OR no login for 7 days OR payment failed ≥2 times  
**Owner:** CSM (urgent priority)  
**Timeline:** 14 days to remediation decision

#### Immediate Actions (Day 1–2)

| Day | Task | Channel | Owner | Goal |
|-----|------|---------|-------|------|
| **1** | Automated alert to CSM | Slack + Dashboard | Auto | CSM awareness |
| **2** | Outreach email | Email | CSM | Root cause inquiry |
| **2** | Calendar invitation (call) | Outlook | CSM | Confirm conversation |

#### Investigation & Remediation (Day 3–7)

**Discovery Questions:**
- Has your business priority shifted?
- Are you encountering a usability issue?
- Is budget a concern?
- Do you need additional training or support?
- Would a feature demo help?

**Remediation Options (CSM selects):**
1. **Training intervention:** Targeted walkthrough, 1:1 session, or recorded demo
2. **Feature unlocking:** Enable premium AI features, advanced analytics
3. **Operational fix:** API integration, data sync issue resolution
4. **Pricing adjustment:** Seasonal discount, smaller plan option
5. **Scope adjustment:** Pause non-critical features, defer expansion

#### Escalation Path (Day 8–14)

**If no response after 3 contact attempts:**
- Day 10: Executive escalation email (VP of CS)
- Day 12: Save offer (20–30% discount, 6-month minimum)
- Day 14: Final decision point (move to Churn-Imminent or Maturity)

#### Success Criteria
- ≥70% of at-risk customers remediate and return to Maturity
- Average time to remediation: ≤7 days
- Re-churn rate (return to at-risk): <20% within 30 days

---

### 4.5 Renewal Playbook (60 Days Pre-Renewal)

**Trigger:** Contract renewal date – 60 days  
**Owner:** CSM + Sales (Account Executive if expansion opportunity)  
**Timeline:** 60 days

#### Timeline

| Days Before Renewal | Task | Channel | Deliverable |
|-------------------|------|---------|-------------|
| **60** | Renewal kick-off | Email + Calendar | Renewal plan document |
| **45** | QBR preparation | Call | Strategy alignment |
| **30** | Pricing review + expansion conversation | Email + Call | Renewal proposal draft |
| **14** | Proposal sent | Email | Formal renewal agreement |
| **7** | Final follow-up | Call | Address questions |
| **1** | Final invoice reminder | Email | Payment due |

#### Renewal Proposal Template

```
[Customer Name] – APEX Renewal Proposal
Renewal Period: [Start] – [End] (12 months)
Current Plan: [Pro / Business / Enterprise]
Expansion Opportunities: [Seats, modules, or upsell]

Current Investment: [Current MRR × 12]
Proposed Investment: [New MRR × 12] ([+/– change])

Value Delivered:
- ROI: [quantified savings/efficiency gains]
- Usage: [logins, transactions, features]
- Milestones: [periods closed, audits completed]

Optional Expansions:
- Add Copilot Premium: [+$X/mo]
- Audit Module: [+$X/mo]
- White-label / Accountant Portal: [+$X/mo]

Success Metrics (Next Year Goals):
- NRR Target: 120%+
- Monthly users: [target]
- Feature adoption: [targets]

Next Steps:
1. Customer review & questions (7 days)
2. Contract signature (7 days)
3. Renewal invoicing (1 day)
4. Payment due (30 days from invoice)
```

#### Auto-Renewal vs. Opt-In Renewal

**Recommended:** Auto-renewal with opt-out window (30 days prior)
- Reduces administrative friction
- Ensures revenue certainty
- Allows customer to pause or downgrade if needed

**If opt-in required:**
- Manual notice must be sent 90 days prior
- Structured reminders at 60d, 30d, 14d, 7d
- If no response by renewal date, send final courtesy email (no auto-charge)

#### Success Criteria
- ≥95% of mature customers renew on-time
- ≥40% of renewals include expansion (upsell/cross-sell)
- Average proposal-to-signature time: ≤14 days

---

### 4.6 Expansion Playbook (Triggered by Usage Signals)

**Trigger:**
- Plan utilization ≥80%
- Seats approaching limit
- Second entity / location mentioned in comms
- NPS ≥8 (detractor to promoter)
- Adoption score ≥80 for 30 days

**Owner:** Account Executive (sales-led) OR CSM (land-and-expand)  
**Timeline:** 30–60 days (typically closes at renewal)

#### Expansion Signals & Opportunities

| Signal | Upsell Opportunity | Cross-sell | Timeline |
|--------|------------------|-----------|----------|
| Seat utilization ≥80% | +5–10 seats | Accountant white-label | Quarterly |
| Period-close velocity increasing | Pro → Business plan | Audit module | At renewal |
| Multi-entity interest expressed | Per-entity licensing | Sub-ledger management | Quarterly |
| Copilot engagement ≥5/mo | Copilot Premium tier | Industry templates | Ongoing |
| Audit engagement created | Standard → Enterprise | Advanced audit workflows | At renewal |
| Workflow automation demand | Professional services | API integrations, webhooks | On-demand |

#### Expansion Conversation Flow

**Stage 1: Opportunity Identification (Week 1–2)**
- CSM identifies signal in health dashboard or customer conversation
- CSM documents expansion need in CRM

**Stage 2: Initial Conversation (Week 3)**
- CSM/AE: "I noticed you're using [feature] heavily. Have you considered [expansion]?"
- Customer: Response (yes / maybe / no)
- If "maybe": Set up product demo with AE

**Stage 3: Proposal & Negotiation (Week 4–6)**
- AE sends expansion proposal (pricing, ROI, timeline)
- Negotiation of terms (discount, pilot, phased approach)

**Stage 4: Close & Implementation (Week 7+)**
- Contract signature
- Provisioning of new licenses/modules
- Training kickoff

#### Expansion Playbook Email Sequence

**Email 1 (Week 3):** Recognition + Light Positioning
```
Subject: You're killing it with [Feature]—let's unlock more

Hi [Name],

I noticed you've been using [Feature] daily to [benefit]. That tells me 
[business outcome is happening].

When you're ready, I'd love to explore how [expansion opportunity] could 
accelerate your [goal]. No pressure—just something to consider.

Would you be open to a 15-min chat next week?

Best,
[CSM Name]
```

**Email 2 (Week 4, if no response):** Value Prop
```
Subject: How [Company] saved 40% on audit prep with APEX [Expansion]

Hi [Name],

I thought of you when reading this case study. [Company in similar industry] 
went from [old state] to [new state] using [expansion feature].

Would you like to see how this could work for you?

Best,
[CSM Name]
```

**Email 3 (Week 5):** Demo Offer
```
Subject: 20-min demo: See [Expansion] in action

Hi [Name],

Ready for a quick demo of [Expansion]? I can walk you through real examples 
from firms like yours.

Slots: [3 times] next week—what works?

Best,
[CSM Name]
```

#### Success Criteria
- ≥40% of expansion opportunities close within 60 days
- Average expansion value: $2,000–$5,000 ACV increase
- Upsell/cross-sell contributing ≥20% to NRR growth

---

### 4.7 Churn-Imminent Playbook (Triggered)

**Trigger:**
- Health score <30 for 14 days
- No login for 30 days
- Explicit cancellation request
- Failed payment × 2 (contract at risk)

**Owner:** VP of Customer Success + VP of Sales  
**Timeline:** 7–30 days (urgent)

#### Immediate Response (Day 1–3)

| Step | Task | Owner | Channel |
|------|------|-------|---------|
| 1 | Executive escalation | VP CS | Slack alert + call assignment |
| 2 | Customer contact attempt | VP / AE | Phone call | 
| 3 | Root cause assessment | VP | Discovery call |
| 4 | Save offer + proposal | VP + CFO | Email + contract |

#### Save Offer Examples

**Discount Save (20–30% reduction):**
```
We value your partnership and want to keep you on APEX. 
We're offering 30% off your next 6 months if you renew today.
Current: $5,000/year → Discounted: $3,500 (6m), then $5,000 (6m renewal)
```

**Pause / Downgrade Save:**
```
If budget is tight, let's pause your Pro plan and downgrade to our Starter 
tier at $X/month. You can upgrade anytime when you're ready.
Current: $5,000/year → Downgrade: $1,500/year (6 months), then reassess
```

**Extended Trial / Feature Unlock:**
```
Let's unlock our Copilot Premium features (3-month trial) to show you the 
full value. If you love it, we'll factor the trial cost into your renewal.
Current: $5,000/year → Trial: Free premium features (90 days), then $5,500/year
```

**Scope Reduction + Future Expansion:**
```
We understand your needs may have shifted. Let's right-size your contract 
for now, and schedule a strategic review in Q3 when things stabilize.
Current: $5,000/year → Interim: $2,500/year (6m), then $5,000+ (renewal)
```

#### Win-Back Campaign (If Churned)

**Email Sequence (30–90 days post-churn):**

1. **Day 7:** Exit survey follow-up + "We'd love to have you back"
2. **Day 21:** "What's new in APEX" (product updates, new features)
3. **Day 45:** Case study from similar customer (results achieved)
4. **Day 60:** Win-back offer (50% discount, 3-month free trial)
5. **Day 90:** Final win-back email + sunset message

#### Success Criteria
- ≥50% of churn-imminent customers are saved (accept offer or defer cancellation)
- ≥5% of churned customers return within 12 months
- Average save offer discount: 20–30% (preserve LTV)

---

### 4.8 Win-Back Playbook (12 Months Post-Churn)

**Trigger:** Customer cancellation date or contract expiry without renewal

**Owner:** SDR (Sales Development Rep) or CSM  
**Timeline:** 12 months (quarterly touchpoints)

#### Win-Back Campaign Calendar

| Month | Task | Channel | Content |
|-------|------|---------|---------|
| **0** | Exit survey | In-App + Email | Why did you leave? |
| **1** | "We'll miss you" email + data export | Email | Offboarding support |
| **2** | Win-back offer (50% off 3m trial) | Email | Limited-time offer |
| **3** | Product update email | Email | 3 major new features |
| **6** | Case study email | Email | Customer in similar industry |
| **9** | "Come back" offer (special pricing) | Email | Incentive to return |
| **12** | Sunset email (final touchpoint) | Email | You're always welcome |

#### Win-Back Content Examples

**Month 1: Exit Survey Email**
```
Subject: We'd love your feedback

Hi [Name],

We're sorry to see you go. To help us improve, could you spend 2 minutes 
answering why you decided to pause your APEX subscription?

[Exit Survey Link]

If there's anything we could have done differently, I'm all ears.

Best,
[Customer Success Team]
```

**Month 2: Win-Back Offer Email**
```
Subject: Come back for 50% off (for 3 months)

Hi [Name],

We miss you! APEX has evolved since you left. Here's what's new:
- AI Copilot (automate 40% of manual tasks)
- Real-time collaboration (team audits together)
- Mobile app (audit from anywhere)

As a former customer, we're offering 50% off your next 3 months. 
No long-term commitment required.

[Renew Now CTA]

Best,
[Customer Success Team]
```

#### Success Criteria
- ≥5–10% of churned customers re-engage within 12 months
- Win-back CAC ≤ expected customer LTV
- Returning customers have longer initial LTV (2–3 years) than first contract

---

## Part 5: CS Automation Patterns

### 5.1 Automated Trigger-Based Workflows

APEX can implement these workflows using **Zapier, Make, or custom webhook integrations** without dedicated CS platform (until scale justifies investment).

#### Health Score Change → CSM Task + Alert

```
Trigger: health_score < 50 for 14 consecutive days
Action 1: Create CSM task in APEX or CRM
        - Task name: "At-Risk: [Customer Name] - Score: [Score]"
        - Priority: High
        - Assigned to: Assigned CSM or rotation
        - Due: Today
Action 2: Post Slack message to #cs-alerts channel
        - "🚨 [Customer] is at-risk (score: [Score]). 
           Root cause: [Top signal]. 
           CSM task created: [Link]"
Action 3: Send email to CSM
        - "Your attention needed: [Customer] at-risk"
```

#### No Login for 7 Days → Email + Dashboard Alert

```
Trigger: no login in 7 days AND health_score ≥ 60 (i.e., engagement dropped)
Action 1: Dashboard red flag (CSM sees customer in dashboard)
Action 2: Email to customer (CSM-personalized)
        - "Hi [Name], we noticed you haven't logged in since [date]. 
           Miss anything? Happy to help."
Action 3: If no login after 14 days: CSM call scheduled (calendar invite)
```

#### Plan Utilization ≥80% → Expansion Signal

```
Trigger: (seats_used / seats_allocated) ≥ 0.80 for 7+ consecutive days
Action 1: Create AE task (if expansion-ready customer)
        - Task: "Expansion opportunity: [Customer] approaching seat limit"
        - CTA: "Schedule conversation, send proposal"
Action 2: Send in-app notification to customer
        - "You're using [X]% of your seats. Interested in expanding?"
        - [Learn More CTA] → Expansion landing page
```

#### Payment Failed × 2 → Billing Alert + CSM Escalation

```
Trigger: payment_failed_count ≥ 2 in 30-day period
Action 1: Automated retry (Stripe / billing system)
        - Retry payment Day 3, Day 7, Day 14
Action 2: CSM task + email to customer
        - "Payment issue on your account—help resolve"
        - Payment link, alternative payment methods
Action 3: If payment not resolved after 14 days: VP CS escalation
```

#### Renewal Date – 60 Days → Renewal Workflow Start

```
Trigger: contract.renewal_date - 60 days = today
Action 1: Create CSM task (renewal planning)
Action 2: Send CSM email: "Renewal kickoff for [Customer]"
        - Renewal prep checklist
        - QBR scheduling link
        - Expansion assessment template
Action 3: Create follow-up tasks at 45d, 30d, 14d, 7d, 1d
Action 4: If expansion signals present: Create AE task + calendar for expansion pitch
```

#### Adoption Milestone Reached → Email Celebration + Feature Nudge

```
Trigger: adoption_score ≥ 70 (any milestone achieved)
Action 1: Send customer celebration email
        - "Congrats! You've completed onboarding!"
        - "Here's what your team can do next..."
Action 2: In-app toast notification
        - "You've unlocked Copilot! Try it now."
Action 3: Create CSM reminder task: "Follow up on adoption momentum"
```

### 5.2 Email Drip Sequences (Automation Examples)

**Tools:** HubSpot workflows, Mailchimp, Klaviyo, or custom email service

#### Onboarding Drip (Days 0–30)

| Day | Email | Condition | CTA |
|-----|-------|-----------|-----|
| 0 | Welcome to APEX | Auto | Start Setup Wizard |
| 3 | "Upload Your Chart of Accounts" | No COA uploaded | Upload Now / Request Help |
| 5 | "Meet Your AI Assistant: Copilot" | No Copilot use | Try Copilot |
| 7 | Check-in: "How's it going?" | No engagement milestone | Book a Call |
| 14 | "Your Onboarding Progress" | Adoption_score <50 | Complete These Tasks |
| 21 | "Features You Haven't Tried Yet" | Usage <5 screens | Explore Features |
| 30 | "Graduation: You're Ready!" | Adoption_score ≥70 | Next Steps |

#### At-Risk Intervention Drip (Day 1–14)

| Day | Email | Condition | CTA |
|-----|-------|-----------|-----|
| 1 | "We noticed you're having trouble" | health_score <50 | Book 15-min call |
| 5 | "Here's how other customers solved this" | No response to Day 1 | Read case study |
| 9 | "Quick training session?" | Still unresponded | Join live demo |
| 14 | "Save offer: 20% off renewal" | Still at-risk | Accept offer / Chat |

#### Renewal Drip (Days 60–0)

| Days Before | Email | CTA |
|-------------|-------|-----|
| 60 | Renewal kick-off + QBR invite | Schedule QBR |
| 45 | Pricing & expansion options | Review proposal draft |
| 30 | Renewal proposal (formal) | Sign & return |
| 14 | Gentle reminder | Final Q&A |
| 7 | "Expires in 7 days" | Renew now |
| 0 | Final courtesy notice | Renew today |

### 5.3 In-App Messages & Banners

**Tools:** Pendo, Appcues, Sprig, or custom notification system

#### Onboarding Hot-Spots

| Location | Message | Trigger | CTA |
|----------|---------|---------|-----|
| Dashboard (login) | "Start here: 3-step setup" | Day 0, login 1 | Start Guide |
| Dashboard (Day 7+) | "You've set up 2/3 steps!" | Adoption_score 40–60 | Next step |
| Copilot menu | "New: AI-powered suggestions" | Copilot feature release | Try Now |
| Settings | "Invite your team (save time)" | Solo user, Day 5+ | Invite users |
| Period close workflow | "Pro tip: Use Copilot for analysis" | Engagement <50%, Day 30+ | Learn more |

#### At-Risk Hot-Spots

| Location | Message | Trigger | CTA |
|----------|---------|---------|-----|
| Top banner | "We're here to help! Having issues?" | No login 7 days | Get support |
| Feature hint | "Try [advanced feature] (premium)" | Expansion-ready signal | Upgrade |
| Settings | "Something wrong? Let us know" | Support ticket recent | Feedback |

### 5.4 Slack Alerts for CSM Proactive Engagement

**Tools:** Slack API + webhook integration

```
Channel: #cs-alerts (CSMs subscribe)

Format:
---
🎯 EXPANSION OPPORTUNITY
Customer: Acme Corp
Signal: Seat utilization 85%
Score: 82 (Green)
Recommended Action: Upsell 10 more seats
AE: [John Smith]
Link: [CRM customer record]
---

🚨 AT-RISK ALERT
Customer: Global Ltd
Signal: Health score dropped 40 points (was 75, now 35)
Duration: 14 days
Root cause: No login, declining usage
CSM: [Jane Doe]
Action: Call scheduled for today
Link: [CSM task]
---

⏰ RENEWAL REMINDER
Customer: BigBiz Inc
Renewal date: [60 days]
Current value: $24,000/year
Expansion opportunity: +$8,000 (Audit module)
CSM: [Mike Brown]
Next step: Schedule QBR
Link: [Renewal pipeline]
---

💚 HEALTH TREND
Customer: SmallCo
Health score: 88 (↑ from 72 last month)
Trend: Positive (high engagement, adoption)
Recommended action: QBR, expansion discussion
Link: [Health dashboard]
```

---

## Part 6: Renewal Management

### 6.1 Renewal Pipeline & Forecasting

**Objective:** Predict renewal revenue ≥3 months in advance; identify at-risk renewals; forecast NRR.

#### Renewal Pipeline Dashboard

**Columns:**
- Customer name
- Renewal date (countdown: 60d, 30d, 14d, 7d, overdue)
- Current ARR
- Expansion opportunity ($ amount)
- Renewal health score (predicted likelihood of renewal: 90%+, 70–89%, <70%)
- Assigned CSM + AE
- Status (Open, Proposed, Negotiating, Signed, Overdue)

#### Renewal Likelihood Prediction

```
Renewal_Likelihood = (
    (health_score / 100) × 0.40 +
    (commercial_score / 100) × 0.35 +
    (engagement_score / 100) × 0.15 +
    (support_health_score / 100) × 0.10
)

If Renewal_Likelihood ≥ 0.90 → High confidence
If 0.70–0.89 → Medium confidence (at-risk review)
If < 0.70 → High at-risk (intervention required)
```

#### Renewal Revenue Forecast

```
Forecasted Renewal Revenue (30–90 days out) = 
    Sum(Current_ARR × Renewal_Likelihood) 
    + Sum(Expansion_ARR × Expansion_Acceptance_Rate)

Example:
Customer A: $10,000 ARR × 95% likelihood = $9,500
Customer B: $5,000 ARR × 75% likelihood = $3,750
Customer A expansion: $2,000 × 60% = $1,200
Total forecasted: $14,450 / $17,000 possible = 85% collected
```

### 6.2 Cancellation Request Flow

**Trigger:** Customer initiates cancellation request (email, support ticket, in-app action)

#### Response Protocol

| Step | Timeline | Owner | Action |
|------|----------|-------|--------|
| 1 | Immediate | Support / Billing | Acknowledge request, do NOT process immediately |
| 2 | Day 1 | CSM | Outreach: "We'd hate to see you go—let's talk" |
| 3 | Day 2 | CSM | Root cause discovery call |
| 4 | Day 3 | VP CS + AE | Save offer proposal (if justified) |
| 5 | Day 5 | CSM | Confirmation: "We're processing your cancellation" OR "Thanks for accepting our offer!" |
| 6 | Day 7 | Operations | Execution: Deactivate account, data export, offboarding |

#### Cancellation Request Email Template

```
Subject: We Hate to See You Go—Let's Chat

Hi [Name],

I received your cancellation request. Before we proceed, I'd love to understand 
what's driving this decision. Is there something we could have done better?

[3 reasons we often hear]:
- Budget constraints? → Let's explore a smaller plan or seasonal pause
- Feature missing? → We may have a roadmap item that solves this
- Onboarding friction? → Let's unblock you with training or support

I'm available for a quick call today or tomorrow: [calendar link]

If it's truly the right call, we'll respect that and make sure your data 
transition is seamless.

Best,
[CSM Name]
```

### 6.3 Save Offer Matrix

**Decision criteria: Evaluate before making an offer (to avoid leaving money on the table)**

| Scenario | Save Offer | Discount | Duration | Notes |
|----------|-----------|----------|----------|-------|
| Budget crunch (revenue concern) | Discount or Downgrade | 20–30% off OR downgrade 1 tier | 6–12 months | Offer with LTV-preserving terms |
| Feature gap (product concern) | Free trial + training | Unlock premium features free | 90 days | Demonstrate value; offer won't last |
| Onboarding barrier (usability) | Extended support + training | Free onboarding call (2–3 sessions) | Through onboarding | Cost to APEX: 2–5 hours labor |
| Inactivity (engagement drop) | Pause contract | Hold billing, keep account live | 3–6 months | Low-risk; customer re-engages |
| Competitive threat | Discount + expansion | 15–25% off + 1 premium module free | 12 months | Bundled value to win back |
| Payment/admin issue (non-product) | Waive late fees | N/A | N/A | Goodwill gesture; no discount needed |

---

## Part 7: Product Analytics & Engagement Signals

### 7.1 Recommended Analytics Stack

**To enable health scoring and playbooks, APEX should track these events and metrics:**

#### Integration Recommendation

| Data Source | Tool | Integration | Purpose |
|-------------|------|-----------|---------|
| **Product usage** | Mixpanel OR Amplitude | SDK (web) + API | Engagement, adoption, churn prediction |
| **In-app messages** | Pendo OR Appcues | SDK (web) | Feature adoption, onboarding nudges |
| **NPS / Surveys** | Sprig OR Typeform | Widget (web) + API | Customer sentiment, CSAT |
| **Support tickets** | Zendesk / Help Scout | API | Support health score |
| **Billing / Contracts** | Stripe / Zuora | API | Commercial score, renewal dates |
| **CRM** | HubSpot OR Salesforce | API | CSM tasks, account data |
| **Email** | SendGrid / Mailchimp | API | Drip campaigns, open/click rates |

#### Must-Track Events

```
[Product] Event Taxonomy

User Events:
- login (timestamp, user_id, session_id)
- screen_view (screen_name, timestamp)
- feature_use (feature_name, timestamp, action)

Engagement Events:
- copilot_message_sent (user_id, message, quality_score)
- copilot_message_used (user_id, accepted: true/false)
- export_generated (report_type, timestamp)
- api_call_made (endpoint, status_code)

Adoption Milestone Events:
- coa_uploaded (file_size, entries_count)
- tb_bound (accounting_system, sync_status)
- period_closed (month, duration_days)
- audit_engagement_created (audit_type)
- user_invited (user_count, role)

Business Events:
- invoice_generated (amount, due_date)
- payment_received (amount, status)
- payment_failed (error_code, retry_count)
- subscription_renewed (new_amount, term)
- subscription_upgraded (old_plan, new_plan, uplift_amount)
- subscription_downgraded (old_plan, new_plan, churn_amount)
- subscription_cancelled (reason)

Support Events:
- support_ticket_created (category, priority)
- support_ticket_resolved (resolution_time, satisfaction_score)
- login_failed (reason, count)
- api_error (endpoint, error_code, frequency)
```

### 7.2 Engagement Score Building

**Once events are tracked, calculate engagement score from:**

```
Daily Active Usage = (logins_today > 0) ? 1 : 0

Weekly Active Users (WAU) = COUNT(DISTINCT user_id) 
                            WHERE login_date ≥ today - 7 days

Monthly Active Users (MAU) = COUNT(DISTINCT user_id) 
                             WHERE login_date ≥ today - 30 days

Stickiness Ratio = WAU / MAU
                 (ratio of weekly to monthly active users)
                 [Target: ≥0.40 = 40% of monthly users active weekly]

Feature Breadth = COUNT(DISTINCT feature_used_last_30_days)
                  [Target: ≥8 features = comprehensive use]

Engagement Score = (
    MIN(logins_per_week / 3, 1) × 0.40 +
    MIN(stickiness / 0.40, 1) × 0.30 +
    MIN(features_used / 8, 1) × 0.20 +
    MIN(copilot_uses / 5, 1) × 0.10
) × 100
```

---

## Part 8: Key Metrics & KPIs

### 8.1 Customer Success Metrics

| Metric | Formula | Target | Why It Matters |
|--------|---------|--------|-----------------|
| **Gross Revenue Retention (GRR)** | (Revenue retained from existing customers / Starting revenue) × 100 | ≥90% | Measures churn—how much revenue stays without expansion |
| **Net Revenue Retention (NRR)** | ((Retained revenue + Expansion) / Starting revenue) × 100 | ≥120% | Gold standard for SaaS growth—expansion offsetting churn |
| **Logo Churn Rate** | (Customers churned / Starting customers) × 100 | <5% | Percentage of customer accounts lost |
| **Revenue Churn Rate** | (Revenue lost to churn / Starting revenue) × 100 | <3% | Revenue impact of churn (weighted) |
| **Onboarding Completion Rate** | (Customers reaching adoption score ≥70 by day 30 / New customers) × 100 | ≥70% | Are new customers successful? |
| **Time to First Value (TTFV)** | Days from signup to first meaningful outcome (e.g., COA uploaded) | ≤7 days | Speed to value drives retention |
| **Expansion Conversion Rate** | (Customers accepting upsell/cross-sell / Expansion-ready customers) × 100 | ≥40% | Revenue growth from existing base |
| **Customer Health Score Distribution** | % of customers in Green / Yellow / Red bands | ≥80% Green, <10% Red | Portfolio health snapshot |
| **Stickiness (DAU/MAU ratio)** | (Daily Active Users / Monthly Active Users) × 100 | ≥40% | Consistent, habitual product use |
| **Customer Acquisition Cost (CAC)** | (Sales + Marketing Spend) / New Customers Acquired | <$3,000 (SMB) | Cost efficiency of go-to-market |
| **Customer Lifetime Value (LTV)** | (ARPU × Customer Lifespan) - (CAC + CS costs) | ≥$15,000 (SMB) | Profitability per customer |
| **LTV / CAC Ratio** | LTV / CAC | ≥3:1 | Payback efficiency; >3 = healthy |
| **CAC Payback Period** | CAC / Monthly Gross Profit per Customer | ≤12 months (target: 6–7) | How fast do we recoup acquisition cost? |
| **Net Promoter Score (NPS)** | (% Promoters – % Detractors) | ≥50 | Customer satisfaction & referral likelihood |
| **Customer Satisfaction (CSAT)** | % of customers rating ≥4/5 on post-interaction survey | ≥80% | Support & service quality |
| **Renewal Rate** | (Renewals / Contracts up for renewal) × 100 | ≥95% | Contract continuity |
| **Expansion Rate** | (Customers with expansion in period / Total mature customers) × 100 | ≥40% | Revenue growth per customer |

### 8.2 Cohort Retention Curves

**Measure:** What % of a cohort of customers (month 0 = signup) still pays in month N?

```
Example:
January 2026 Cohort (started with 100 customers):
Month 0: 100 customers (100%)
Month 1: 98 customers (98% retention)
Month 3: 95 customers (95% retention)
Month 6: 92 customers (92% retention)
Month 12: 88 customers (88% retention = GRR)
Month 12 (with expansion): 105 customers (105% retention = NRR)

Target: Month 12 retention ≥88% (GRR), ≥105% (NRR)
```

### 8.3 Monthly Reporting

**CS Dashboard KPIs (monthly review):**

```
APRIL 2026 CUSTOMER SUCCESS METRICS
─────────────────────────────────────────

Portfolio Health:
├─ Active Customers: 250 (↑5 from March)
├─ Health Score Distribution:
│  ├─ Green (≥80): 210 (84%)
│  ├─ Yellow (50–79): 35 (14%)
│  └─ Red (<50): 5 (2%)
└─ At-Risk Customers: 5 (↓2 from March—good!)

Churn & Retention:
├─ Gross Revenue Retention (GRR): 92% (Target: ≥90%) ✓
├─ Net Revenue Retention (NRR): 115% (Target: ≥120%) — Need more expansion
├─ Logo Churn Rate: 1.2% (Target: <5%) ✓
├─ Revenue Churn: $8,500 (0.8% of MRR)
└─ Churn Reason Breakdown:
   ├─ Budget (40%)
   ├─ Competitive loss (25%)
   ├─ Product (20%)
   └─ Other (15%)

Onboarding & Adoption:
├─ New Customers (Month): 22
├─ Onboarding Completion Rate: 72% (Target: ≥70%) ✓
├─ Avg TTFV: 6.2 days (Target: ≤7) ✓
└─ Adoption Score (mature cohort): 76 (↑2 from March)

Engagement:
├─ DAU: 820 (↑8% from March)
├─ MAU: 1,840 (↑5% from March)
├─ Stickiness (DAU/MAU): 45% (Target: ≥40%) ✓
└─ Avg Features Used: 7.1/10 (Target: ≥8) — Near target

Expansion & Revenue Growth:
├─ Expansion Opportunities Identified: 18 (↑5 from March)
├─ Expansion Conversion Rate: 38% (Target: ≥40%) — Close!
├─ Upsell Revenue (MTD): $12,400 (↑$3,000 from March)
├─ Cross-sell Revenue (MTD): $4,200 (new module adoption)
└─ Avg Expansion Value: $910/deal

Customer Satisfaction:
├─ NPS Score: 52 (Target: ≥50) ✓
├─ CSAT Score: 78% (Target: ≥80%) — Slight dip; investigate
├─ Support Ticket Volume: 145 (↓12 from March)
└─ Avg Resolution Time: 18 hours (↓4h from March)

Renewal Pipeline:
├─ Renewals Due (next 90 days): 42
├─ Renewals Already Signed: 28 (67%)
├─ Renewals at Risk (Likelihood <70%): 4
├─ Renewal Revenue at Risk: $18,500
├─ Forecast (next 90d): $184,200 (85% collection confidence)
└─ Expansion Embedded: $7,500 (+4% to base)

Cost Efficiency:
├─ CAC: $2,800
├─ LTV: $18,200
├─ LTV/CAC Ratio: 6.5:1 (Target: ≥3:1) ✓✓
└─ CAC Payback Period: 5.2 months (Target: ≤12 months) ✓

Top Actions This Month:
1. Increase expansion conversations (NRR still below 120%)
2. Investigate CSAT dip (likely support or onboarding issue)
3. Save 4 at-risk renewals (interventions in progress)
4. Onboard expansion features to high-engagement customers
```

---

## Part 9: Customer Success Module Design for APEX

### 9.1 Internal CSM Dashboard

**Users:** APEX employees (CSMs, CS managers, VP CS)

#### Dashboard Views

1. **Customer Roster (List View)**
   - Customer name, industry, plan, CSM assigned
   - Health score (color-coded), trend arrow
   - Last login date, engagement score
   - NRR contribution, renewal date
   - Quick actions: Schedule QBR, Send message, Create task

2. **Health Score Heatmap (Portfolio View)**
   - Grid of customers colored by health (Green/Yellow/Red)
   - Segment filters: By plan tier, industry, region
   - Drill-down: Click customer → detail card

3. **Renewal Pipeline (Waterfall View)**
   - Renewals by month (next 90 days)
   - Status: Open, Proposed, Negotiating, Signed
   - At-risk flag for likely churners
   - Expansion opportunity $ per customer
   - Target: 80% signed 30 days before renewal

4. **Expansion Pipeline (Forecast View)**
   - Opportunities by stage (Identified, Pitched, Negotiating, Closed)
   - Expansion type: Upsell, cross-sell, add-on
   - Deal size, close probability, forecast date
   - Target: 40% conversion rate

5. **At-Risk Alerts (Incident View)**
   - Customers with health score <50
   - Root cause (engagement drop, payment failed, support sentiment)
   - CSM assigned, intervention in progress
   - Recommended playbook (At-Risk intervention)

6. **Cohort Retention (Trend View)**
   - Retention curve by cohort month
   - GRR / NRR tracking vs. target
   - Segment analysis: Free vs. Pro vs. Enterprise

#### CSM Task Management

```
Task List (integrated with APEX or Zapier):
- [ ] Schedule QBR with Acme Corp (due today)
- [ ] Follow up on at-risk customer (Global Ltd)
- [ ] Send expansion proposal to BigBiz Inc
- [ ] Renewal contract execution (SmallCo)
- [ ] Win-back outreach (churned customer)

Task Auto-Generated From:
├─ Health score triggers (at-risk, expansion-ready)
├─ Renewal dates (60d, 30d, 14d, 7d before)
├─ Milestone completions (onboarding, adoption)
└─ Manual CSM creation
```

### 9.2 Playbook Execution Engine (Low-Code)

**Goal:** CSMs can configure and execute playbooks without engineering.

#### Playbook Builder UI

```
[New Playbook] Form:

Name: "At-Risk Intervention"
Trigger: Health score drops below 50 for 14 consecutive days
Segment: All customers
Enabled: [YES/NO toggle]

Touchpoints:
├─ Day 1: Task to CSM
│  └─ Title: "At-Risk: [Customer] score [X]"
│  └─ Priority: High
│  └─ Assigned to: Segment rotation
├─ Day 2: Email to customer
│  └─ Template: "We noticed you're having trouble"
│  └─ Personalization: [Customer name], [Product area]
├─ Day 5: Email to customer (if no response)
│  └─ Template: "Case study: How others solved this"
├─ Day 7: Call scheduled
│  └─ Calendar invite to CSM + customer
└─ Day 14: Decision point
   └─ If no engagement: Move to Churn-Imminent playbook

Success Metrics:
├─ % of at-risk customers returning to health
├─ Avg resolution time
└─ Re-churn rate (30-day relapse)
```

### 9.3 Account Planning Tool

```
[Account Plan Template]

Customer: Acme Corp
CSM: Jane Doe
Plan Year: 2026

Executive Summary:
- Current ARR: $24,000
- Growth target: +$8,000 (expansion)
- Risk level: Green (85 health score)

Current State:
- Product adoption: 85% (all key features used)
- Team size: 8 users (room to grow)
- Billing model: Monthly (consider annual discount)

Objectives (Next 12 months):
1. Maintain engagement (email check-ins monthly)
2. Upsell Audit Module ($4,000 ARR)
3. Add 5 more seats (+$4,000 ARR)
4. Achieve annual contract (save 10%)

Tactics:
├─ Monthly check-ins (emails + Slack)
├─ Q1 QBR: Strategic alignment
├─ Q2 Proposal: Audit module demo
├─ Q3 Renewal: Conversion to annual (early renewal incentive)
└─ Q4: Expansion celebration + referral ask

Risks:
- Competitor: [Competitor X] has feature [Y]
- Budget: Re-evaluation in Q2 (confirm again in April)

Success Metrics:
- Health score: Maintain ≥80
- NRR contribution: +$8,000
- Customer satisfaction: NPS ≥8

Resources:
- Case study: [Link to Acme-like company]
- Roadmap: [Link to Q2-Q4 feature releases]
- Training: [Link to Audit module onboarding]
```

---

## Part 10: Build vs. Buy Recommendations

### 10.1 Build in APEX (MVP Phase)

**What APEX should build first (within app, minimal external tools):**

| Feature | Build | Buy | Why |
|---------|-------|-----|-----|
| Health Score Model | ✓ | - | Core IP, data already in APEX, 2–4 week sprint |
| Health Score Dashboard | ✓ | - | Leverage existing APEX architecture, simple UI |
| Engagement Score Calculation | ✓ | - | Log events already collected, no external tool needed |
| Adoption Tracking | ✓ | - | Feature flags, milestone events tracked natively |
| Basic Alerts (Slack/email) | ✓ | - | Zapier/Make integration, no code needed |
| Playbook Rules Engine | ~ | ~ | Build simple version first, evaluate platforms later |
| CSM Task Management | ~ | ✓ | Use HubSpot CRM initially, integrate via API |
| Renewal Pipeline | ✓ | - | Query contract data, simple forecasting logic |

### 10.2 Buy / Integrate (Year 1–2)

**External tools APEX should evaluate and integrate:**

| Category | Tools | Integration | Why |
|----------|-------|-----------|-----|
| **Product Analytics** | Mixpanel, Amplitude, Pendo | SDK + API | Enable heat-mapping, funnel analysis, user journeys |
| **In-App Messaging** | Pendo, Appcues, Sprig | SDK + API | Onboarding tours, feature adoption, surveys |
| **CRM** | HubSpot Sales Cloud | OAuth 2.0 | CSM account management, opportunity pipeline |
| **Email Automation** | HubSpot Workflows, Klaviyo | API | Drip campaigns, triggered sequences |
| **Survey & Sentiment** | Sprig, Typeform | Widget + API | NPS, CSAT, feedback collection |
| **Dedicated CS Platform** | Gainsight, ChurnZero, Vitally | API | Advanced health scoring, playbooks, automation (Year 2+) |

### 10.3 Platform Recommendation for APEX (Year 2+)

**When APEX scales to 500+ customers, consider a dedicated CS platform:**

#### **Gainsight** (Enterprise, $50k+/year)
- Pros: Most mature, Scorecards, Advanced playbooks, CRM integration
- Cons: Expensive, complex setup, overkill for SMB SaaS initially
- Best for: Large, complex accounts (Enterprise segment)

#### **ChurnZero** (Mid-market, $10k–$30k/year)
- Pros: Strong health scores, churn prediction, affordable
- Cons: Fewer integrations than Gainsight
- Best for: APEX fit if focus is SaaS SMB churn prevention

#### **Vitally** (Mid-market, $15k–$25k/year)
- Pros: Modern UX, AI-powered health scores, good integrations
- Cons: Newer platform, smaller customer base
- Best for: APEX if prioritizing product engagement + health scoring

---

## Part 11: Tenant-Facing (Customer) Features

### 11.1 Onboarding Checklist Widget

**In-app checklist that customers see and track themselves:**

```
🚀 Your APEX Onboarding Checklist

□ Step 1: Set up your company profile (2 min)
  └─ Industry, timezone, team size
  └─ [Complete] ✓

□ Step 2: Upload your Chart of Accounts (5 min)
  └─ Upload CSV or import from QB/SAP
  └─ [Need help?] [Upload]

□ Step 3: Connect your accounting system (3 min)
  └─ Link trial balance to APEX
  └─ [Connect]

□ Step 4: Invite your team (3 min)
  └─ Add accountants, managers
  └─ [Invite users] (2/5 invited)

□ Step 5: Run your first period close (15 min)
  └─ See APEX in action
  └─ [Start tutorial]

Progress: 1/5 completed (20%)
🎉 Estimated time to completion: 25 min
💬 Need help? Chat with our onboarding specialist

[Gamification: "You've unlocked Bronze badge!"]
```

### 11.2 Feature Adoption Hints (In-App Suggestions)

```
Context: Customer is on Trial Balance reconciliation screen, 
         but hasn't used Copilot

Hint:
┌──────────────────────────────────────────────────┐
│ 💡 Did you know?                                 │
│                                                   │
│ APEX's AI Copilot can help you find TB differences │
│ in seconds. Save 30% of your reconciliation time. │
│                                                   │
│ [Try Copilot] [Dismiss]                          │
└──────────────────────────────────────────────────┘

Trigger: (copilot_uses == 0) AND (time_on_tb_reconcile > 5 min)
```

### 11.3 "What's New" Announcements

```
APEX Release Notes – April 2026
┌──────────────────────────────────────────────────┐
│ ✨ New Features                                   │
│                                                   │
│ 1. Bulk TB Import                                │
│    Upload multiple trial balances at once        │
│                                                   │
│ 2. Copilot Insights                              │
│    AI suggests missing entries, duplicate       │
│    accounts                                      │
│                                                   │
│ 3. Mobile Audit App                              │
│    Prepare audits from anywhere                  │
│                                                   │
│ 🎯 Coming Soon: Real-time collaboration,        │
│    advanced forecasting, white-label portal      │
│                                                   │
│ [Full Release Notes] [Feedback]                  │
└──────────────────────────────────────────────────┘
```

### 11.4 Resource Library (In-App + Email)

**Contextual help based on customer segment:**

#### For SMB Customers:
- "5 tips for fast month-end close"
- "Audit prep checklist"
- "Setting up multi-entity consolidation"
- Case study: "How [peer SMB] saved 10 hours/month"

#### For Audit Firms:
- "Client communication best practices"
- "Audit fieldwork coordination templates"
- "ERP integration guide"
- Case study: "How [audit firm] doubled client retention"

#### For Enterprise:
- "Advanced reconciliation workflows"
- "Custom reporting & analytics"
- "API integrations & webhooks"
- "Advanced user management & SSO setup"

### 11.5 In-App Surveys (Pulse Checks)

**Lightweight, triggered surveys:**

```
[Post-onboarding, Day 30]
┌──────────────────────────────────────────────────┐
│ Quick question: How are you getting along?       │
│                                                   │
│ ⭐⭐⭐⭐⭐ (5 stars: Love it!)                      │
│ ⭐⭐⭐⭐ (4 stars: Pretty good)                     │
│ ⭐⭐⭐ (3 stars: It's okay)                        │
│ ⭐⭐ (2 stars: Not great)                         │
│ ⭐ (1 star: Struggling)                          │
│                                                   │
│ [Submit] [Skip]                                  │
└──────────────────────────────────────────────────┘

[After each feature use]
NPS Survey: "How likely are you to recommend APEX 
to a peer (0–10)?"

Why did you give that score?
[Open-ended feedback]

[Submit]
```

### 11.6 Feedback Widget

```
💬 Share Feedback
┌──────────────────────────────────┐
│ [Feedback form icon in corner]   │
│                                   │
│ Category:                         │
│ [Bug] [Feature request] [Other] │
│                                   │
│ Message:                          │
│ [Text box]                        │
│                                   │
│ Contact me: [Email checkbox]     │
│                                   │
│ [Submit]                          │
└──────────────────────────────────┘

Feedback routed to:
- Product team (feature requests)
- Engineering (bugs)
- CS (general feedback, CSM outreach if needed)
```

---

## Part 12: Implementation Roadmap (6–18 Months)

### Phase 0: Foundation (Weeks 1–4)

- [ ] Define health score components (stakeholder alignment)
- [ ] Audit event data in APEX (what's being logged?)
- [ ] Build simple health score calculation (SQL query)
- [ ] Create CSM dashboard (basic view: list of customers + score)
- [ ] Set up Slack alerts (basic webhook for at-risk customers)

### Phase 1: MVP (Weeks 5–12)

- [ ] Launch health score dashboard (internal CSM use)
- [ ] Implement engagement score calculation
- [ ] Implement adoption score calculation
- [ ] Create at-risk alert workflow (auto-task generation)
- [ ] Build onboarding playbook (email sequences + tasks)
- [ ] Set up Mixpanel / Amplitude event tracking (SDK)

### Phase 2: Expansion (Weeks 13–24)

- [ ] Implement adoption playbook
- [ ] Implement maturity playbook (QBR scheduling, NPS surveys)
- [ ] Build renewal pipeline dashboard
- [ ] Create renewal email drip sequences
- [ ] Integrate HubSpot CRM (CSM account management)
- [ ] Launch Pendo for in-app messaging (onboarding tour, feature hints)

### Phase 3: Automation & Intelligence (Weeks 25–36)

- [ ] Implement at-risk intervention playbook
- [ ] Implement churn-imminent playbook (save offers)
- [ ] Launch expansion playbook (upsell email sequences)
- [ ] Build expansion pipeline dashboard
- [ ] Integrate Sprig for NPS/CSAT surveys
- [ ] Advanced health score: Churn prediction model (ML)

### Phase 4: Sophistication (Months 9–18)

- [ ] Evaluate dedicated CS platform (ChurnZero, Vitally, or Gainsight)
- [ ] Migration planning (if platform selected)
- [ ] Advanced analytics: Cohort retention, LTV/CAC optimization
- [ ] Win-back campaigns (for churned customers)
- [ ] Segment-specific playbooks (Free vs. Pro vs. Enterprise)
- [ ] CSM performance analytics (territory health, productivity)

---

## Part 13: Success Metrics & Tracking

### 13.1 CS Team Goals (Quarterly)

```
Q2 2026 Goals:

OKR 1: Improve Net Revenue Retention
├─ KR 1.1: Achieve NRR ≥120% (baseline: 115%)
├─ KR 1.2: Close ≥40% of expansion opportunities (baseline: 38%)
└─ KR 1.3: Reduce revenue churn <3% (baseline: 3.2%)

OKR 2: Enhance Customer Health
├─ KR 2.1: Keep ≥85% of customers in Green band (baseline: 84%)
├─ KR 2.2: Reduce at-risk interventions by 20% (proactive vs. reactive)
└─ KR 2.3: Increase NPS to ≥55 (baseline: 52)

OKR 3: Operational Excellence
├─ KR 3.1: Achieve 95%+ renewal signing rate (baseline: 92%)
├─ KR 3.2: Reduce avg onboarding time by 15% (baseline: 22 days)
└─ KR 3.3: CSM productivity: +2 customers per CSM (scaling)

Owner: VP of Customer Success
Cadence: Weekly progress, monthly review
```

### 13.2 Dashboard Refresh Cadence

| Frequency | Owner | Audience | Focus |
|-----------|-------|----------|-------|
| **Daily** | CSM (self-serve) | CSM | At-risk alerts, daily tasks |
| **Weekly** | CSM + Manager | CSM + CS Lead | Playbook progress, health trends |
| **Bi-weekly** | Manager | CSM team | Team performance, blockers |
| **Monthly** | VP CS | Executive team | NRR, churn, renewal pipeline, OKRs |
| **Quarterly** | VP CS | Board | Strategic CS initiatives, ROI |

---

## Sources & References

### Primary Sources:
- [Gainsight: Customer Health Scores](https://www.gainsight.com/blog/customer-health-scores/)
- [ChurnZero: Customer Health Score Handbook](https://churnzero.com/guides/the-customer-health-score-handbook/)
- [Vitally: Dynamic Health Scores](https://www.vitally.io/features/health-scores)
- [Vitally: How to Create a Customer Health Score with 4 Metrics](https://www.vitally.io/post/how-to-create-a-customer-health-score-with-four-metrics)

### B2B SaaS Methodology:
- [Vitally: Build vs Buy Customer Health Scoring](https://churnassassin.com/blog/customer-health-scoring-for-b2b-saas-companies-build-vs-buy)
- [HubSpot: Customer Health Score Basics](https://blog.hubspot.com/service/customer-health-score)
- [UserPilot: Customer Health Score for SaaS](https://userpilot.com/blog/customer-health-score/)

### Retention & Churn Metrics:
- [ChartMogul: Net Revenue Retention Benchmarks](https://chartmogul.com/saas-metrics/nrr/)
- [Fullview: NRR Calculator & Benchmarks](https://www.fullview.io/blog/net-retention-rate-for-saas)
- [Stripe: Net Revenue Retention Guide](https://stripe.com/resources/more/net-revenue-retention)

### Churn Prediction & ML:
- [Emerald Publishing: Churn Prediction with Machine Learning](https://www.emerald.com/inmr/article/22/2/130/1251238/Churn-prediction-for-SaaS-company-with-machine)
- [ChurnAssassin: Building a Churn Prediction Model](https://churnassassin.com/blog/how-to-build-a-saas-churn-prediction-model-for-customer-churn-analysis)

### Lifecycle & Playbooks:
- [Gainsight: Customer Lifecycle Stages](https://www.gainsight.com/essential-guide/the-customer-journey-and-lifecycle/)
- [ZapScale: Six Crucial Stages of Customer Success Lifecycle](https://www.zapscale.com/blog/customer-success-lifecycle)
- [ChurnZero: Customer Success Playbooks](https://churnzero.com/features/customer-playbooks/)

### Renewal & Expansion:
- [Cacheflow: Renewal Management Software](https://www.getcacheflow.com/renewal-management-software)
- [HubiFi: SaaS Renewals Guide](https://www.hubifi.com/blog/renewal-management-strategies)
- [Vitally: Expansion Revenue Components](https://www.vitally.io/post/upselling-cross-selling-and-renewals-comparing-3-vital-components-of-expansion-revenue)
- [UserPilot: Account Expansion for B2B SaaS](https://userpilot.com/blog/account-expansion-saas/)

### QBR & Strategic Engagement:
- [Gainsight: Quarterly Business Reviews Guide](https://www.gainsight.com/essential-guide/quarterly-business-reviews-qbrs/)
- [ChurnZero: QBRs in Customer Success](https://churnzero.com/blog/quarterly-business-reviews/)
- [Custify: QBR for SaaS](https://www.custify.com/blog/qbr-saas-customer-success/)

### Product Analytics & Engagement:
- [UserPilot: Pendo vs Amplitude](https://userpilot.com/blog/pendo-vs-amplitude/)
- [UserPilot: Heap vs Amplitude vs Mixpanel](https://userpilot.com/blog/heap-vs-amplitude-vs-mixpanel-for-product-analytics/)
- [Pendo: Best Product Analytics Tools](https://www.pendo.io/pendo-blog/top-10-product-analytics-tools/)

### Time to Value & Onboarding:
- [Monetizely: Time to First Value (TTFV) Explained](https://www.getmonetizely.com/articles/how-to-calculate-time-to-first-value-ttfv-the-critical-metric-for-saas-success/)
- [AlexanderJarvis: Improving TTFV](https://www.alexanderjarvis.com/what-is-time-to-first-value-in-saas-how-to-improve-it/)

### Unit Economics & Metrics:
- [Chargebee: LTV/CAC Ratio Guide](https://www.chargebee.com/resources/glossaries/ltv-cac-ratio/)
- [HBS Online: LTV/CAC Ratio Explained](https://online.hbs.edu/blog/post/ltv-cac)
- [SarasAnalytics: CAC Payback Period Guide](https://www.sarasanalytics.com/blog/cac-payback-period)

### Drip Campaigns & Automation:
- [Monday.com: Drip Campaigns for Conversions](https://monday.com/blog/monday-campaigns/drip-campaigns/)
- [SmashSend: B2B SaaS Email Drip Campaign Examples](https://smashsend.com/blog/email-drip-campaign-examples)
- [Salesforce: Drip Marketing Automation](https://www.salesforce.com/marketing/email/drip-marketing/)

### AARRR Pirate Metrics:
- [UserPilot: Pirate Metrics for Product-Led SaaS](https://userpilot.com/blog/pirate-metrics-saas/)
- [PostHog: AARRR Pirate Funnel Explained](https://posthog.com/product-engineers/aarrr-pirate-funnel)

---

## Appendix: Health Score Implementation SQL (PostgreSQL)

```sql
-- APEX Health Score Calculation (Weekly Job)

WITH latest_events AS (
  -- Engagement: logins, screens, copilot use (last 30 days)
  SELECT 
    tenant_id,
    COUNT(DISTINCT DATE(login_at)) AS login_days,
    ROUND(COUNT(DISTINCT DATE(login_at))::numeric / 4, 1) AS logins_per_week,
    COUNT(DISTINCT screen_name) AS unique_screens,
    COUNT(DISTINCT CASE WHEN feature = 'copilot' THEN id END) AS copilot_uses
  FROM events
  WHERE event_type IN ('login', 'screen_view', 'copilot_message')
    AND event_at >= NOW() - INTERVAL '30 days'
  GROUP BY tenant_id
),

adoption_milestones AS (
  -- Adoption: COA, TB, period close, audit, team members
  SELECT
    tenant_id,
    (CASE WHEN coa_uploaded_at IS NOT NULL THEN 20 ELSE 0 END) +
    (CASE WHEN tb_bound_at IS NOT NULL THEN 20 ELSE 0 END) +
    (CASE WHEN last_period_closed_at IS NOT NULL THEN 15 ELSE 0 END) +
    (CASE WHEN audit_count > 0 THEN 10 ELSE 0 END) +
    (CASE WHEN team_member_count >= 2 THEN 10 ELSE 0 END) +
    (CASE WHEN profile_complete THEN 15 ELSE 0 END) AS adoption_score_raw
  FROM accounts
),

commercial_health AS (
  -- Commercial: payment status, utilization, renewal
  SELECT
    tenant_id,
    (CASE WHEN last_payment_status = 'paid' THEN 40 ELSE 20 END) +
    (CASE WHEN plan_utilization >= 0.70 THEN 30
          WHEN plan_utilization >= 0.40 THEN 15
          ELSE 0 END) +
    (CASE WHEN days_until_renewal > 90 THEN 20
          WHEN days_until_renewal > 30 THEN 10
          ELSE 5 END) AS commercial_score_raw
  FROM subscriptions
),

support_metrics AS (
  -- Support: tickets, login failures, API errors
  SELECT
    tenant_id,
    100 - (
      (support_tickets_30d * 15) +
      ((100 - resolution_rate) * 0.20) +
      (login_failures_30d * 10) +
      (api_errors_30d * 2)
    ) AS support_score_raw
  FROM support_stats
),

risk_signals AS (
  -- Risk: no login, declining trends, payment issues
  SELECT
    tenant_id,
    MIN(
      (CASE WHEN days_since_login >= 30 THEN 1.0
            WHEN days_since_login >= 14 THEN 0.60
            WHEN days_since_login >= 7 THEN 0.40
            ELSE 0 END) +
      (CASE WHEN login_trend_30d < -0.50 THEN 0.25 ELSE 0 END) +
      (CASE WHEN transaction_trend_30d < -0.50 THEN 0.25 ELSE 0 END) +
      (CASE WHEN failed_payments_30d >= 2 THEN 0.35 ELSE 0 END),
      1.0
    ) AS risk_score_raw
  FROM engagement_trends
),

composite_score AS (
  SELECT
    le.tenant_id,
    (
      (COALESCE(le.logins_per_week / 3.0, 0) * 0.40 +
       COALESCE(le.unique_screens / 8.0, 0) * 0.30 +
       COALESCE(le.copilot_uses / 5.0, 0) * 0.20) * 100
    ) * 0.25 +
    (COALESCE(am.adoption_score_raw, 0) / 100) * 25 +
    (COALESCE(ch.commercial_score_raw, 0) / 100) * 30 +
    (COALESCE(GREATEST(sm.support_score_raw, 0), 0) / 100) * 10 +
    ((1 - COALESCE(rs.risk_score_raw, 0)) * 100) * 0.10 AS health_score
  FROM latest_events le
  LEFT JOIN adoption_milestones am ON le.tenant_id = am.tenant_id
  LEFT JOIN commercial_health ch ON le.tenant_id = ch.tenant_id
  LEFT JOIN support_metrics sm ON le.tenant_id = sm.tenant_id
  LEFT JOIN risk_signals rs ON le.tenant_id = rs.tenant_id
)

INSERT INTO customer_health_scores (tenant_id, score, calculated_at)
SELECT tenant_id, ROUND(health_score, 0), NOW()
FROM composite_score
ON CONFLICT (tenant_id, calculated_at::DATE)
DO UPDATE SET score = EXCLUDED.score;
```

---

## Conclusion

This blueprint provides APEX with a **production-ready customer success operations framework** aligned to B2B SaaS best practices. Implementation should follow the phased roadmap, starting with health score calculation and CSM dashboarding (MVP), then adding playbooks, analytics, and automation over 6–18 months.

**Immediate next steps:**
1. **Week 1:** Stakeholder alignment on health score model
2. **Week 2:** Event data audit (confirm what's being logged)
3. **Week 3–4:** SQL queries for score calculation
4. **Week 5–8:** CSM dashboard MVP launch
5. **Week 9–12:** Onboarding playbook activation

**Success indicators:**
- NRR increasing from ~115% → 120%+ within 6 months
- At-risk customer remediation rate ≥70%
- Onboarding completion ≥70% within 30 days
- CSM utilization: +2 customers per CSM (from 25 → 27 customers)

