---
name: aws-cost-tag-audit
description: Run read-only AWS cost allocation tag compliance audits and Cost Explorer breakdowns through aws-vault, with optional remediation tracking in Linear. Use when you need to check selected service sections (for example RDS/Aurora or ECS services) against required base tags such as Environment, ManagedBy, Project, and Team, and when you need service-level spend or "Others" breakdowns (for example Usage+Support views and region-filtered views).
---

# AWS Cost Tag Audit

## Inputs
Collect these inputs first:
- `aws_profile` (example: `oc-admin`)
- `regions` (comma-separated, or `all`)
- `sections` (comma-separated; supported: `rds-aurora`, `ecs-services`)
- `required_tags` (default: `Environment,ManagedBy,Project,Team`)
- `output_dir` (optional; defaults to current directory)
- `linear_parent_issue` (optional; example: `ENG-3852`)
- `linear_project` and `linear_milestone` (optional)
- `cost_period_start` and `cost_period_end` (optional, end-exclusive; example `2026-04-01` to `2026-05-01`)
- `cost_region` (optional; example: `ap-southeast-5`)
- `others_top_services` (optional; default: top 5 named services before remainder is treated as `Others`)

## Hard Rules
- Run AWS calls only via `aws-vault exec <profile> -- aws ...`.
- Start with identity check:
`aws-vault exec <profile> -- aws sts get-caller-identity`
- If interactive login/MFA is prompted, ask the user to complete it and wait.
- Keep the audit read-only. Do not run tag mutations (`tag-resource`, `add-tags-*`, `create-tags`, `update-service`, etc.) during this skill.

## Workflow
1. Confirm inputs and required tags.
2. Validate identity with `sts get-caller-identity`.
3. Run the section audit script:
```bash
bash scripts/audit_sections.sh \
  --profile oc-admin \
  --regions ap-southeast-1,ap-southeast-5 \
  --sections rds-aurora,ecs-services \
  --required-tags Environment,ManagedBy,Project,Team \
  --output-dir ./audit-output
```
4. If spend analysis is requested, run Cost Explorer queries from `references/cost_explorer_queries.md`.
5. Review generated artifacts:
- `tag_audit_details.tsv`
- `tag_audit_summary_by_section.tsv`
- `tag_audit_missing_tag_counts.tsv`
6. Summarize compliance with:
- total resources checked
- compliant vs non-compliant count
- missing tags by key
- non-compliant resource list
7. If Cost Explorer analysis is requested, summarize:
- metric and charge scope used (for UI parity usually `UnblendedCost` with `RECORD_TYPE=Usage,Support`)
- period and optional region filter
- top services and explicit `Others` remainder
8. If Linear tracking is requested, create or update an issue with:
- scope (sections, regions, required tags)
- findings summary
- non-compliant resources
- remediation acceptance criteria

## Section Semantics
- `rds-aurora`: audits RDS DB instances and DB clusters (including Aurora clusters).
- `ecs-services`: audits ECS service tags from `describe-services --include TAGS`.

## Output Contract
Return all of the following in your response:
- run timestamp and caller identity
- exact required tags used
- sections and regions audited
- compliance summary per section
- list of non-compliant resources with missing keys
- if Cost Explorer was requested: period, filters, metric, top services, and `Others` breakdown method
- absolute paths to evidence files

## References
- Linear issue template and acceptance criteria checklist:
`references/linear_issue_template.md`
- Cost Explorer query recipes (service breakdown and `Others` decomposition):
`references/cost_explorer_queries.md`
