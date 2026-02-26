---
title: "Shallow Clone Fix — fetch-depth: 0"
tags: [guide, shallow-clone, fetch-depth, git-history, github-actions, base-sha, new-branch]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "guides"
---

# Guide: Shallow Clone Fix — fetch-depth: 0

## The Problem

Default `actions/checkout` uses `fetch-depth: 1` (a shallow clone that fetches only the single most recent commit). TruffleHog's `git` subcommand needs the full commit history to scan historical commits. With a shallow clone, the BASE SHA from `github.event.before` or `github.event.pull_request.base.sha` does not exist locally, causing an empty scan or a scan failure.

Symptoms of the shallow clone problem:
- TruffleHog exits 0 on a repository that contains known secrets
- The scan completes in under 1 second for a large repository
- TruffleHog output mentions scanning 0 or 1 commits
- Error: `fatal: ambiguous argument 'SHA...': unknown revision or path not in the working tree`

---

## The Fix

Add `fetch-depth: 0` and `persist-credentials: false` to the `actions/checkout` step:

```yaml
# WRONG — shallow clone, TruffleHog misses almost all history
- uses: actions/checkout@v4

# CORRECT — full history, TruffleHog can scan all commits
- uses: actions/checkout@v4
  with:
    fetch-depth: 0          # Clone full history
    persist-credentials: false  # Security hardening
```

`fetch-depth: 0` tells Git to fetch all branches and all history — equivalent to `git clone` without `--depth`. `persist-credentials: false` prevents the GitHub token from being stored in `.git/config` on the runner.

Using the SHA-pinned version (recommended for production):

```yaml
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
  with:
    fetch-depth: 0
    persist-credentials: false
```

---

## Why the Official TruffleHog Action Still Needs This

The official action handles base/head SHA computation automatically, but it cannot scan commits that were not fetched. The action mounts the workspace into a Docker container. If the workspace only has one commit (shallow clone), the `--since-commit` range has no history to scan.

All official TruffleHog action documentation and examples include `fetch-depth: 0`. The checkout configuration is independent of the action configuration — you must set it explicitly.

---

## Performance Impact

For diff scans (push, PR), the performance impact of `fetch-depth: 0` depends on repository size:

| Repository Size | fetch-depth: 1 | fetch-depth: 0 |
|----------------|---------------|---------------|
| Small (<10K commits) | < 1s | Negligible (seconds) |
| Medium (10K–100K commits) | < 1s | 10–30 seconds |
| Large (100K+ commits) | < 1s | 1–5 minutes |

For PR and push scans where TruffleHog only examines a small diff, the extra clone time is worth the correctness guarantee.

### Partial Fetch Optimisation (For Very Large Repositories)

If full clone time is impractical, use a limited fetch depth. This trades correctness for performance:

```yaml
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
  with:
    fetch-depth: 100  # Last 100 commits only
```

**Trade-off**: secrets committed beyond the depth limit will not be detected. Use `fetch-depth: 0` for scheduled full-history scans and a limited depth for PR/push scans:

```yaml
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
  with:
    fetch-depth: ${{ github.event_name == 'schedule' && '0' || '100' }}
    persist-credentials: false
```

---

## Base SHA Edge Case (New Branch Pushes)

When pushing a new branch for the first time, `github.event.before` is set to all zeros (`0000000000000000000000000000000000000000`). The official TruffleHog action handles this by setting `BASE=""`, which triggers a full scan of the branch.

If you are using the binary install instead of the official action, you must handle this case manually:

```bash
if [ "${{ github.event.before }}" = "0000000000000000000000000000000000000000" ]; then
  # New branch — scan full branch history
  trufflehog git "file://$GITHUB_WORKSPACE" --results=verified --json
else
  # Existing branch — scan only the diff
  trufflehog git "file://$GITHUB_WORKSPACE" \
    --since-commit "${{ github.event.before }}" \
    --branch "${{ github.event.after }}" \
    --results=verified --json
fi
```

Without this check, TruffleHog will fail when it cannot resolve the all-zeros SHA as a valid git reference.

---

## Full Correct Checkout Configuration

```yaml
- name: Checkout
  uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
  with:
    fetch-depth: 0             # Required: full history for TruffleHog git scan
    persist-credentials: false # Security: do not store token in .git/config
```

---

## See Also

- [../troubleshooting/shallow-clone-git-history.md](../troubleshooting/shallow-clone-git-history.md) — Diagnosing shallow clone symptoms in more detail
- [../patterns/diff-only-scan.md](../patterns/diff-only-scan.md) — How --since-commit and --branch enable diff-only scanning
- [../examples/trufflehog-git-scan-workflow.md](../examples/trufflehog-git-scan-workflow.md) — Complete workflow with correct checkout configuration
- [../glossary.md](../glossary.md) — fetch-depth: 0 and BASE SHA definitions
