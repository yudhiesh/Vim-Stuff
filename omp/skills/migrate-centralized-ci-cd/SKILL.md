---
name: migrate-centralized-ci-cd
description: Migrate a OneCreditMY service repository from local GitHub Actions build, staging deploy, production deploy, and release-please workflow copies to the centralized ci-cd-workflows Release Contract v1. Use when Codex is asked to update or review repository CI/CD migration PRs, add .github/deploy.apps.json, replace deploy/release workflows with thin callers to OneCreditMY/ci-cd-workflows, align self-hosted runner labels, or verify release/staging/production dispatch behavior.
---

# Migrate Centralized CI/CD

## Core Workflow

1. Inspect the target repository before editing.
   - Read `.github/workflows/*.yml`, release-please config/manifests, version files, Dockerfiles, task definitions, README/deploy docs, and PR template.
   - Identify deployable apps, app keys, version files, ECR repositories, build contexts, Dockerfiles, ECS services, clusters, task definition paths, and container names.
   - Search for old commands and local reusable workflows: `/deploy`, `/run-*`, `reusable-build.yml`, `reusable-deploy-*`, `workflow_dispatch`, `release`, PAT-based release-please, and repo vars such as `ECS_*` or `ECR_*`.

2. Load `references/release-contract-v1.md` when implementing or reviewing exact workflow contracts.

3. Add or update `.github/deploy.apps.json`.
   - Use top-level `defaults.staging.cluster` and `defaults.production.cluster` when clusters are shared.
   - Use `apps.<APP_KEY>` entries whose keys match release/staging normalization: uppercase and replace non-alphanumeric characters with `_`.
   - Include only apps that are meant to participate in the shared staging/release/production contract.
   - Do not add staging-only or ad hoc task runners as release-managed apps unless their release tag behavior is explicitly defined.

4. Replace local orchestration with thin callers.
   - Staging caller: `issue_comment` -> `OneCreditMY/ci-cd-workflows/.github/workflows/dispatch-staging-from-pr-comment.yml@main`.
   - Production caller: `repository_dispatch` type `deploy-production-from-release-please` -> `dispatch-production-from-release.yml@main`.
   - Release caller: use `reusable-release-please.yml@main` with `github.token`; do not pass PAT secrets.
   - Release PR gate caller: use `release-pr-gate.yml@main`.
   - Keep ordinary CI/test jobs local unless the task explicitly asks to migrate them.

5. Preserve app-specific behavior deliberately.
   - Convert old release commands such as `/deploy-api release` to `/deploy-api-release`.
   - Remove manual production deploy triggers; production is dispatch-only.
   - If an old one-off task command is outside the centralized contract, either leave it out and document that it is not migrated, or keep it as separate local workflow logic if the user explicitly requires it.
   - For multiple task definitions sharing one version file, make sure the release gate will not require undeployable app keys. This was the oc-recsys failure mode: `CONSUMER_DLQ_REPLAY` shared `consumer/version.txt` but release-please only emitted `consumer-vX.Y.Z`, so production could never select `CONSUMER_DLQ_REPLAY`.

6. Update docs and PR templates.
   - Document `.github/deploy.apps.json`, required repo variables `DEPLOY_TAG_PROJECT` and `DEPLOY_TAG_TEAM`, `AWS_ECR_ROLE_ARN`, slash commands, and dispatch-only production behavior.
   - Remove references to deleted helper scripts or old repo variables.
   - Keep docs factual: do not claim a component is release-managed unless release-please emits a matching tag.

7. Validate narrowly, then commit/push if requested by the user.
   - Parse workflow YAML with Python or `ruby -e`/`yq` if available.
   - Run `git diff --check`.
   - Run `pre-commit run --files` for touched workflows/docs/tests when practical.
   - Run targeted tests for any copied test changes.
   - If hooks fail on pre-existing repo-wide lint debt, report that clearly and avoid broad cleanup unless requested.

## Review Checklist

- `.github/deploy.apps.json` exists and required fields are present for each release-managed app.
- No two app keys normalize to the same `<APP_KEY>`.
- Release tags map to manifest app keys. Example: `consumer-v1.2.3` maps to `CONSUMER`.
- Apps with the same `versionFile` are intentional; otherwise they can force extra `staging-release/<APP_KEY>` checks.
- Production workflow has only `repository_dispatch` for `deploy-production-from-release-please`.
- Release-please uses the central reusable workflow and `${{ github.token }}`.
- Staging commands follow `/deploy-<app>` and `/deploy-<app>-release` exactly.
- Shared workflows use self-hosted runners through the central repo; local CI changes are separate from deployment migration unless explicitly requested.
- Deleted files have no stale README or PR-template references.

## GitHub PR Handling

When the user asks to review a migration PR, use GitHub tools or `gh` to inspect the full diff and changed file list. Lead with contract-breaking findings, then summarize aligned parts. If the user asks to make a note, post a concise PR review/comment that states the specific contract mismatch and the expected scope.
