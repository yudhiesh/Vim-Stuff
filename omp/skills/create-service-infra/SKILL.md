---
name: create-service-infra
description: >
  Onboard one new ECS API or RabbitMQ consumer in the infrastructure
  repository. Creates all required stacked PRs in a single pass for one
  environment (staging or production). Part of the "Zero → Production"
  pipeline — runs after the application repository exists and before
  the first CI/CD deployment.
---

# Create Service Infra

Onboard exactly one ECS service for exactly one environment. The infrastructure
repository is the source of truth: copy its existing archetypes and neighboring
entries; do not invent template HCL.

## 1. Mode and prerequisites

Ask for `mode` before any other input. Valid modes are `execute` and `dry-run`.
If omitted, use `execute`.

In `execute` mode, verify all of these before intake:

1. The working directory is the infrastructure repository root.
2. Filesystem read/write access is available.
3. Git can create branches, commit, and push.
4. GitHub API access is available to create branches, pull requests, and PR descriptions.
5. Linear API access is available to validate the ticket.

If any execute prerequisite is unavailable, stop immediately and report the
missing item. Do not run intake, validation, confirmation, or PR generation.

In `dry-run` mode, GitHub, Linear, AWS, Git mutation, and write access are not
required and must not be used. Report those checks as `not-run`, not `passed`.
A dry-run may only use read-only commands such as `pwd`, `test`, `find`,
`grep`, `git status`, and `git diff --check`.

Dry-run is strictly read-only. Do not call APIs. Do not create, checkout,
reset, or remove branches. Do not write or format files. Do not stage, commit,
push, or create PRs. Do not run `tofu` or `terraform` commands. Report every
unavailable check honestly.

## 2. Scope and contracts

Handle only:

- ECS APIs: `service_slug` ends in `-api`.
- ECS RabbitMQ consumers: `service_slug` ends in `-consumer`.

Optional capabilities:

- PostgreSQL
- S3
- RabbitMQ
- Secrets Manager
- ECR

Do not modify:

- `modules/`
- Inventory files
- Application repositories
- Unrelated stacks

### Naming and tags

- `service_slug` is lowercase kebab-case and the exact map key for the ECR entry, and exact name for the Secrets Manager entry, ECS state path, ECS service/container, and API route.
- `project` is derived by removing `-api` or `-consumer` from `service_slug`, unless the user explicitly supplies another lowercase kebab-case value.
- `team` is exactly `Data`, `Product`, or `DevOps`.
- `service_identifier` is the Terraform identifier made by replacing hyphens in `service_slug` with underscores. `project_identifier` is the same normalization for `project`.
- Every generated `Project` tag and supported `additional_tags.Project` input must evaluate to `project`, never to `service_slug` or an archetype's old project. If a target module has no tag input, follow its module-specific limitation below rather than inventing one.
- Every generated `Team` tag and metadata `team` must evaluate to `team`.
- Preserve `ManagedBy = "OpenTofu"` and the selected environment.
- Before relying on the ECR convention, read both `global/ecr/main.tf` and `modules/aws/ecr/v1`. Verify that `global/ecr/main.tf` passes `each.key` as the child module's `name`, and that the child module builds `local.repository_name = lower(format("oc-%s-%s", var.environment, var.name))` and uses it for `aws_ecr_repository.this.name`. With `environment = "Shared"`, the ECR map key and child-module input remain `{service_slug}`, while the actual repository and ECS image repository component are exactly `oc-shared-{service_slug}`. If either implementation or prefix differs, stop and report the mismatch; do not hard-code a convention.
- `github.repository` in the ECR entry is the application GitHub repository, not the ECR map key or repository/image name. Ask for it when an ECR PR is needed; never infer it from `service_slug` or use it as an image repository component.

### Network rules

- APIs use the shared internal ALB and private Route53 zone.
- API route entries contain service slug, team, hostname, port `8080`, project tag, and health check path `/health`.
- Consumers have no ALB, Route53, or internal-route wiring.
- RabbitMQ is optional for APIs and always enabled for consumers.
- Staging has no private RabbitMQ security-group rule. The real staging API archetype has no RabbitMQ file, variable, or security-group mapping; with RabbitMQ enabled, preserve its exact eight-file API inventory, add no RabbitMQ HCL or private rule, and state that application credentials, queues, and exchanges are application-managed and outside this infrastructure PR. If infrastructure-managed RabbitMQ access is required, stop and report the missing source contract rather than copying consumer HCL or inventing rules.
- Production uses the EC2 RabbitMQ security group and TLS port `5671` only when the selected production archetype explicitly supplies that contract. If a production API with RabbitMQ lacks an explicit source file/variable/local security-group mapping for the EC2 rule, stop and report the missing archetype contract; never copy a consumer file or invent HCL.
- PostgreSQL ingress uses port `5432`.
- A new PostgreSQL cluster reads the ECS stack `security_group_id` through remote state and passes it as `allowed_security_group_ids` inside the existing PostgreSQL service module block.
- With `database_ref`, add exactly one ECS-side `5432` ingress rule sourced from the managed database cluster's exact remote-state `security_group_id` output. Add an explicit `terraform_remote_state` block for `{environment}/postgresql/{database_ref}/cluster/terraform.tfstate`, then assign `[data.terraform_remote_state.postgresql_cluster.outputs.security_group_id]` to the ECS stack's `postgresql_security_group_ids` local/input that drives `database_access.tf`. Never hard-code an SG ID.
- Without `database_ref`, set every copied `postgresql_security_group_ids` default or module input to `[]`. Retain `database_access.tf` only if its rule iterates over that empty list; otherwise remove every database ingress resource. The final ECS stack must have no TCP `5432` ingress.
- New PostgreSQL databases use `database_name = database_slug`. If the target PostgreSQL module or platform contract rejects that name, stop rather than retaining an archetype default such as `recsys`.

