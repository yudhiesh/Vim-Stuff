#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  $0 --profile <aws-vault-profile> \
     --regions <all|region1,region2> \
     --sections <rds-aurora,ecs-services> \
     [--required-tags Environment,ManagedBy,Project,Team] \
     [--output-dir ./audit-output]

Notes:
- Read-only audit only.
- Requires: aws, aws-vault, jq.
USAGE
}

PROFILE=""
REGIONS_ARG=""
SECTIONS_ARG=""
REQUIRED_TAGS_ARG="Environment,ManagedBy,Project,Team"
OUTPUT_DIR="./audit-output"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --regions) REGIONS_ARG="$2"; shift 2 ;;
    --sections) SECTIONS_ARG="$2"; shift 2 ;;
    --required-tags) REQUIRED_TAGS_ARG="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$PROFILE" || -z "$REGIONS_ARG" || -z "$SECTIONS_ARG" ]]; then
  usage
  exit 1
fi

for cmd in aws aws-vault jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing dependency: $cmd" >&2
    exit 1
  fi
done

IFS=',' read -r -a REQUIRED_TAGS <<< "$REQUIRED_TAGS_ARG"
IFS=',' read -r -a SECTIONS <<< "$SECTIONS_ARG"

if [[ "$REGIONS_ARG" == "all" ]]; then
  mapfile -t REGIONS < <(aws-vault exec "$PROFILE" -- aws ec2 describe-regions --query 'Regions[].RegionName' --output text | tr '\t' '\n')
else
  IFS=',' read -r -a REGIONS <<< "$REGIONS_ARG"
fi

mkdir -p "$OUTPUT_DIR"
DETAILS_FILE="$OUTPUT_DIR/tag_audit_details.tsv"
SUMMARY_SECTION_FILE="$OUTPUT_DIR/tag_audit_summary_by_section.tsv"
MISSING_COUNTS_FILE="$OUTPUT_DIR/tag_audit_missing_tag_counts.tsv"

printf 'section\tresource_type\tregion\tidentifier\tarn\tmissing_tags\tpresent_tags\n' > "$DETAILS_FILE"

audit_one() {
  local section="$1"
  local resource_type="$2"
  local region="$3"
  local identifier="$4"
  local arn="$5"
  local tag_keys_csv="$6"

  local missing=()
  local present=()
  local k

  for k in "${REQUIRED_TAGS[@]}"; do
    if grep -Fxq "$k" <(tr ',' '\n' <<< "$tag_keys_csv"); then
      present+=("$k")
    else
      missing+=("$k")
    fi
  done

  local missing_str=""
  local present_str=""
  missing_str=$(IFS=','; echo "${missing[*]}")
  present_str=$(IFS=','; echo "${present[*]}")

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$section" "$resource_type" "$region" "$identifier" "$arn" "$missing_str" "$present_str" >> "$DETAILS_FILE"
}

for region in "${REGIONS[@]}"; do
  for section in "${SECTIONS[@]}"; do
    case "$section" in
      rds-aurora)
        db_instances=$(aws-vault exec "$PROFILE" -- aws rds describe-db-instances --region "$region" --output json)
        while IFS= read -r inst; do
          arn=$(jq -r '.DBInstanceArn' <<< "$inst")
          id=$(jq -r '.DBInstanceIdentifier' <<< "$inst")
          tags_json=$(aws-vault exec "$PROFILE" -- aws rds list-tags-for-resource --region "$region" --resource-name "$arn" --output json)
          keys_csv=$(jq -r '.TagList[].Key' <<< "$tags_json" | paste -sd ',' -)
          audit_one "$section" "db-instance" "$region" "$id" "$arn" "${keys_csv:-}"
        done < <(jq -c '.DBInstances[]?' <<< "$db_instances")

        db_clusters=$(aws-vault exec "$PROFILE" -- aws rds describe-db-clusters --region "$region" --output json)
        while IFS= read -r clu; do
          arn=$(jq -r '.DBClusterArn' <<< "$clu")
          id=$(jq -r '.DBClusterIdentifier' <<< "$clu")
          engine=$(jq -r '.Engine' <<< "$clu")
          tags_json=$(aws-vault exec "$PROFILE" -- aws rds list-tags-for-resource --region "$region" --resource-name "$arn" --output json)
          keys_csv=$(jq -r '.TagList[].Key' <<< "$tags_json" | paste -sd ',' -)
          audit_one "$section" "db-cluster($engine)" "$region" "$id" "$arn" "${keys_csv:-}"
        done < <(jq -c '.DBClusters[]?' <<< "$db_clusters")
        ;;

      ecs-services)
        clusters_json=$(aws-vault exec "$PROFILE" -- aws ecs list-clusters --region "$region" --output json)
        while IFS= read -r cluster_arn; do
          [[ -z "$cluster_arn" || "$cluster_arn" == "null" ]] && continue
          services_json=$(aws-vault exec "$PROFILE" -- aws ecs list-services --region "$region" --cluster "$cluster_arn" --output json)
          while IFS= read -r service_arn; do
            [[ -z "$service_arn" || "$service_arn" == "null" ]] && continue
            svc=$(aws-vault exec "$PROFILE" -- aws ecs describe-services --region "$region" --cluster "$cluster_arn" --services "$service_arn" --include TAGS --output json)
            id=$(jq -r '.services[0].serviceName' <<< "$svc")
            keys_csv=$(jq -r '.services[0].tags[]?.key' <<< "$svc" | paste -sd ',' -)
            audit_one "$section" "ecs-service" "$region" "$id" "$service_arn" "${keys_csv:-}"
          done < <(jq -r '.serviceArns[]?' <<< "$services_json")
        done < <(jq -r '.clusterArns[]?' <<< "$clusters_json")
        ;;

      *)
        echo "Unsupported section: $section" >&2
        exit 1
        ;;
    esac
  done
done

awk -F'\t' '
  NR>1 {
    total[$1]++;
    if ($6=="" || $6=="-") compliant[$1]++; else noncompliant[$1]++;
  }
  END {
    print "section\ttotal\tcompliant\tnoncompliant";
    for (s in total) {
      printf "%s\t%d\t%d\t%d\n", s, total[s], compliant[s]+0, noncompliant[s]+0;
    }
  }
' "$DETAILS_FILE" > "$SUMMARY_SECTION_FILE"

awk -F'\t' '
  NR>1 {
    n=split($6,a,",");
    for (i=1; i<=n; i++) if (a[i] != "") counts[a[i]]++;
  }
  END {
    print "tag_key\tmissing_count";
    for (k in counts) printf "%s\t%d\n", k, counts[k];
  }
' "$DETAILS_FILE" | sort > "$MISSING_COUNTS_FILE"

echo "Wrote: $DETAILS_FILE"
echo "Wrote: $SUMMARY_SECTION_FILE"
echo "Wrote: $MISSING_COUNTS_FILE"
