---
name: aws-vault
description: Use this skill when AWS access is required through aws-vault profiles, especially for commands that may require interactive sign-in, keychain unlock, SSO browser auth, or MFA input. It standardizes running AWS CLI calls as `aws-vault exec profile-name -- aws command`, verifies identity before sensitive operations, and explicitly asks the user to complete interactive authentication steps when prompted.
---

# AWS Vault

## Overview
Use `aws-vault` as the required entry point for AWS CLI access. Keep all AWS commands wrapped in `aws-vault exec <profile> -- ...` and handle authentication prompts with explicit user handoff.

## Workflow
1. Confirm target profile and region assumptions from context.
2. Start with a safe identity check:
```bash
aws-vault exec <profile> -- aws sts get-caller-identity
```
3. If authentication is interactive (SSO login, MFA, keychain unlock), pause and ask the user to complete it.
4. After user confirmation, rerun identity check.
5. Run requested AWS command(s) only after identity succeeds.

## Required Command Pattern
Always use:
```bash
aws-vault exec <profile> -- aws <service> <operation> ...
```

Never run bare `aws ...` unless the user explicitly asks to bypass `aws-vault`.

## User-Assist Handoff
When interactive auth is required, send a short instruction like:
- "Please complete the `aws-vault` sign-in/MFA prompt in the terminal. Tell me when done and I will continue."

Then wait for user confirmation before continuing.

## Safety Checks
- Validate current identity before destructive or high-impact operations.
- Echo assumed account/role back to user before proceeding on production-like targets.
- If profile access fails, report the exact error and stop instead of retry-looping.

## Common Examples
Identity check:
```bash
aws-vault exec oc-admin -- aws sts get-caller-identity
```

Region-scoped query:
```bash
aws-vault exec oc-admin -- aws ecs list-clusters --region ap-southeast-5
```

Cost Explorer query:
```bash
aws-vault exec oc-admin -- aws ce get-cost-and-usage --time-period Start=2026-05-01,End=2026-06-01 --granularity MONTHLY --metrics UnblendedCost
```
