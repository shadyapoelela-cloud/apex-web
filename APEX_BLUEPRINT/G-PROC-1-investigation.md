# G-PROC-1 Phase 1 — Process Root Cause Investigation

**Status:** Investigation only. **No code changes in this PR.**
**Sprint:** 9, week 1.
**Predecessor:** G-T1.7 (Sprint 8) — surfaced the original "21:1 source:test ratio" finding that motivated this gap.
**Follow-up:** Phase 2 PR will implement the chosen control(s) from § G after user approval.

---

## A. Updated ratio (post-Sprint 8)

### A.1 Sprint 7 window (2026-04-24 → 2026-05-01) — original window

Original G-T1.7 finding: "21:1 source:test ratio in `app/ai/` + `app/core/`."

**Verify-first refinement during this investigation:**

| Scope | Source lines | Test lines | Ratio |
| --- | ---: | ---: | ---: |
| `app/ai/` + `app/core/` only, matched test files (G-T1.7's original framing) | 15,053 | 743 | **20.3:1** |
| `app/` (full backend) + matched test files | ~17,300 | 743 | **23:1** |
| `app/` + `apex_finance/lib/` (full hand-written source) | **77,679** | **1,628** *(all `tests/`)* | **47.7:1** |

The original "21:1" was correct for the narrow scope (ai/core matched-tests).
The **global hand-written-source / hand-written-tests ratio is 47.7:1** — about **2.3× worse** than the original framing because:
1. The **frontend** (`apex_finance/lib/`) added 60,340 lines in Sprint 7 — nearly 4× the backend addition.
2. **Frontend has near-zero test budget** today (G-T1.1 blocker — `package:web` 1.1.1 vs Flutter 3.27.4 prevents widget tests for screens that pull `api_service.dart`).
3. So most of Sprint 7's source code didn't even have a *path* to tests — the tooling was broken.

### A.2 Sprint 8 window (2026-05-01 onward)

| Scope | Source lines | Test lines | Ratio |
| --- | ---: | ---: | ---: |
| `app/` + `apex_finance/lib/` | ~92 | ~120 | **0.8:1** |
| Tests already exceed source. |

Sprint 8 was a **discipline-restoration** sprint: 8 of 10 merged PRs added zero source code (docs, config, refactor only). The 2 PRs that did add source (G-S2: 43 dart lines + 71 test lines; G-A2.1: 49 dart lines as part of a `git mv`) had **healthier or zero source-leaning** ratios. The pattern can be reversed when discipline is enforced.

### A.3 Why the headline ratio matters

The ratio is **leading**, not trailing — it predicts coverage decay months before the cascade gate fires. Sprint 7's 47.7:1 produced a directly-observable −29.7pp decay in `app/ai/` and −13.3pp in `app/core/` over 7 days. At that pace the global CI gate (`--cov-fail-under=55`) hits its floor in ~14 days from 2026-05-01 — that is the deadline this gap must beat.

---

## B. Top-30 file churn (Sprint 7 window)

Raw `git log --numstat` totals were misleading: **99.1% of all line additions were Flutter build artifacts** (`docs/main.dart.js` alone = 9.5M lines added).

Bucketed by category (after excluding artifacts):

| Bucket | Lines added | % of non-artifact |
| --- | ---: | ---: |
| `apex_finance/lib/` (Flutter app code) | 60,340 | 47.6% |
| `APEX_BLUEPRINT/` (docs) | 47,655 | 37.6% |
| `app/` (backend) | 17,339 | 13.7% |
| `tests/` | 1,628 | 1.3% |
| `config` (toml/yaml/yml/json) | 202 | 0.2% |

**Top 15 hand-written code files** (excluding artifacts and pure-docs):

| Total churn | Added | Path | Type |
| ---: | ---: | --- | --- |
| 5,088 | 3,595 | `apex_finance/lib/pilot/screens/setup/je_builder_live_v52.dart` | feature screen |
| 4,017 | 2,590 | `apex_finance/lib/screens/operations/sales_invoices_screen.dart` | feature screen |
| 3,044 | 2,569 | `apex_finance/lib/widgets/apex_list_toolbar.dart` | shared widget |
| 2,336 | 74 | `apex_finance/lib/main.dart` | bootstrap (G-A1 split) |
| 2,214 | 2,214 | `apex_finance/lib/core/apex_magnetic_shell.dart` | core layout |
| 1,702 | 1,164 | `apex_finance/lib/pilot/tenant_tree_picker.dart` | feature widget |
| 1,390 | 695 | `apex_finance/lib/screens/operations/financial_ops_hub_screen.dart` | feature screen |
| 1,349 | 1,349 | `apex_finance/lib/screens/lab/innovation_lab_screen.dart` | feature screen |
| 1,155 | 1,114 | `app/ai/routes.py` | backend routes |
| 1,029 | 1,029 | (rounded — see top-30 in raw output) | — |
| ... | ... | ... | ... |

### B.1 Build-artifact leak — separate process gap (note, not in scope)

The top 9 churn entries are Flutter compiled outputs (`docs/main.dart.js`, `apex_finance/build/web/main.dart.js`, `canvaskit/*.symbols`, etc.) that account for **16.3M of 16.4M** total churn lines.

`.gitignore` analysis:
- `apex_finance/build/` IS in `.gitignore`, but the files are **already tracked** (legacy commits from before the rule was added). New edits sometimes land because git only ignores untracked files.
- `docs/` is **intentionally tracked** — used for GitHub Pages deployment. Comment in `.gitignore` says: *"Flutter build outputs (deployed via GH Pages from `docs/` — still tracked there, not in `build/`)."*

**Implication for G-PROC-1:** the GH Pages deploy artifact in `docs/` is a *legitimate* but high-noise commit pattern. Any test-budget metric that uses raw line totals will be dominated by this and produce false alarms. **Test-budget controls must filter `docs/`, `apex_finance/build/`, `*.symbols`, and similar from line counts before evaluating ratios.**

A separate gap (suggested: **G-PROC-2 — separate `docs/` deploy from main repo via gh-pages branch**) is worth opening if the deploy artifact volume continues to confuse signal. Not blocking G-PROC-1 Phase 2.

---

## C. Line classification (top 10 hand-written file additions)

Sampled the top-10 hand-written files:

| File | Type | Hand-written? | Tests? |
| --- | --- | --- | --- |
| `je_builder_live_v52.dart` | Feature screen (Journal Entry builder) | Yes, complex | None matching |
| `sales_invoices_screen.dart` | Feature screen | Yes | None matching |
| `apex_list_toolbar.dart` | Shared widget | Yes | None matching |
| `apex_magnetic_shell.dart` | Core layout primitive | Yes | None matching |
| `tenant_tree_picker.dart` | Feature widget | Yes | None matching |
| `financial_ops_hub_screen.dart` | Hub screen | Yes | None matching |
| `innovation_lab_screen.dart` | Feature screen | Yes | None matching |
| `app/ai/routes.py` | Backend routes (Copilot agent + tax timeline) | Yes | Partial — `tests/test_tax_timeline.py` covers ~1 endpoint of ~12 |
| `app/core/workflow_engine.py` | Backend service (G-T1.7b target) | Yes | **None** — 23.7% covered |
| `app/core/api_keys.py` | Backend service (G-T1.7b target) | Yes | **None** — 31.9% covered |

**Classification:**
- **0%** generated boilerplate (no `*.g.dart`, no auto-routes)
- **~5%** scaffolding (basic Stateful/Stateless wrappers)
- **~95%** hand-written feature code

Insight: Sprint 7's growth was almost entirely real feature code. The decay isn't a quirk of generators — it's a real accumulation of untested business logic.

---

## D. PR audit — last 10 merged PRs (Sprint 8 window)

| PR | Title (truncated) | Source +/− | Tests +/− | Ratio | Has tests? |
| ---: | --- | ---: | ---: | ---: | :---: |
| #118 | G-A2.1 V4→V5 migration | dart=49 | 0 | inf | ❌ (refactor — no logic) |
| #117 | G-T1.3 cov-fail-under sync | 0 | 0 | n/a | n/a (config) |
| #116 | G-T1.7 floor recalibration | 0 | 35 (Py) | 0.0 | ✅ |
| #115 | G-T1.6 obviated docs | 0 | 0 | n/a | n/a (docs) |
| #114 | G-T1.4 tax_timeline fix | 0 | 9 (Py) | 0.0 | ✅ |
| #113 | G-DEV-1 local runbook | 0 | 0 | n/a | n/a (docs) |
| #112 | **G-S2 auth-guard** | dart=43 | dart=71 | **0.6:1** | ✅ **best** |
| #111 | G-T1.2 test_flutter_files | 0 | 11 (Py) | 0.0 | ✅ |
| #110 | G-DOCS-1 blueprint audit | 0 | 0 | n/a | n/a (docs) |
| #109 | G-B2 SMS docs (Sprint 7) | 0 | 0 | n/a | n/a (docs) |

Counts:
- PRs adding `> 100 source lines` with proportional tests: **0**
- PRs adding `> 100 source lines` without tests: **0**
- PRs adding `> 30 source lines`: 2 (#118 49 dart, #112 43 dart)
- PRs whose source-only additions had **at least 1:1 test coverage**: 1 (#112 G-S2 — *because we deliberately wrote 7 widget tests with 71 lines for a 43-line auth_guard.dart*)

**Insight:** Sprint 8 was almost entirely zero-source PRs. **The 21-30:1 ratio pattern of Sprint 7 was not present in Sprint 8 — but only because Sprint 8 wasn't shipping features.** The first Sprint-9 PR that adds a real feature will be the test of whether the discipline survives without a process control.

---

## E. Existing CI / process gates

| Gate | Where | What it does | Reactive or Proactive? |
| --- | --- | --- | --- |
| `--cov-fail-under=55` | `.github/workflows/ci.yml:86` | Fails CI if global coverage < 55% | **Reactive** — only catches aggregate decay |
| `fail_under = 55` | `pyproject.toml [tool.coverage.report]` | Same gate, local | Reactive |
| Per-directory floors | `tests/test_per_directory_coverage.py` | 23 directory-specific floors | Reactive — runs against `main`, not PR diff |
| Black format | `ci.yml` (Black format check step) | Refuses unformatted Python | Proactive style-only |
| Ruff lint | `ci.yml` (Ruff step) | **Non-blocking** (`\|\| echo "::warning"`) | Advisory only |
| Bandit security | `ci.yml` (Bandit step) | Static security scan | Proactive |
| **Test-budget enforcement** | — | — | **NOT PRESENT** |
| **PR-level coverage delta** | — | — | **NOT PRESENT** |
| **Per-directory gate on PR diff** | — | — | **NOT PRESENT** |
| **PR template** | — | — | **NOT PRESENT** (`.github/` has only `agents/` + `workflows/`) |
| **CODEOWNERS** | — | — | **NOT PRESENT** |

**Summary of E:** the only test/coverage controls today are **post-merge global gates**. There is **no PR-level proactive control** — a PR can merge that drops `app/core/` coverage by 5% in a single commit and no gate fires until the next `main` cascade run. By then the source is in `main` and the pressure is on the *next* PR to write the missing tests.

---

## F. Root cause hypothesis

**Hypothesis (chosen, with evidence):**

The 47.7:1 Sprint 7 source:test ratio is the joint result of three interacting failures:

1. **No PR-level test-budget signal.** A developer writing 500 lines of Dart in a screen has no automated nudge to write a corresponding test. The `--cov-fail-under=55` gate is global and post-merge — it can be silently used as a "buffer" until the buffer is gone (which it now nearly is — 58.25% actual vs 55% gate, 3.25pp headroom, decaying −2.65pp/week).

2. **Flutter test infra blocker (G-T1.1).** Even a developer who *wants* to write widget tests for a screen pulling `api_service.dart` cannot — `package:web` 1.1.1 vs Flutter 3.27.4 makes those tests fail to compile. The 60K Sprint-7 frontend lines had no realistic path to tests *at all*. This is structurally unfixable inside G-PROC-1; G-T1.1 must ship in parallel for any frontend-test-budget rule to be enforceable.

3. **Documented vs undocumented PR culture mismatch.** The 4 documented Sprint 7 Waves (Wave 1 OAuth, Wave 11 ZATCA, Wave 13 Bank Feeds, Wave SMS) **all have proper test budgets** and are NOT in any failing files list. The decay comes from **20+ undocumented squash-merged feature commits** on 2026-04-27 → 04-29. Pattern: *what gets a PR description gets a test budget; what gets squash-merged in a flurry doesn't.* PR descriptions correlate with test discipline because the act of writing one creates a moment to ask "what tests cover this?".

The first failure (no PR-level signal) is what G-PROC-1 Phase 2 should fix. The second (G-T1.1) is a separate gap and remains a hard prerequisite for any *frontend* test-budget rule. The third (documented vs undocumented) is what a PR-template control would address.

---

## G. Proposed process controls (5 options, ranked)

Each option includes implementation cost, friction per PR, false-positive estimate, and a bypass mechanism (legitimate refactors / docs PRs / hotfixes must NOT be blocked).

### G.1 — `pytest-cov` PR-diff gate (RECOMMENDED)

**Description:** Add a CI step that computes coverage **on the diff** of the PR, using `diff-cover` or `pytest --cov + diff-cover`. Fails CI if the PR's added lines are < 70% covered (configurable). Doesn't care about pre-existing untested code, only about new code.

**Implementation cost:** ~3-4 hours
- Install `diff-cover` in CI deps
- Add a `Coverage on diff` step after `Run tests with coverage`
- Threshold: 70% on diff (well above the 55% global floor — encourages new code to be better than legacy)
- Add `[skip-coverage-gate]` PR-description marker for legitimate exceptions

**Friction per PR:** Low for typical feature PRs (tests proportional to code). High for docs-only PRs that touch one source line incidentally — needs the bypass marker.

**False positive rate:** ~5-10%. Most are docs PRs that touch a `__doc__` string in source. Bypass marker fixes those.

**Bypass:** `[skip-coverage-gate]` in PR description body — checked via `gh pr view --json body`.

**Why recommended:** directly addresses root cause #1 (no PR-level signal), is the smallest change that makes a measurable difference, and has prior art (Codecov, diff-cover, GitHub-native).

---

### G.2 — PR template with required "Tests added" checkbox

**Description:** `.github/pull_request_template.md` with a mandatory checklist:
```
## Test budget
- [ ] This PR adds production code (`app/`, `apex_finance/lib/`)
- [ ] If yes: this PR also adds tests covering the new code, OR
- [ ] If no tests: justify (refactor / config / docs / hotfix)
```
CI step that greps the PR body for the checkboxes — fails if production-code-without-tests is selected without a justification.

**Implementation cost:** ~2 hours.

**Friction per PR:** Medium. Forces a checklist on every PR, even trivial ones.

**False positive rate:** ~15-25% (forgotten checkbox). Reduces over time as developers internalize.

**Bypass:** Justification field is free-text — never *blocks* a PR, only gates merge until the box is filled.

**Why useful but not standalone:** addresses root cause #3 (documented vs undocumented), but easily ignored if no enforcement. Best paired with G.1.

---

### G.3 — Per-directory floor on PR diff

**Description:** Take the existing `tests/test_per_directory_coverage.py` and run it against the PR's coverage report. Refuses merge if the PR drops any directory below its floor.

**Implementation cost:** ~4-6 hours
- Adapt `test_per_directory_coverage.py` to accept a "before" + "after" coverage.json
- New CI step that runs the test on the PR
- Already-failing directories (`ai/`, `core/` per G-T1.7) don't count — only deltas

**Friction per PR:** Low for most PRs. High for PRs that touch a low-coverage directory (`pilot/`, `phase5/`) without adding tests.

**False positive rate:** ~5%.

**Bypass:** Same `[skip-coverage-gate]` marker as G.1.

**Why useful:** addresses the same root cause as G.1 but with finer granularity — would have caught Sprint 7's `app/core/workflow_engine.py` (219 missing stmts) the day it was added.

**Why not chosen alone:** the per-directory test runs pytest as a subprocess (~5 min); running it on every PR doubles CI time. G.1 (diff-cover) gives 80% of the value at 30% of the runtime cost.

---

### G.4 — CODEOWNERS for high-risk paths

**Description:** Add `.github/CODEOWNERS`:
```
/app/core/                 @critical-path-owner
/app/ai/                   @critical-path-owner
/app/auth/                 @critical-path-owner
/apex_finance/lib/core/    @critical-path-owner
```
Forces an explicit review on critical-path changes. Doesn't gate on tests, but slows down "ship now, test later" by injecting a human checkpoint.

**Implementation cost:** ~1 hour (file creation + branch protection setup in GitHub UI).

**Friction per PR:** Variable. Low if owner is responsive. High if owner is sole-maintainer and on vacation.

**False positive rate:** None — it's an approval gate, not a test gate.

**Bypass:** Org-admin override on GitHub UI.

**Why useful:** complements coverage gates with human judgment. Prevents another Sprint 7 squash-merge flurry by ensuring at least one pair of eyes per critical-path commit.

---

### G.5 — Lower-effort alternative: PR-description grep

**Description:** Lightest-weight version of G.2. CI step greps the PR body for the strings `"test"`, `"tests"`, `"coverage"`, OR a justification keyword like `"docs-only"` / `"refactor-only"` / `"hotfix"`. Fails if production-code is added (>30 lines in `app/` or `apex_finance/lib/`) and none of the strings appear.

**Implementation cost:** ~1 hour.

**Friction per PR:** Very low. Most real PRs already mention tests in the description.

**False positive rate:** ~10-20%.

**Bypass:** Just write "no tests — refactor only" in the PR body.

**Why useful:** the cheapest possible gate, gives ~50% of G.1's value for 25% of the implementation cost.

**Why not standalone:** trivially gameable (anyone can write "test" in the body without actually adding tests). Best as a tripwire before G.1 lands.

---

## H. Recommended Phase 2 scope

**Recommendation: G.1 + G.2 (combined).**

| Phase 2 PR | Effort | Description |
| --- | --- | --- |
| **a. PR-diff coverage gate** (G.1) | 3-4 hours | Adds `diff-cover` to CI, gates at 70% on PR diff with `[skip-coverage-gate]` bypass. The hard control. |
| **b. PR template** (G.2) | 2 hours | Adds `.github/pull_request_template.md` with test-budget checklist. The cultural control. |

Both deliverables fit in **one Phase 2 PR** (~5-6 hours total). They reinforce each other: the PR template asks the developer about tests *before* CI runs; the diff-coverage gate enforces the answer.

**Deferred (not in Phase 2):**
- **G.3** (per-directory PR-diff gate) — wait for G.1's effectiveness data; if G.1 catches >80% of regressions, G.3 is overhead without gain.
- **G.4** (CODEOWNERS) — separate concern (organizational, not technical). Worth opening as **G-PROC-3** if you want it. Doesn't block G-PROC-1 closure.
- **G-PROC-2** (separate `docs/` deploy from main repo) — the GH Pages artifact noise is real but secondary. Open as standalone gap.

**Risk assessment for Phase 2:**

| Risk | Mitigation |
| --- | --- |
| `diff-cover` slows CI noticeably | Runs in parallel to existing `pytest --cov` step; should add < 30s |
| Frontend lines (G-T1.1 blocker) cause false positives | `diff-cover` is path-aware — exclude `apex_finance/lib/**/*.dart` from gate UNTIL G-T1.1 ships, then re-enable |
| PR-template checklist friction frustrates contributors | Justification field is free-text; gate fails only if production-code is added AND none of "test"/"tests"/"refactor"/"docs"/"hotfix" appears in the body |
| Existing PRs in flight when Phase 2 lands break CI | Apply only to PRs opened *after* Phase 2 merges (use `github.event.pull_request.created_at`) |

---

## Summary

| Question | Answer |
| --- | --- |
| Was the original "21:1" finding accurate? | Narrow yes (ai/core matched-tests). Globally **47.7:1** — worse. |
| Has Sprint 8 reversed it? | **Yes.** 8 of 10 PRs added zero source. The 2 source PRs had healthy ratios. |
| Why did it happen? | (1) No PR-level test signal. (2) G-T1.1 makes frontend tests impossible. (3) Documented vs undocumented PR culture. |
| Which control should Phase 2 ship? | **G.1 (diff-cover) + G.2 (PR template)** in one PR. ~5-6 hours. |
| What about G-T1.1? | Blocks frontend test-budget enforcement. Must ship in parallel for any frontend rule to bite. |
| Deadline? | CI `--cov-fail-under=55` hits floor in ~14 days from 2026-05-01 at the −2.65pp/week pace. Phase 2 must beat it. |

---

**Awaiting user approval on:**
1. Combined G.1 + G.2 scope, OR a different combination
2. Whether to open G-PROC-2 (`docs/` deploy separation) and G-PROC-3 (CODEOWNERS) as separate gaps now, or hold
3. Phase 2 PR ordering relative to G-T1.7a (which is the "ai/ coverage push" — same Sprint 9 priority queue)
