---
title: "Full History Scan"
tags: [pattern, full-history, schedule, workflow-dispatch, audit]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "patterns"
---

# Pattern: Full History Scan

## Problem

Push and PR scans only cover new commits. A repository may have secrets committed months or years ago that were never detected. An organisation adopting TruffleHog for the first time has no coverage of historical commits.

## Solution

Run TruffleHog with a `schedule` or `workflow_dispatch` trigger and no base/head range, forcing a full scan of all git history.

## When to Use This Pattern

- When first adopting TruffleHog — run a full history scan before adding ongoing PR/push scans
- Weekly scheduled audits to catch secrets that may have slipped through incremental scans
- When a security incident triggers a mandatory full audit
- When adding new detectors — existing history must be rescanned with the new patterns

## How It Works

When TruffleHog's `base` and `head` inputs are empty (as they are on `schedule` and `workflow_dispatch` triggers), it performs a full history scan: every commit from the repository's initial commit to HEAD is scanned.

The official action detects empty base/head and falls back to full-history mode automatically. If using the binary directly, simply omit `--since-commit` and `--branch`.

## Scheduled Full History Scan

```yaml
name: Weekly Full History Secret Scan
on:
  schedule:
    - cron: '0 2 * * 0'   # Every Sunday at 02:00 UTC
  workflow_dispatch: {}     # Allow manual trigger

permissions: {}

jobs:
  full-scan:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
        with:
          fetch-depth: 0
      - uses: trufflesecurity/trufflehog@v3.93.4
        with:
          extra_args: --results=verified,unknown --json
```

## Performance Considerations

Full history scans on large repositories can take a long time. Optimise with:

```yaml
- uses: trufflesecurity/trufflehog@v3.93.4
  with:
    extra_args: >-
      --results=verified,unknown
      --force-skip-binaries
      --archive-max-size=5MB
      --concurrency=4
```

- `--force-skip-binaries` — skip compiled binaries and media files (not useful for secret detection)
- `--archive-max-size=5MB` — skip large archives
- `--concurrency=4` — parallel detection goroutines

For very large repositories, see [../troubleshooting/large-repo-performance.md](../troubleshooting/large-repo-performance.md).

## Using workflow_dispatch for On-Demand Audits

The `workflow_dispatch` trigger lets you run a full scan on demand from the GitHub Actions UI or via the API:

```bash
# Trigger via GitHub CLI
gh workflow run "Weekly Full History Secret Scan" --repo org/repo
```

This is useful for:
- Post-incident audits
- Auditing before a major release
- Testing a new `config.yaml` against all history

## Output and Alerting

For scheduled scans, pipe findings to a step summary, upload as an artifact for the audit trail, and post a summary:

```yaml
- name: Run full history scan
  id: scan
  run: |
    trufflehog git \
      --force-skip-binaries \
      --archive-max-size=5MB \
      --fail \
      --json \
      file://"$GITHUB_WORKSPACE" 2>/dev/null | tee /tmp/findings.ndjson || true

- name: Post summary to step
  if: always()
  run: |
    COUNT=$(wc -l < /tmp/findings.ndjson)
    echo "## Full History Scan Results" >> $GITHUB_STEP_SUMMARY
    echo "Total findings: $COUNT" >> $GITHUB_STEP_SUMMARY
    if [ "$COUNT" -gt "0" ]; then
      echo "### Verified Findings" >> $GITHUB_STEP_SUMMARY
      cat /tmp/findings.ndjson | jq -r \
        'select(.Verified==true) | "\(.DetectorName): \(.SourceMetadata.Data.Git.file):\(.SourceMetadata.Data.Git.line)"' \
        >> $GITHUB_STEP_SUMMARY
    fi

- name: Upload findings as artifact
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: trufflehog-full-history-${{ github.run_id }}
    path: /tmp/findings.ndjson
    retention-days: 90
```

Uploading the raw NDJSON as an artifact preserves the complete finding record for the audit trail, including metadata such as commit SHA, file path, line number, and detector name. The `retention-days: 90` setting keeps findings available for quarterly reviews without indefinite storage cost.

## Limitations

- Does not retroactively prevent merges — it reports findings after the fact
- On repositories with many years of history, may approach GitHub Actions' 6-hour job time limit
- Duplicate findings within a run are suppressed; across runs you will see the same findings repeatedly until credentials are revoked

## See Also

- [ci-scan-on-push.md](./ci-scan-on-push.md) — For catching new secrets on every push
- [ci-scan-on-pull-request.md](./ci-scan-on-pull-request.md) — For blocking merges
- [../troubleshooting/large-repo-performance.md](../troubleshooting/large-repo-performance.md) — Performance tuning for large repositories
- [../examples/trufflehog-git-scan-workflow.md](../examples/trufflehog-git-scan-workflow.md) — Complete workflow combining push, PR, and scheduled scans
- [../guides/handling-confirmed-leak.md](../guides/handling-confirmed-leak.md) — Responding to findings
