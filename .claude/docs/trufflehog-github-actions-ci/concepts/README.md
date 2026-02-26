---
title: "Concepts — TruffleHog GitHub Actions CI"
tags: [concepts, navigation]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "concepts"
---

# Concepts

Core concepts and fundamentals for understanding TruffleHog and GitHub Actions secret scanning.

## What This Section Covers

The concepts section explains *how things work* — the underlying mechanics, design decisions, and mental models needed to use TruffleHog effectively in CI.

## Files

| File | Description |
|------|-------------|
| [trufflehog-architecture.md](./trufflehog-architecture.md) | TruffleHog v3 engine pipeline, Go rewrite, AGPL-3.0, scan subcommands, CLI flags |
| [detection-engine.md](./detection-engine.md) | Aho-Corasick pre-filter, regex matching, verification flow, 700+ detectors, JSON output schema |
| [github-actions-security-model.md](./github-actions-security-model.md) | Permissions, triggers, token scoping, SHA pinning, security hardening, real incidents |
| [template-repository-model.md](./template-repository-model.md) | Reusable workflows vs starter templates, versioning, org access configuration |
| [secret-scanning-fundamentals.md](./secret-scanning-fundamentals.md) | Secret types, detection methods, verification states, false positives |

## Reading Order

If you are new to this domain, read concepts in this order:

1. [secret-scanning-fundamentals.md](./secret-scanning-fundamentals.md) — understand what you are looking for
2. [trufflehog-architecture.md](./trufflehog-architecture.md) — understand the tool's structure
3. [detection-engine.md](./detection-engine.md) — understand how detection works in detail
4. [github-actions-security-model.md](./github-actions-security-model.md) — understand the environment it runs in
5. [template-repository-model.md](./template-repository-model.md) — understand organisation-scale deployment

## See Also

- [../patterns/README.md](../patterns/README.md) — apply these concepts as patterns
- [../glossary.md](../glossary.md) — definitions for unfamiliar terms
