---
name: workflow-packaging-audit
description: Audit recent work history to identify repeated manual workflows worth packaging, then create only high-confidence missing assets. Use when Codex should review the last 30 days (or all available history if shorter), gather evidence from sessions, memories/rollout notes, Chronicle discovery, and existing skills/agents/automations, then decide whether each candidate should become a skill, subagent, automation, extension, or be skipped.
---

# Workflow Packaging Audit

## Objective

Identify recurring, costly manual workflows and package only the highest-confidence missing items with minimal overlap.

## Evidence Order

Collect evidence in this strict order:
1. Recent Codex sessions and task summaries.
2. Codex Memories and rollout summaries.
3. Chronicle (discovery only), then confirm important details in source systems when possible.
4. Existing skills, custom agents, and automations.

If history is shorter than 30 days, use all available history.

## Candidate Criteria

Only act when the candidate:
- occurred at least twice, or is clearly likely to recur and costly to repeat
- has stable inputs, repeatable procedure, and clear output or stopping condition
- materially improves speed, quality, consistency, or reliability
- is not already adequately covered

## Decision Types

Choose the smallest appropriate form:
- `skill`: reusable workflow/playbook
- `subagent`: bounded specialist role suitable for delegation
- `automation`: scheduled recurring check/report/reminder/monitor
- `extend existing`: update an existing skill/agent/automation
- `skip`: one-off, ambiguous, sensitive, or weakly evidenced

## Workflow

1. Define analysis window.
- Use the last 30 days by default.
- If less than 30 days of history exists, use all available history.

2. Gather and normalize evidence.
- Extract repeated themes, dates, and counts from session/task history.
- Capture memory/rollout signals and Chronicle discoveries.
- Verify whether each theme is already covered by existing assets.

3. Build a compact shortlist first.
- For each candidate include:
  - repeated workflow
  - supporting evidence and dates
  - frequency/confidence
  - recommended form
  - why it is or is not worth creating

4. Create only high-confidence missing items.
- Prefer narrow, practical assets with clear validation.
- Avoid speculative, overlapping, or broad assets.
- Reuse/extend existing assets when coverage is already sufficient.

5. Validate outputs.
- Ensure each created or updated asset maps to concrete evidence.
- Confirm no duplicate purpose across skills/subagents/automations.

6. Finish with a packaging summary.
- what was created or extended
- what was deliberately skipped
- what needs more evidence before packaging

## Output Contract

Always output:
1. A compact shortlist table/list with evidence and recommendation per candidate.
2. Only the high-confidence created/extended assets.
3. A closing section with:
- created or extended
- deliberately skipped
- needs more evidence

## Guardrails

- Do not create assets for one-time tasks unless recurrence and cost are clearly justified.
- Do not duplicate existing capabilities without a clear gap.
- Treat Chronicle as discovery; confirm high-impact details in source systems where possible.
- Keep created assets testable, source-aware, and easy to maintain.