## 3. Intake

Handle one environment per run. Staging is first. Production is a later,
separate run with a separate Linear ticket.

Run this procedure in order:

1. Ask for `service_slug`.
   - Accept only lowercase kebab-case.
   - Require the suffix `-api` or `-consumer`.
   - Reject uppercase letters, underscores, spaces, and other suffixes.
2. Infer `service_type` from the suffix. Do not ask for it.
   - `-api` means `api`.
   - `-consumer` means `consumer`.
3. Derive `project` by removing the suffix.
   - Ask: `Project will be tagged as {project}, correct?`
   - Accept a correction only if it remains lowercase kebab-case.
4. Ask for `linear_ticket`.
   - Require `[A-Z]+-[0-9]+`.
   - In execute mode, verify it through Linear and stop if it does not exist.
   - In dry-run mode, do not call Linear; report ticket existence as `not-run`.
5. Ask for `team` and accept only `Data`, `Product`, or `DevOps`.
6. Set `environment` to `staging` by default and confirm it.
   - If `production` is selected, confirm that a separate production ticket exists and staging is already applied.
   - Do not process staging and production in one run.
7. Resolve database mode exactly once.
   - If the initial request names an existing managed database, set `database_mode = existing` and `database_ref` to that reference.
   - Otherwise ask whether a new PostgreSQL database is needed.
   - `no` sets `database_mode = none`.
   - `yes` sets `database_mode = new` and `database_slug = project` unless the user supplies another lowercase kebab-case slug.
   - `database_mode = existing` and `database_mode = new` are mutually exclusive.
8. For APIs only, ask whether RabbitMQ access is needed.
   - `yes` enables RabbitMQ.
   - `no` disables RabbitMQ.
   - Consumers always have RabbitMQ enabled; do not ask.
9. If S3 access is requested, ask for all three values:
   - `key`: S3 mapping key.
   - `scope`: `environment` or `shared`.
   - `access`: `read` or `full`.
10. Read `global/ecr/locals.tf`.
    - If `service_slug` has no existing mapping, include an ECR PR and ask for the application `github.repository` value.
    - If it already has a mapping, do not create an ECR PR and do not ask for `github.repository`.
11. Inspect the selected archetype's container image.
    - If the source explicitly marks the image as pipeline-managed, `image_ref` is not required.
    - Otherwise ask for `image_ref`; in execute mode it is required before confirmation and must reference the exact ECR repository `oc-shared-{service_slug}`. In dry-run mode report it as unresolved when absent. Do not use `github.repository` as the ECR repository or image component.

If `database_ref` was not named in the initial request, do not ask a second
question for an existing database reference after selecting `new` or `none`.

## 4. Validate

After intake and before confirmation, run every applicable check using
read-only inspection:

1. Verify `{environment}/ecs/shared/services/{service_slug}` does not exist.
2. Verify `{environment}/secretsmanager/locals.tf` exists.
3. Verify that file has no mapping for `{service_slug}`.
4. For APIs, verify `{environment}/internal-service-routes/locals.tf` exists.
5. For APIs, verify that file has no mapping for `{service_slug}`.
6. For `database_mode = new`, verify `{environment}/postgresql/{database_slug}/cluster` does not exist.
7. For `database_mode = new`, verify `{environment}/postgresql/{database_slug}/database` does not exist.
8. If an ECR PR is needed, verify `global/ecr/locals.tf` has no mapping for `{service_slug}`, then read both `global/ecr/main.tf` and `modules/aws/ecr/v1`. Verify the global module passes `each.key` as `name`, the child module derives `lower(format("oc-%s-%s", var.environment, var.name))` for the repository name, and `environment = "Shared"` therefore yields map key/input `{service_slug}` but actual repository/image component `oc-shared-{service_slug}`. Stop and report any implementation or prefix mismatch before generation.
9. If S3 was requested, verify the selected S3 `locals.tf` exists and has no mapping for `{key}`.
10. Verify `{environment}-atlantis.yaml` exists before any generation.
11. Read `{environment}-atlantis.yaml`. For every Atlantis project entry this
    run will add (ECS, and optionally PostgreSQL cluster + database), verify
    that no existing entry has the same `name` or `dir` value. If any
    duplicate exists, stop and report it.
