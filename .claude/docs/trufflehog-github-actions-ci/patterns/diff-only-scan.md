---
title: "Diff-Only Scan"
tags: [pattern, diff, since-commit, branch, pull-request, performance]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "patterns"
---

# Pattern: Diff-Only Scan

## Problem

A full repository scan on every PR is too slow and noisy for frequent use. You need a scan that is fast, covers exactly the new code being introduced, and completes in seconds rather than minutes.

## Solution

Use TruffleHog's `--since-commit` and `--branch` flags when calling the binary directly, scoping the scan precisely to the commits in the current PR or push.

## When to Use This Pattern

- When the official action's automatic diff detection is insufficient for your workflow
- When you need custom logic around base/head SHA computation
- When combining TruffleHog with other tools in a pipeline that has its own SHA management
- When using the binary install instead of the Docker action

## How It Works

The binary's `git` subcommand accepts:

```
--since-commit <SHA>   Start scanning from this commit (exclusive)
--branch <name>        Limit to commits reachable from this branch
```

Together, these scan only the commits introduced in a branch since a specific point:

```bash
trufflehog git \
  --since-commit "$BASE_SHA" \
  --branch "$HEAD_BRANCH" \
  --fail \
  --json \
  file://"$GITHUB_WORKSPACE"
```

## Computing the Correct SHAs

### For Pull Request Events

```yaml
- name: Run diff scan
  env:
    BASE_SHA: ${{ github.event.pull_request.base.sha }}
    HEAD_BRANCH: ${{ github.event.pull_request.head.ref }}
  run: |
    trufflehog git \
      --since-commit "$BASE_SHA" \
      --branch "$HEAD_BRANCH" \
      --fail \
      file://"$GITHUB_WORKSPACE"
```

### For Push Events

```yaml
- name: Run diff scan
  env:
    BASE_SHA: ${{ github.event.before }}
    HEAD_SHA: ${{ github.event.after }}
  run: |
    # Handle new branch (before SHA is all zeros)
    if [ "$BASE_SHA" = "0000000000000000000000000000000000000000" ]; then
      trufflehog git --fail file://"$GITHUB_WORKSPACE"
    else
      trufflehog git \
        --since-commit "$BASE_SHA" \
        --fail \
        file://"$GITHUB_WORKSPACE"
    fi
```

## max-depth as an Alternative

For repositories where a branch may have a very long history from its base, `--max-depth` limits the number of commits scanned:

```bash
trufflehog git \
  --max-depth 50 \
  --fail \
  file://"$GITHUB_WORKSPACE"
```

`--max-depth` counts from HEAD backwards. It does not guarantee you have scanned the full PR diff — use `--since-commit` when you have the exact base SHA.

## Important: Removing a Secret Does Not Clear the Finding

A follow-up commit that removes a secret file or reverts a commit does **not** retroactively clear TruffleHog findings. The secret still exists in git history at the original commit SHA. Any repository clone or `git log` can retrieve it.

The correct remediation after a secret is found in a diff scan is:

1. **Revoke the credential immediately** — treat it as compromised from the moment it appeared in a commit
2. **Remove the secret from history** with a force push (`git filter-repo`, BFG Repo-Cleaner) or accept that it exists in history permanently
3. **Issue a new credential** — the revoked one must not be reused

Diff-only scans catch the introduction of the secret in real time. They do not certify that the secret is gone after a follow-up commit.

## Comparison with the Official Action

| Aspect | Official Action | Binary + diff flags |
|--------|----------------|---------------------|
| SHA computation | Automatic | Manual |
| Code required | None | ~10 lines |
| Customisation | `extra_args` only | Full flag control |
| Base/head override | Via `base` and `head` inputs | Via flags |
| Flexibility | Limited | Full |

The official action's automatic SHA computation covers the most common cases (push, pull_request, schedule/dispatch). Use the binary directly only when you need behaviour the action does not support.

## See Also

- [ci-scan-on-pull-request.md](./ci-scan-on-pull-request.md) — The higher-level PR scan pattern
- [ci-scan-on-push.md](./ci-scan-on-push.md) — Push scan pattern and new-branch SHA handling
- [binary-install-vs-official-action.md](./binary-install-vs-official-action.md) — When to use the binary
- [../concepts/trufflehog-architecture.md](../concepts/trufflehog-architecture.md) — Full CLI flags reference
- [../examples/trufflehog-pr-diff-scan-workflow.md](../examples/trufflehog-pr-diff-scan-workflow.md) — Complete workflow using this pattern
