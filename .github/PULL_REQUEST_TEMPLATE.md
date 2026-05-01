## What this PR does
<!-- 1-2 sentences. Link to issue/gap if applicable. -->

## Type
<!-- Check ALL that apply -->
- [ ] feat (new feature)
- [ ] fix (bug fix)
- [ ] refactor (no functional change)
- [ ] docs (documentation only)
- [ ] test (test additions/improvements)
- [ ] chore (build/CI/tooling)
- [ ] proc (process/CI/governance — adds tests indirectly via tooling)
- [ ] hotfix (emergency, post-mortem to follow)

## Test budget
<!-- Required: explain test strategy. CI will verify. -->
- [ ] Tests added for new code paths
- [ ] Existing tests cover the change (link them)
- [ ] Refactor only — behavior unchanged (no new tests needed)
- [ ] Docs/config only — no test impact
- [ ] Hotfix — tests in follow-up PR within 48h

<!-- If none of the above apply, explain in 1-2 sentences. -->

## Verification
- [ ] `pytest tests/ -x` passes locally
- [ ] `flutter analyze` shows no new issues (frontend changes only)
- [ ] `flutter test` passes locally (frontend changes only)

## Risk
<!-- Blast radius: what could break? -->

## Bypass diff-cover gate?
<!-- If you need to skip the PR-diff coverage gate, add the
     label `skip-coverage-gate` AND explain here why. -->
