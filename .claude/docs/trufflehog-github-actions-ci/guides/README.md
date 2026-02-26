---
title: "Guides — TruffleHog GitHub Actions CI"
tags: [guides, navigation, installation, template-repository, detectors, false-positives, incident-response, shallow-clone]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "guides"
---

# Guides

Step-by-step how-to instructions for common TruffleHog tasks. Each guide is focused on a single topic and includes copy-paste ready code blocks.

## Files

| File | What It Teaches |
|------|----------------|
| [local-trufflehog-installation.md](./local-trufflehog-installation.md) | Install TruffleHog using any of the five methods (install script, official action, Docker, Homebrew, pre-commit) with version pinning and a comparison table |
| [creating-template-repository.md](./creating-template-repository.md) | Set up a central org repository with a reusable engine workflow, starter template, branch protection, CODEOWNERS, and Dependabot (9 steps) |
| [configuring-detectors.md](./configuring-detectors.md) | Control built-in detectors via CLI flags, specify detector versions, and add custom detectors via config.yaml with entropy, exclusions, and verification webhooks |
| [suppressing-false-positives.md](./suppressing-false-positives.md) | Suppress false positives using all seven available methods, from inline comments to `--force-skip-binaries`, with a decision table |
| [handling-confirmed-leak.md](./handling-confirmed-leak.md) | Step-by-step incident response for a verified secret finding: revoke first, assess blast radius, remove from code, decide on history rewrite, deploy with least privilege |
| [shallow-clone-fix.md](./shallow-clone-fix.md) | Understand why `fetch-depth: 0` is required, performance impact by repository size, partial fetch optimisation, and the new-branch base SHA edge case |

## Quick Navigation

- **Setting up for the first time?** Start with [local-trufflehog-installation.md](./local-trufflehog-installation.md)
- **Deploying org-wide?** See [creating-template-repository.md](./creating-template-repository.md)
- **Too much noise?** See [suppressing-false-positives.md](./suppressing-false-positives.md)
- **Found a real secret?** See [handling-confirmed-leak.md](./handling-confirmed-leak.md)
- **Scan not working in CI?** See [shallow-clone-fix.md](./shallow-clone-fix.md)

## See Also

- [../troubleshooting/README.md](../troubleshooting/README.md) — Diagnosing specific error conditions
- [../examples/README.md](../examples/README.md) — Ready-to-use workflow YAML and config files
- [../patterns/README.md](../patterns/README.md) — Architectural patterns and design decisions
