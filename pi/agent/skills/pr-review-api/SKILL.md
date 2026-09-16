---
name: pr-review-api
description: Review HTTP/REST API pull requests for correctness — status semantics, route/service/repository layering, versioning, input validation, async lifecycle. Use this skill whenever a PR touches HTTP routes, endpoints, handlers, middleware, status codes, request/response models, pagination or input bounds, or async request handling. Examples use FastAPI but the rules apply to any HTTP framework. Load alongside pr-review-contracts, which carries the base typed-boundary, error-contract, and output-format rules. Normally reached via the pr-review dispatcher.
---

# PR Review — HTTP / API Layer

HTTP-specific layer. Load **alongside `pr-review-contracts`** (typed boundaries, error contracts,
idempotency, testing, scope/defer, and the Review Output Format all live there). This skill adds
the HTTP-specific semantics worth enforcing on any REST API.

Examples below use FastAPI because it's a common case, but the rules are HTTP-generic — apply them
to any framework. Apply the Confidence behavior from `pr-review-contracts` (HIGH/MEDIUM are firm;
LOW are candidate rules phrased as suggestions).

---

## Patterns

### [BLOCKER] Correct HTTP status semantics
- confidence: HIGH

**Anti-pattern:** returning `200` for an unknown entity/identifier instead of `404`; status codes
that don't reflect what actually happened (e.g. a client/request-shape error surfacing as `500`).

**Preferred:** explicit `404`/`4xx` for missing or invalid resources; the status code matches the
outcome.

**Why:** a `200` for a non-existent entity silently misleads every consumer. API semantic
correctness is approval-gating.

**Illustrative anchor:** an endpoint returned `200` for unknown identifiers because the underlying
query always returned one row. The right fix anchors the HTTP behavior in the query semantics
(return zero rows for a missing seed) rather than patching it in the route.

**Review comment template:** "For an unknown identifier this returns 200, which tells the client
the entity exists. This should be a 404. The cleanest fix is at the query layer — return zero rows
for a missing seed (or gate on an existence check) — so the HTTP contract is anchored in the query
semantics rather than patched in the route."

---

### [BLOCKER] Route/service/repository layering with typed DTO boundaries
- confidence: HIGH

**Anti-pattern:** the route layer depends directly on raw DB shape (e.g. an `asyncpg.Record` or a
raw row tuple) to decide both semantics (`None` => 404) and response shape.

**Preferred:** the repository/service returns a typed domain DTO (or `None`); the route handles
only HTTP concerns.

**Why:** coupling DB output shape to HTTP behavior makes correctness fragile — a query shape change
silently alters the HTTP response.

**Review comment template:** "The route is reaching into the raw DB record to decide both the 404
and the response shape, which couples the query output to HTTP behavior — a column change could
silently break the contract. Let's have the repository return a typed domain DTO (or `None`), and
keep the route focused on HTTP concerns only."

---

### [STRONG_PREFERENCE] Route versioning + input bounds/validation
- confidence: MEDIUM

**Anti-pattern:** unbounded size/pagination params; weak identifier validation; PII leakage in
error details.

**Preferred:** versioned route prefixes; bounded, validated parameters; sanitized error details.

**Review comment template:** "External-facing routers should use a versioned prefix (e.g. `/v1/`)
so we can evolve the API without breaking existing consumers. For any integer parameter that
controls result size (limit, page_size, offset), constrain it — in FastAPI, `limit: int =
Query(20, ge=1, le=100)` — to prevent unbounded queries. Also make sure identifier validation is
strict and error details don't echo back PII."

---

### [STRONG_PREFERENCE] Async lifecycle + cancellation cleanup
- confidence: MEDIUM

**Anti-pattern:** blocking I/O inside async flows; cancelling tasks without awaiting cleanup.

**Preferred:** non-blocking I/O in async functions; explicit cancellation join
(`await gather(..., return_exceptions=True)`) before teardown. Regression-test lifecycle/startup
behavior when shared API state is introduced.

**Why:** a reliability/performance risk, especially when a request coordinates multiple concurrent
tasks.

**Review comment template:** "This cancels the tasks but tears down before awaiting them, so
cleanup can race. Let's join the cancelled tasks (`await gather(..., return_exceptions=True)`)
before teardown. Also worth checking the I/O here is non-blocking inside the async path."

---

### [NIT / candidate] Probe scope aligned to traffic gating
- confidence: LOW

**Anti-pattern:** exposing a readiness endpoint that isn't used by the load balancer's traffic
gating.

**Preferred:** a single liveness probe that mirrors the actual gating model; reduce operational/API
surface.

**Review comment template:** "Worth considering: this readiness endpoint isn't part of the load
balancer's gating model, so it adds surface without affecting traffic. Have you considered a single
liveness probe that mirrors what the balancer actually checks?"
