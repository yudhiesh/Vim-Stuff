---
name: pr-ready-gate
description: Run a strict pre-review readiness gate for pull requests and return a go/no-go decision with required fixes. Use when a team is preparing to move a PR from Draft to Ready for Review, or asks for a final quality, risk, and reviewer-readiness check.
---

# PR Ready Gate

## Objective

Decide whether a PR is ready to move from Draft to Ready for Review, and list only the fixes required to pass.

## Inputs

Collect:
- PR URL or repo + PR number
- target branch
- linked ticket/spec (if any)
- expected test scope (unit/integration/e2e/manual)
- risk level (low/medium/high)

If the PR is not provided, resolve from current branch.

## Gate Workflow

1. Verify scope and intent.
- Confirm PR goal matches linked ticket/spec.
- Flag scope creep or mixed unrelated changes.

2. Check change quality.
- Identify behavioral regressions, correctness risks, and unsafe migrations.
- Prioritize findings over style nits.
- Require clear naming and maintainable boundaries.

3. Check tests and validation.
- Verify changed behavior is covered by tests.
- Verify critical paths have regression coverage.
- Verify lint/type/test commands pass or document exact failures.

4. Check operability and safety.
- Confirm config, secrets, migrations, and rollout/rollback steps are safe.
- Confirm observability impact (logs/metrics/alerts) for risky changes.
- Flag missing runbooks or deployment notes when needed.

5. Check reviewer readiness.
- Ensure PR description explains what changed, why, risk, and validation evidence.
- Ensure commit history is reviewable or explicitly justified.
- Ensure screenshots/logs/output are attached when relevant.

6. Return verdict.
- `READY`: safe to convert to Ready for Review.
- `NOT_READY`: keep Draft; provide required fixes only.

## Output Contract

Always return:
1. `Verdict`: READY or NOT_READY
2. `Blocking findings` (ordered by severity, with file references)
3. `Required fixes before Ready`
4. `Non-blocking improvements` (optional)
5. `Validation summary` (what passed/failed/not run)
6. `Reviewer handoff note` (2-5 bullets reviewers should know)

## Severity Rules

- `P0`: release/safety/data-loss/security risk
- `P1`: correctness or major regression risk
- `P2`: maintainability/test gap likely to cause breakage
- `P3`: minor quality improvement

A PR is `NOT_READY` if any P0/P1 exists, or if validation evidence is missing for risky changes.

## Guardrails

- Do not approve based on green CI alone.
- Do not block on low-value style-only issues.
- Do not hide uncertainty; call out assumptions explicitly.
- Prefer minimal, high-leverage fixes that unblock review quality quickly.

## Recommended Default

If signals conflict, default to `NOT_READY` with concrete remediation steps.
