---
title: "Shallow Clone Git History Issues"
tags: [troubleshooting, shallow-clone, fetch-depth, git-history]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "troubleshooting"
---

# Troubleshooting: Shallow Clone Git History

## Symptoms

- TruffleHog completes in under 1 second for a large repository (suspiciously fast)
- TruffleHog reports scanning 0 or 1 commits
- TruffleHog exits 0 (clean) on a repository known to contain secrets in history
- The scan output shows no files or commits examined
- Error messages about missing commits or unreachable refs: `fatal: ambiguous argument: unknown revision`

---

## Root Cause

GitHub Actions' `actions/checkout` defaults to `--depth=1`, creating a shallow clone that contains only the HEAD commit. TruffleHog's `git` subcommand scans git history, but with a shallow clone there is only one commit in that history. Any secrets in previous commits are invisible to the scan.

---

## The Fix

Add `fetch-depth: 0` to your checkout step:

```yaml
- name: Checkout
  uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
  with:
    fetch-depth: 0             # REQUIRED — fetch full history
    persist-credentials: false
```

`fetch-depth: 0` instructs Git to fetch all branches and all history. Without it, TruffleHog sees at most one commit regardless of how many commits are in the repository.

---

## Diagnosing the Issue

Confirm you have a shallow clone with these commands in your workflow:

```bash
# Check how many commits are visible:
git rev-list --count HEAD
# If this returns "1", the clone is shallow

# Check if a specific SHA exists (e.g., the before SHA on a push event):
git cat-file -t ${{ github.event.before }}
# "fatal: Not a valid object name" confirms the SHA is not in the clone
```

After fixing with `fetch-depth: 0`:

```bash
$ git rev-list --count HEAD
4827   # full history visible
```

---

## Edge Cases

### Squash Merge

`github.event.before` may reference a now-orphaned SHA if the branch was squash-merged and the source branch deleted. A full clone (`fetch-depth: 0`) ensures all reachable commits are available, but the specific SHA may still not exist if it was never part of the main branch history.

### New Branch Push (Before SHA = Zeros)

When a branch is pushed for the first time, `github.event.before` is `0000000000000000000000000000000000000000`. This is expected behavior, not an error. The TruffleHog action detects the all-zeros before SHA and performs a full scan of the branch from its initial commit. This is correct.

### Force Push

If the branch was rewritten with a force push, `github.event.before` may reference a commit that no longer exists in the branch's history. With `fetch-depth: 0`, if the old commit was ever reachable from any ref, it may still be available. With a shallow clone, it definitely will not be.

---

## Performance vs Correctness Trade-off

For very large repositories, `fetch-depth: 0` can significantly increase clone time:

| Repository size | Shallow clone | Full clone |
|-----------------|--------------|-----------|
| 100 commits     | < 1s         | < 1s      |
| 10,000 commits  | < 1s         | 5–30s     |
| 100,000+ commits | < 1s        | 1–10 min  |

### Partial Depth Optimization for PR/Push Triggers

For PR and push scans (where only recent commits are relevant), a partial depth often provides sufficient coverage without the full clone cost:

```yaml
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
  with:
    # For PRs/push: fetch enough history to cover the diff
    # For schedule/dispatch: fetch all history
    fetch-depth: ${{ (github.event_name == 'schedule' || github.event_name == 'workflow_dispatch') && '0' || '100' }}
```

**Trade-off**: A depth of 100 covers most PR diffs but will miss secrets introduced more than 100 commits ago. Use `fetch-depth: 0` only for scheduled full-history scans to avoid the performance cost on every push.

```yaml
# .github/workflows/secret-scan.yml
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
  with:
    fetch-depth: 500  # last 500 commits; pair with full-clone scheduled scan
```

---

## See Also

- [../guides/shallow-clone-fix.md](../guides/shallow-clone-fix.md) — Complete explanation and fix workflow
- [../patterns/full-history-scan.md](../patterns/full-history-scan.md) — Full history scan pattern and timing
- [../patterns/diff-only-scan.md](../patterns/diff-only-scan.md) — Keeping PR scans fast with shallow history
