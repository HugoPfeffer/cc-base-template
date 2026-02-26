---
title: "TruffleHog Git Scan Workflow — Push and PR"
tags: [example, workflow, push, pull-request, github-actions, trufflehog]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "examples"
---

# Example: TruffleHog Git Scan Workflow (Push + PR)

This is the standard single-file workflow that covers both push and pull request events using the official TruffleHog action. It is the recommended starting point for most repositories.

## When to Use This Example

- Starting point for most repositories
- When you want push scanning and PR scanning in one file
- When the official action's automatic SHA detection is sufficient
- When you do not need JSON output or custom exit-code handling

## The Workflow

```yaml
# .github/workflows/secret-scan.yml
name: Secret Scanning

on:
  push:
    branches: [main]
  pull_request:

permissions: {}

jobs:
  trufflehog:
    name: TruffleHog Secret Scan
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          persist-credentials: false

      - name: TruffleHog OSS
        uses: trufflesecurity/trufflehog@main
        with:
          extra_args: --results=verified
```

## Line-by-Line Explanation

### Trigger (`on`)

```yaml
on:
  push:
    branches: [main]
  pull_request:
```

- `push: branches: [main]` — runs the scan whenever commits are pushed directly to `main`. The action uses `github.event.before` and `github.event.after` to determine the commit range.
- `pull_request` — runs on every pull request event (opened, synchronised, reopened). The action uses `github.event.pull_request.base.sha` and `github.event.pull_request.head.sha` to scan only the PR diff.

### Permissions

```yaml
permissions: {}
```

Denies all permissions at the workflow level. Individual jobs then grant only the minimum required. This is a defence-in-depth measure: even if a step is compromised, it cannot escalate to write or admin permissions.

```yaml
permissions:
  contents: read
```

The job grants only `contents: read`, which is the minimum permission needed to clone the repository. No write, no packages, no secrets access.

### Checkout Step

```yaml
- name: Checkout code
  uses: actions/checkout@v4
  with:
    fetch-depth: 0
    persist-credentials: false
```

- `fetch-depth: 0` — fetches the complete git history. Without this, the runner gets a shallow clone (depth 1), and TruffleHog cannot walk back through commits to find the scan base. This is the single most common misconfiguration.
- `persist-credentials: false` — prevents `actions/checkout` from writing the `GITHUB_TOKEN` into `.git/config`. If a subsequent step or action is malicious, it cannot read the token from the git configuration.

### TruffleHog Step

```yaml
- name: TruffleHog OSS
  uses: trufflesecurity/trufflehog@main
  with:
    extra_args: --results=verified
```

- `uses: trufflesecurity/trufflehog@main` — references the official TruffleHog GitHub Action. In production, pin this to a specific tag or commit SHA (e.g., `@v3.93.4`) to prevent unexpected behaviour from upstream changes.
- `extra_args: --results=verified` — passes flags to the underlying `trufflehog` binary. The action itself always injects `--fail`, `--no-update`, and `--github-actions`.

The action automatically detects from context whether this is a push or PR event and sets the appropriate `--since-commit`/`--branch` flags.

## Customising with extra_args

| Goal | extra_args | Noise Level |
|------|-----------|-------------|
| Only verified (active) credentials | `--results=verified` | Low — high confidence, fewest alerts |
| Verified and unknown states | `--results=verified,unknown` | Moderate — catches unverifiable detectors |
| All results including unverified | `--results=verified,unverified,unknown` | High — maximum coverage, more review needed |
| Use a custom config | `--config .trufflehog/config.yaml` | — |
| Skip binary files | `--force-skip-binaries` | — |
| Limit archive scanning | `--archive-max-size=5MB` | — |
| Combine options | `--results=verified --force-skip-binaries --archive-max-size=5MB` | — |

The `--results=verified` option (low noise) is the recommended default for teams starting out. Once the team is comfortable triaging findings, expand to `--results=verified,unknown`.

## Flags Injected by the Official Action

The official action always injects these flags regardless of what you set in `extra_args`:

| Flag | Effect |
|------|--------|
| `--fail` | Exits with code 183 if findings match the `--results` filter. This is what causes the workflow step to fail. |
| `--no-update` | Disables the automatic version update check. Important in CI to prevent network calls and unpredictable version changes. |
| `--github-actions` | Emits `::warning file=X,line=Y::` annotations visible in the PR diff view and Files tab. |

## Branch Protection Integration

A passing scan step is only meaningful if merging is blocked when the step fails. Configure branch protection to require the `TruffleHog Secret Scan` check before merging. See [branch-protection-required-checks.md](./branch-protection-required-checks.md) for detailed instructions.

## Variant: Scheduled Full History Scan

The push + PR workflow only scans new commits. For periodic audits of full repository history, add a separate workflow:

```yaml
# .github/workflows/secret-scan-scheduled.yml
name: Weekly Full History Secret Scan

on:
  schedule:
    - cron: '0 2 * * 0'   # 02:00 UTC every Sunday
  workflow_dispatch: {}    # Allow manual trigger from Actions UI

permissions: {}

jobs:
  full-history-scan:
    name: TruffleHog Full History Scan
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          persist-credentials: false

      - name: TruffleHog OSS (full history)
        uses: trufflesecurity/trufflehog@main
        with:
          # No --since-commit; scans entire repository history
          extra_args: --results=verified --force-skip-binaries --archive-max-size=5MB
```

This workflow is not triggered on push or PR, so it does not block any developer workflow. It runs as an audit job to catch secrets that may have been committed before secret scanning was enabled.

## See Also

- [../patterns/ci-scan-on-push.md](../patterns/ci-scan-on-push.md) — Push scan pattern explanation
- [../patterns/ci-scan-on-pull-request.md](../patterns/ci-scan-on-pull-request.md) — PR scan pattern explanation
- [../concepts/github-actions-security-model.md](../concepts/github-actions-security-model.md) — Permissions model and security hardening
- [trufflehog-pr-diff-scan-workflow.md](./trufflehog-pr-diff-scan-workflow.md) — PR-only scan with JSON output and step summary
- [branch-protection-required-checks.md](./branch-protection-required-checks.md) — Enforcing the scan as a merge gate
