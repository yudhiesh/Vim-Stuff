# Release Contract v1 Reference

Use this reference when implementing or reviewing the exact centralized CI/CD migration contract.

## Thin Caller Workflows

### Staging

```yaml
name: Deploy Staging

on:
  issue_comment:
    types:
      - created

permissions:
  actions: read
  contents: read
  issues: write
  pull-requests: write
  id-token: write
  statuses: write

jobs:
  dispatch-staging:
    uses: OneCreditMY/ci-cd-workflows/.github/workflows/dispatch-staging-from-pr-comment.yml@main
    with:
      aws-region: ap-southeast-5
      deploy-config-file: .github/deploy.apps.json
    secrets:
      aws-ecr-role-arn: ${{ secrets.AWS_ECR_ROLE_ARN }}
```

### Production

```yaml
name: Deploy Production

on:
  repository_dispatch:
    types:
      - deploy-production-from-release-please

permissions:
  actions: read
  contents: read
  id-token: write

jobs:
  dispatch-production:
    uses: OneCreditMY/ci-cd-workflows/.github/workflows/dispatch-production-from-release.yml@main
    with:
      aws-region: ap-southeast-5
      deploy-config-file: .github/deploy.apps.json
    secrets:
      aws-ecr-role-arn: ${{ secrets.AWS_ECR_ROLE_ARN }}
```

### Release PR Gate

```yaml
name: Release PR Gate

on:
  pull_request:
    types:
      - opened
      - reopened
      - synchronize
      - edited

permissions:
  actions: read
  contents: read
  pull-requests: read
  statuses: write

jobs:
  publish-release-pr-readiness-status:
    uses: OneCreditMY/ci-cd-workflows/.github/workflows/release-pr-gate.yml@main
    with:
      deploy-config-file: .github/deploy.apps.json
```

### Release Please

Use `OneCreditMY/ci-cd-workflows/.github/workflows/reusable-release-please.yml@main`.

Required behavior:
- Use `googleapis/release-please-action@v4` through the central workflow.
- Use `${{ github.token }}` only; do not pass PATs.
- Trigger production dispatch only from the repository default branch.
- Dispatch event type must be `deploy-production-from-release-please`.
- Dispatch payload must include `release_tag`, `source_workflow`, `source_run_id`, `source_sha`, and `source_ref`.

## Deploy Manifest

```json
{
  "defaults": {
    "staging": {
      "cluster": "apps-staging"
    },
    "production": {
      "cluster": "apps-production"
    }
  },
  "apps": {
    "API": {
      "versionFile": "api/version.txt",
      "ecrRepository": "service-api",
      "imageScope": "api",
      "containerName": "api",
      "build": {
        "context": "api",
        "dockerfile": "api/Dockerfile"
      },
      "staging": {
        "service": "service-api-staging",
        "taskDefinition": "api/task-definitions/staging.json"
      },
      "production": {
        "service": "service-api-production",
        "taskDefinition": "api/task-definitions/production.json"
      }
    }
  }
}
```

Required app fields for staging:
- `versionFile`
- `ecrRepository`
- `staging.service`
- `apps.<APP_KEY>.staging.cluster` or `defaults.staging.cluster`

Required app fields for production:
- `versionFile`
- `ecrRepository`
- `production.service`
- `apps.<APP_KEY>.production.cluster` or `defaults.production.cluster`

Useful optional fields:
- `build.context`
- `build.dockerfile`
- `imageScope`
- `containerName`
- `staging.containerName`
- `production.containerName`
- `staging.taskDefinition`
- `production.taskDefinition`

## Normalization Rules

Staging command `/deploy-consumer-dlq-replay` maps to:
- app name: `consumer-dlq-replay`
- app key: `CONSUMER_DLQ_REPLAY`

Release tag `consumer-v1.2.3` maps to:
- component: `consumer`
- app key: `CONSUMER`

This means every release-managed manifest app must have a release tag component that maps to its app key. Do not add entries like `CONSUMER_DLQ_REPLAY` to the release/production contract unless release-please can emit `consumer-dlq-replay-vX.Y.Z` or another tag that maps to that key.

## Validation Commands

Run from the target repo when practical:

```bash
python3 - <<'PY'
import pathlib, yaml
for path in pathlib.Path(".github/workflows").glob("*.yml"):
    yaml.safe_load(path.read_text())
print("workflow yaml ok")
PY

git diff --check
pre-commit run --files .github/workflows/*.yml .github/deploy.apps.json README.md .github/pull_request_template.md
```

For test changes, run the narrowest relevant test command. Example:

```bash
cd api
uv run pytest tests/unit/api/test_logging_warnings.py
```
