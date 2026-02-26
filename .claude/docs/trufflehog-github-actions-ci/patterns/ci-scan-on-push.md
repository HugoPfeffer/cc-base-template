---
title: "CI Scan on Push"
tags: [pattern, push, github-actions, trufflehog, secret-scanning]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "patterns"
---

# Pattern: CI Scan on Push

## Problem

A developer commits directly to a branch (bypassing a PR), or a PR merges without triggering a scan. Secrets that enter the repository through any path must be detected.

## Solution

Run TruffleHog on every `push` event, scanning the diff between `github.event.before` and `github.event.after`.

## When to Use This Pattern

- As a safety net when PR scanning is the primary gate but direct pushes are possible
- When the repository allows force pushes or bypass merges
- When you need an audit trail of every commit that was scanned
- As the only scan if PRs are not used in your workflow

## How It Works

On a `push` event, GitHub provides:
- `github.event.before` — the SHA of the commit before the push
- `github.event.after` — the SHA of the HEAD after the push

The official TruffleHog action automatically uses these as `base` and `head` for a diff scan. Only commits in the push are scanned, not the entire history.

### Special Case: New Branch Push

When a branch is pushed for the first time, `github.event.before` is all zeros (`0000000000000000000000000000000000000000`). The TruffleHog action detects this and sets `BASE=""` (empty string), which causes TruffleHog to scan all commits reachable from `HEAD` on that branch — a full branch scan rather than a diff scan. This is the correct behaviour: for a brand-new branch, every commit is new and must be scanned.

If you are computing SHAs manually (binary install, not the official action), you must implement this check yourself:

```bash
BASE="${{ github.event.before }}"
if [ "$BASE" = "0000000000000000000000000000000000000000" ]; then
  # New branch: scan full branch history
  trufflehog git --fail file://"$GITHUB_WORKSPACE"
else
  trufflehog git --since-commit "$BASE" --fail file://"$GITHUB_WORKSPACE"
fi
```

## Minimal Example

```yaml
name: Secret Scan on Push
on:
  push:
    branches: [main, develop]

permissions: {}

jobs:
  scan:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
        with:
          fetch-depth: 0
      - uses: trufflesecurity/trufflehog@v3.93.4
```

## Scope Considerations

### Limiting to Specific Branches

```yaml
on:
  push:
    branches:
      - main
      - 'release/**'
      - 'hotfix/**'
```

Scanning every branch on every push can be expensive for high-traffic repositories. Focus on branches that have production access or that gate deployment.

### Scanning All Branches

```yaml
on:
  push:
    branches: ['**']
```

This catches secrets earlier (before a PR is opened) but increases CI cost. Use with `--only-verified` to reduce noise.

## Limitations

- Push scans only catch secrets in new commits. They miss secrets already present in the repository before the scan was added. Use the [full-history-scan.md](./full-history-scan.md) pattern to address historical debt.
- If a developer force-pushes to rewrite history, the `before` SHA may not exist in the local clone. Ensure `fetch-depth: 0` is set.

## Complementary Patterns

This pattern works best in combination with:
- [ci-scan-on-pull-request.md](./ci-scan-on-pull-request.md) — catches secrets before they merge
- [full-history-scan.md](./full-history-scan.md) — audits existing history
- [pre-commit-to-ci-layered-defense.md](./pre-commit-to-ci-layered-defense.md) — catches secrets before they are committed

## See Also

- [diff-only-scan.md](./diff-only-scan.md) — Computing base/head SHAs manually when using the binary directly
- [../examples/trufflehog-git-scan-workflow.md](../examples/trufflehog-git-scan-workflow.md) — Complete workflow YAML with both push and PR triggers
- [../concepts/trufflehog-architecture.md](../concepts/trufflehog-architecture.md) — How base/head SHAs drive diff scanning
- [../guides/shallow-clone-fix.md](../guides/shallow-clone-fix.md) — Why fetch-depth: 0 is required
