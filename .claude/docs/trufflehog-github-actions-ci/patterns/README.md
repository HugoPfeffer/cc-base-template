---
title: "Patterns — TruffleHog GitHub Actions CI"
tags: [patterns, navigation]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "patterns"
---

# Patterns

Patterns describe *when and why* to use a particular approach. Each pattern is a recurring solution to a specific problem in CI secret scanning.

## Files

| File | Problem It Solves |
|------|------------------|
| [ci-scan-on-push.md](./ci-scan-on-push.md) | Detect secrets in every commit that lands on a protected branch |
| [ci-scan-on-pull-request.md](./ci-scan-on-pull-request.md) | Block merges that introduce secrets |
| [full-history-scan.md](./full-history-scan.md) | Audit the complete repository history for secrets committed at any point |
| [diff-only-scan.md](./diff-only-scan.md) | Limit scan to only the changed commits in a PR to reduce cost and noise |
| [reusable-workflow-pattern.md](./reusable-workflow-pattern.md) | Enforce scanning consistently across all organisation repositories |
| [pre-commit-to-ci-layered-defense.md](./pre-commit-to-ci-layered-defense.md) | Give developers early feedback while keeping CI as the enforcement gate |
| [binary-install-vs-official-action.md](./binary-install-vs-official-action.md) | Choose between the install script and the official Docker-based action |

## Choosing the Right Pattern

```
Do you need to block PRs? ─────────► ci-scan-on-pull-request
                                        + diff-only-scan (for speed)

Do you need to catch pushes to main? ► ci-scan-on-push

Do you have historical debt to audit? ► full-history-scan

Do you manage 5+ repositories? ─────► reusable-workflow-pattern

Do you want faster developer feedback? ► pre-commit-to-ci-layered-defense

Do you need custom exit-code logic? ─► binary-install-vs-official-action
```

Most production deployments use **all three trigger patterns together**: PR scan + push scan + scheduled full-history.

## See Also

- [../concepts/README.md](../concepts/README.md) — Concepts that underpin these patterns
- [../examples/README.md](../examples/README.md) — Complete code for each pattern