12. If `database_mode = existing`, verify the managed database stack for `database_ref` exists and exposes the exact `security_group_id` output.
13. Verify the Git working tree has no unrelated uncommitted changes.
14. Verify the selected source archetype matches the exact file inventory from section 6: no expected file is missing and no extra file is present. For staging API + RabbitMQ, verify the real API source has exactly the eight API files and no RabbitMQ file, variable, or security-group mapping; preserve that application-managed contract without adding HCL. If infrastructure-managed access was requested, stop and report the missing source contract. For a production API with RabbitMQ, verify an explicit RabbitMQ source file/variable/local SG mapping exists; otherwise stop and report the missing archetype contract.
15. Verify the source image is explicitly pipeline-managed or that a valid `image_ref` was supplied. A missing image policy is a failed execute check.

In `execute` mode, any failed check stops the run immediately. Do not clean,
stash, overwrite, or continue around a failed check. Do not confirm or
produce branches after a failed check.

In `dry-run` mode, report every result and continue with read-only simulation.
A failed clean-tree check remains a blocker in the report; it is never silently
cleaned or treated as passed.

If the user corrects any value, rerun every applicable validation check, not
only checks that appear affected, before showing confirmation again.

## 5. Confirm

In `execute` mode, present this summary and wait for the exact response `go` or
`yes` (case-insensitive). Any other response means stop without mutation:

```text
Creating {environment} infrastructure for `{service_slug}`:
- Team: {team}, Project: {project}
- Database: `new ({database_slug})`, `existing ({database_ref})`, or `none`
- RabbitMQ: `yes` or `no`
- Linear ticket: {linear_ticket}
- PRs: {comma-separated PR types}
- Atlantis projects to add:
  - {environment}-ecs-{service_slug}
  - {environment}-postgresql-{database_slug}-cluster  (if database = new)
  - {environment}-postgresql-{database_slug}-database  (if database = new)

Confirm?
```

Do not create branches, commits, pushes, or PRs before confirmation. Any other
response means stop without mutation.

In `dry-run` mode, show the same summary and the planned PR matrix, but never
interpret confirmation as permission to mutate. Dry-run always ends after the
report and does not require confirmation.

## 6. PR Generation

The following operations apply only in `execute` mode and only after passing
validation and confirmation.

### Branch, base, and PR title conventions

Every branch uses the format `feature/{linear_ticket}-{suffix}`. The suffixes
are `ecr`, `secretsmanager`, `s3`, `internal-routes`, `ecs-service`, and
`postgresql`.
Every PR title uses the format `{linear_ticket}: {commit_message}`.

The commit message remains unchanged (Conventional Commit format).

For the ordered list of applicable PRs, assign stack layer numbers starting at
1. The first applicable branch is created from the environment repository's
default branch and its PR base is that default branch. Each subsequent branch
is created from the immediately preceding applicable branch and its PR base is
that branch. For example, when all six layers apply:

```text
feature/DAT-1625-ecr             -> PR 1, base: main
feature/DAT-1625-secretsmanager  -> PR 2, base: feature/DAT-1625-ecr
feature/DAT-1625-s3              -> PR 3, base: feature/DAT-1625-secretsmanager
feature/DAT-1625-internal-routes -> PR 4, base: feature/DAT-1625-s3
feature/DAT-1625-ecs-service     -> PR 5, base: feature/DAT-1625-internal-routes
feature/DAT-1625-postgresql      -> PR 6, base: feature/DAT-1625-ecs-service
```

Omitted PR types are removed from the chain; do not leave a gap or point a PR
at a nonexistent branch. Use explicit GitHub API/CLI `head` and `base` values.

For every PR:

1. Start from the environment repository default branch.
2. Create the exact branch specified by the applicable PR section. For the
   first applicable layer, branch from the default branch; for every later
   layer, branch from the immediately preceding applicable layer.
3. Make only the listed stack changes.
4. Use the Atlantis duplicate check from validation step 4.11 before adding any project entry.
5. Use existing formatting and neighboring entry shapes.
6. Run `git diff --check`.
7. Commit with the specified Conventional Commit message.
8. Push the branch.
9. Create the PR through the GitHub API with the exact stack head and base.
10. Include the required description fields from section 7, including layer,
    stack predecessor, and merge order.
11. Read back the created PR and verify its base branch, head branch, and
    changed-file diff before proceeding to the next layer.
12. Keep the new branch checked out while creating the next layer.

Do not wait for Atlantis, CI, merging, or user input between PR creations.
The PRs are created as one linear stack, but do not merge or apply them in this
step. Do not run OpenTofu or Terraform plan/apply. Dry-run performs none of
these mutating steps.

