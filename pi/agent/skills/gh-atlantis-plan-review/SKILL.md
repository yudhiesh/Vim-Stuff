---
name: gh-atlantis-plan-review
description: Review Atlantis/OpenTofu/Terraform plans posted as GitHub PR comments, especially when the user asks to use GitHub to pull plans from oc-staging-atlantis-app and oc-production-atlantis-app, inspect the most recent PR comments, and compare them with expected infrastructure changes.
---

# GitHub Atlantis Plan Review

## Overview

Review the latest Atlantis plan comments on a GitHub PR and compare observed resource changes with the expected plan scope. Prefer the GitHub connector first; use the bundled helper script or `gh api` when Atlantis comments are too large or truncated.

## Workflow

1. Resolve the PR repository and number.
   - Use explicit PR URLs when provided.
   - Otherwise use the current checkout with `gh pr view --json number,headRefName,url`.
2. Fetch PR comments with the GitHub connector first.
   - Use `_fetch_pr_comments` for the PR.
   - Identify comments authored by `oc-staging-atlantis-app[bot]` and `oc-production-atlantis-app[bot]`.
3. If connector output is truncated, use `scripts/extract_latest_atlantis.py`.
   - This is normal for large Atlantis comments.
   - The helper writes full latest bot comment bodies and prints a compact grep-style summary.
4. Select only the newest comment per Atlantis bot unless the user asks for historical comparison.
5. For each environment, split the Atlantis comment by project block.
   - Common project names: `staging-ecs-github-runners-cluster`, `staging-ecs-github-runners-service`, `production-ecs-github-runners-cluster`, `production-ecs-github-runners-service`.
6. Compare the observed plan against the expected change list from the PR body, ticket, or user-provided expectations.
7. Report verdict clearly: matches, expected-but-notable, or blocker.

## Helper Script

Run from any local checkout with authenticated `gh`:

```bash
python3 ~/.codex/skills/gh-atlantis-plan-review/scripts/extract_latest_atlantis.py \
  --repo OneCreditMY/infrastructure \
  --pr 184
```

Useful options:

```bash
--out /tmp/pr184-atlantis
--bots oc-staging-atlantis-app[bot],oc-production-atlantis-app[bot]
--context-lines 2
```

The script prints:

- latest Atlantis comment id, author, and timestamp per bot
- files containing the full comment bodies
- compact lines matching resources, action summaries, and common Terraform diffs

## Review Checklist

For service plans, check:

- task definition replacements are expected when container definitions, CPU, memory, or logging change
- sidecar removals match scope, for example Datadog agent or FireLens log-router
- IAM policy attachment destroys are expected when removed secrets/logging are no longer needed
- ECS service updates are expected or explicitly accepted, for example tag propagation
- `desired_count` changes are absent when ignored by lifecycle, unless autoscaling target changes are expected
- Application Auto Scaling resources match expected `min_capacity`, `max_capacity`, metric target, and cooldowns
- unexpected memory, CPU, networking, or secret changes are called out

For cluster plans, check:

- ASG `min_size`, `desired_capacity`, and `max_size` match the intended baseline and ceiling
- launch template instance type changes match target instance family and size
- mixed instances policy is present only when expected
- Spot/on-demand distribution matches purchase model
- instance overrides are all placeable for the task shape
- capacity provider managed scaling, termination protection, and draining match expectations
- no ASG or launch template destroy/recreate unless explicitly intended

## Output Format

Keep the response concise and decisive:

```markdown
**Atlantis Review**
- Staging comment: <link/id/timestamp>
- Production comment: <link/id/timestamp>

**Verdict**
Matches expected / Matches with notes / Blocked.

**Staging**
- Cluster: ...
- Service: ...

**Production**
- Cluster: ...
- Service: ...

**Notes**
- Expected-but-notable items...
- Blockers, if any...
```

## Guardrails

- Do not apply Atlantis plans unless the user explicitly asks.
- Do not post PR comments unless the user explicitly asks.
- Do not treat old Atlantis comments as current if newer bot comments exist.
- Do not rely on truncated connector output for final comparison.
- Include exact timestamps or comment ids when distinguishing old and latest plans.
