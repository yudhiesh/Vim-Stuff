---
name: daily-leadership-catchup
description: Generate a manual leadership catch-up across Linear and GitHub and write it to Obsidian for cross-project oversight. Use when the user asks to catch up on what changed over the last day or business window, identify what needs their attention, split updates into Data vs Infrastructure/DevOps lanes, or produce on-demand daily leadership summary notes.
---

# Daily Leadership Catchup

## Overview

Use this skill to produce a decision-ready daily leadership update from Linear and GitHub, then write it into Obsidian under OneCredit work notes.

Default output target:
- Vault path: `Work/OneCredit/Leadership Catchups/YYYY-MM-DD - Leadership Catchup.md`
- Reruns on same day: append `### Run at HH:mm`
- State file: `Work/OneCredit/Leadership Catchups/.state.json`

## Operating Profile

Use this profile unless the user overrides it:
- timezone: `Asia/Kuala_Lumpur`
- Linear profile: `yudhiesh`
- GitHub username: `yudhiesh-oc`
- Email alias: `yravindranath@onecredit.my`
- DevOps Linear project id: `devops-c91ffc92ee78`

If any identity/scope value is missing, ask once, then continue.

## Skill Composition

This skill should explicitly compose these companion skills when available:

1. `obsidian-cli`
- Use for reading, creating, appending, and updating catch-up notes in the Obsidian vault.
- Prefer `obsidian` CLI commands over raw filesystem edits when Obsidian CLI is available.

2. `github` (GitHub connector skill/app)
- Use for repository discovery, PR/issue search, review-request signals, and PR metadata enrichment.
- Prefer GitHub connector/API tools over ad-hoc scraping.

If either companion skill is unavailable, continue with the best equivalent fallback and mark run status as `partial` if coverage is reduced.

## Workflow

### 1. Resolve Time Window

Always use a rolling last 24-hour window ending at run time.
Do not switch to incremental windows based on `last_successful_run_at`.

### 2. Collect Linear Updates

Use Linear tools to fetch updates in the chosen window:
- Data lane: issues from Data team projects
- Infrastructure/DevOps lane: issues from project `devops-c91ffc92ee78` (under Engineering)

Capture at minimum:
- issue id/key, title, assignee, status, priority, labels, project, updated_at, due date, urls
- mention/reviewer/requested-input signals for `yudhiesh`

### 3. Collect GitHub Updates

Use GitHub connector for Data + DevOps repo scopes:
- include PRs/issues updated in window
- include review requests, mentions, failing checks, and linked incidents
- then run a second pass for open PR review backlog (outside window)

Capture at minimum:
- repo, PR/issue id, title, state, review status, check status, labels, updated_at, urls
- direct attention signals on `yudhiesh-oc`

Second-pass review backlog rules:
1. Query open PRs in Data + DevOps repo scopes without the 24-hour `updated` filter.
2. Include PRs where review is requested from:
   - `yudhiesh-oc` directly, or
   - any team that `yudhiesh-oc` belongs to (for example `OneCreditMY/devops`).
3. Tag these records as `attention_backlog=true` and keep them eligible for `Needs My Attention`.
4. When an item is both in-window and backlog, keep one row only (deduplicate by stable PR ID).
5. If the reason is backlog-only, set `Why now` to `Awaiting my review (backlog)` and keep the real `updated_at` so staleness is visible.

### 4. Merge, Classify, and Prioritize

De-duplicate cross-system items in this order:
1. Linear key mentioned in PR title/branch/commits
2. explicit cross-links in issue/PR bodies
3. shared URL references
4. heuristic normalized title + repo/project within window

Lane classification precedence:
1. If Linear project is `devops-c91ffc92ee78` or GitHub repo is in DevOps team scope -> `Infrastructure/DevOps`
2. Else if in Data team scope -> `Data`
3. Else -> `Needs Triage`

Needs-attention rules (any true => `Needs My Attention`):
1. waiting on me: assigned/review requested/mentioned for my identity aliases
2. high risk: P0/P1, prod incident, security/data-quality/infrastructure regression, critical CI failure
3. cross-team dependency likely blocked without my action
4. open review backlog: PR is still open and requested from me or my teams even if last update is outside the 24-hour window

Everything else -> `FYI`.

Sort within each section:
1. P0/P1 first
2. due soon
3. newest updates

### 5. Write Obsidian Note

Write or append today’s note:
- `Work/OneCredit/Leadership Catchups/YYYY-MM-DD - Leadership Catchup.md`

Use the fixed section structure in `references/note-template.md`.

Readability rules:
1. Keep one authoritative section at top: `Current Snapshot (Latest Run)`.
2. Replace verbose per-item bullet cards with compact action rows.
3. Put each item on one row with fixed fields:
   - `Priority`
   - `Lane`
   - `Item`
   - `Why now`
   - `Owner`
   - `State`
   - `Updated`
   - `Next action`
   - `Due/Risk`
   - `Links`
4. Do not aggregate unrelated items into one FYI bullet; keep one row per item.
5. Add `Changes Since Previous Run` to avoid rereading the entire note.
6. Keep prior runs in `Historical Runs` so the top snapshot stays clean.

Rerun behavior:
- rewrite `Current Snapshot (Latest Run)` with the newest run
- append one compact log block under `Historical Runs`
- keep all items (no cap)
- de-duplicate identical items inside that run by stable IDs

### 6. Persist Run State

Update `.state.json` in catch-up folder using schema in `references/state-schema.json`:
- set `last_successful_run_at` for each successful manual run
- keep alias and scope metadata current
- do not use state timestamps to change the data collection window

## Output Contract

End each run with:
1. what window was used
2. whether run completed successfully or partially
3. where note was written
4. what still needs manual follow-up
5. what changed since the previous run
