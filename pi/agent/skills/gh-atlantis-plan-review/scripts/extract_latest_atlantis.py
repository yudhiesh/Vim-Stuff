#!/usr/bin/env python3
"""Extract latest Atlantis PR comments and print compact plan summaries."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

DEFAULT_BOTS = ["oc-staging-atlantis-app[bot]", "oc-production-atlantis-app[bot]"]
DEFAULT_PATTERNS = [
    r"^### .*project:",
    r"^\s*# .* (will be|must be)",
    r"^Plan:",
    r"^[+-/~]{1,3} resource ",
    r"desired_capacity",
    r"min_size",
    r"max_size",
    r"min_capacity",
    r"max_capacity",
    r"instance_type",
    r"mixed_instances_policy",
    r"on_demand_",
    r"spot_allocation_strategy",
    r"managed_scaling",
    r"managed_termination_protection",
    r"managed_draining",
    r"cpu\s+=",
    r"memory\s+=",
    r"logDriver",
    r"scale_in_cooldown",
    r"scale_out_cooldown",
    r"target_value",
    r"enable_ecs_managed_tags",
    r"propagate_tags",
]


def run_gh_comments(repo: str, pr: int) -> list[dict]:
    cmd = [
        "gh",
        "api",
        f"repos/{repo}/issues/{pr}/comments",
        "--paginate",
        "--jq",
        ".[] | @json",
    ]
    proc = subprocess.run(cmd, text=True, capture_output=True)
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr)
        raise SystemExit(proc.returncode)

    comments = []
    for line in proc.stdout.splitlines():
        line = line.strip()
        if line:
            comments.append(json.loads(line))
    return comments


def latest_by_bot(comments: list[dict], bots: list[str]) -> dict[str, dict]:
    latest: dict[str, dict] = {}
    for comment in comments:
        user = (comment.get("user") or {}).get("login")
        if user not in bots:
            continue
        prior = latest.get(user)
        if prior is None or comment.get("created_at", "") > prior.get("created_at", ""):
            latest[user] = comment
    return latest


def summarize_body(body: str, patterns: list[str], context_lines: int) -> list[str]:
    combined = re.compile("|".join(f"(?:{p})" for p in patterns))
    lines = body.splitlines()
    selected: set[int] = set()
    for idx, line in enumerate(lines):
        if combined.search(line):
            start = max(0, idx - context_lines)
            end = min(len(lines), idx + context_lines + 1)
            selected.update(range(start, end))

    output = []
    last = -2
    for idx in sorted(selected):
        if idx != last + 1 and output:
            output.append("...")
        output.append(f"{idx + 1}: {lines[idx]}")
        last = idx
    return output


def safe_name(bot: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "-", bot).strip("-")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True, help="Repository full name, for example OneCreditMY/infrastructure")
    parser.add_argument("--pr", required=True, type=int, help="Pull request number")
    parser.add_argument("--bots", default=",".join(DEFAULT_BOTS), help="Comma-separated Atlantis bot logins")
    parser.add_argument("--out", default=None, help="Directory for full comment bodies")
    parser.add_argument("--context-lines", type=int, default=0, help="Lines of context around matched summary lines")
    args = parser.parse_args()

    bots = [bot.strip() for bot in args.bots.split(",") if bot.strip()]
    out_dir = Path(args.out or f"/tmp/pr{args.pr}-atlantis")
    out_dir.mkdir(parents=True, exist_ok=True)

    comments = run_gh_comments(args.repo, args.pr)
    latest = latest_by_bot(comments, bots)

    missing = [bot for bot in bots if bot not in latest]
    if missing:
        print(f"Missing Atlantis comments for: {', '.join(missing)}", file=sys.stderr)

    for bot in bots:
        comment = latest.get(bot)
        if not comment:
            continue
        body = comment.get("body") or ""
        path = out_dir / f"{safe_name(bot)}-{comment['id']}.md"
        path.write_text(body, encoding="utf-8")

        print(f"\n## {bot}")
        print(f"id: {comment['id']}")
        print(f"created_at: {comment.get('created_at')}")
        print(f"url: {comment.get('html_url')}")
        print(f"body_file: {path}")
        print("summary:")
        summary = summarize_body(body, DEFAULT_PATTERNS, args.context_lines)
        if summary:
            for line in summary:
                print(line)
        else:
            print("  (no matching plan summary lines found)")


if __name__ == "__main__":
    main()