All applicable PRs use this stack order:

```text
default branch
  └─ ECR
       └─ Secrets Manager
            └─ S3
                 └─ Internal Routes
                      └─ ECS Service
                           └─ PostgreSQL
```

The first applicable PR targets the environment repository's default branch.
Every later applicable PR targets the head branch of the previous applicable
PR. If ECR or S3 is omitted, the next applicable layer targets the most recent
applicable layer. The branch/base relationship is authoritative; PR
descriptions and labels are supporting metadata.

Create branches and PRs in this order. For each layer after the first,
checkout the previous layer's branch before creating the new branch. Do not
return to the default branch between stacked layers.

Before creating or updating a stack, record every branch name, PR number when
known, head SHA, base branch, and base SHA. After each push, verify the PR's
base/head relationship and changed-file diff. A rewritten lower branch requires
a cascading update of every branch above it, followed by fresh CI and Atlantis
plans for all affected PRs.

### PR 1: ECR — conditional

Create when `global/ecr/locals.tf` has no mapping for `service_slug`.

- File: `global/ecr/locals.tf`.
- Append one entry with:
  - map key `{service_slug}`;
  - `team = "{team}"`;
  - `github.org = "OneCreditMY"`;
  - `github.repository = {github_repository}` supplied during intake;
  - `github.branches = []`;
  - `additional_tags.Project = "{project}"`.
- Preserve `{service_slug}` as the ECR map key and child-module `name` input. After the source-of-truth check confirms both ECR files derive the Shared repository as `oc-shared-{service_slug}`, use `oc-shared-{service_slug}` as the actual repository/image component. Do not conflate `github.repository` with either value; if the source-of-truth check fails, stop rather than hard-coding this convention.
- Do not add an Atlantis project.
- Stack predecessor: `none — bottom layer; base is the environment default branch`.
- Apply prerequisite: `none`.
- Branch: `feature/{linear_ticket}-ecr`; base: the environment default branch.
- Commit: `feat(ecr): add {service_slug} repository`.

### PR 2: Secrets Manager — always

- File: `{environment}/secretsmanager/locals.tf`.
- Append metadata using this exact shape:

```hcl
{service_slug} = {
  name           = "{service_slug}"
  team           = "{team}"
  description    = "Secrets required by {service_slug} in {environment}."
  enable_replica = false
  additional_tags = {
    Project = "{project}"
  }
}
```

- Add metadata only. Never add secret values.
- Do not add Datadog access to Secrets Manager locals.

Datadog secret access is handled in the ECS stack's `iam.tf`, not in
Secrets Manager locals. The ECS PR (PR 5) preserves the
`execution_datadog_secret_access` IAM policy attachment from the source
archetype. Do not add a Datadog entry to Secrets Manager `locals.tf`.

- In the copied ECS `iam.tf`, preserve the exact
  `aws_iam_role_policy_attachment.execution_datadog_secret_access` resource
  from `{environment}/ecs/shared/services/recommendation-service/iam.tf` or
  the corresponding consumer archetype. Its policy lookup must remain
  `secret_read_only_policy_arns["datadog_api_token"]`.
- Change only the service-secret lookup in
  `aws_iam_role_policy_attachment.execution_secret_access` to
  `secret_read_only_policy_arns["{service_slug}"]`. If either attachment is
  absent, stop rather than invent HCL.
- Do not add an Atlantis project.
- Stack predecessor: ECR when the ECR PR exists; otherwise the environment default branch.
- Apply prerequisite: `none`.
- Branch: `feature/{linear_ticket}-secretsmanager`; base: the previous applicable layer.
- Commit: `feat(secretsmanager): add {service_slug} secrets`.

### PR 3: S3 — conditional

Create only when S3 access was requested.

- File: `{environment}/s3/locals.tf` for `scope = environment`; otherwise `global/s3/locals.tf`.
- Append one mapping using the supplied `key`, `scope`, and `access`.
- Use existing S3 module policy ARNs. Never invent wildcard policies.
- Do not add an Atlantis project.
- Stack predecessor: the previous applicable layer.
- Apply prerequisite: `none`.
- Branch: `feature/{linear_ticket}-s3`; base: the previous applicable layer.
- Commit: `feat(s3): add {key} access`.

### PR 4: Internal Routes — API only

- File: `{environment}/internal-service-routes/locals.tf`.
- Append one `service_routes` entry with:

```hcl
{
  name              = "{service_slug}"
  team              = "{team}"
  hostnames         = ["{service_slug}.internal.{environment}.onecredit.my"]
  port              = 8080
  health_check_path = "/health"
  tags = {
    Project = "{project}"
  }
}
```

The generated application template exposes `/health` by default. If the
application uses a different health check path, update this route entry
after generation.

