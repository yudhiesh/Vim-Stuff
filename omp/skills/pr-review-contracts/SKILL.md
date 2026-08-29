---
name: pr-review-contracts
description: Base layer for reviewing Python pull requests for contract correctness. Use this skill whenever reviewing Python code changes, PR diffs, data model changes, API contracts, payload/DTO shapes, DB read/write semantics, env/config wiring, or any code that crosses a boundary. This is the foundation skill loaded for almost every PR review — pair it with pr-review-api (HTTP changes) and pr-review-domain-logic (scoring/recommendation/financial logic) when those areas are touched. Normally reached via the pr-review dispatcher.
---

# PR Review — Base Contracts

The base layer for reviewing Python PRs. Load it for nearly every review, then add the change-type
specialists. The job is to pre-review a PR and catch contract and correctness issues before merge:
be direct and specific, always explain *why*, and anchor on the actual diff.

These patterns are distilled from real review history. The code examples are illustrative of the
pattern, not citations — adapt them to the diff in front of you.

## How to use this skill

1. Read the diff and classify what it touches (models/DTOs, DB access, config/env, migrations,
   API routes, business logic).
2. Apply the patterns below. Each has a confidence level that governs how hard you push.
3. Pair with the relevant specialist skill(s) for HTTP or domain-logic changes.
4. Deliver findings using the Review Output Format at the end of this file.

## Confidence behavior

Confidence reflects how broadly a pattern applies, which sets how hard to push:

- **HIGH / MEDIUM**: firm rules. Use direct language ("This should…", "Please…") and treat
  violations as real findings at their stated severity.
