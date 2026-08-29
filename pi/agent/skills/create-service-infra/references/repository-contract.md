# Infrastructure Repository Contract

Use this reference when generating or reviewing a manifest. Inspect the live checkout if a pattern has changed.

## Stack boundaries

| Capability | Staging | Production | PR behavior |
| --- | --- | --- | --- |
| ECS service | `staging/ecs/shared/services/<slug>` | `production/ecs/shared/services/<slug>` | New Atlantis project entry in the same PR |
| Secrets | `staging/secretsmanager/locals.tf` | `production/secretsmanager/locals.tf` | Existing shared stack mapping only |
| S3 | `staging/s3/locals.tf` | `production/s3/locals.tf` | Existing mapping; use `global/s3` only when cross-environment |
| Internal routes | `staging/internal-service-routes/locals.tf` | `production/internal-service-routes/locals.tf` | Existing mapping only; APIs only |
| PostgreSQL cluster | `staging/postgresql/<db>/cluster` | `production/postgresql/<db>/cluster` | New Atlantis project |
| PostgreSQL database | `staging/postgresql/<db>/database` | `production/postgresql/<db>/database` | New Atlantis project |
| Shared ECR | `global/ecr/locals.tf` | same | One global PR, linked to both environment tickets |

The matching Atlantis config is `staging-atlantis.yaml` or `production-atlantis.yaml`. Use the existing `tofu` workflow and OpenTofu 1.10.6 settings.

## Archetypes

- API: `staging/ecs/shared/services/recommendation-service` or its production equivalent.
- Consumer: `staging/ecs/shared/services/recommendation-service-consumer` or its production equivalent.
- PostgreSQL cluster: `staging/postgresql/recommendation-service/cluster` or production equivalent, using `modules/aws/postgresql_service/v2` with `backend = "postgres"`.
- PostgreSQL database: matching `database` directory using `modules/aws/postgresql_database/v1`.
- S3 access: `modules/aws/s3/v1` outputs `read_access_policy_arn` and `full_access_policy_arn`; attach the selected policy to the application ECS task role, following the MLflow service pattern.

## Network rules

- APIs use the shared internal ALB and private Route53 zone. Add a route entry with the service slug, team, hostname, port, project tag, and default `/health` check.
- Consumers do not get ALB or Route53 wiring.
- RabbitMQ is optional for APIs and required for consumers. Staging does not add private RabbitMQ SG rules. Production uses the established EC2 RabbitMQ security groups and TLS port 5671.
- PostgreSQL access uses port 5432. A new PostgreSQL cluster should read the applied ECS service stack’s `security_group_id` through remote state and pass it as `allowed_security_group_ids`. A service using `database_ref` should read the managed database stack’s `security_group_id` and add the 5432 rule from the ECS stack.

## Naming and tags

- New API slugs end in `-api`.
- New consumer slugs end in `-consumer`.
- `Team` is one of `Data`, `Product`, or `DevOps`.
- `Project` is an explicit lowercase-kebab identifier and may differ from the service slug.
- Preserve `ManagedBy = OpenTofu`, environment, team, project, and `oc-{environment}-{suffix}` naming behavior.
- ECR names derive from the service slug; project remains a tag.

## Security boundaries

- Never put AWS credentials, secret values, database passwords, or application credentials in generated files.
- Secrets Manager metadata and read-only policies are environment-scoped. Users populate values after apply.
- PostgreSQL creates admin and read-only roles in Parameter Store. The skill documents consumption but does not inject them into ECS.
- S3 permissions come from the S3 module’s generated policy ARNs. Do not invent wildcard policies.
- Keep application access on the ECS task role; keep ECS execution-role access limited to ECS execution needs and the existing secret/Datadog pattern.
