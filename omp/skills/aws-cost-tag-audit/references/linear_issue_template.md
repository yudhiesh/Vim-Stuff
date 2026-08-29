# Linear Remediation Template

Use this structure when creating follow-up remediation issues.

## Title
`<Service/Section> tagging remediation: enforce base cost allocation tags`

## Scope
- Account:
- Regions:
- Sections:
- Required tags:
  - Environment
  - ManagedBy
  - Project
  - Team

## Findings
- Total resources checked:
- Compliant:
- Non-compliant:
- Missing-tag distribution:

## Required remediation
1. Add missing required tags with non-empty values on all non-compliant resources.
2. Re-run read-only audit and attach evidence artifact.
3. Validate Cost Explorer attribution after propagation window.

## Acceptance criteria
- 100% compliance for required base tags.
- No empty values for required tags.
- Evidence files attached.