- **LOW**: candidate rules. Phrase as a question or suggestion ("Worth considering: …", "Have you
  considered…") and flag for attention rather than auto-blocking — *unless* the finding also trips
  the domain-logic meta-principle (silent wrong business output). Then escalate to BLOCKER with
  explicit rationale.

---

## Patterns

### [STRONG_PREFERENCE] Typed boundaries over loose dict/tuple shapes
- confidence: HIGH

**Anti-pattern:** nested `dict`/`tuple`/manual key access for data crossing a boundary — API
payloads, DB rows, queue messages, AI/model response parsing — e.g. chained `.get("toc", {})`
parsing on an external payload, then branching on the raw shape.

**Preferred:** a typed structure at every boundary where an external shape enters the system, so
schema drift fails loud at the boundary instead of branching silently deep in business logic.

**Choosing the structure (match the tool to the trust boundary):**
- Use **Pydantic** where *untrusted* data enters the system — HTTP bodies, queue messages,
  AI/model responses, external API payloads, env/config. That is where runtime validation and
  coercion earn their cost.
- For data already inside the trust boundary (constructed by your own typed code, already
  validated at entry), prefer the lightest typed structure that holds the invariant: a
  **dataclass** by default, **`NamedTuple`/`TypedDict`** for simple records, a **frozen dataclass
  or `attrs`** for value objects.
- Reaching for Pydantic on purely internal structures is mild over-engineering — a NIT, not a
  violation. The real blocker is an **untyped dict/tuple crossing any boundary.** Don't block on
  internal-Pydantic; do block on a raw dict at an HTTP/queue/AI boundary.

**Review comment template (boundary):** "This parses the payload by reaching into a raw dict
(`toc_data.get("toc", {})`) and branching on its shape. This is a trust boundary (external input),
so let's validate it into a Pydantic model here — a schema change should fail loudly at the
boundary rather than produce a subtly wrong result downstream."

**Review comment template (internal over-engineering, NIT):** "Minor: this is an internal
structure built by our own code, so it doesn't need Pydantic's runtime validation cost. A
dataclass (or `NamedTuple` for something this small) would be lighter and express the same shape."

---

### [BLOCKER] Explicit failure/status contracts
- confidence: HIGH

**Anti-pattern:** swallowed exceptions, inconsistent 400/500 semantics, tri-state outcomes encoded
as optional booleans, free-form error envelopes.

**Preferred:** custom exception types, explicit state models (e.g. `completed` / `failed` /
`skipped`), deterministic transitions, and a clear client-vs-server error split. Errors must
preserve root cause.

**Why:** hidden failures and ambiguous status let wrong outcomes pass as success and force
downstream consumers to guess.

**Review comment template:** "This path can swallow the failure and still report a successful
status. Let's model the outcome explicitly (completed / failed / skipped) and let the exception
propagate with its root cause preserved, so a downstream consumer can't mistake a failed run for a
completed one."

---

### [BLOCKER] Idempotent persistence + deterministic reads
- confidence: HIGH

**Anti-pattern:** append-only writes on reruns/retries; unordered reads like `result[0]` that
become non-deterministic once duplicates exist.

**Preferred:** upsert/idempotent write paths, explicit ordering on reads, replay-safe storage.
Reruns are normal in production and must not change business output.

**Review comment template:** "Jobs get retried in production, so this append-only write will
accumulate duplicate rows, and the unordered `result[0]` read then becomes non-deterministic.
Let's make the write an upsert keyed on the run identity, and add an explicit ORDER BY on the read
so a rerun produces the same output."

---

### [STRONG_PREFERENCE] Fail-fast runtime config
- confidence: MEDIUM

**Anti-pattern:** non-local runtime silently falling back to staging URLs/tokens; missing env
wiring; credentials passed through app code.

**Preferred:** required config validated at startup (fail-fast on missing critical vars),
environment parity, role-based auth rather than app-level credential passing.

**Why:** implicit defaults cause cross-environment leakage and hidden misconfiguration that
surfaces only at runtime.

**Review comment template:** "If this env var is missing in production it silently falls back to a
staging URL, which risks cross-environment leakage. Let's require it explicitly and fail fast at
startup when a critical var is absent, rather than defaulting in app code."

---

### [STRONG_PREFERENCE] High-risk logic must ship with tests
- confidence: HIGH

Logic with multiple branches, fallback rules, state transitions, or output that feeds a decision
must ship with tests in the same PR. When flagging any pattern violation in high-risk logic, also
note what tests should accompany the fix.

All test-quality judgment — what counts as adequate, and the anti-patterns to flag (happy-path-only,
weak assertions, implementation coupling, missing seam/integration coverage, un-parametrized
duplication, missing boundary cases) — lives in **`pr-review-tests`**. Load that skill whenever the
diff adds high-risk logic or touches test files.

---

### [STRONG_PREFERENCE] PR scope: correctness fixes now, structural cleanup as follow-up
- confidence: HIGH

A decision rule to apply to every PR, balancing "this code should be better" against "this PR
needs to ship":

1. Mentally split the diff into **correctness changes** (bug fixes, status semantics, contract
   violations, idempotency) and **structural improvements** (decomposition, naming, layering
   refactors, dead-code removal).
2. Correctness issues are **blockers in this PR**.
3. Structural improvements not required for correctness are **deferred to follow-up tickets**.
4. If correctness and structural changes are interleaved so deeply they can't be reviewed
   independently, that is itself a finding: **the PR should be split.**

**Review comment template (defer):** "This function is doing several things and would read better
split up — but that's not required for correctness here. Not blocking, but worth a follow-up
ticket: extract the parsing logic into its own unit so it can be tested in isolation."

**Review comment template (split):** "The bug fix and the larger refactor are tangled together
here, which makes the correctness change hard to verify on its own. Could we land the fix (plus its
tests) first, and move the refactor to a separate PR?"

---

### [BLOCKER] Database migrations: new revisions, not modified existing ones
- confidence: LOW, but BLOCKER when observed

Migration correctness is not optional. Editing an existing migration revision to add schema
changes breaks rollback capability and corrupts migration history.

**Anti-pattern:** modifying an existing migration revision file to add new schema changes.

**Preferred:** create a new revision (e.g. `alembic revision --autogenerate -m "description"`);
never modify existing revision files; regenerate unique revision IDs for new migrations.

**Review comment template:** "This modifies an existing migration revision file instead of creating
a new one. Editing existing revisions breaks rollback and loses migration history — please create a
new revision for these schema changes and regenerate unique revision IDs."

---

### [NIT] Import / constant hygiene
- confidence: HIGH

Top-level imports (not inline inside functions), constants extracted instead of magic
numbers/strings, enums over string literals where a fixed set exists. Real and recurring, but a
NIT — never block on it.

**Review comment template:** "Minor: this import is inside the function; move it to the top of the
module unless there's a circular-import reason. Same for the magic number — pull it into a named
constant."

---

### [BLOCKER] Canonical machine-readable error codes
- confidence: LOW (candidate)

**Anti-pattern:** free-form error detail dicts that collapse into unstable generic envelopes
clients must string-parse.

**Preferred:** canonical error-code mapping; promote structured exceptions into stable API errors.

**Review comment template:** "The error response here uses a free-form detail dict that downstream
clients will need to string-parse. Worth considering: map this to a canonical error code (e.g.
`{"error": {"code": "registry_unavailable"}}`) so clients can switch on the code rather than
pattern-matching detail strings."

---

## Review Output Format

When producing review findings, follow these conventions.

### Inline comments
- Post at the specific diff line where the pattern violation appears.
- Prefix with a severity tag: `[BLOCKER]`, `[STRONG PREFERENCE]`, or `[NIT]`.
- State what the issue is, why it matters, and what the preferred alternative is.
- For HIGH/MEDIUM confidence patterns: use direct language ("This should…" / "Please…").
- For LOW confidence patterns: phrase as a question or suggestion ("Worth considering: …").

### Summary comment
- Post one summary comment per review for PR-scope and structural concerns.
- Use it for cross-cutting findings that don't attach to a specific line: PR scope issues, missing
  test coverage for new branches, follow-up ticket suggestions.

### Escalation
- When flagging a BLOCKER, explicitly state the risk: what goes wrong if this ships as-is.
- When the meta-principle applies ("if this logic is wrong, will anyone notice before the output is
  consumed?"), state it — that is the justification for the block.
- When a STRONG_PREFERENCE violation co-occurs with a correctness risk, escalate to BLOCKER and
  explain the connection.

### Follow-up tickets
- For a structural improvement that should not block the current PR, phrase it as: "Not blocking,
  but worth a follow-up ticket: [specific improvement]."
- Be specific about what the ticket should cover — vague "clean this up later" is not useful.
