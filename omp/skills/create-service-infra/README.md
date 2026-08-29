# Create Service Infrastructure

This directory contains the `create-service-infra` skill and an end-to-end
example for onboarding an API service.

## Example: onboarding `demo-api`

### User prompt

```text
Run the create-service-infra skill in execute mode for DAT-1625:
  service_slug: demo-api
  team: Data
  environment: staging
  database_mode: new
  database_slug: demo
  rabbitmq: yes
  s3: no
  linear_ticket: DAT-1625
  github.repository: oc-nexus
Follow the skill exactly. Generate all applicable PRs (ECR, Secrets Manager,
Internal Routes, ECS, PostgreSQL) in one pass. Use the section 9 report
template for the final summary — every subsection present, exact values, no
paraphrasing.
When you hit the confirmation step, show it and wait for "go".
```

### Confirmation output

```text
Creating staging infrastructure for `demo-api`:
- Team: Data, Project: demo
- Database: `new (demo)`
- RabbitMQ: yes
- Linear ticket: DAT-1625
- PRs: ECR, Secrets Manager, Internal Routes, ECS, PostgreSQL
- Atlantis projects to add:
  - staging-ecs-demo-api
  - staging-postgresql-demo-cluster
  - staging-postgresql-demo-database

Confirm?
```

### User confirmation

```text
go
```

### Generated PRs

```text
- ECR: https://github.com/OneCreditMY/infrastructure/pull/276
- Secrets Manager: https://github.com/OneCreditMY/infrastructure/pull/277
- Internal Routes: https://github.com/OneCreditMY/infrastructure/pull/278
- ECS Service: https://github.com/OneCreditMY/infrastructure/pull/279
- PostgreSQL: https://github.com/OneCreditMY/infrastructure/pull/280
```

Merge order:

1. ECR is the bottom layer and targets `main`.
2. Secrets Manager targets `feature/DAT-1625-ecr`.
3. Internal Routes targets `feature/DAT-1625-secretsmanager`.
4. ECS targets `feature/DAT-1625-internal-routes` and waits for ECR to be merged and applied.
5. PostgreSQL targets `feature/DAT-1625-ecs-service` and waits for ECS to be merged and applied.
6. Merge all layers strictly bottom-up. PostgreSQL Atlantis applies the cluster before the database.

Each PR description records its stack layer, head branch, base branch, stack
predecessor, apply prerequisites, and merge order. CI and Atlantis plans may
run while the stack is open, but higher layers do not merge or apply before
lower layers.

### Atlantis plan review

```text
Atlantis Review

- PR #276 ECR: Matches. Creates oc-shared-demo-api; no unexpected changes.
- PR #277 Secrets Manager: Matches. Creates expected secret and IAM policies; no secret values or Datadog changes.
- PR #278 Internal Routes: Matches with note. Adds the expected route, but recalculates priorities for 14 existing listener rules.
- PR #279 ECS: Blocked on the current base. The expected Secrets Manager key and route target are absent because prerequisite PRs are not merged. No RabbitMQ or PostgreSQL ingress changes.
- PR #280 PostgreSQL: Blocked on the current base. ECS and cluster remote-state outputs are unavailable because dependencies are not applied yet. Cluster is configured before database.

Production Atlantis comments: none found.
No plans were applied, and no comments were posted.
```

See [`SKILL.md`](./SKILL.md) for the complete intake, validation,
confirmation, generation, and handoff workflow.