- Do not add a legacy priority override; automatic priority calculation applies.
- Do not add an Atlantis project.
- Stack predecessor: the previous applicable layer.
- Apply prerequisite: `none`.
- Branch: `feature/{linear_ticket}-internal-routes`; base: the previous applicable layer.
- Commit: `feat(routes): add {service_slug} route`.

### PR 5: ECS Service — always

- Staging API source: `staging/ecs/shared/services/recommendation-service`. Its real source has exactly the eight API files and no RabbitMQ file, variable, or security-group mapping.
- Staging consumer source: `staging/ecs/shared/services/recommendation-service-consumer`.
- Production source: use the corresponding `production/ecs/shared/services` archetype only after verifying the same file inventory, IAM attachment, image policy, and network contracts. For a production API with RabbitMQ, the source must explicitly contain the RabbitMQ file/variable/local security-group mapping required for EC2 TLS `5671`; if it does not, stop and report the missing archetype contract. The eight-file API inventory cannot implement an absent rule. Never copy a consumer file or invent HCL, SG IDs, or mappings, and never silently use staging sources for production.
- Target: `{environment}/ecs/shared/services/{service_slug}`.
- Copy the complete selected source directory. Do not silently omit files or add files from another archetype.

Exact API source files:

```text
database_access.tf
iam.tf
locals.tf
main.tf
outputs.tf
providers.tf
variables.tf
versions.tf
```

Exact consumer source files are those eight plus:

```text
rabbitmq_access.tf
```

Copy and replace in this order:

1. Copy the entire selected archetype directory.
2. API: replace every service-name token `recommendation-service` with `{service_slug}` and every Terraform identifier `recommendation_service` with `{service_identifier}`.
3. Consumer: replace `recommendation-service-consumer` with `{service_slug}` and `recommendation_service_consumer` with `{service_identifier}`. Then replace remaining old base-project tokens `recommendation-service` and `recommendation_service` with `{project}` and `{project_identifier}` only where they identify the old base service. Do not broadly alter module source paths or unrelated provider names.
4. Set `service_name = "{service_slug}"`.
5. Add or set `project = "{project}"` and make every `Project` tag use `local.project`, not `local.service_name`.
6. Set team values to `{team}` and ensure every `Team` tag resolves to `{team}`.
7. Preserve `ManagedBy = "OpenTofu"` and the selected environment.
8. Set the container name to `{service_slug}`, set the ECS container port to `8080`, and replace old ECR image components such as `oc-shared-recommendation-service` with `oc-shared-{service_slug}` only after the source-of-truth check for both ECR files. Do not invent an image tag. If `image_ref` was supplied, use it only after verifying its repository component is exactly `oc-shared-{service_slug}`; never use `github.repository` or bare `{service_slug}` as the image repository. Retain a placeholder only when the source line explicitly identifies the image as pipeline-managed. Otherwise stop and request an image reference. When a pipeline-managed placeholder is retained, preserve its placeholder marker, add `managed by deployment pipeline: replace before apply`, and include the image replacement checklist in the PR description.
9. In copied `outputs.tf`, replace every stale service description (including `monitoring service`) with exactly `{service_slug} ECS service`; do not merely remove the old phrase. Replace old project literals such as `oc-recsys` everywhere they identify the old project.
10. API only: preserve shared ALB and internal-route wiring. Consumer: preserve no-ALB/no-Route53 behavior.
11. RabbitMQ final state:
    - API with RabbitMQ disabled: remove every RabbitMQ file, reference, and security-group rule.
    - API with RabbitMQ enabled: for staging, preserve the exact eight-file API inventory from the real archetype, add no RabbitMQ HCL or private security-group rule, and state that application credentials, queues, and exchanges are application-managed and outside this infrastructure PR.

      Include this exact text in the ECS PR description under the post-apply
      checklist:

        RabbitMQ access in staging does not require infrastructure changes.
        Application code manages credentials, queues, and exchanges directly.
        See the application repository README for RabbitMQ configuration.

      If infrastructure-managed staging access is requested, stop and report the missing source contract rather than copying consumer files or inventing HCL. In production, require the selected API archetype's explicit RabbitMQ file/variable/local EC2 security-group mapping for TLS TCP `5671`; if absent, stop and report the missing archetype contract rather than copying consumer files or inventing HCL.
    - Consumer: RabbitMQ remains enabled; staging has no private RabbitMQ security-group rule; production uses only the source archetype's explicit EC2 RabbitMQ security-group mapping on TLS TCP `5671`.
    - Infrastructure does not create queues or exchanges; application owners create them in code.
