#!/usr/bin/env python3
"""Read-only preflight validation for create-service-infra manifests."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


TEAMS = {"Data", "Product", "DevOps"}
SLUG_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
TICKET_RE = re.compile(r"^[A-Z][A-Z0-9]+-[0-9]+$")


def error(errors: list[str], message: str) -> None:
    errors.append(message)


def read_manifest(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read JSON manifest {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError("manifest must contain a JSON object")
    return value


def require_string(data: dict[str, Any], key: str, errors: list[str]) -> str | None:
    value = data.get(key)
    if not isinstance(value, str) or not value.strip():
        error(errors, f"{key} must be a non-empty string")
        return None
    return value.strip()


def mapping_exists(path: Path, key: str) -> bool:
    if not path.exists():
        return False
    pattern = re.compile(rf"^\s*{re.escape(key)}\s*=\s*\{{", re.MULTILINE)
    return pattern.search(path.read_text()) is not None


def validate_manifest(manifest: dict[str, Any], repo_root: Path) -> tuple[list[str], list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    plan: list[str] = []

    environment = require_string(manifest, "environment", errors)
    ticket = require_string(manifest, "linear_ticket", errors)
    service_slug = require_string(manifest, "service_slug", errors)
    service_type = require_string(manifest, "service_type", errors)
    team = require_string(manifest, "team", errors)
    project = require_string(manifest, "project", errors)

    if environment and environment not in {"staging", "production"}:
        error(errors, "environment must be staging or production")
    if ticket and not TICKET_RE.fullmatch(ticket):
        error(errors, "linear_ticket must look like ENG-1234")
    if service_slug and not SLUG_RE.fullmatch(service_slug):
        error(errors, "service_slug must be lowercase kebab case")
    if project and not SLUG_RE.fullmatch(project):
        error(errors, "project must be lowercase kebab case")
    if team and team not in TEAMS:
        error(errors, f"team must be one of {sorted(TEAMS)}")
    if service_type not in {"api", "consumer"}:
        error(errors, "service_type must be api or consumer")
    if service_slug and service_type:
        suffix = "-api" if service_type == "api" else "-consumer"
        if not service_slug.endswith(suffix):
            error(errors, f"{service_type} service_slug must end with {suffix}")

    secrets = manifest.get("secrets_manager", {})
    if secrets is not True and secrets != {"enabled": True}:
        error(errors, "secrets_manager must be enabled; per-service secret metadata is mandatory")

    rabbitmq = manifest.get("rabbitmq", {})
    if not isinstance(rabbitmq, dict):
        error(errors, "rabbitmq must be an object")
        rabbitmq = {}
    if service_type == "consumer" and rabbitmq.get("enabled") is not True:
        error(errors, "consumer services must explicitly enable rabbitmq")
    if service_type == "api" and rabbitmq.get("enabled") not in {True, False}:
        error(errors, "API requests must explicitly set rabbitmq.enabled to true or false")

    database = manifest.get("database", {})
    if not isinstance(database, dict):
        error(errors, "database must be an object")
        database = {}
    database_mode = database.get("mode")
    if database_mode not in {"none", "new"}:
        error(errors, "database.mode must be none or new")
    database_slug = database.get("slug", service_slug)
    if not isinstance(database_slug, str) or not SLUG_RE.fullmatch(database_slug):
        error(errors, "database.slug must be lowercase kebab case when provided")
    database_ref = database.get("database_ref")
    if database_ref is not None and (not isinstance(database_ref, str) or not SLUG_RE.fullmatch(database_ref)):
        error(errors, "database.database_ref must be lowercase kebab case when provided")
    if database_mode == "new" and database_ref:
        error(errors, "database.database_ref cannot be combined with database.mode=new")
    if database_mode != "none" and database_ref:
        error(errors, "database.database_ref requires database.mode=none")

    s3 = manifest.get("s3")
    if s3 is not None:
        if not isinstance(s3, dict):
            error(errors, "s3 must be null or an object")
        else:
            if s3.get("scope") not in {"environment", "shared"}:
                error(errors, "s3.scope must be environment or shared")
            if s3.get("access") not in {"read", "full"}:
                error(errors, "s3.access must be read or full")

    ecr = manifest.get("ecr", {})
    if not isinstance(ecr, dict):
        error(errors, "ecr must be an object")
        ecr = {}
    if ecr.get("create") is True:
        production_ticket = ecr.get("production_ticket")
        if not isinstance(production_ticket, str) or not TICKET_RE.fullmatch(production_ticket):
            error(errors, "new shared ECR requires ecr.production_ticket")
        elif production_ticket == ticket:
            error(errors, "shared ECR production_ticket must differ from the environment ticket")
        plan.append("global/ecr (shared PR linked to both environment tickets)")

    if environment:
        service_dir = repo_root / environment / "ecs/shared/services" / (service_slug or "<service-slug>")
        if service_dir.exists():
            error(errors, f"target service directory already exists: {service_dir}")
        secret_locals = repo_root / environment / "secretsmanager/locals.tf"
        if not secret_locals.exists():
            error(errors, f"required Secrets Manager stack is missing: {secret_locals}")
        elif service_slug and mapping_exists(secret_locals, service_slug):
            error(errors, f"Secrets Manager mapping already exists for {service_slug}: {secret_locals}")

        if s3 is not None:
            s3_locals = repo_root / ("global/s3/locals.tf" if s3.get("scope") == "shared" else f"{environment}/s3/locals.tf")
            if not s3_locals.exists():
                error(errors, f"required S3 stack is missing: {s3_locals}")
            elif isinstance(s3.get("key"), str) and mapping_exists(s3_locals, s3["key"]):
                error(errors, f"S3 mapping already exists for {s3['key']}: {s3_locals}")

        route_locals = repo_root / f"{environment}/internal-service-routes/locals.tf"
        if service_type == "api" and not route_locals.exists():
            error(errors, f"required internal service route stack is missing: {route_locals}")
        elif service_type == "api" and service_slug and mapping_exists(route_locals, service_slug):
            error(errors, f"internal service route already exists for {service_slug}: {route_locals}")

        if database_mode == "new":
            cluster_dir = repo_root / environment / "postgresql" / database_slug / "cluster"
            database_dir = repo_root / environment / "postgresql" / database_slug / "database"
            if cluster_dir.exists() or database_dir.exists():
                error(errors, f"PostgreSQL target already exists for {database_slug}: {cluster_dir.parent}")
        if database_ref:
            cluster_dir = repo_root / environment / "postgresql" / database_ref / "cluster"
            database_dir = repo_root / environment / "postgresql" / database_ref / "database"
            if not cluster_dir.exists() or not database_dir.exists():
                error(errors, f"database_ref must resolve to a managed PostgreSQL pair: {environment}/postgresql/{database_ref}")

        ecr_locals = repo_root / "global/ecr/locals.tf"
        if ecr.get("create") is True and mapping_exists(ecr_locals, service_slug or ""):
            error(errors, f"ECR mapping already exists for {service_slug}: {ecr_locals}")
        if ecr.get("create") is False and not mapping_exists(ecr_locals, service_slug or ""):
            error(errors, f"ecr.create=false but no shared ECR mapping exists for {service_slug}: {ecr_locals}")

    plan.append(f"{environment}/secretsmanager mapping")
    if s3 is not None:
        plan.append(f"{environment if s3.get('scope') == 'environment' else 'global'}/s3 mapping")
    if service_type == "api":
        plan.append(f"{environment}/internal-service-routes mapping")
    plan.append(f"{environment}/ecs/shared/services/{service_slug or '<service-slug>'}")
    if database_mode == "new":
        plan.extend([
            f"{environment}/postgresql/{database_slug}/cluster",
            f"{environment}/postgresql/{database_slug}/database",
        ])
    elif database_ref:
        warnings.append(f"Service will reference managed database {environment}/postgresql/{database_ref}.")

    if environment == "production":
        warnings.append("Production requires a separate ticket and the verified staging manifest/apply first.")
    warnings.append("Remote Linear, GitHub, branch, PR, CI, and Atlantis checks are outside this local script.")
    return errors, warnings, plan


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--json", action="store_true", dest="as_json")
    args = parser.parse_args()

    try:
        manifest = read_manifest(args.manifest)
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    errors, warnings, plan = validate_manifest(manifest, args.repo_root.resolve())
    result = {"valid": not errors, "errors": errors, "warnings": warnings, "planned_prs": plan}
    if args.as_json:
        print(json.dumps(result, indent=2))
    else:
        print("Preflight: PASS" if not errors else "Preflight: BLOCKED")
        for item in plan:
            print(f"  PR: {item}")
        for message in warnings:
            print(f"  Warning: {message}")
        for message in errors:
            print(f"  Error: {message}")
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
