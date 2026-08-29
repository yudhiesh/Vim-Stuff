---
name: pr-review-domain-logic
description: Review business-logic correctness in Python pull requests — scoring, recommendation/ranking, financial calculations, fallback/fail-closed rules, winner selection, evaluation logic. Use this skill whenever a PR touches logic whose output feeds a business or model decision, including fallback or default-value behavior, status publication, and any conditional/return-value logic that isn't plain plumbing. Load alongside pr-review-contracts. This skill also governs when to escalate any finding to BLOCKER based on business impact. Normally reached via the pr-review dispatcher.
---

# PR Review — Domain Logic Correctness

Business-output correctness layer. Load **alongside `pr-review-contracts`** and apply its Review
Output Format. This skill carries the meta-principle that governs **escalation** across all the
review skills: it decides when an otherwise-lower-severity finding becomes a blocker.

Examples reference domains like scoring and financial calculation where the domain *is* the lesson
— that's what makes "don't silently return an estimate" land. Adapt the principle to whatever the
diff's output feeds.

---

## The meta-principle (governs escalation everywhere)

**If this logic is wrong, will anyone notice before the output is consumed?**

If the answer is no — the code can silently produce a wrong business output that something
downstream treats as real — that is an automatic BLOCKER, regardless of the pattern's normal
confidence level. State this principle explicitly when you use it to justify a block. A LOW-
confidence finding in any skill escalates to BLOCKER when it trips this test.

- confidence: HIGH

---

## Patterns

### [BLOCKER] Fail-closed when required inputs are missing
- confidence: MEDIUM

**Anti-pattern:** returning an estimated/default value when required source data is absent, with
ambiguous warning-only semantics. Consumers can't tell a synthetic default from a real output.

**Preferred:** explicit per-result availability/status; return `null` (no output) when
prerequisites are absent, or gate estimates behind an explicit opt-in flag.

**Illustrative anchor:** scoring branches that returned population-estimated values by default when
financial data was missing. The fix: return `null` for unavailable result families plus tests
enforcing "missing inputs => no output" unless estimates are explicitly opted into.

**Review comment template:** "When required source data is absent, the current implementation
returns an estimated/default value. This should return a null result with an explicit status
indicating why (e.g. `missing_required_inputs`) so the consumer can distinguish 'no result
available' from 'the result is zero.' Returning an estimate silently can mislead downstream
business decisions. If estimates are a real product need, gate them behind an explicit opt-in flag,
and add tests enforcing missing-inputs => no-output."

---

### [BLOCKER] Preserve unknown-vs-zero semantics
- confidence: MEDIUM

**Anti-pattern:** converting a computed `0` into `None` (or vice versa), erasing the distinction
between an actual zero and a missing value — which then corrupts downstream ratios and
interpretation.

**Preferred:** an explicit zero-vs-missing policy, applied consistently, with tests covering both.

**Review comment template:** "This converts computed `0` values to `None`, which erases the
difference between 'the value is actually zero' and 'the value is missing.' Those mean different
things to the downstream ratios. Let's define an explicit zero-vs-missing policy and add tests for
both cases."

---

### [BLOCKER] No false success statuses
- confidence: MEDIUM

**Anti-pattern:** publishing a `completed`/success event when required artifacts/results are
missing or failed; tri-state outcomes encoded as optional booleans.

**Preferred:** explicit state models (completed / failed / skipped); fail-closed behavior; success
published only after downstream artifact validity is established.

**Illustrative anchor:** a processing flow that marked itself `completed` and published a success
event even when the output artifact was not actually created/uploaded.

**Review comment template:** "This can publish a `completed` event even when the artifact wasn't
actually created — a false success that downstream consumers will trust. Success should only be
published after the artifact's validity is confirmed; otherwise emit `failed` or `skipped`.
Flagging as a blocker: if this is wrong, nothing downstream will notice until the missing artifact
surfaces as a later failure."

---

### [BLOCKER] Winner/candidate selection must follow ranked output
- confidence: LOW (candidate), escalate via meta-principle

**Anti-pattern:** selecting a "winner" by exclusion (e.g. first non-baseline candidate) rather than
from the actual sorted ranking — which can silently pick a non-best option.

**Preferred:** selection tied to the actual sorted ranking outcome, with an explicit safeguard for
when the baseline legitimately remains top.

**Why:** a wrong winner artifact propagates into decision-making. Escalate via the meta-principle.

**Review comment template:** "The winner is chosen by excluding the baseline rather than by taking
the top of the sorted ranking, so if the baseline is actually best we'd silently promote a worse
candidate. Let's tie selection to the ranked result directly, with an explicit branch for the
baseline-stays-top case. Flagging as a blocker because a wrong winner artifact propagates into
decisions unnoticed."

---

### [STRONG_PREFERENCE] User-story-first framing for model/experiment changes
- confidence: MEDIUM

**Anti-pattern:** implementation-first PRs that don't explain the workflow impact for the people
who consume the results (experiments, evaluation, decision criteria).

**Preferred:** design and acceptance criteria framed by the consumer's user story first,
implementation second. For ML/recsys work, the data scientists who act on the output are the
primary customers for change quality.

**Review comment template:** "Before the implementation detail — can we frame this by the user
story for whoever consumes the output? What experiment/evaluation does this enable, and what's the
decision criterion? That's the acceptance bar, and it makes the implementation choices easier to
review."

---

## Domain heuristics

- Outputs that feed a decision must encode availability semantics as a contract, not an
  implementation detail.
- Event-driven processing must never publish success before downstream artifact validity is
  established.
- Recommendation/evaluation code must preserve ranking truth — "best" means the actual top-ranked,
  not the first non-baseline.
- Experiment/evaluation scripts must not alter production deployment semantics or trigger
  environment side effects.