12. Database final state:
    - With `database_ref`: add this exact read-only state block to the copied ECS stack:
      ```hcl
      data "terraform_remote_state" "postgresql_cluster" {
        backend = "s3"

        config = {
          bucket = "oc-shared-opentofu-state"
          key    = "{environment}/postgresql/{database_ref}/cluster/terraform.tfstate"
          region = "ap-southeast-5"
        }
      }
      ```
      Verify the managed stack exposes `security_group_id`, then explicitly assign the ECS stack's input/local that drives the ingress list:
      ```hcl
      locals {
        postgresql_security_group_ids = [
          data.terraform_remote_state.postgresql_cluster.outputs.security_group_id
        ]
      }
      ```
      Have `database_access.tf` iterate over `local.postgresql_security_group_ids` (not a hard-coded ID) to create exactly one TCP `5432` ingress rule. Never use another output name.
    - Without `database_ref`: set every copied `postgresql_security_group_ids` default or module input to `[]`. Retain `database_access.tf` only when its rule iterates over that empty list; otherwise remove every database ingress resource. The final ECS stack must have no TCP `5432` ingress.
13. Preserve the ECS `security_group_id` output.
14. Add exactly one Atlantis entry (validated for duplicates in step 4.11):

```yaml
- <<: *default
  name: {environment}-ecs-{service_slug}
  dir: {environment}/ecs/shared/services/{service_slug}
```

The entry must inherit `*default`; do not invent per-project workflow settings.

Before staging or committing, report every copied file and run read-only
residual checks. Require zero unexplained matches for:

- old hyphenated and underscore service tokens;
- `monitoring service`;
- `oc-recsys` and old project literals;
- wrong `Project` or `Team` values;
- database `5432` rules when `database_ref` is unset;
- private RabbitMQ rules in staging;
- old ECR image repository components (for example `oc-shared-recommendation-service`); the final ECR image component must be exactly `oc-shared-{service_slug}`, never the map key alone or `github.repository`.

For consumers, rerun the residual grep for both `recommendation-service` and
`recommendation_service` after every replacement and require zero matches.
Stop on any unexplained match.

- Stack predecessor: the previous applicable layer.
- Apply prerequisite: ECR must be merged and applied first when an ECR PR exists; otherwise `none`.
- Branch: `feature/{linear_ticket}-ecs-service`; base: the previous applicable layer.
- Commit: `feat(ecs): add {service_slug} service`.

### PR 6: PostgreSQL — conditional

Create when `database_mode = new`. Cluster and database are in one PR.

- Cluster source: `{environment}/postgresql/recommendation-service/cluster`.
- Database source: `{environment}/postgresql/recommendation-service/database`.
- Targets: `{environment}/postgresql/{database_slug}/cluster` and `/database`.
- Copy every source file. Current archetypes contain five cluster files and six database files.
- Replace every old hyphenated and underscore service token with `{database_slug}` and `{database_identifier}` where it identifies the state path, service variable, module/reference name, or database mapping.
- Set `service = "{database_slug}"`, `database_name = "{database_slug}"`, and `team = "{team}"` using only inputs supported by each copied module. This skill intentionally standardizes new database names on `database_slug`; do not retain `recsys`.
- Cluster tagging contract: the PostgreSQL cluster archetype/module supports `tags`; set the supported cluster `additional_tags.Project = "{project}"` and preserve the other required tags.
- Database tagging contract: inspect the database module variables before generation. The current `modules/aws/postgresql_database/v1` has no `tags` or `additional_tags` input, so preserve its supported inputs and do not add an unsupported tag argument, variable, or invented HCL. If Project tagging is a platform requirement for the database resource, stop and report this platform limitation; do not modify the module.
- Require zero `recommendation-service` and `recsys` matches in both target directories.

The cluster must read the ECS stack's `security_group_id` through remote state:

```hcl
data "terraform_remote_state" "ecs_service" {
  backend = "s3"

  config = {
    bucket = "oc-shared-opentofu-state"
    key    = "{environment}/ecs/shared/services/{service_slug}/terraform.tfstate"
    region = "ap-southeast-5"
  }
}
```

Add the argument inside the existing `module "postgresql_service"` block;
never place it at top level:

```hcl
module "postgresql_service" {
  # preserve the existing source and arguments
  source = "../../../../modules/aws/postgresql_service/v2"

  # existing arguments remain here
  allowed_security_group_ids = [
    data.terraform_remote_state.ecs_service.outputs.security_group_id
  ]
}
```

If the ECS output is absent, stop rather than guessing an output or security
group ID. Add no credentials or secret values.

Add exactly these inherited Atlantis entries (validated for duplicates in step 4.11), cluster first:

```yaml
- <<: *default
  name: {environment}-postgresql-{database_slug}-cluster
  dir: {environment}/postgresql/{database_slug}/cluster
- <<: *default
  name: {environment}-postgresql-{database_slug}-database
  dir: {environment}/postgresql/{database_slug}/database
```

Preserve the repository's
`tofu` workflow, OpenTofu distribution, version `1.10.6`, and autoplan settings
through `*default`.

- Stack predecessor: ECS.
- Apply prerequisite: ECS must be merged and applied first.
- Branch: `feature/{linear_ticket}-postgresql`; base: ECS.
- Commit: `feat(postgresql): add {database_slug} database`.

