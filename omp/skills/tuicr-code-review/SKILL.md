---
name: tuicr-code-review
description: Run an interactive code review with tuicr, inspect diffs, annotate files, and export review comments. Use when the user asks to review working-tree changes, commits, branches, GitHub pull requests, or GitLab merge requests with tuicr.
---

# tuicr Code Review

## Workflow

1. Identify the review target:
   - Uncommitted changes: `tuicr -w`
   - Commit range: `tuicr -r '<base>...HEAD'`
   - GitHub/GitLab review: `tuicr pr <number-or-url>`
   - One file without VCS: `tuicr --file <path>`
2. Before opening the TUI, check the repository status and confirm the intended base or PR.
3. Start tuicr with `--no-update-check` for repeatable runs.
4. In the TUI, inspect changed files and hunks, then add comments only for actionable findings:
   - correctness or regression risk
   - security or data-loss risk
   - broken tests or missing high-risk coverage
   - contract/API incompatibility
   - maintainability issue that materially affects the change
5. Export the review with `--stdout` when the result must be captured or processed; otherwise use the default clipboard export.
6. Report findings with file, line/hunk, severity, explanation, and suggested fix. Do not modify code unless explicitly asked.

## Useful commands

```sh
tuicr -w --no-update-check
tuicr -r 'main...HEAD' --no-update-check
tuicr pr 123 --no-update-check
tuicr review list
tuicr review comments
```

Keep the review focused: no speculative refactors, style nits already enforced by tooling, or comments without a concrete impact.
