# Cost Explorer Query Recipes

Use these only when the user asks for spend breakdowns (especially `Others`).

## Guardrails
- Run through aws-vault only: `aws-vault exec <profile> -- aws ...`
- Cost Explorer is billing-scope global; apply `REGION` filter explicitly when needed.
- Time period end is exclusive (`Start=2026-04-01,End=2026-05-01` means April 2026).
- For parity with common console stacks, use `UnblendedCost` with `RECORD_TYPE=Usage,Support`.

## 1) Service Breakdown (All Regions, Usage+Support)
```bash
aws-vault exec oc-admin -- aws ce get-cost-and-usage \
  --time-period Start=2026-04-01,End=2026-05-01 \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --filter '{"Dimensions":{"Key":"RECORD_TYPE","Values":["Usage","Support"]}}' \
  --group-by Type=DIMENSION,Key=SERVICE \
  --output json \
| jq -r '.ResultsByTime[0].Groups[] | [.Keys[0], (.Metrics.UnblendedCost.Amount|tonumber)] | @tsv' \
| sort -t $'\t' -k2,2nr
```

## 2) Service Breakdown (Region-Scoped, Usage+Support)
```bash
aws-vault exec oc-admin -- aws ce get-cost-and-usage \
  --time-period Start=2026-04-01,End=2026-05-01 \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --filter '{"And":[{"Dimensions":{"Key":"REGION","Values":["ap-southeast-5"]}},{"Dimensions":{"Key":"RECORD_TYPE","Values":["Usage","Support"]}}]}' \
  --group-by Type=DIMENSION,Key=SERVICE \
  --output json \
| jq -r '.ResultsByTime[0].Groups[] | [.Keys[0], (.Metrics.UnblendedCost.Amount|tonumber)] | @tsv' \
| sort -t $'\t' -k2,2nr
```

## 3) Record Type Sanity Check (Why Net Can Look Tiny)
```bash
aws-vault exec oc-admin -- aws ce get-cost-and-usage \
  --time-period Start=2026-04-01,End=2026-05-01 \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=RECORD_TYPE \
  --output json \
| jq -r '.ResultsByTime[0].Groups[] | [.Keys[0], (.Metrics.UnblendedCost.Amount|tonumber)] | @tsv' \
| sort -t $'\t' -k2,2nr
```

Use this when the user sees large service stacks in the console but net total is near zero due to credits.

## 4) Break Down `Others`
Assume top services shown in UI are:
- `Amazon Relational Database Service`
- `Amazon Elastic Container Service`
- `AmazonCloudWatch`
- `AWS Support (Business)`
- `EC2 - Other`

Given `service_breakdown.tsv` from query #1 or #2:
```bash
awk -F'\t' '
  $1!="Amazon Relational Database Service" &&
  $1!="Amazon Elastic Container Service" &&
  $1!="AmazonCloudWatch" &&
  $1!="AWS Support (Business)" &&
  $1!="EC2 - Other" {
    print $0;
    others += $2;
  }
  END { printf "OTHERS_TOTAL\t%.2f\n", others > "/dev/stderr" }
' service_breakdown.tsv \
| sort -t $'\t' -k2,2nr
```

Adjust the excluded list if the console is showing a different top-N set.