## 7. PR Descriptions

Every PR description must contain these fields in this order:

1. `Linear ticket: {linear_ticket}`
2. `Environment: {environment}`
3. `Stack: {linear_ticket}, layer {layer_number}/{layer_count}`
4. `Branch: {head_branch}`
5. `Base: {base_branch}`
6. `Creates: {specific resources and files}`
7. `Stack predecessor: {previous PR number/branch, or "none — bottom layer"}`
8. `Apply prerequisite: {required applied PRs, or "none"}`
9. `Merge order: merge bottom-up; this is layer {layer_number} of {layer_count}`
10. `Atlantis: {existing stack or new project entries}`

The description must not say that stacked layers can merge in parallel. CI and
Atlantis plans may run in parallel, but merges and applies proceed bottom-up.
Every PR above a failing, conflicted, stale, or unapplied lower PR is blocked.

The ECS description must include:

- [ ] Populate Secrets Manager values manually.
- [ ] Ensure the Docker image listens on port `8080`.
- [ ] Replace any deployment-pipeline placeholder image before apply.
- [ ] Create RabbitMQ queues/exchanges in application code if RabbitMQ is enabled.
- [ ] For staging API RabbitMQ: credentials, queues, and exchanges are application-managed. No infrastructure RabbitMQ changes in this PR.
- [ ] Use PostgreSQL Parameter Store roles; read-only is preferred for runtime.
- [ ] Configure application S3 settings if S3 is enabled.

The PostgreSQL description must state that PostgreSQL creates admin and
read-only roles in Parameter Store and credentials are not injected into ECS.

## 8. Handoff

In execute mode, after all applicable PRs are created, return actual PR links
only. Never fabricate links.

Summarize the stack from bottom to top, including each actual PR number and
branch. State that merges proceed strictly bottom-up. A higher PR may be
reviewed while lower PRs are open, but it must not merge until every lower
layer has passed required checks and the infrastructure prerequisites needed by
that layer have been applied. PostgreSQL Atlantis still applies the cluster
before the database.

End with exactly:

`DevOps will review and merge these via Atlantis. Your infrastructure will be ready after all PRs are applied.`

In dry-run mode, return the planned PR matrix, branch names, commit messages,
files, replacements, dependencies, and unresolved inputs instead of links.
Stop after the report. Do not check Atlantis results or resume the workflow.

## 9. Dry-run acceptance fixture

The following fixture must be supported without API calls or mutation:

```text
service_slug: demo-api
service_type: api
project: demo
team: Data
environment: staging
database_mode: new
database_slug: demo
rabbitmq: yes
s3: no
database_ref: unset
linear_ticket: DAT-1625
```

A correct dry-run report must contain the following exact PR matrix. Do not add
unstated dependencies or invent a production ticket:

| PR | Branch | Base | Commit | Files | Stack/apply dependencies |
|---|---|---|---|---|
| ECR (when the mapping is absent) | `feature/DAT-1625-ecr` | `main` | `feat(ecr): add demo-api repository` | `global/ecr/locals.tf` | layer 1; no apply prerequisite |
| Secrets Manager | `feature/DAT-1625-secretsmanager` | `feature/DAT-1625-ecr` | `feat(secretsmanager): add demo-api secrets` | `staging/secretsmanager/locals.tf` | layer 2; no apply prerequisite |
| Internal Routes | `feature/DAT-1625-internal-routes` | `feature/DAT-1625-secretsmanager` | `feat(routes): add demo-api route` | `staging/internal-service-routes/locals.tf` | layer 3; no apply prerequisite |
| ECS Service | `feature/DAT-1625-ecs-service` | `feature/DAT-1625-internal-routes` | `feat(ecs): add demo-api service` | exactly the eight API files under `staging/ecs/shared/services/demo-api`, plus one inherited Atlantis entry | layer 4; ECR merged and applied first when the ECR PR exists |
| PostgreSQL | `feature/DAT-1625-postgresql` | `feature/DAT-1625-ecs-service` | `feat(postgresql): add demo database` | five cluster files, six database files, plus two inherited Atlantis entries | layer 5; ECS merged and applied first |

No S3, application-repository, inventory, module, or state PR is planned. The
applicable stack therefore skips the S3 layer and PostgreSQL is based directly
on the ECS branch.
`github.repository` is an unresolved application-repository input when ECR is
needed; it is never an ECR dependency and never a production-ticket
requirement.

The report must also state:

