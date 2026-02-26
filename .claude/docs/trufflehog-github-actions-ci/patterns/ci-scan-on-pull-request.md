---
title: "CI Scan on Pull Request"
tags: [pattern, pull-request, github-actions, trufflehog, branch-protection]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "patterns"
---

# Pattern: CI Scan on Pull Request

## Problem

Secrets need to be caught before they are merged into the main branch, giving the developer an opportunity to remove the secret and revoke the credential before it is permanently in the branch history.

## Solution

Run TruffleHog on the `pull_request` trigger, scanning only the diff of the PR (base SHA to head SHA). Mark the scan as a required status check in branch protection settings so PRs cannot merge when findings exist.

## When to Use This Pattern

- This should be the primary scan for almost every repository
- When you want to enforce a "no secrets in main" policy
- When combined with branch protection required checks

## How It Works

On a `pull_request` event, GitHub provides:
- `github.event.pull_request.base.sha` — the SHA at the base of the PR
- `github.event.pull_request.head.sha` — the SHA of the PR's head commit

The TruffleHog action uses these to scan only the commits that are part of the PR, not the entire repository history. This is fast — a PR with 5 commits scans 5 commits, regardless of repository age.

## Security Consideration: pull_request vs pull_request_target

**Always use `pull_request`, never `pull_request_target`** for secret scanning.

`pull_request` runs in the fork's context with a read-only token. `pull_request_target` runs with write access and access to repository secrets. A malicious PR against a workflow using `pull_request_target` can exfiltrate your repository's own secrets.

## Minimal Example

```yaml
name: Secret Scan on PR
on:
  pull_request: {}

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

## Making It a Required Check

A scan that can be bypassed is not a policy. Enforce it via branch protection:

1. The workflow must run at least once to appear as a status check
2. In the repository **Settings > Branches**, add a branch protection rule for `main`
3. Enable **Require status checks to pass before merging**
4. Search for and add the job name (e.g., `scan`) as a required check
5. Enable **Require branches to be up to date before merging**

For complete configuration, see [../examples/branch-protection-required-checks.md](../examples/branch-protection-required-checks.md).

## Handling the `|| true` Pattern

When collecting JSON output for reporting, you may need to prevent TruffleHog's exit 183 from masking the collection step:

```yaml
- name: Scan PR diff
  run: |
    trufflehog git \
      --since-commit ${{ github.event.pull_request.base.sha }} \
      --branch ${{ github.event.pull_request.head.ref }} \
      --fail \
      --json 2>/dev/null | tee findings.json || true
- name: Post findings summary
  if: always()
  run: |
    if [ -s findings.json ]; then
      echo "## TruffleHog Findings" >> $GITHUB_STEP_SUMMARY
      cat findings.json | jq -r '...' >> $GITHUB_STEP_SUMMARY
    fi
- name: Fail if findings exist
  run: |
    if [ -s findings.json ]; then exit 183; fi
```

This pattern captures output, posts it as a step summary, then explicitly fails the job if findings were found.

## Limitations

- PR scans only catch secrets introduced in the PR's commits. Secrets already in the base branch are not caught here — use [ci-scan-on-push.md](./ci-scan-on-push.md) and [full-history-scan.md](./full-history-scan.md) for broader coverage.
- Fork PRs from external contributors have limited permissions. The scan still runs correctly because it only needs `contents: read`.

## See Also

- [../examples/trufflehog-pr-diff-scan-workflow.md](../examples/trufflehog-pr-diff-scan-workflow.md) — Complete PR-only workflow with JSON output
- [../examples/branch-protection-required-checks.md](../examples/branch-protection-required-checks.md) — Enforcing scans via branch protection
- [diff-only-scan.md](./diff-only-scan.md) — Using the binary directly for precise diff control
- [../concepts/github-actions-security-model.md](../concepts/github-actions-security-model.md) — pull_request_target warning
