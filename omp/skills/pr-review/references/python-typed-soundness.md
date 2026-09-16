# Python Typed Soundness Review Notes

Use this reference when a Python PR changes public interfaces, data shapes, lifecycle/state
modelling, serialization formats, IDs, units, resource handling, or concurrency/resource seams.
The review lens is inspired by "Writing Python like it's Rust": prefer interfaces that make
incorrect use hard to express, easy for a type checker to catch, or explicit at the boundary.

## Core principle

Review whether the diff moves Python code toward or away from making illegal states
unrepresentable. In Python this usually means using clearer types and narrower constructors, not
copying Rust syntax. Treat weak shapes as review findings only when they create a plausible
correctness, persistence, API, operational, or downstream business-output risk.

## Review checks

- Prefer typed public function signatures. Missing, broad, or misleading annotations on changed
  public helpers, service methods, serializers, route handlers, and repository boundaries make it
  harder to catch swapped arguments, unclear failure modes, or stale callers before runtime.
- Prefer named records over positional tuples or raw `dict[str, Any]` payloads. For stable internal
  contracts, suggest dataclasses, Pydantic models, TypedDicts, NamedTuples, or small domain objects
  so field names, field types, and refactors are visible to tools.
- Prefer closed unions for closed sets of variants. When the valid shapes are known, model them as
  explicit union members instead of ad hoc string tags plus optional fields. Review match/if chains
  for missing cases; in Python 3.11+, `typing.assert_never` can make exhaustiveness visible to type
  checkers.
- Prefer semantic primitive wrappers for IDs, units, and metrics that can be mixed up. `NewType`,
  small value objects, or domain-specific aliases are useful when two values share the same runtime
  type but must not be substituted, such as `CustomerId` vs `ApplicationId`, cents vs ringgit, or
  normalized vs pixel coordinates.
- Prefer explicit construction functions for alternate initialization paths. A large `__init__`
  with optional parameters, boolean mode flags, or mutually exclusive argument groups often allows
  invalid combinations; named constructors such as `from_api_payload`, `from_db_row`, or
  `from_normalized_bbox` make the accepted input shape explicit.
- Prefer state-specific objects over lifecycle booleans when methods are valid only after a
  transition. If a class tracks states like connected/authenticated/closed, review whether the API
  exposes methods on states where they are invalid. A construction function returning a
  `ConnectedClient`, then an `AuthenticatedClient`, may remove runtime-only rules.
- Prefer context managers for scoped resources. `with` blocks should replace manual
  acquire/release, open/close, lock/unlock, or start/stop flows when forgetting cleanup would leak
  resources, double-close, or leave state inconsistent.
- Prefer wrappers that bind protected data to the guard/resource. For locks, transactions, sessions,
  and mutable shared state, review whether callers can access the protected data without acquiring
  the guard or opening the transaction.

## Escalation guidance

Escalate to a blocking finding when the loose shape can cross a module/API/persistence boundary,
store invalid state, silently mix incompatible IDs or units, skip a valid variant, leak or double-use
a resource, or change business output. Keep it as non-blocking design feedback when the concern is
local, easy to inspect, and unlikely to produce an observable failure.
