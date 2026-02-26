---
title: "Troubleshooting — TruffleHog GitHub Actions CI"
tags: [troubleshooting, navigation]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "troubleshooting"
---

# Troubleshooting

Common problems and their solutions when running TruffleHog in GitHub Actions.

## Files

| File | Problem Addressed |
|------|------------------|
| [false-positives-common-cases.md](./false-positives-common-cases.md) | Specific false positive sources (test fixtures, docs, vendor code, rotation scripts, high-entropy generated content) and how to handle each |
| [shallow-clone-git-history.md](./shallow-clone-git-history.md) | Scan misses commits, completes suspiciously fast, or reports 0 findings on a repo known to have secrets in history |
| [runner-permission-errors.md](./runner-permission-errors.md) | Docker not found, permission denied, GITHUB_TOKEN errors, self-hosted runner security risks |
| [verification-rate-limits.md](./verification-rate-limits.md) | Many `unknown` results; GitHub API rate limiting; how to provide authentication tokens |
| [large-repo-performance.md](./large-repo-performance.md) | Scan takes too long, times out at 6-hour limit, or causes OOM; binary skipping, archive size limits, concurrency tuning |

## Quick Diagnosis

| Symptom | Likely Cause | File |
|---------|-------------|------|
| Scan exits 0 immediately | Shallow clone — only HEAD commit visible | [shallow-clone-git-history.md](./shallow-clone-git-history.md) |
| Many `unknown` results | Verification rate limiting | [verification-rate-limits.md](./verification-rate-limits.md) |
| Scan times out (6h limit) | Large repository — full history scan on every PR | [large-repo-performance.md](./large-repo-performance.md) |
| `docker: command not found` | Docker not installed on self-hosted runner | [runner-permission-errors.md](./runner-permission-errors.md) |
| `docker: permission denied` | Runner user not in docker group | [runner-permission-errors.md](./runner-permission-errors.md) |
| Same finding on every PR | False positive in base branch; must be suppressed there | [false-positives-common-cases.md](./false-positives-common-cases.md) |
| Findings in `vendor/` or `node_modules/` | Third-party code not excluded | [false-positives-common-cases.md](./false-positives-common-cases.md) |
| Reusable workflow not accessible | Engine repo not configured for cross-org access | [runner-permission-errors.md](./runner-permission-errors.md) |
| OOM / runner killed during scan | Large archives being decompressed | [large-repo-performance.md](./large-repo-performance.md) |

## See Also

- [../guides/README.md](../guides/README.md) — Step-by-step guides for common tasks
- [../concepts/detection-engine.md](../concepts/detection-engine.md) — Understanding verification states (`verified`, `unverified`, `unknown`)
- [../guides/suppressing-false-positives.md](../guides/suppressing-false-positives.md) — All suppression methods in detail
