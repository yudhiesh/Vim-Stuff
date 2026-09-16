---
name: pr-review-tests
description: Review the quality of tests in a Python pull request — whether tests exist for high-risk logic, and whether the tests that exist are good. Use this skill whenever a PR touches test files, or whenever a PR adds branchy/fallback/state-transition logic or anything whose output feeds a decision (to check tests should have accompanied the change, present or not). Load alongside pr-review-contracts. Normally reached via the pr-review dispatcher.
---

# PR Review — Test Quality

Review-time test specialist. Load **alongside `pr-review-contracts`** and apply its Review Output
Format and Confidence behavior. Two jobs:

1. When the diff **adds high-risk logic** (multiple branches, fallback rules, state transitions, or
   output that feeds a business/model decision) — check whether tests accompany it. The most
   important finding here is an *absence*: new high-risk logic with no tests. That won't show up as
   a changed test file, so look at the logic diff, not just the test diff.
2. When the diff **touches test files** — judge whether those tests are actually good, using the
   anti-patterns below.

The bar is not a coverage percentage. It is: do the tests exercise the behavior that can break, at
the seams where it breaks?

---

## What good looks like (the standard)

- Every branch, fallback, and error path of high-risk logic has a case — not just the happy path.
- Tests assert on **observable behavior** (return values, persisted state, published events,
  HTTP responses), not on internal implementation calls.
- Tests are **deterministic** and independent of execution order.
- Cases that share structure and differ only in data are **parametrized**, not copy-pasted.
- Logic that crosses a **seam** (persistence, eventing/queue, HTTP, cross-service) has an
  **integration test** exercising that seam — a fully-mocked unit test does not prove the seam works.

---

## Anti-patterns to flag

### [STRONG_PREFERENCE] Happy-path-only tests for branchy logic
- confidence: HIGH

Logic with multiple branches/fallbacks/state transitions tested only on the success path. Every
branch — including null/omitted, missing-input, and failure paths — needs a case.

**Review comment template:** "This logic has several branches but the tests only cover the happy
path. Please add cases for each branch — including the null/omitted and failure paths — in the same
PR as the change."

---

### [STRONG_PREFERENCE] Repeated near-identical tests that should be parametrized
- confidence: HIGH

Several test functions with the same body differing only in input/expected literals. Parametrize
them so the shared behavior is expressed once and cases are easy to extend.

**Caveat — don't over-apply:** parametrize only when the cases share the same behavior and differ
only in data. Tests that *look* similar but assert genuinely different behaviors should stay
separate — merging them hurts readability and makes failures harder to localize.

**Review comment template:** "These three tests have the same structure and differ only in the
input and expected value — let's parametrize them (`@pytest.mark.parametrize`) so the case table is
in one place and adding a case is one line. (If any of them is actually asserting different
behavior, keep that one separate.)"

---

### [BLOCKER] Integration gap: unit-only coverage where the change crosses a seam
- confidence: HIGH

When the change crosses a persistence / eventing / HTTP / cross-service boundary, a unit test with
the seam mocked proves almost nothing — the seam is exactly where the failure modes live
(idempotent writes, false-success publication, query-to-HTTP semantics). There must be an
integration test exercising that seam.

**Scope:** this applies to seam-crossing changes. Pure in-memory logic (a calculation, a ranking
function with no I/O) is well served by fast unit/parametrized tests and does **not** need an
integration test — don't flag those.

**Why BLOCKER:** an untested seam can ship a silently-wrong behavior that unit tests can't catch —
this connects to the domain-logic meta-principle.

**Review comment template:** "This change writes to the DB and publishes a completion event, but
the only tests mock both. A mocked unit test can't catch the failure modes that live at that seam
(duplicate writes on rerun, a success event published when the write failed). Please add an
integration test that exercises the real persistence + publish path. Flagging as a blocker because
the untested seam is exactly where a silent wrong outcome would slip through."

---

### [STRONG_PREFERENCE] Assertion-free or weak-assertion tests
- confidence: MEDIUM

A test that calls the function and asserts nothing, or only that it "didn't raise." It passes
without proving the behavior.

**Review comment template:** "This test calls the function but doesn't assert on the result, so it
only checks that nothing threw. Let's assert on the actual returned value / persisted state so the
test fails if the behavior regresses."

---

### [STRONG_PREFERENCE] Tests coupled to implementation
- confidence: MEDIUM

Asserting on internal calls, private methods, or mock call counts rather than observable behavior.
These break on harmless refactors and pass through real bugs.

**Review comment template:** "This asserts on the internal call sequence rather than the observable
result, so it'll break on a refactor that keeps behavior identical and won't catch a behavior
change that keeps the same calls. Let's assert on the output / resulting state instead."

---

### [STRONG_PREFERENCE] Over-mocking the unit under test
- confidence: MEDIUM

Mocking so much that the test validates the mock rather than the code — including mocking the very
thing being tested.

**Review comment template:** "Most of the collaborators here are mocked, including part of the logic
we're trying to test, so the test is largely asserting on the mocks. Let's narrow the mocking to the
true external boundaries and let the real logic run."

---

### [STRONG_PREFERENCE] Non-deterministic or order-dependent tests
- confidence: MEDIUM

Reliance on real wall-clock time, real randomness, shared mutable state, or test execution order.
Flaky tests erode trust in the suite.

**Review comment template:** "This depends on real time/randomness (or shared state across tests),
which makes it flaky and order-dependent. Let's inject/freeze the clock (or seed the RNG) and keep
each test self-contained."

---

### [BLOCKER] Missing boundary cases the logic implies
- confidence: MEDIUM

When the code distinguishes meaningful cases — zero vs missing, null vs omitted, empty vs absent —
the tests must cover that distinction. An untested distinction is a silent-wrong-output risk.

**Review comment template:** "The logic treats a computed zero differently from a missing value,
but the tests only cover one of them. Please add cases for both — the distinction is the whole point
of the change, and right now a regression that collapses them would pass."