- `DAT-1625` format is valid; Linear existence is `not-run`.
- The ECR map key and child-module input are `demo-api`; the Shared resource and ECS image repository component are `oc-shared-demo-api`. `github.repository` remains unresolved and separate from both values.
- If the source image is marked only `Placeholder image` and not explicitly pipeline-managed, `image_ref` is unresolved and execute-mode generation stops.
- Secrets Manager adds metadata only; no Datadog rule is added to its locals.
- Route is `demo-api.internal.staging.onecredit.my`, port `8080`, health check `/health`, project `demo`, team `Data`.
- The confirmation summary lists `staging-ecs-demo-api`, `staging-postgresql-demo-cluster`, and `staging-postgresql-demo-database`, with the PostgreSQL entries present because `database_mode = new`.
- The ECS target contains exactly these files: `database_access.tf`, `iam.tf`, `locals.tf`, `main.tf`, `outputs.tf`, `providers.tf`, `variables.tf`, and `versions.tf`. It sets `project = "demo"`, makes every Project tag resolve through `local.project`, uses container port `8080`, preserves `security_group_id`, sets `postgresql_security_group_ids = []`, and has no PostgreSQL ingress because `database_ref` is unset.
- For staging API RabbitMQ, the ECS target has no RabbitMQ HCL, private rule, or extra file, and the ECS PR description includes exactly:

  ```text
  RabbitMQ access in staging does not require infrastructure changes.
  Application code manages credentials, queues, and exchanges directly.
  See the application repository README for RabbitMQ configuration.
  ```

- PostgreSQL contains five cluster files and six database files, uses database name `demo`, and adds `allowed_security_group_ids` inside the existing PostgreSQL module block. The cluster remote state must preserve `backend = "s3"`, bucket `oc-shared-opentofu-state`, region `ap-southeast-5`, and key `staging/ecs/shared/services/demo-api/terraform.tfstate`. Cluster Atlantis is listed before database Atlantis.
- The cluster Project tag resolves to `demo` where supported. Do not pass unsupported `tags` or `additional_tags` to the database module. If Project tagging is a platform requirement for the database resource, stop and report the platform limitation.
- Residual-grep expectations are explicitly listed and must be zero in generated targets for: `recommendation-service`, `recommendation_service`, bare `recsys`, `oc-recsys`, `monitoring service`, old ECR components such as `oc-shared-recommendation-service`, wrong Project or Team values, database `5432` rules when `database_ref` is unset, and private staging RabbitMQ rules. If targets do not exist in dry-run, report those target greps as `not-run` or `not-applicable` and state the expected result is zero.
- Every copied file, literal/token replacement, residual-grep result, and `git diff --check` result is reported.
- API, Linear, AWS, Atlantis, remote Git, branch, commit, push, PR, and other mutation checks are explicitly `not-run`. Local read-only checks such as `git status` and `git diff --check` must report their actual results; do not call an unperformed check passed.
- No files, branches, index, state, API calls, OpenTofu/Terraform commands, or PRs were changed or created.

Before finishing, perform this report-completeness self-check and stop with an
incomplete-report status if any item is missing:

- [ ] Exact five-row PR matrix, including conditional ECR, explicit bases, and exact stack/apply dependencies.
- [ ] ECR map key, child input, `oc-shared-demo-api`, and unresolved `github.repository` are separated.
- [ ] Exact eight-file ECS inventory, `project = "demo"`, `Project = local.project`, and no RabbitMQ HCL are reported.
- [ ] Exact three-line staging RabbitMQ text is included.
- [ ] PostgreSQL file counts, remote-state backend/bucket/region/key, and `allowed_security_group_ids` are reported.
- [ ] Unsupported database tags and the platform-limitation stop condition are reported.
- [ ] Every required residual token/category has an explicit zero expectation and actual status.
- [ ] Every read-only/API/Git/Linear check and every mutation is classified honestly.
- [ ] Dirty-tree status, copied files, replacements, and `git diff --check` are reported.

## 10. Safety Rules

These rules are non-negotiable:

- Never put AWS credentials, secret values, database passwords, or application credentials in generated files.
- Never run `tofu plan`, `tofu apply`, `terraform plan`, or `terraform apply`.
- Never modify files under `modules/`.
- Never overwrite existing service directories or stack mappings.
- Never silently auto-rebase or force-push. If a lower branch changes or its
  base merges, perform an explicit cascading rebase only after recording the
  old SHAs and validating the intended chain. Publish rewritten branches only
  with `--force-with-lease`, then require fresh CI and Atlantis plans for every
  affected PR.
- Never merge an upper stack layer while a lower layer is failing, conflicted,
  stale, unapplied, or has an unexpected diff.
- On a rebase conflict, stop, preserve the affected branch, resolve from the
  lowest layer upward, and revalidate every PR's base/head relationship before
  continuing.
- Do not use guessed repository names, image tags, secret patterns, security-group outputs, security-group IDs, or database names to resolve ambiguity; stop and report the missing input.
- Do not claim a check, ticket, PR, apply, or merge that was not performed.
- Secrets Manager metadata is generated; users populate actual secret values after apply.
- PostgreSQL creates admin and read-only roles in Parameter Store; document consumption but do not inject roles into ECS.
- S3 permissions come from the S3 module policy ARNs; do not invent wildcard policies.
- The skill's own implementation must not modify infrastructure files.
