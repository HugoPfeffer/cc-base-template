---
title: "Reusable Workflow — Engine (Central Repository)"
tags: [example, reusable-workflow, engine, workflow-call, central]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "examples"
---

# Example: Reusable Workflow Engine (Central Repository)

The engine workflow is the single source of truth for TruffleHog scanning logic in your organisation. It lives in a central security workflows repository (e.g., `your-org/security-workflows`) and is invoked by thin caller workflows in every application repository.

## When to Use This Example

- When deploying organisation-wide TruffleHog enforcement
- When you want to update scanning logic in one place and have it propagate to all repositories
- When you need parameterised scanning behaviour per repository

## The Engine Workflow

```yaml
# your-org/security-workflows/.github/workflows/secret-scan.yml
name: TruffleHog Secret Scan (Reusable)

on:
  workflow_call:
    inputs:
      scan-level:
        description: 'Results to report'
        required: false
        default: 'verified'
        type: string

permissions:
  contents: read

jobs:
  trufflehog:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          persist-credentials: false

      - name: Install TruffleHog
        run: |
          curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh \
            | sh -s -- -b /usr/local/bin

      - name: Scan
        run: |
          TMP="$RUNNER_TEMP/results.json"
          : > "$TMP"
          EXCLUDE="$RUNNER_TEMP/exclude.txt"
          printf '^\.git/\n^vendor/\n^node_modules/\n' > "$EXCLUDE"

          if [ "${{ github.event_name }}" = "pull_request" ]; then
            BASE="${{ github.event.pull_request.base.sha }}"
            HEAD="${{ github.event.pull_request.head.sha }}"
            trufflehog git "file://$GITHUB_WORKSPACE" \
              --since-commit "$BASE" --branch "$HEAD" \
              --results="${{ inputs.scan-level }}" \
              --json --no-update --github-actions \
              --force-skip-binaries --archive-max-size=5MB \
              --exclude-paths "$EXCLUDE" \
              >> "$TMP" || true
          else
            trufflehog git "file://$GITHUB_WORKSPACE" \
              --results="${{ inputs.scan-level }}" \
              --json --no-update --github-actions \
              --force-skip-binaries --archive-max-size=5MB \
              --exclude-paths "$EXCLUDE" \
              >> "$TMP" || true
          fi

          trufflehog filesystem "." \
            --results="${{ inputs.scan-level }}" \
            --json --no-update --github-actions \
            --force-skip-binaries --archive-max-size=5MB \
            --exclude-paths "$EXCLUDE" \
            >> "$TMP" || true

          cp "$TMP" results.json

      - name: Upload findings
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: trufflehog-findings
          path: results.json
          if-no-files-found: ignore

      - name: Fail if secrets found
        run: |
          COUNT=$(jq -c . results.json 2>/dev/null | wc -l | tr -d ' ')
          [ "$COUNT" -eq 0 ] && echo "Clean." && exit 0
          echo "::error::$COUNT secret(s) found."
          exit 1
```

## Key Design Decisions

### `workflow_call` with Inputs

```yaml
on:
  workflow_call:
    inputs:
      scan-level:
        description: 'Results to report'
        required: false
        default: 'verified'
        type: string
```

The `workflow_call` trigger makes this a reusable workflow. The `inputs:` block defines the interface that caller workflows can use to customise behaviour:

- `required: false` with a `default` means callers that do not provide the input get the sensible default.
- `type: string` — valid types are `string`, `boolean`, and `number`.
- Callers cannot override security controls (permissions, SHA pins, the binary version) — only the declared inputs.

To add more inputs, extend this block. For example, to allow callers to pass a config file path:

```yaml
inputs:
  scan-level:
    description: 'Results to report'
    required: false
    default: 'verified'
    type: string
  config-path:
    description: 'Path to .trufflehog/config.yaml relative to repo root'
    required: false
    default: ''
    type: string
```

### Dual Scan Approach (git + filesystem)

The Scan step runs two separate TruffleHog commands:

1. **`trufflehog git`** — walks the git history (or PR diff) looking for secrets introduced in commits. This catches secrets in commit history, not just the current working tree.
2. **`trufflehog filesystem`** — scans the current file tree on disk. This catches secrets in files that were never committed but are present in the working directory during CI (e.g., generated files, downloaded dependencies).

Both commands append to the same results file (`$TMP`). On a pull request, the git scan is constrained to the PR diff using `--since-commit` and `--branch`. On push events, the full branch history is scanned.

The `|| true` after each command prevents the step from failing when TruffleHog exits non-zero due to findings. The actual failure check happens in the dedicated "Fail if secrets found" step.

### Event-Based Branch Targeting

```bash
if [ "${{ github.event_name }}" = "pull_request" ]; then
  BASE="${{ github.event.pull_request.base.sha }}"
  HEAD="${{ github.event.pull_request.head.sha }}"
  trufflehog git ... --since-commit "$BASE" --branch "$HEAD" ...
else
  trufflehog git ... # Scans full branch history
fi
```

This conditional ensures:
- On pull requests: only new commits in the PR are scanned (fast, targeted)
- On push to `main` or scheduled runs: the full branch history is scanned (comprehensive)

### Archive and Binary Limits

```bash
--force-skip-binaries --archive-max-size=5MB
```

- `--force-skip-binaries` — skips binary files that cannot contain plaintext secrets and would slow down the scan significantly.
- `--archive-max-size=5MB` — limits the size of archives (ZIP, JAR, etc.) that TruffleHog will decompress and scan. This prevents the scanner from hanging on large artifact files.

## Granting Access to Caller Repositories

Before any caller in your organisation can reference this workflow, configure repository access:

1. Navigate to the security workflows repository: **Settings > Actions > General**
2. Under "Access", select **"Accessible from repositories in the [your-org] organization"**
3. Save changes

Without this step, calls from other repositories will fail with a permission error even if the workflow file is public.

For cross-organisation access, the calling repository owner must also explicitly allow access in their organisation's Actions settings.

## Version Pinning in Callers

Callers reference this workflow with a branch, tag, or SHA:

```yaml
# Pin to a tag (recommended for stability)
uses: your-org/security-workflows/.github/workflows/secret-scan.yml@v1.2.0

# Pin to a specific SHA (most secure)
uses: your-org/security-workflows/.github/workflows/secret-scan.yml@a1b2c3d4e5f6...

# Track a branch (easiest to keep current, least deterministic)
uses: your-org/security-workflows/.github/workflows/secret-scan.yml@main
```

Tag this workflow file with semantic versions when making breaking changes to inputs, following conventional versioning to allow callers to pin to a major version.

## See Also

- [reusable-caller-workflow.md](./reusable-caller-workflow.md) — The thin caller workflow that invokes this engine
- [../patterns/reusable-workflow-pattern.md](../patterns/reusable-workflow-pattern.md) — Pattern explanation and deployment model
- [trufflehog-pr-diff-scan-workflow.md](./trufflehog-pr-diff-scan-workflow.md) — Standalone PR scan with similar JSON output patterns
