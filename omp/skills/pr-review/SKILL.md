---
name: pr-review
description: Entry point for reviewing a Python pull request. Use this skill whenever asked to review a PR, review a diff, pre-review changes before merge, or check a branch for issues — whether the request comes from a person ("review this PR") or an automated CI agent. This skill inspects what the diff actually changes and loads the matching specialist review skills. Always start here for any code review task on a Python codebase.
---

# PR Review — Dispatcher

This is the routing entry point for reviewing a Python pull request. Its only job is to look at
what the diff changes and load the right specialist skills. It contains no review rules of its
own — the rules live in the specialists.

## How to route

Inspect the changed files and hunks in the diff. Classify by **what the diff actually changes**,
not by what kind of repo it is (repo type is at most a secondary hint — a PR in an API service may
touch only a migration and some calculation logic and zero routes). Then load skills as follows:

### Always load
- **`pr-review-contracts`** — the base ruleset. Typed boundaries, error/status contracts,
  idempotency, fail-fast config, branch-covering tests, PR scope/defer, migration safety, data
  persistence contracts, external-service seams, and the Review Output Format that governs how
  every finding is delivered. Load it for every review.

### Load when the diff touches HTTP/API code
- **`pr-review-api`** — load when changed files are routes/endpoints/handlers/middleware, or the
  diff adds or changes HTTP status codes, route decorators/prefixes, request/response models, or
  pagination/input bounds. Signals: route or router modules, `@app.`/`@router.` decorators,
  `HTTPException`, status codes, `Query(...)`/`Path(...)` params, async request handlers.

### Load when the diff touches business-output code
- **`pr-review-domain-logic`** — load when the diff changes logic whose output feeds a business or
  model decision: scoring, recommendation/ranking, financial calculations, fallback/default-value
  behavior, status publication, pipeline completion state, artifact pointers, persisted extracted
  data, or evaluation/winner-selection code. Because "business output" is defined by what the code
  *means* rather than where it lives, err toward loading this whenever the diff changes any
  conditional, fallback, return-value, status, or persistence logic that isn't obviously plumbing —
  the skill's meta-principle then filters what actually matters.

### Load when the diff touches data pipelines or external-service seams
- **`pr-review-contracts` + `pr-review-domain-logic` + `pr-review-tests`** — load this combination
  when the diff orchestrates DB/S3/filesystem/queue/OCR/LLM/API calls, persists artifact pointers,
  updates processing statuses, returns job payloads, or coordinates old/new implementations through
  a shared dispatcher. Treat these as contract-bearing changes, not just refactors: reviewers must
  verify the success/skip/failure lifecycle, persisted fields, returned message shape, idempotency,
  and whether globals or in-function client construction make the seams hard to test or swap.

### Load when the diff touches tests — or should have
- **`pr-review-tests`** — load on either of two signals: (1) the diff changes test files (judge
  whether those tests are good), or (2) the diff adds high-risk logic — multiple branches, fallback
  rules, state transitions, cross-service orchestration, or output that feeds a decision —
  *regardless of whether tests are present* (check that tests should have accompanied the change).
  The second signal is the important one: new high-risk logic with no tests is an absence that
  won't show up as a changed test file, so trigger on the logic diff, not just the test diff.

### Load when the diff weakens typed soundness
- **`pr-review-contracts` + `pr-review-domain-logic` + `pr-review-tests` as applicable** — load
  these when the diff makes Python interfaces easier to misuse: broad or missing type hints on
  public function signatures, raw tuple/dict payloads where a dataclass/TypedDict/named type would
  preserve field meaning, `int`/`str` identifiers or metrics that can be accidentally swapped,
  loosely modelled state machines, ad hoc string tags, boolean lifecycle flags, or constructor
  parameters that allow invalid combinations. Then read
  `references/python-typed-soundness.md` for the full checklist and escalation guidance before
  deciding whether this is a blocker or design feedback.

### Treat these as review signals even when they look cosmetic
- Magic numbers, raw dict payloads, unclear `None` returns, module-level caches/clients, misleading
  logs, and dead setup for disabled features are not always blockers by themselves. Route them
  through the loaded specialists and escalate only when they affect correctness, operational
  observability, persisted state, or downstream business output.

## After loading

Apply the loaded specialists together. `pr-review-contracts` defines the Review Output Format and
the confidence behavior (how hard to push on each finding) — follow it for all findings regardless
of which specialist surfaced them. `pr-review-domain-logic` defines the escalation meta-principle
that can raise a finding from any skill to BLOCKER.

If the diff touches none of the specialist areas (e.g. docs, comments, pure renames), load only
`pr-review-contracts` and review against the base rules.
